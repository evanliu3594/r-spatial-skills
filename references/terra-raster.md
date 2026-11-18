# terra 大栅格操作

本文件用于超大栅格、重计算、磁盘工作流。示例在本机 terra 1.9.50 实测。

## 1 对象与状态

`SpatRaster` 保存格网元数据和指向数据的指针。数据可以在内存、临时文件或源文件。

```r
library(terra)

r <- rast("input.tif")
hasValues(r)    # 有像元值吗；空壳参与运算会报错
inMemory(r)     # 值在内存中吗
sources(r)      # 数据来自哪个文件
datatype(r)     # 磁盘数据类型；内存对象常为 ""
NAflag(r)       # 文件中的 NA 标记
ncell(r)        # 总像元数
nlyr(r)         # 波段数
res(r)          # 分辨率
ext(r)          # 范围
crs(r)          # CRS
names(r)        # 波段名
```

`inMemory(r) == FALSE` 不表示数据已经全部读入。terra 只在需要时按块读取。`sources(r)` 为空或指向临时文件时，要检查输出是否已经落盘。`sources(x, bands = TRUE)` 可逐层列出文件与波段。

## 2 读取与写出

### 2.1 读取

```r
# 本地文件
r <- rast("input.tif")

# 多文件拼接为一个虚拟栅格
r <- vrt(c("tile_01.tif", "tile_02.tif"), "output/tiles.vrt")

# 只读指定波段
r <- rast("multiband.tif")[[c(1, 4, 5)]]

# 只读窗口：先用 ext() 裁剪，避免读取整幅
r_window <- crop(rast("big.tif"), ext(100000, 120000, 4000000, 4020000))

# 远程文件：GDAL 前缀；需要网络与驱动支持
r_remote <- rast("/vsicurl/https://example.com/file.tif")
```

`vrt()` 只写索引，不复制像元。原始瓦片必须保留，移动或删除后 VRT 失效。

### 2.2 写出

```r
writeRaster(
  r,
  "output/result.tif",
  overwrite = TRUE,
  datatype = "FLT4S",
  gdal = c("COMPRESS=DEFLATE", "TILED=YES")
)
```

COG：

```r
writeRaster(
  r,
  "output/result_cog.tif",
  filetype = "COG",
  overwrite = TRUE,
  gdal = c("COMPRESS=DEFLATE", "OVERVIEWS=AUTO")
)
```

`OVERVIEWS=AUTO` 生成金字塔；不写时文件可能是 COG 布局但没有概览层。`describe("output/result_cog.tif")` 等价于 `gdalinfo`，可核对 `LAYOUT=COG`、块大小与 overviews。

选择数据类型：

- 连续值用 `FLT4S` 或 `FLT8S`。
- 分类值用 `INT1U`、`INT2U` 或 `INT4U`，确保编码范围足够。
- `datatype` 留空时 terra 可能按值域推断为 `INT4U`；显式给 `datatype=` 控制文件大小。
- 旧参数 `options=` 已废弃，改用 `gdal=` 或 `wopt = list(gdal = )`。
- 写完后 `rast()` 回读，检查 `crs()`、`ext()`、`res()`、`ncell()` 和 NA 数量。

## 3 裁剪、掩膜、范围

```r
# 按矩形范围裁剪
r_crop <- crop(r, ext(5.8, 6.2, 49.6, 49.9))

# 按矢量边界裁剪并掩膜；crop 自带 mask 参数
v <- vect("boundary.gpkg")
r_crop <- crop(r, v, mask = TRUE)

# 只改范围，不设 NA
r_crop <- crop(r, v)

# 只掩膜，保留原范围
r_mask <- mask(r, v)

# 条件掩膜：maskvalues 指定被遮的值
r_cond <- mask(r, r > 50, maskvalues = FALSE)
```

区别：

- `crop()` 改变范围，保留矩形。
- `mask()` 保留范围，把不满足条件的像元设为 NA。
- `mask(r, r > 50)` 默认只遮 NA，可能一格都不遮；条件掩膜必须给 `maskvalues = FALSE` 或 `0`。
- `crop(r, v, mask = TRUE)` 一步完成裁剪和掩膜。
- `crop()` 与 `mask()` 对 CRS 不一致只发 warning；`mask()` 可能把全部格置 NA。跨对象前显式投影。
- 边界像元是否算入，取决于格网和几何；写论文前检查边界像元。

