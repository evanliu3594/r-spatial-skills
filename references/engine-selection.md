# 引擎选择与对象模型

本文件回答两个问题：这份数据该交给 terra、sf 还是 stars；对象之间怎么换，换完检查什么。

## 1 三个对象模型

| 引擎 | 主类 | 几何/维度 | 数据存放 | 强项 |
|---|---|---|---|---|
| terra | `SpatRaster`、`SpatVector` | 规则格网或简单要素 | 元数据 + C++ 指针；可指向磁盘文件 | 分块 I/O、邻域、分区、地形、投影、栅格代数 |
| sf | `sf`、`sfc`、`sfg` | 简单要素几何列 | data.frame + 几何列表列 | 属性连接、空间谓词、叠加、缓冲、测量 |
| stars | `stars`、`stars_proxy` | 带命名维度的数组 | R 数组；proxy 只存文件指针与调用列表 | 多波段/时间立方、tidy 运算、`st_apply()`、绘图 |

判断对象来源：

```r
class(x)
inherits(x, "SpatRaster")
inherits(x, "sf")
inherits(x, "stars")
inherits(x, "stars_proxy")
```

## 2 选择顺序

```text
有没有矢量几何？
  有 -> sf
  没有 -> 是栅格或数据立方
          是否需要处理超出内存的大栅格，或做重计算？
             是 -> terra
             否 -> 是否需要多波段/时间维、tidy 数组运算或 geom_stars 绘图？
                    是 -> stars
                    否 -> terra 或 stars 均可；默认 terra 做计算，stars 做图
```

### 2.1 选 terra 的信号

- 单文件或瓦片集合超过可用内存。
- 需要 `focal()`、`zonal()`、`terrain()`、`distance()`、`predict()`、`mosaic()`。
- 需要分块写 COG、VRT、多文件拼接。
- 需要把大栅格按多边形提取或按区域统计。
- 需要严格的格网对齐、原点、分辨率控制。

### 2.2 选 sf 的信号

- 数据是点、线、多边形及其属性表。
- 需要 `st_join()`、`st_intersects()`、`st_within()`、`st_nearest_feature()`。
- 需要 `st_buffer()`、`st_intersection()`、`st_difference()`、`st_union()`。
- 需要 `st_area()`、`st_length()`、`st_distance()` 和 `units` 单位。
- 需要把表格转成点：`st_as_sf(df, coords = c("x", "y"), crs = ...)`。

### 2.3 选 stars 的信号

- 多波段影像、时间序列、NetCDF/Zarr 数据立方。
- 想按维度名做 `slice()`、`st_apply()`、`split()`、`aperm()`。
- 需要 `st_warp()`、`st_downsample()`、`st_mosaic()`、`st_rasterize()`。
- 需要 `geom_stars()` 直接画栅格，或 `plot()` 快速看立方。
- 数据量中小，或已经从大栅格裁剪出小窗口。

## 3 三条硬规则的边界

### 3.1 大栅格用 terra，不等于所有栅格都用 terra

中小栅格做 tidy 运算、多波段统计和绘图时，stars 更直接。把 500 × 500 的裁剪窗口转成 stars 不会造成内存问题。

### 3.2 矢量用 sf，不等于矢量永远不进入 terra

当矢量只用于裁剪、掩膜、分区统计，且栅格很大：

```r
v_terra <- terra::vect(v_sf)
r_study <- terra::crop(r, v_terra) |>
  terra::mask(mask = v_terra)
```

这样避免把大栅格转成 stars，也避免在 sf 中复制整幅栅格。矢量本身仍以 sf 为主对象。

### 3.3 可视化用 stars，不等于把整幅栅格读进 stars

正确顺序：

1. 在 terra 中裁剪研究区。
2. 按目标像素数计算降采样因子。
3. 只把裁剪后、降采样后的对象转成 stars。
4. 用 `geom_stars(downsample = )` 或 `plot(downsample = )`。

```r
# 先在小范围、低分辨率上转换
r_plot <- terra::crop(r, terra::vect(plot_area)) |>
  terra::aggregate(fact = 8, fun = "mean", na.rm = TRUE)

s_plot <- stars::st_as_stars(r_plot)
```

## 4 内存与数据量判断

### 4.1 栅格

```r
n_cell <- terra::ncell(r)
n_layer <- terra::nlyr(r)
gib <- n_cell * n_layer * 8 / 1024^3

mem <- terra::mem_info(r)
mem[["available"]]
```

规则：

- `gib` 小于可用内存的 25%：可以读入内存做中小规模运算。
- `gib` 达到可用内存的 50%：优先磁盘工作流。
- 需要邻域运算时，实际峰值内存高于 `ncell * nlyr * 8`，因为要保留窗口。
- 多波段文件按层读取，避免一次读全部层。

### 4.2 stars

`object.size(stars)` 只反映 R 对象开销，不总等于文件大小。看 `dim()` 和数据类型估计：

```r
prod(dim(x)) * 8 / 1024^3
```

`stars_proxy` 只保存元数据和调用列表，读取发生在 `plot()`、`st_as_stars()`、`write_stars()`。其他操作只追加调用。

### 4.3 矢量

文件大小不能直接推断内存。重点看：

- 要素数 `nrow(v)`。
- 几何复杂度：`st_geometry_type()`、顶点数、是否有大量孔洞。
- `st_is_valid()` 的失败数量。
- 空间连接是否会一对多放大行数。

大矢量优先：

