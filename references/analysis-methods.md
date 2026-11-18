# 空间分析方法

本文件把 sdsr 与 rspatial 分析篇的方法整理成可操作流程。它负责方法选择、输入输出和验收；统计理论查原书。

本机未安装 `gstat`、`spdep`、`spatialreg`、`spatstat.explore`、`blockCV` 等可选包。以下代码是流程骨架，运行前先装对应包。

## 0 三条硬约束

1. **投影先行。** 距离、面积、缓冲、变差函数先用等积或等距投影。实测：卢森堡在 EPSG:32632 为 2565.5 km²，在错带 EPSG:32617 为 4379.6 km²，偏大 71%。
2. **验证方式决定结论。** 随机 5 折中 26.2% 的测试点距训练点不足 1 km；按坐标切带的空间 5 折为 0%。两种分数要并列报告。
3. **格网单独验收。** 回写前断言 CRS、分辨率、范围、行列数四项。

## 1 任务选择树

```text
结果是点事件吗？
  是 -> 点模式：强度、最近邻、K/L 函数、聚类/排斥
  否 -> 结果是连续场吗？
          是 -> 插值/地统计：IDW、趋势面、克里金、条件模拟
          否 -> 结果是面单元吗？
                 是 -> 面数据：邻接、空间权重、Moran、LISA、空间回归
                 否 -> 结果是栅格预测/分类吗？
                        是 -> 空间交叉验证 + terra::predict()
                        否 -> 先明确分析单元
```

先定义支持（support）：点、像元、面、时间切片。支持不一致时，先做面积加权或重采样。

点模式与地统计的分界：问“无点的位置是否也属观测”。属观测（该处确无事件）走点模式；不属观测（该处未采样）走地统计。窗口与强度只在点模式下有意义。

## 2 点模式

### 2.1 输入

- 点事件坐标。
- 研究窗口（边界）。
- 可选的标记（类型、强度）。

```r
library(sf)
library(spatstat.geom)
library(spatstat.explore)

pts <- read_sf("events.gpkg")
coords <- st_coordinates(pts)
window <- owin(
  xrange = range(coords[, 1]),
  yrange = range(coords[, 2])
)
pattern <- ppp(coords[, 1], coords[, 2], window = window)
```

窗口决定边界效应。用矩形窗口方便，但真实研究区边界更合适。算强度前先投影，窗口面积与点坐标使用同一单位。若把 `sf` 转 `ppp`，CRS 会丢失；回写时用 `st_set_crs()` 补回。

### 2.2 强度与最近邻

```r
intensity(pattern)
nndist(pattern)
```

强度是单位面积事件数。报告时写清面积单位和窗口。

### 2.3 K/L 函数

```r
k <- Kest(pattern, correction = "border")
plot(k)

envelope_k <- envelope(
  pattern,
  fun = Kest,
  nsim = 99,
  correction = "border"
)
```

判断：

- 观测曲线高于包络：聚集。
- 观测曲线低于包络：排斥。
- 落在包络内：与完全随机零模型无显著差异。

`nsim` 至少 99，正式分析用 999 或更多。边界校正方法要写进结果。

### 2.4 标记点与协变量

- 标记点：`ppp(..., marks = )`。
- 线网络：`lpp()`。
- 协变量：`rhohat()` 或点过程模型。

不要用普通回归替代点过程模型；事件位置与强度之间的关系需要专门模型。

## 3 插值

### 3.1 选择方法

| 方法 | 适用 | 关键假设 |
|---|---|---|
| 最近邻 | 快速分类/填洞 | 局部同质 |
| IDW | 连续场、样本较密 | 距离越近越相似 |
| 趋势面 | 大尺度平滑 | 全局多项式 |
| 薄板样条 | 平滑连续面 | 平滑度参数 |
| 普通克里金 | 有空间自相关 | 平稳、已知变差函数 |
| 泛克里金 | 有趋势 | 趋势 + 残差变异 |
| 条件模拟 | 需要不确定性/多实现 | 变差函数模型 |

### 3.2 IDW

```r
library(gstat)
library(sf)

points <- read_sf("points.gpkg") |>
  st_transform(32633)
grid <- st_as_stars(st_bbox(points), dx = 500, dy = 500)
stopifnot(st_crs(grid) == st_crs(points))

idw_result <- idw(
  formula = value ~ 1,
  locations = points,
  newdata = grid,
  idp = 2
)
```

