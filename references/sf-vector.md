# sf 矢量操作

本文件用于点、线、多边形及其属性。示例在本机 sf 1.1.3 实测。

## 1 对象与检查

```r
library(sf)

v <- read_sf("boundary.gpkg")
class(v)
st_crs(v)
st_bbox(v)
st_geometry_type(v)
nrow(v)
st_is_valid(v)
```

`sf` 是 data.frame，几何存于 `geometry` 列表列。`sfc` 是几何列，`sfg` 是单个几何。

常用操作：

```r
st_geometry(v)          # 提取几何列
st_drop_geometry(v)     # 去掉几何，得到普通表
st_set_geometry(v, g)   # 换几何
st_as_sf(df, coords = c("x", "y"), crs = 4326)
```

几何列有粘性：`select()` 会自动保留；`select(-geometry)` 删不掉；`st_drop_geometry()` 才真正去掉。改名用 `st_geometry(v) <- "new_name"`，直接改 `names()` 会破坏 `sf_column` 指针。

读入后先看 `st_crs()`。没有 CRS 的矢量不能和投影数据直接叠加。

## 2 读写

```r
# 读
v <- read_sf("input.gpkg")
v <- read_sf("input.gpkg", layer = "counties")

# 用 SQL 在数据库侧过滤；表名取 st_layers()$layer_name
v <- st_read(
  "database.gpkg",
  query = "SELECT id, name, geom FROM counties WHERE year = 2020"
)
# 写
write_sf(v, "output/result.gpkg", layer = "result", quiet = TRUE)

# 追加
write_sf(v, "output/result.gpkg", layer = "result", append = TRUE)
```

格式选择：

- GeoPackage（`.gpkg`）：字段名、类型、CRS 保留好；首选。
- GeoJSON（`.geojson`）：交换方便，字段类型和精度会损失。
- Shapefile（`.shp`）：字段名截断到 10 字符，编码问题多；只在对方要求时使用。
- GeoParquet：大表、列式读取；需要 GDAL 和箭头生态支持。

`read_sf()` 返回 tibble，`st_read()` 默认返回 data.frame。二者都用 GDAL。

OGR SQL 的 `SELECT` 必须包含几何列。只选属性列会返回普通 tibble，几何与 CRS 丢失。表名取 `st_layers()` 的图层名，不是文件名主干。

Shapefile 字段名会缩写到 10 字符，中文需要 `layer_options = "ENCODING=UTF-8"`。需要保留长字段名和编码时用 GeoPackage。

## 3 CRS 与 s2

```r
st_crs(v)
st_crs(v)$input
st_crs(v)$wkt

# 显式投影
v_proj <- st_transform(v, 32119)
v_proj <- st_transform(v, "EPSG:32633")

# 只改标签，不动坐标；确认数据本来就是该 CRS 时才用
v_labeled <- st_set_crs(v, 4326)
```

`st_crs(v) <-` 和 `st_set_crs()` 只写元数据。坐标没有变换时用它们会造成错位。

### 3.1 s2 的语义

sf 对地理坐标默认启用 s2：

```r
sf_use_s2()   # TRUE
```

启用 s2 时：

- `st_area()` 返回球面面积，单位 m²（`units`）。
- `st_distance()` 返回米。
- `st_buffer(dist = 1000)` 的 1000 按米解释。
- 几何谓词在球面上计算，跨日界线更稳。

关闭 s2 后，GEOS 按平面坐标处理经纬度：

```r
old <- sf_use_s2()
sf_use_s2(FALSE)
# 此时 dist = 1 表示 1 度，不是 1 米
sf_use_s2(old)
```

规则：

- 需要米制缓冲、面积、距离时，优先 `st_transform()` 到合适的投影 CRS。
- 不要为了修复一个拓扑错误全局关闭 s2。
- 关闭 s2 后必须恢复原状态，避免影响后续代码。
- 跨日界线的数据用 s2，或 `st_wrap_dateline()`。

## 4 属性操作

### 4.1 选择与修改

```r
library(dplyr)

v_sel <- v |>
  filter(year == 2020) |>
  select(id, name, geometry)

v_mut <- v |>
  mutate(area_km2 = as.numeric(set_units(st_area(geometry), "km^2")))
```

用 `geometry` 裸列名，不要写 `$geometry`。`select()` 会自动保留几何列。

### 4.2 连接

