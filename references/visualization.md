# 空间可视化

本文件用于静态地图：矢量用 `geom_sf()`，栅格用 `geom_stars()`，二者可叠加。示例在本机 ggplot2 4.0.3、stars 0.7.3 实测。

## 1 先决定画什么

| 数据 | 图层 | 用途 |
|---|---|---|
| `sf` 点/线/多边形 | `geom_sf()` | 边界、点位、区域填色 |
| `stars` 规则栅格 | `geom_stars()` | 连续面、分类面、多波段分面 |
| `SpatRaster` 且不想转 | `tidyterra::geom_spatraster()` | terra 原生绘图 |
| 快速检查 | `plot()` / `image()` | EDA，不用于交付 |

交付图优先用 ggplot2：

- 坐标系明确。
- 图例、标题、注记可复用。
- 多图拼版容易。
- 与 `geom_sf()` 叠加简单。

## 2 矢量地图

```r
library(ggplot2)
library(sf)

v <- read_sf("boundary.gpkg")

ggplot(v) +
  geom_sf(aes(fill = value), colour = "white", linewidth = 0.1) +
  scale_fill_viridis_c(na.value = "grey90") +
  coord_sf() +
  labs(
    title = "Title with unit",
    subtitle = "Subtitle",
    fill = "Value (unit)",
    caption = "Source: ..."
  ) +
  theme_void()
```

要点：

- `aes(fill = value)` 的 `value` 是裸列名。
- 多边形边界用 `colour`，填充用 `fill`。
- `linewidth` 控制边界线宽，旧代码的 `size` 已不推荐。
- 经纬度数据由 `coord_sf()` 处理；需要指定投影时加 `crs =`。
- 分类变量用 `scale_fill_brewer()` 或 `scale_fill_viridis_d()`；连续变量用 `scale_fill_viridis_c()`。

## 3 栅格地图

```r
library(ggplot2)
library(dplyr)
library(stars)

r <- read_stars("input.tif")
band_1 <- slice(r, along = "band", index = 1)

ggplot() +
  geom_stars(data = band_1, downsample = 2) +
  coord_equal() +
  scale_fill_viridis_c(na.value = "transparent") +
  labs(
    title = "Title with unit",
    fill = "Value (unit)",
    caption = "Source: ..."
  ) +
  theme_void()
```

### 3.1 多波段分面

```r
ggplot() +
  geom_stars(data = r) +
  facet_wrap(~band, ncol = 3) +
  coord_equal() +
  scale_fill_viridis_c() +
  theme_void() +
  scale_x_discrete(expand = c(0, 0)) +
  scale_y_discrete(expand = c(0, 0))
```

`geom_stars()` 会自动选择 `geom_raster()`、`geom_rect()` 或 `geom_sf()`，取决于网格类型。

### 3.2 分类栅格

```r
ggplot() +
  geom_stars(data = land_cover, downsample = 2) +
  scale_fill_brewer(palette = "Set3", na.value = "transparent") +
  coord_equal() +
  theme_void()
```

分类栅格先确认值是因子或整数编码，图例标签要显式给出。连续色标用在分类数据上会误导。

## 4 降采样

`geom_stars()` 不会自动读取屏幕分辨率，必须给 `downsample`。该参数表示跳过的像元数，`downsample = 2` 每 3 个像元取 1 个，不是缩小 2 倍。

估算跳过数：

```r
target_pixels <- 2000 * 2000
spatial_cells <- prod(dim(r)[1:2])
step <- ceiling(sqrt(spatial_cells / target_pixels))
downsample <- max(step - 1, 0)
```

用法：

```r
geom_stars(data = r, downsample = downsample)
```

规则：

- 预览：`downsample` 取 4 到 16。
- 交付：按输出图的像素宽度反推，保证每像素至少 1 个像元。
- 大栅格不要先转 stars 再降采样；先在 terra 中裁剪和聚合。
- `plot(stars_proxy)` 会自动选择降采样；`geom_stars()` 不会。
- `st_downsample(x, n)` 的 `n` 同样是跳过数，步长是 `n + 1`。

## 5 与矢量叠加

```r
# 先把矢量变换到栅格 CRS；geom_stars 不随 coord_sf(crs=) 重投影
boundary <- st_transform(boundary, st_crs(band_1))

ggplot() +
  geom_stars(data = band_1, downsample = 2) +
  geom_sf(data = boundary, fill = NA, colour = "red", linewidth = 0.4) +
  coord_sf(datum = NA) +
  scale_fill_viridis_c(na.value = "transparent") +
  theme_void()
```

