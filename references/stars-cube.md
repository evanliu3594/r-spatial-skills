# stars 数据立方与 geom_stars

本文件用于中小栅格、多波段/时间立方、NetCDF/Zarr 与 `geom_stars()` 可视化。示例在本机 stars 0.7.3 实测。

## 1 对象模型

`stars` 是带命名维度的数组：

- 属性：一个或多个变量。
- 维度：`x`、`y`、`band`、`time` 等，存于 `st_dimensions()`。
- 几何：维度的 `refsys` 与 `point` 描述坐标参照和像元中心/面积语义。

```r
library(stars)
library(dplyr)

x <- read_stars("input.tif")
class(x)
dim(x)
st_dimensions(x)
st_crs(x)
st_bbox(x)
names(x)
```

`dim(x)` 的顺序与数组一致。不要凭打印顺序猜 `band` 或 `time`。

常见的网格类型：

- regular：等间距、北向上。
- rectilinear：x、y 各自等间距，但网格可不等距。
- curvilinear：每个像元有自己的坐标。
- rotated/sheared：仿射变换后的网格。

`st_dimensions()` 会显示 `delta`、`offset`、`refsys`、`point`、`x/y` 标记。

## 2 读取

### 2.1 普通读取

```r
x <- read_stars("input.tif")
x <- read_stars("input.nc")
x <- read_ncdf("input.nc")
```

`read_stars()` 走 GDAL；读 NetCDF 时维度常为 `x/y/time`，CRS 可能为 `NA`。`read_ncdf()` 走 RNetCDF；维度常为 `longitude/latitude/time`，CRS 由 CF 属性推断。两个入口的纬度方向和变量选择参数不同，混用前先统一网格与 CRS。

```r
nc <- system.file("nc/bcsd_obs_1999.nc", package = "stars")
a <- read_stars(nc, quiet = TRUE)
b <- read_ncdf(nc, var = "pr")
st_crs(a)   # 可能为 NA；需要时 st_set_crs(a, 4326)
st_crs(b)   # 可能由 CF 推断为 CRS84
```

`read_stars(..., proxy = TRUE)` 返回代理。`read_ncdf()` 的 proxy 行为由 `options(stars.n_proxy)` 控制。

GDAL 多维接口用于 NetCDF、Zarr 和远程 store：

```r
# offset 从 0 开始；count 与 step 按源文件维度顺序
m <- read_mdim(
  "input.nc",
  variable = "sst",
  offset = c(0, 0, 0, 0),
  count = c(100, 100, 1, 1),
  proxy = TRUE
)
```

Zarr 的 `.zip` 不能直接交给 `/vsizip/`，先解压成目录。`read_mdim()` 的维度名与 `read_stars()` 不一定相同；混用前统一。

### 2.2 只读窗口与降采样

```r
# GDAL RasterIO：偏移、窗口、输出大小、波段
rasterio <- list(
  nXOff = 100,
  nYOff = 100,
  nXSize = 1000,
  nYSize = 1000,
  nBufXSize = 250,
  nBufYSize = 250,
  bands = c(1, 4, 5),
  resample = "bilinear"
)
x <- read_stars("input.tif", RasterIO = rasterio)
```

重采样方法包括 `nearest_neighbour`、`bilinear`、`cubic`、`cubic_spline`、`lanczos`、`average`、`mode`、`Gauss`。

分类变量用 `mode` 或 `nearest_neighbour`。

### 2.3 proxy

```r
p <- read_stars("big.tif", proxy = TRUE)
class(p)
st_dimensions(p)
object.size(p)
```

`stars_proxy` 只保存元数据和文件指针，不读像元。真正取数的操作：

- `plot(p)`：按绘图设备分辨率读取。
- `st_as_stars(p, downsample = )`：读入内存。
- `write_stars(p, ...)`：分块写出。

`st_crop(p, ...)` 会记录裁剪，保持惰性。`st_downsample(p, 2)` 会实际读取并返回 `stars`，不是 proxy。

## 3 维度操作

### 3.1 切片与子集

```r
# 选变量
x["ndvi"]

# 选波段；需要 dplyr 提供 slice() 泛型
band_1 <- slice(x, along = "band", index = 1)

# 按坐标范围裁剪
x_crop <- st_crop(x, st_bbox(c(xmin = 0, ymin = 0, xmax = 10, ymax = 10), crs = st_crs(x)))

# 数组下标；顺序由 dim(x) 决定
x_sub <- x[, 1:100, 1:100, 1:3]
```

`filter()` 在 stars 上需要 `cubelyr` 包，且只支持部分网格类型。优先用 `[` 或 `st_crop()`。

### 3.2 维度值

```r
st_get_dimension_values(x, "x")
st_get_dimension_values(x, "time")

# 改维度名、值或顺序
st_set_dimensions(x, "band", values = c("blue", "green", "red"))
aperm(x, c("band", "x", "y"))
```

`st_redimension()` 用于把多个属性合并为维度，或把维度拆成属性；参数要求严格，转换前先用 `?st_redimension` 核对维度表。

## 4 运算

### 4.1 逐像元运算