`idp` 用交叉验证选择，不要凭默认值直接交付。搜索半径和最大邻居数要写清。

### 3.3 薄板样条

```r
library(fields)

tps <- Tps(
  x = st_coordinates(points),
  Y = points$value
)
# grid_coordinates 是目标格网像元中心的 x/y 矩阵
prediction <- predict(tps, newdata = grid_coordinates)
```

样条对异常值敏感；先检查分布和离群点。

## 4 地统计

### 4.1 工作流

```text
检查坐标与单位
  -> 计算样本变差函数
  -> 拟合变差函数模型（块金、基台、变程）
  -> 交叉验证
  -> 克里金预测
  -> 输出预测与标准差
```

### 4.2 变差函数

```r
library(gstat)

vg <- variogram(value ~ 1, data = points)
plot(vg)

model <- vgm(
  psill = 1,
  model = "Sph",
  range = 10000,
  nugget = 0.1
)
fit <- fit.variogram(vg, model = model)
plot(vg, fit)
```

检查：

- 块金是否过大。块金/基台超过 0.5 时空间结构弱。
- 变程是否超过研究区尺度，或超过最大 lag 的一半。
- 各向异性是否需要建模。
- 拟合失败时不要强行套模型。
- `vgm(psill, model, range, nugget)` 的参数顺序写错不报错，只给错结果。
- 每个距离区间至少 30 对点；点间距大于变程时拟合退化。

### 4.3 克里金

```r
kriged <- krige(
  formula = value ~ 1,
  locations = points,
  newdata = grid,
  model = fit
)
```

输出通常含预测值和方差。报告：

- 变差函数模型与参数。
- 交叉验证的 RMSE、偏差。
- 预测范围是否超出样本支持；超出样本协变量范围的位置置 NA 或单列。
- 外推区域的不确定性。
- 条件模拟设 `nmax`，否则邻域会随实现扩大，内存迅速增长。

### 4.4 交叉验证

```r
krige_cv <- krige.cv(
  formula = value ~ 1,
  locations = points,
  model = fit,
  nfold = 10
)
sqrt(mean(krige_cv$residual^2))
```

随机折交叉验证会低估空间误差。正式比较用空间折或留一空间块。

## 5 面数据

### 5.1 邻接与权重

```r
library(spdep)

nb <- poly2nb(polygons, queen = TRUE)
listw <- nb2listw(nb, style = "W", zero.policy = TRUE)
```

检查：

- 是否有孤岛（`card(nb) == 0`）。
- 权重是否行标准化。
- 邻接定义（Queen/Rook）是否与研究问题一致。

### 5.2 全局空间自相关

```r
moran.test(polygons$value, listw, zero.policy = TRUE)
geary.test(polygons$value, listw, zero.policy = TRUE)
```

报告 Moran's I、期望值、方差、p 值和置换次数。

### 5.3 局部空间自相关

```r
local <- localmoran(polygons$value, listw, zero.policy = TRUE)
```

局部结果需要多重比较校正。LISA 聚类图要标出 High-High、Low-Low、High-Low、Low-High。

实测量级（2495 个单元）：未校正时约 15% 的局部 p 值小于 0.005；FDR 校正后约 6%，BY 约 2.5%，Bonferroni 约 1.5%。报告时写清校正方法和 cutoff，措辞用“值得关注”，不写“显著热点”。

## 6 空间回归

### 6.1 先做非空间基线

```r
base <- lm(y ~ x1 + x2, data = polygons)
lm.morantest(base, listw)
```

残差仍有空间自相关时，考虑空间滞后或空间误差模型。

### 6.2 空间滞后与空间误差

```r
library(spatialreg)

lag_model <- lagsarlm(
  formula = y ~ x1 + x2,
  data = polygons,
  listw = listw
)

error_model <- errorsarlm(
  formula = y ~ x1 + x2,
  data = polygons,
  listw = listw
)
```

比较：

- AIC、logLik。
- 残差空间自相关。
- 系数解释：空间滞后模型的系数含反馈效应，不能按普通最小二乘解释。

### 6.3 地理加权回归

```r
library(spgwr)

bandwidth <- gwr.sel(y ~ x1 + x2, data = polygons, adapt = TRUE)
gwr_model <- gwr(
  formula = y ~ x1 + x2,
  data = polygons,
  adapt = bandwidth
)
```