```r
# 普通属性连接：左表保留几何
joined <- v |>
  left_join(lookup, by = "id")

# 连接后检查行数
stopifnot(nrow(joined) == nrow(v))
```

属性连接前检查键唯一性：

```r
stopifnot(!anyDuplicated(lookup$id))
```

一对多连接会放大行数，先聚合再连接。

### 4.3 聚合

```r
summary_sf <- v |>
  group_by(region) |>
  summarise(
    n = n(),
    area_km2 = sum(as.numeric(set_units(st_area(geometry), "km^2")))
  )
```

`summarise()` 返回 `sf`，几何按组 union。属性聚合与几何聚合同时发生，结果要检查几何类型。

## 5 空间谓词

```r
st_intersects(v, y)
st_within(v, y)
st_touches(v, y)
st_covers(v, y)
st_crosses(v, y)
st_overlaps(v, y)
st_contains(v, y)
st_disjoint(v, y)
```

这些函数返回稀疏逻辑列表或矩阵。`st_intersects(v, y)` 的第 i 个元素是 `v[i, ]` 命中的 `y` 行号。

DE-9IM：

```r
st_relate(v[1, ], y[1, ])
st_relate(v[1, ], y[1, ], pattern = "T*1******")
```

先用 `st_intersects()` 缩小候选，再做 DE-9IM 细化。

## 6 空间连接

```r
# 默认左连接，谓词是 st_intersects
joined <- st_join(v, y["name"])

# 点落在多边形内
joined <- st_join(points, polygons["name"], join = st_within)

# 一个点落在多个多边形内，保留交集片体量最大的一块
joined <- st_join(points, polygons["name"], join = st_within, largest = TRUE)

# 内连接
joined_inner <- st_join(v, y["name"], left = FALSE)
```

`st_join()` 会增加列，不改变 x 的几何。一个 x 命中多个 y 时会产生多行；`largest = TRUE` 先算交集片体量，每个 x 留一块，结果与 y 的行序有关。需要“面积最大的 y”时，先算交集面积再筛。

### 6.1 最近邻

```r
idx <- st_nearest_feature(points, polygons)
nearest <- polygons[idx, ]

# 带距离的连接
joined_near <- st_join(
  points,
  polygons["name"],
  join = st_is_within_distance,
  dist = 1000
)
```

`dist` 的单位由 CRS 决定。经纬度数据先投影，或确认 s2 的距离单位。

### 6.2 距离矩阵

```r
d <- st_distance(points, polygons)
dim(d)
units::set_units(d, "km")
```

大对象两两距离矩阵会迅速膨胀。先按范围或候选集过滤。

## 7 几何操作

```r
# 修复无效几何
bad <- !st_is_valid(v)
v_valid <- st_make_valid(v)

# 缓冲
v_buf <- st_buffer(v_proj, dist = 1000)

# 叠加
inter <- st_intersection(v_proj, y_proj)
diff <- st_difference(v_proj, y_proj)
union_sfc <- st_union(v_proj)

# 简化；只用于显示或粗粒度分析
v_simple <- st_simplify(v_proj, dTolerance = 100, preserveTopology = TRUE)

# 中心点与凸包
centers <- st_centroid(st_geometry(v_proj))
hull <- st_convex_hull(st_union(v_proj))
```

注意：

- `st_union(v)` 返回 `sfc`，不是 `sf`；需要属性表时用 `summarise()` 或 `st_sf()`。
- `st_intersection()` 保留两个输入的属性，列名冲突会加后缀；结果行数可能放大。
- `st_make_valid()` 可能改变几何类型，例如把 `GEOMETRYCOLLECTION` 拆成多边形；后续用 `st_collection_extract()`。
- `st_simplify()` 的容差单位随 CRS。经纬度数据用 s2 时按米换算并保留拓扑；投影数据按 CRS 单位。简化后不要继续用面积和长度做正式统计。
- `st_buffer()` 在投影坐标下用米；经纬度数据先投影。
- `st_voronoi()` 返回 `GEOMETRYCOLLECTION`，用 `st_collection_extract("POLYGON")` 取多边形。

## 8 测量

```r
area <- st_area(v_proj)
length <- st_length(v_proj)
distance <- st_distance(v_proj[1, ], v_proj[2, ])

units::set_units(area, "km^2")
units::set_units(length, "km")
```

不要用 `st_area(x) / 1e6` 冒充 km²；`units` 标签仍是 m²。用 `set_units()` 换算。

面积和长度依赖 CRS：