```r
# 逐像元加减乘除
doubled <- x * 2
flipped <- 255 - x
```

`min(x)`、`max(x)` 不能直接作用于 stars 对象。整体范围用 `terra::global(terra::rast(x), c("min", "max"), na.rm = TRUE)`，或先转成 data.frame。

### 4.2 沿维度归约
`st_apply(X, MARGIN, FUN, ...)` 中 `MARGIN` 是要保留的维度；其余维度传给函数。

```r
# 每个像元跨波段算 NDVI；返回 x/y 两维
ndvi <- st_apply(
  x,
  c("x", "y"),
  \(z) (z[4] - z[3]) / (z[4] + z[3])
)

# 每个波段的全图均值；返回 band 一维
band_mean <- st_apply(x, "band", mean, na.rm = TRUE)

# 每个像元的时间均值；保留 x/y
time_mean <- st_apply(x, c("x", "y"), mean, na.rm = TRUE)
```

函数接收的数组顺序由剩余维度决定。先在小切片上验证一次，再跑全图。

### 4.3 拆分与合并

```r
# 按波段拆成列表
bands <- split(x, "band")

# 按时间拆分
years <- split(x, "time")

# 合并
combined <- do.call(c, unname(bands))
```

`c()` 合并 stars 对象时要求维度兼容。合并前检查 `st_dimensions()`。

### 4.4 代数与函数

stars 支持 `+`、`-`、`*`、`/` 等逐像元运算：

```r
scaled <- (x - min(x, na.rm = TRUE)) /
  (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
```

`min()`、`max()` 对 stars 对象的返回值要确认。需要整体统计时用 `st_apply()` 或 `as.data.frame()`。

## 5 裁剪、重采样、拼接

```r
# 按 bbox 裁剪
x_crop <- st_crop(x, bb)

# 降采样；n 是跳过的像元数，步长 n+1
x_low <- st_downsample(x, 4)

# 拼接相邻瓦片
x_mosaic <- st_mosaic(x1, x2)

# 变形到规则目标格网
target <- st_as_stars(st_bbox(x_crop), nx = 500, ny = 500)
x_warp <- st_warp(x_crop, target)
```

`st_crop` 裁 bbox；给 `sf`/`sfc` 多边形时裁 bbox 并掩膜。`crop = FALSE` 对 bbox 不裁剪，对多边形只掩膜、不改范围。curvilinear 网格裁剪前先 `st_warp()` 到规则网格。

`st_mosaic()` 用 GDAL 拼接相邻或重叠瓦片；默认输出临时 VRT，需要持久结果时显式给 `dst`。四维立方或多属性对象不支持拼接。

### 5.1 st_transform 与 st_warp

```r
# 改变像元坐标；可能得到曲线格网
x_curv <- st_transform(x, "OGC:CRS84")

# 生成规则格网；适合后续数组运算和写盘
x_regular <- st_warp(x, target)

# 双线性只在 use_gdal = TRUE 时可用
x_bilinear <- st_warp(x, target, use_gdal = TRUE, method = "bilinear")
```

`st_warp()` 默认 `method = "near"`；`bilinear`、`cubic` 等方法需要 `use_gdal = TRUE`，并显式给 `no_data_value`，否则缺失值可能变 0。

`st_transform()` 对栅格不是重采样到规则格网，结果可能是 curvilinear。需要规则格网、COG、后续 `st_apply()` 时用 `st_warp()`。

### 5.2 写盘

```r
write_stars(x, "output/result.tif")

# proxy 分块写出
write_stars(p, "output/result_cog.tif", chunk_size = c(1024, 1024))
```

`write_stars()` 一次只写第一个属性；多属性对象用 `layer=` 指定。默认 `type = "Float32"`，高精度浮点数据显式给 `type = "Float64"`。COG 用 `driver = "COG"`，并可加 `options = "COMPRESS=DEFLATE"`。

写完后 `read_stars()` 回读，检查维度、CRS、范围和 NA。

## 6 点抽取与矢量栅格化

### 6.1 点抽取

```r
library(sf)

points <- read_sf("points.gpkg")
points <- st_transform(points, st_crs(x))
values <- st_extract(x, points)
```

点与栅格 CRS 必须一致。`st_extract()` 只接受 `stars`，传 `SpatRaster` 会报 no applicable method。输入含 x/y 以外维度时返回 `stars`（`geometry` 维 + 剩余维）；只有 x/y 时返回 `sf`；`at` 为坐标矩阵时返回矩阵。点在栅格外返回 NA。

```r
# 大批点用矩阵，避免 sf 逐点开销
values_matrix <- st_extract(x[1], st_coordinates(points))
```

### 6.2 矢量栅格化

```r
library(sf)

v <- read_sf("polygons.gpkg")
grid <- st_rasterize(v["value"], dx = 100, dy = 100)
```

`st_rasterize()` 使用 GDAL rasterize。目标几何可由 `dx/dy` 或 `nx/ny` 控制。

高频错误：