GWR 输出局部系数。报告带宽、核函数、局部 R² 和系数分布。局部系数图要防止过度解读。

## 7 空间交叉验证

### 7.1 随机折的问题

随机折会让相邻样本同时进入训练集和测试集，导致：

- 空间自相关泄漏。
- 测试误差偏低。
- 模型选择偏向复杂模型。

实测（400 个点，EPSG:32632）：随机 5 折的最小测试-训练距离为 75 m，1 km 内有训练点的测试点占 26.2%；按 x 分位切带的空间 5 折分别为 1433 m 和 0%。报告 CV 分数时同时报最小距离与泄漏占比。

### 7.2 空间折

```r
library(blockCV)

folds <- cv_spatial(
  x = points,
  size = 10000,
  k = 5,
  selection = "random",
  progress = FALSE
)
```

或用 `mlr3spatiotempcv` 的 `spcv_block`、`spcv_coords`。

规则：

- 训练块与测试块之间留缓冲区，缓冲宽度取变程的 1 到 2 倍；没有变程时取平均采样间距的 2 倍。
- 分类任务按类别分层。
- 时间序列按时间切分，避免未来数据进入训练。
- 交叉验证的折数、块大小、缓冲区写进结果。
- 超参数调优放在空间折内层，否则调优过程本身泄漏。

## 8 结果回写

### 8.1 面数据回写

```r
polygons$prediction <- predict(model, newdata = polygons)
st_write(polygons, "output/predictions.gpkg")
```

### 8.2 栅格预测

```r
library(terra)

r <- rast("predictors.tif")
prediction <- predict(r, model, na.rm = TRUE)
writeRaster(prediction, "output/prediction.tif", overwrite = TRUE)
```

检查：

- 训练列名与栅格层名一致。
- 因子水平一致。
- 预测范围在训练支持内。
- CRS、范围、分辨率与输入一致。
- `st_extract()` 只接受 stars；传 SpatRaster 会报 no applicable method。需要从 terra 栅格取点时用 `terra::extract()`。

### 8.3 不确定性

- 克里金输出预测方差。
- 条件模拟输出多个实现，汇总分位数。
- 机器学习用袋外误差、交叉验证或分位数回归。
- 外推区域单独标注，不把预测当观测。

## 9 常见错误

| 症状 | 原因 | 处理 |
|---|---|---|
| Moran's I 很高但模型无意义 | 忽略趋势/协变量 | 先做非空间基线，再看残差 |
| 交叉验证 RMSE 过低 | 随机折泄漏 | 改空间折 + 缓冲区 |
| 克里金预测异常 | 变差函数外推 | 限制预测范围，检查变程 |
| 点模式全显著 | 窗口或边界校正不当 | 用真实窗口和边界校正 |
| 局部系数图过度解读 | 多重比较未校正 | 校正 p 值，报告不确定性 |
| 面数据结果与栅格不一致 | 支持不同 | 明确支持，做面积加权或重采样 |
| 经纬度距离错 | 平面公式用于经纬度 | 投影或用球面距离 |
| 投影带选错 | 面积整体偏大或偏小 | 按经度选带；跨带用等积投影 |
| `st_extract()` 报 no applicable method | 传入 SpatRaster | 先 `st_as_stars()`，或改用 `terra::extract()` |

## 10 来源索引

- `sdsr/10-Models.qmd`
- `sdsr/11-PointPattern.qmd`
- `sdsr/12-Interpolation.qmd`
- `sdsr/13-Geostatistics.qmd`
- `sdsr/14-Areal.qmd`
- `sdsr/15-Measures.qmd`
- `sdsr/16-SpatialRegression.qmd`
- `sdsr/17-Econometrics.qmd`
- `geocompr/12-spatial-cv.Rmd`
- `rspatial-terra-web/source/analysis/_R/2-scale_distance.rmd`
- `rspatial-terra-web/source/analysis/_R/4-interpolation.rmd`
- `rspatial-terra-web/source/analysis/_R/6-local_regression.rmd`
- `rspatial-terra-web/source/analysis/_R/7-spregression.rmd`
- `rspatial-terra-web/source/analysis/_R/8-pointpat.rmd`
- `rspatial-terra-web/source/rosu/_R/Chapter7.rmd`
- `rspatial-terra-web/source/rosu/_R/Chapter8.rmd`
- `rspatial-terra-web/source/rosu/_R/Chapter10.rmd`