- 投影坐标：平面计算，单位由 CRS 给出。
- 地理坐标 + s2：球面计算，单位米。
- 地理坐标 + GEOS：按度计算，结果没有物理意义。

多边形面积与像元面积是两种口径。比较多边形统计与栅格统计前，统一支持（support）和边界规则。

## 9 大矢量

### 9.1 读取阶段

```r
# 数据库侧过滤
v <- st_read(dsn, query = "SELECT id, geom FROM t WHERE year = 2020")

# 只读需要的列
v <- read_sf(dsn, layer = "t") |> select(id, geometry)
```

### 9.2 计算阶段

- 先 `st_is_valid()`，只修复无效几何。
- 先用 bbox 或 `st_intersects()` 缩小候选，再做逐对叠加。
- 空间连接前检查是否一对多。
- 面积、长度、缓冲在投影坐标下做。
- `st_simplify()` 只用于显示，不用于正式面积统计。
- 大范围叠加分块处理，按网格或行政区切片。

### 9.3 s2 的性能与正确性

s2 在球面上计算，跨日界线和极区更稳，但复杂几何的谓词可能更慢。不要为了速度关闭 s2 后继续使用经纬度缓冲；正确做法是投影到局部 CRS。

## 10 栅格-矢量互操作

### 10.1 多边形提取栅格值

```r
library(terra)

r <- rast("input.tif")
v_terra <- vect(v)

values <- extract(
  r,
  v_terra,
  fun = "mean",
  na.rm = TRUE,
  exact = TRUE,
  ID = FALSE
)
```

`exact = TRUE` 对边界像元按覆盖比例处理。大范围、多多边形用 `exactextractr::exact_extract()`。

### 10.2 矢量栅格化

```r
library(stars)

# sf 没有 st_rasterize()；用 stars
grid <- st_rasterize(v["value"], dx = 100, dy = 100)
```

### 10.3 栅格转矢量

```r
poly <- st_as_sf(grid, as_points = FALSE, merge = TRUE)
poly <- st_make_valid(poly)
```

`st_as_sf()` 生成的多边形经常无效，进入 sf 分析前修复。

### 10.4 点抽取

```r
points <- read_sf("points.gpkg")
values <- st_extract(grid, points)
```

`st_extract()` 要求点与栅格 CRS 一致。先 `st_transform()`。

## 11 可视化

矢量地图用 `geom_sf()`：

```r
library(ggplot2)

ggplot(v) +
  geom_sf(aes(fill = value), colour = "white", linewidth = 0.1) +
  scale_fill_viridis_c() +
  coord_sf() +
  theme_void()
```

细节见 `references/visualization.md`。

## 12 常见错误

| 症状 | 原因 | 处理 |
|---|---|---|
| 叠加结果为空 | CRS 不一致 | 先 `st_transform()` |
| 缓冲大得离谱 | 经纬度数据按度缓冲 | 投影后再缓冲，并确认 `sf_use_s2()` |
| 面积是 0 或负数 | 无效几何或错误环方向 | `st_is_valid(reason = TRUE)`、`st_make_valid()` |
| 空间连接行数翻倍 | 一对多命中 | 先聚合，或用 `largest = TRUE` 并核对语义 |
| `st_union()` 丢了属性 | 返回 `sfc` | 用 `summarise()` 或 `st_sf()` |
| 简化后面积变了 | 容差过大 | 降低 `dTolerance`；统计用原几何 |
| 读入后字段名被截断 | Shapefile 限制 | 改用 GeoPackage |
| 经纬度距离很小 | 单位是度 | 投影到米制 CRS |
| SQL 查询报 no such table | 表名写成文件名 | 用 `st_layers()` 的图层名 |

## 13 来源索引

- `geocompr/02-spatial-data.Rmd`
- `geocompr/03-attribute-operations.Rmd`
- `geocompr/04-spatial-operations.Rmd`
- `geocompr/05-geometry-operations.Rmd`
- `geocompr/06-raster-vector.Rmd`
- `geocompr/07-reproj.Rmd`
- `geocompr/08-read-write-plot.Rmd`
- `sdsr/03-Geometries.qmd`
- `sdsr/04-Spherical.qmd`
- `sdsr/05-Attributes.qmd`
- `sdsr/07-Introsf.qmd`
- `sdsr/09-Large.qmd`
- `sdsr/14-Areal.qmd`
- `sdsr/15-Measures.qmd`