```r
extend(r, 10)   # 向外扩 10 个像元
trim(r)         # 去掉全 NA 的外围行列
```

不要用 `res(r) <-`、`ncol(r) <-`、`nrow(r) <-` 改分辨率：`res<-` 会改 extent，行列数赋值会清空值。要改分辨率用 `aggregate()`、`disagg()`、`resample()`。`shift()` 移动地理参考，不移动值；`flip()` 翻转行列。`c(a = r1, b = r2)` 返回 list，命名放到 `c()` 之后。

## 4 波段与栅格代数

```r
# 单层提取
elev <- r[[1]]

# 波段名选择
r_sub <- r[[c("red", "nir")]]

# 逐像元运算
ndvi <- (r[["nir"]] - r[["red"]]) / (r[["nir"]] + r[["red"]])

# 条件赋值
masked <- ifel(r > 300, r, NA)

# 分段分类
classes <- classify(
  r,
  rcl = matrix(
    c(
      0, 300, 1,
      300, 600, 2,
      600, Inf, 3
    ),
    ncol = 3,
    byrow = TRUE
  )
)
```

`classify()` 默认 `right = TRUE`，区间是 `(a, b]`；最小值等于第一行下界时不会被重分类，需要并入第一类时加 `include.lowest = TRUE`。分类会丢弃因子水平，分类后要重新 `levels<-`。`cut()` 在 terra 1.9.50 不存在，统一用 `classify()`。

### 4.1 app

多层自定义函数用 `app()`：

```r
index <- app(
  r[[c("red", "nir")]],
  fun = \(x) (x[2] - x[1]) / (x[2] + x[1])
)
```

函数必须返回长度 1 的向量，或与输入像元数相等的向量。不要在函数里读大对象。

## 5 分辨率、重采样、投影

### 5.1 聚合与分解

```r
# 分辨率变粗，像元值取均值
r_coarse <- aggregate(r, fact = 4, fun = "mean", na.rm = TRUE)

# 分辨率变细，仅用于对齐；不增加信息
r_fine <- disagg(r, fact = 2, method = "bilinear")
```

`aggregate()` 的 `fact` 必须是整数倍；非整数倍会被截断，`fact = 2.5` 按 2 处理。分类栅格用 `fun = "modal"` 可保留因子水平。非整数倍重采样用 `resample()`。

### 5.2 重采样到模板

```r
template <- rast(ext(r), resolution = 0.01, crs = crs(r))
r_aligned <- resample(r, template, method = "bilinear")
```

`resample()` 要求模板与输入在同一 CRS。分类变量用 `method = "near"`。

### 5.3 投影

```r
# 直接对齐到模板；同时处理 CRS 和格网
r_proj <- project(r, template, method = "bilinear")

# 只给 CRS
r_utm <- project(r, "EPSG:32633", method = "bilinear")
```

选择方法：

- 连续变量：`bilinear` 或 `cubic`。
- 分类变量：`near`。
- 别对分类栅格用双线性，结果会产生不存在的类别。

经纬度栅格的距离用 `distance()` 时，terra 1.9.50 默认 `unit = "m"`、`method = "haversine"`，输出米；手写欧氏距离、`dist()` 或先转成坐标矩阵再算才会得到度。地形计算仍建议先投影，因为坡度依赖水平分辨率。

## 6 邻域、地形、距离

```r
# 3 x 3 均值；只填充 NA 像元
r_focal <- focal(
  r,
  w = 3,
  fun = "mean",
  na.policy = "only",
  na.rm = TRUE
)

# 坡度与坡向；建议先投影到米制 CRS
terrain_layers <- terrain(r_utm, v = c("slope", "aspect"), unit = "degrees")

# 到最近非 NA 像元的距离
dist_to_value <- distance(r > 400)
```

`focal()` 默认 `fun = "sum"`，忘记写会得到求和。`na.policy = "all"` 时窗口含 NA 结果即 NA；`"only"` 只填 NA 格。