```r
# 只读需要的列和范围
v <- read_sf(dsn, query = "SELECT id, geom FROM layer WHERE ...")

# 数据库侧过滤
v <- st_read(dsn, query = "SELECT ... FROM ... WHERE ...")
```

## 5 格网与 CRS 对齐

### 5.1 栅格对齐四项

```r
ext(a)       # 范围
res(a)       # 分辨率
origin(a)    # 原点
crs(a)       # 坐标参照
```

检查：

```r
same_grid <- terra::compareGeom(a, b, stopOnError = FALSE)
stopifnot(same_grid)
```

需要把 `a` 对齐到 `b` 的格网：

```r
a_on_b <- terra::project(a, b, method = "bilinear")
```

`project(x, y)` 同时处理 CRS 和格网；比先 `project()` 再 `resample()` 少一次重采样。

### 5.2 sf 对齐

```r
st_crs(v)
st_bbox(v)
st_transform(v, st_crs(target))
```

`st_crs(v) == st_crs(target)` 为 `FALSE` 时不要直接叠加。经纬度对象和投影对象的 bbox 单位不同，范围看起来接近也不代表能直接运算。

### 5.3 stars 对齐

```r
st_dimensions(x)
st_crs(x)
st_bbox(x)
```

`st_warp(x, target)` 生成与 `target` 对齐的规则格网。`st_transform(x, crs)` 改变像元坐标，可能得到曲线格网；需要规则格网时用 `st_warp()`。

## 6 转换矩阵

| 从 | 到 | 代码 | 备注 |
|---|---|---|---|
| terra 栅格 | stars | `st_as_stars(r)` | 元数据与值一起转；大栅格先裁剪 |
| stars 栅格 | terra | `rast(s)` | 要求规则/可解析维度 |
| terra 矢量 | sf | `st_as_sf(v)` | 属性与几何保留 |
| sf | terra 矢量 | `vect(v)` | 用于栅格管线 |
| sf | stars 栅格 | `st_rasterize(v["field"], dx =, dy =)` | `st_as_stars(v)` 默认给矢量立方 |
| sf | stars 矢量立方 | `st_as_stars(v)` | 维度是 `geometry`，不是 x/y |
| stars 栅格 | sf | `st_as_sf(s, as_points = FALSE, merge = TRUE)` | 多边形化，可能产生无效几何 |
| stars 栅格 | sf 点 | `st_as_sf(s, as_points = TRUE)` | 每像元一点 |
| stars 矢量立方 | sf | `st_as_sf(s)` | 保留几何维度 |

### 6.1 转换后的四查

```r
# 1. 格数一致
stopifnot(terra::ncell(r) == prod(dim(s)[1:2]))

# 2. 范围一致（同一 CRS 下逐项比较）
terra_box <- unname(as.vector(terra::ext(r))[c(1, 2, 3, 4)])
stars_box <- unname(as.numeric(sf::st_bbox(s)[c("xmin", "xmax", "ymin", "ymax")]))
stopifnot(all.equal(terra_box, stars_box, tolerance = 1e-6))

# 3. CRS 可解析为同一参照
stopifnot(sf::st_crs(terra::crs(r)) == sf::st_crs(s))

# 4. 分辨率与维度增量一致
stopifnot(all.equal(terra::res(r)[1], abs(st_dimensions(s)$x$delta)))
stopifnot(all.equal(terra::res(r)[2], abs(st_dimensions(s)$y$delta)))
```

转换后写盘并回读一次，能发现仅靠对象元数据看不出的类型和压缩问题。

### 6.2 一个高频错误

```r
# 错误：想栅格化，却得到矢量立方
s <- st_as_stars(nc["BIR74"], dx = 0.1, dy = 0.1)
class(s)
# "stars"，维度是 geometry，不是 x/y

# 正确：显式栅格化
s <- st_rasterize(nc["BIR74"], dx = 0.1, dy = 0.1)
```

## 7 混合管线示例

```r
library(terra)
library(sf)
library(stars)

# 大栅格在 terra 中裁剪和降采样
r <- rast("big.tif")
v <- read_sf("study_area.gpkg")
v <- st_transform(v, crs(r))
r_small <- crop(r, vect(v)) |>
  mask(mask = vect(v)) |>
  aggregate(fact = 4, fun = "mean", na.rm = TRUE)

# 小对象转 stars 做立方运算和绘图
s <- st_as_stars(r_small)
ndvi <- st_apply(s, c("x", "y"), \(z) (z[4] - z[3]) / (z[4] + z[3]))

# 需要回到 terra 写 COG
writeRaster(rast(ndvi), "output/ndvi.tif", filetype = "COG", overwrite = TRUE)
```

## 8 来源索引

| 主题 | 来源 |
|---|---|
| 大栅格磁盘工作流、分块 | `rspatial-terra-web/source/spatial/_R/4-rasterdata.rmd`、`8-rastermanip.rmd`、`pkg/_R/10-parallel.rmd` |
| terra 对象创建与来源 | `rspatial-terra-web/source/pkg/_R/3-objects.rmd`、`7-writing.rmd` |
| sf 与 stars 入门 | `sdsr/07-Introsf.qmd` |
| 大数据与 proxy | `sdsr/09-Large.qmd` |
| stars 维度与 proxy | `stars/vignettes/stars2.Rmd`、`stars4.Rmd` |
| 矢量-栅格转换 | `stars/vignettes/stars5.Rmd` |
| 数据读写 | `geocompr/08-read-write-plot.Rmd` |
| 重投影 | `geocompr/07-reproj.Rmd` |