```r
# 这得到矢量立方，不是 x/y 栅格
s <- st_as_stars(v["value"], dx = 100, dy = 100)

# 栅格化要用 st_rasterize()
s <- st_rasterize(v["value"], dx = 100, dy = 100)
```

### 6.3 栅格转矢量

```r
poly <- st_as_sf(x, as_points = FALSE, merge = TRUE)
poly <- st_make_valid(poly)
```

`as_points = TRUE` 输出点；`merge = TRUE` 合并同值像元。结果多边形经常无效，进 sf 前修复。

## 7 可视化

### 7.1 base plot

```r
plot(x, downsample = 4)
plot(x, breaks = "equal", col = hcl.colors(20, "Viridis"))
```

`plot()` 对大对象自动降采样；`downsample` 可显式控制。多波段对象默认逐波段出图。

### 7.2 geom_stars

```r
library(ggplot2)

ggplot() +
  geom_stars(data = band_1, downsample = 2) +
  coord_equal() +
  scale_fill_viridis_c(na.value = "transparent") +
  labs(fill = "DN", title = "Landsat band 1") +
  theme_void()
```

要点：

- `geom_stars()` 默认把第一个属性映射到 `fill`。
- 多波段对象用 `slice()` 选一层，或 `facet_wrap(~band)`。
- `downsample` 必须显式给；ggplot2 不知道设备尺寸。
- `coord_equal()` 保持像元形状；需要投影时先 `st_warp()`，再用 `coord_sf(datum = NA)`。`geom_stars()` 不随 `coord_sf(crs=)` 重投影。
- NA 设透明，避免背景色误导。
- 与矢量叠加时先统一 CRS：

```r
boundary <- st_transform(boundary, st_crs(band_1))

ggplot() +
  geom_stars(data = band_1, downsample = 2) +
  geom_sf(data = boundary, fill = NA, colour = "red") +
  coord_sf(datum = NA) +
  theme_void()
```

### 7.3 与 tidyterra 的分工

- 数据已经是 `SpatRaster`，且不想转换：`tidyterra::geom_spatraster()`。
- 数据是 `stars`，或要做数据立方切片：`geom_stars()`。
- 同一张图混用 `geom_spatraster()` 与 `geom_stars()` 容易产生坐标冲突；统一一种。

## 8 性能与内存

- 大文件先 `proxy = TRUE`，看维度和范围。
- 预览用 `plot(p, downsample = )` 或 `geom_stars(downsample = )`。
- 需要数值时用 `st_as_stars(p, downsample = )`，不要无条件读全分辨率。
- `st_apply()` 对 proxy 可以延迟，但最终会取数；分块写出用 `write_stars(chunk_size=)`。
- `st_transform()` 对大栅格可能生成巨大曲线格网；优先 `st_warp()` 到目标规则格网。
- 时间维很密集时，逐像元时间函数可能比按波段循环慢；先裁剪空间范围。

## 9 与 terra、sf 互转

```r
# terra -> stars
s <- st_as_stars(r)

# stars -> terra
r <- terra::rast(s)

# sf -> stars 矢量立方
vc <- st_as_stars(v)

# sf -> stars 栅格
g <- st_rasterize(v["value"], dx = 100, dy = 100)

# stars -> sf
v2 <- st_as_sf(g, as_points = FALSE, merge = TRUE)
```

互转后检查：

```r
st_crs(s)
st_dimensions(s)
st_bbox(s)
terra::ncell(terra::rast(s))
```

## 10 常见错误

| 症状 | 原因 | 处理 |
|---|---|---|
| `slice()` 找不到函数 | 没有加载 dplyr | `library(dplyr)` |
| `filter()` 报缺 cubelyr | stars 的可选依赖 | 用 `[` 或 `st_crop()` |
| `st_as_stars(sf)` 不是栅格 | 默认生成矢量立方 | 用 `st_rasterize()` |
| `geom_stars()` 画得极慢 | 没有降采样 | 设 `downsample` |
| `geom_stars()` 加投影后空白 | `coord_sf(crs=)` 不重投影栅格 | 先 `st_warp()`，再 `coord_sf(datum = NA)` |
| `st_transform()` 后不是规则格网 | 坐标变换逐像元 | 用 `st_warp()` |
| `rast(stars)` 报维度错误 | 对象是矢量立方或维度不完整 | 先转规则栅格 |
| 点抽取全 NA | 点与栅格 CRS 不一致 | 先 `st_transform()` |
| 读 proxy 后对象很大 | 某个操作触发了取数 | 检查 `st_downsample()`、`st_as_stars()` |

## 11 来源索引

- `stars/README.md`
- `stars/vignettes/stars1.Rmd`
- `stars/vignettes/stars2.Rmd`
- `stars/vignettes/stars3.Rmd`
- `stars/vignettes/stars4.Rmd`
- `stars/vignettes/stars5.Rmd`
- `stars/vignettes/stars6.Rmd`
- `stars/vignettes/stars7.Rmd`
- `sdsr/06-Cubes.qmd`
- `sdsr/07-Introsf.qmd`
- `sdsr/09-Large.qmd`
- `sdsr/13-Geostatistics.qmd`
- `geocompr/06-raster-vector.Rmd`