规则：

- 两个对象先统一 CRS。
- 栅格先画，矢量后画。
- 边界用 `fill = NA`，只描边。
- 点用 `geom_sf(size = )`，线用 `linewidth`。
- 叠加前检查范围是否相交；CRS 不同会导致空图或错位。
- `geom_stars()` 不会因为 `coord_sf(crs = )` 而重投影栅格。需要另一 CRS 时，先用 `st_warp()` 生成规则目标格网，或 `st_transform()` 生成曲线格网，再画。

## 6 投影与坐标

```r
ggplot(v) +
  geom_sf() +
  coord_sf(crs = "+proj=robin", default_crs = 4326)
```

`default_crs` 告诉 ggplot2 原始经纬度数据的参照。没有它，`xlim`、`ylim` 会按投影坐标解释。`coord_sf()` 只对 `sf` 图层做重投影；`geom_stars()` 的栅格需要先 `st_warp()` 或 `st_transform()`。

常用投影：

- 全球：Robinson、Equal Earth、Mollweide。
- 区域：局部 Albers、Lambert Conformal Conic、UTM。
- 极区：Polar Stereographic。
- 中国：Albers Equal Area 或地方高斯-克吕格。

选择原则：

- 面积比较用等积投影。
- 距离比较用等距或局部投影。
- 形状展示可用折中投影。
- 不为了“好看”换投影后做面积统计。

## 7 配色与图例

连续变量：

```r
scale_fill_viridis_c(option = "viridis", na.value = "transparent")
scale_fill_viridis_b(breaks = seq(0, 100, 20))
```

分类变量：

```r
scale_fill_brewer(palette = "Set2", na.value = "grey90")
scale_fill_manual(values = c(low = "#440154", high = "#FDE725"))
```

规则：

- 色标范围取数据列，不取矩阵最大值。
- 不用 `limits` 放大局部；用 `coord_sf(xlim =, ylim =)`。
- 缺失值用透明或灰色，并在图注说明。
- 发散型数据用 `scale_fill_gradient2()`，中点设 0。
- 色盲安全优先：viridis、Okabe-Ito、Brewer。

## 8 多图与拼版

```r
library(patchwork)

p1 <- ggplot() + geom_stars(data = band_1, downsample = 2) + theme_void()
p2 <- ggplot() + geom_sf(data = boundary) + theme_void()

p1 | p2
```

拼版前统一：

- 投影和范围。
- 色标与断点。
- 图例位置和字号。
- 标题层级。

跨图比较时，色标范围要一致；只在同一图内使用 `limits`。

## 9 输出

```r
ggsave(
  filename = "output/map.png",
  plot = map,
  width = 7,
  height = 5,
  dpi = 300
)
```

交付格式：

- 屏幕与网页：PNG，150 到 300 dpi。
- 论文：PDF 或 SVG，矢量优先。
- 大幅海报：PDF，检查字体嵌入。

图注写清：

- 数据来源。
- 时间范围。
- 空间分辨率。
- 投影与 CRS。
- 单位。
- 缺失值处理。

## 10 常见错误

| 症状 | 原因 | 处理 |
|---|---|---|
| 图很慢或内存爆 | 全分辨率转 stars | 先在 terra 裁剪、聚合 |
| 图糊成一团 | 没有 `downsample` | 计算降采样因子 |
| 栅格与边界错位 | CRS 不一致 | 先 `st_transform()` |
| 图例范围不对 | 色标取了矩阵最大值 | 取数据列范围 |
| 放大后空白 | 用 `limits` 裁了数据 | 用 `coord_sf(xlim =, ylim =)` |
| 经纬度地图变形 | 没指定投影 | `coord_sf(crs =)`（仅 sf） |
| `geom_stars` 加 `coord_sf(crs=)` 后空白 | 栅格不随 coord_sf 重投影 | 先 `st_warp()` 栅格，再 `coord_sf(datum = NA)` |
| 分类图出现连续渐变 | 用了连续色标 | 改 `scale_fill_brewer()` |
| 中文乱码 | 设备字体不支持 | 指定字体或用 ragg |

## 11 来源索引

- `sdsr/08-Plotting.qmd`
- `sdsr/12-Interpolation.qmd`
- `geocompr/09-mapping.Rmd`
- `stars/vignettes/stars3.Rmd`
- `stars/vignettes/stars6.Rmd`
- `yifan-r-code-style/references/visualization.md`