```r
# 分区统计必须 na.rm = TRUE，否则含 NA 的分区返回 NaN
zone_mean <- zonal(r, zones, fun = "mean", na.rm = TRUE)
```

边界效应：

- `focal()` 在栅格边缘的窗口不完整；对边缘敏感的分析先 `extend()`。
- `distance()` 的像元中心距离与像元面积不同，不能直接当面积权重。
- 地形计算依赖水平分辨率；经纬度输入的度不能当米。

## 7 分区统计与像元抽取

### 7.1 矢量分区

```r
zonal_mean <- zonal(r, v, fun = "mean", na.rm = TRUE)
```

返回一行一个分区。分区字段名和顺序要检查。

### 7.2 多边形统计

```r
poly_mean <- extract(
  r,
  v,
  fun = "mean",
  na.rm = TRUE,
  exact = TRUE,
  ID = FALSE
)
```

- `exact = TRUE` 处理边界像元的部分覆盖，结果多 `fraction` 列。
- 小多边形、窄条、海岸线附近必须用 `exact = TRUE`。
- `exact = TRUE` 时可按 `fraction` 加权汇总；使用 `weights = TRUE` 会返回 `weight` 列，列名与 `fraction` 不同。
- 大范围、多多边形统计可考虑 `exactextractr::exact_extract()`，它专门处理覆盖比例。

### 7.3 点抽取

```r
pts <- vect("points.gpkg")
values <- extract(r, pts, ID = FALSE)
```

点落在像元边界时，先确认 `pts` 的 CRS 与 `r` 一致。批量点先裁剪栅格到点范围。

### 7.4 全图统计

```r
# 默认按像元计数；连续值统计要 na.rm = TRUE
global(r, fun = c("mean", "min", "max"), na.rm = TRUE)
```

`global()` 对应旧 raster 包的 `cellStats()`；terra 1.9.50 没有 `cellStats()`。`cut()` 也不存在，用 `classify()`。

经纬度栅格做面积加权统计：

```r
# mask = TRUE 只累计有效像元
total_area <- global(cellSize(r, unit = "km", mask = TRUE), "sum", na.rm = TRUE)[[1]]
```

`global()` 默认按像元计数。面积加权必须显式构造面积权重。

## 8 栅格化与矢量化

```r
# 矢量 -> 栅格
template <- rast(ext(v), resolution = 0.01, crs = crs(v))
pop <- rasterize(v, template, field = "POP", fun = "sum")

# 栅格 -> 多边形
poly <- as.polygons(r > 300, dissolve = TRUE)
```

`rasterize()` 的关键参数：

- `field`：要写入的字段；省略时写几何存在性。
- `fun`：一个像元覆盖多个要素时的汇总函数。
- `background`：无要素像元的背景值。
- `touches`：边界像元是否算入；按分析目的设定。

`rasterize()` 不自动投影。模板 CRS 与矢量 CRS 不一致时可能输出全空栅格且不报错；先 `project(v, crs(template))`。

`as.polygons()` 生成的几何可能无效，进入 sf 前用 `st_make_valid()`。

## 9 大栅格工作流

### 9.1 先判断

```r
gib <- ncell(r) * nlyr(r) * 8 / 1024^3
mem <- mem_info(r)
mem[["available"]]
```

`mem_info()` 返回命名数值向量，包含 `needed`、`available`、`memfrac`、`chunk_rows`、`fits_mem`。

### 9.2 写盘而不是留在临时文件

```r
out <- file.path("output", "result.tif")
writeRaster(result, out, overwrite = TRUE)
stopifnot(file.exists(out), !inMemory(rast(out)))
```

临时文件会在会话结束时消失。交付结果必须显式写入项目目录。

### 9.3 分块邻域运算

terra 1.9.50 提供 `tile_apply()`：

```r
out <- tile_apply(
  r,
  fun = function(x) focal(x, w = 11, fun = "mean"),
  cores = 4,
  buffer = 5,
  filename = "output/focal.tif",
  overwrite = TRUE
)
```

`buffer` 要覆盖窗口半径，否则瓦片接缝会错。没有 `tile_apply()` 的旧版本，用 `terraOptions()` 控制分块，或手动按窗口读写。`getTileExtents(x, c(2000, 2000), buffer = 1)` 的第一个参数是每块行列数；传标量 `4` 会得到极多小块。

### 9.4 并行

```r
terraOptions(parallel = TRUE, threads = 4)

out <- app(r, fun = \(x) median(x, na.rm = TRUE), cores = 4)
```

注意：

- `cores` 只对 R 自定义函数有意义；内置的 `"mean"`、`"sum"` 等使用 C++/TBB。
- Windows 上避免 fork 并行；用 PSOCK 或 `tile_apply()`。
- 工作进程不能直接共享 terra 的 C++ 指针。优先传文件名。
- 必须跨进程传对象时用 `wrap()` / `unwrap()`，并在小对象上确认打包方式与内存开销；文件支撑的大栅格优先让每个 worker 自己 `rast(filename)`。
- 大对象不要被函数闭包捕获。

### 9.5 VRT 与瓦片

```r
vrt_file <- "output/mosaic.vrt"
mosaic <- vrt(c("tile_01.tif", "tile_02.tif"), vrt_file)
writeRaster(mosaic, "output/mosaic.tif", overwrite = TRUE)
```

VRT 是索引，适合先统一读取，再一次性写 COG。瓦片必须保持原地。

## 10 预测

```r
model <- lm(y ~ elev + slope, data = train)

prediction <- predict(
  r_predictors,
  model,
  na.rm = TRUE
)
```

检查：

- 训练数据的列名与栅格层名一致。
- 预测栅格的 CRS、范围和分辨率与训练样本一致。
- 因子变量的水平集合与训练数据一致。
- 预测结果写盘并回读。

## 11 常见错误

| 症状 | 原因 | 处理 |
|---|---|---|
| 结果范围比研究区大 | 只做了 `crop()`，没做 `mask()` | 加 `mask()` |
| 条件掩膜一格都没遮 | `mask()` 默认只遮 NA | 设 `maskvalues = FALSE` 或 `0` |
| 掩膜后全部 NA | `mask()` 的 CRS 不一致，仅 warning | 先比较并统一 CRS |
| 分区统计返回 NaN | 没给 `na.rm = TRUE` | 加 `na.rm = TRUE` |
| 邻域结果全偏高 | `focal()` 默认 `fun = "sum"` | 明确 `fun = "mean"` |
| 非整数倍聚合结果不对 | `fact` 被截断 | 改用 `resample()` |
| 边界像元统计偏高 | 像元中心落在多边形外 | `extract(exact = TRUE)` |
| 分类图出现新类别 | 对分类栅格用了双线性 | 改 `method = "near"` |
| 距离值只有几度 | 手写欧氏距离或坐标矩阵 | 改用 `terra::distance()`；经纬度默认 haversine 米 |
| 面积与多边形不符 | `global()` 未按面积加权 | 用 `cellSize()` 做权重 |
| 邻域结果有接缝 | 分块没有缓冲 | `buffer` 覆盖窗口半径 |
| 临时结果丢失 | 只写了 tempfile | 显式 `writeRaster()` 到项目目录 |
| 并行报指针错误 | 跨进程传 SpatRaster | 传文件名或 `wrap()` |
| VRT 打不开 | 原始瓦片被移动 | 保持瓦片路径不变 |

## 12 来源索引

- `rspatial-terra-web/source/spatial/_R/4-rasterdata.rmd`
- `rspatial-terra-web/source/spatial/_R/8-rastermanip.rmd`
- `rspatial-terra-web/source/pkg/_R/3-objects.rmd`
- `rspatial-terra-web/source/pkg/_R/5-methods.rmd`
- `rspatial-terra-web/source/pkg/_R/7-writing.rmd`
- `rspatial-terra-web/source/pkg/_R/8-cell_level_functions.rmd`
- `rspatial-terra-web/source/pkg/_R/9-predict.rmd`
- `rspatial-terra-web/source/pkg/_R/10-parallel.rmd`
- `rspatial-terra-web/source/pkg/_R/11-misc.rmd`
- `rspatial-terra-web/source/spatial/_R/6-crs.rmd`
- `geocompr/06-raster-vector.Rmd`
- `geocompr/07-reproj.Rmd`
- `geocompr/08-read-write-plot.Rmd`
