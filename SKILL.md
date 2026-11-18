---
name: r-spatial-skills
description: >
  R 空间数据运算的引擎选择与实战规范，覆盖 terra 大栅格、sf 矢量几何、stars 数据立方与 geom_stars 可视化。
  用于读写、裁剪、投影、重采样、栅格代数、邻域与分区统计、空间连接、叠加、缓冲、栅格化、点抽取、
  数据立方运算、地图绘制和结果验收。默认规则：超大栅格用 terra，矢量操作用 sf，
  中小栅格与可视化用 stars + geom_stars。含 CRS、单位、格网对齐、内存控制、跨引擎转换与常见坑。
  Triggers: R 空间数据, R spatial, terra, sf, stars, geom_stars, SpatRaster, SpatVector,
  栅格, 矢量, 空间运算, 空间连接, 空间叠加, 缓冲区, 重投影, 重采样, 裁剪, 掩膜,
  分区统计, 栅格化, 点抽取, 大栅格, 数据立方, NetCDF, COG, GeoTIFF, CRS, 空间可视化.
  编写、修改或审查涉及空间对象的 R 代码时自动启用；代码风格同时服从 yifan-r-code-style。
version: 1.0.0
tags: [R, Spatial, terra, sf, stars, Raster, Vector, Geospatial, Visualization]
---

# R Spatial Skills

本技能把四个文档库中的空间运算整理成可执行规则。它解决三件事：选对引擎、保持空间语义正确、交付前证明结果可复现。

代码风格服从 `yifan-r-code-style`。本技能只补充空间对象、CRS、格网、单位和引擎边界。

## 三条引擎硬规则

1. **超大栅格、重计算、磁盘工作流用 terra。**
   读取、裁剪、掩膜、重采样、投影、邻域、分区统计、地形、栅格代数、预测、栅格化都用 `terra`。
   不为绘图把整幅大栅格读进内存。

2. **矢量几何用 sf。**
   读取、属性连接、空间谓词、空间连接、叠加、缓冲、简化、面积与距离都用 `sf`。
   几何列始终保留；CRS 在每次跨对象运算前检查。

3. **中小栅格、时间/波段立方、可视化用 stars 与 geom_stars。**
   多波段、时间序列、NetCDF/Zarr、tidy 数组运算、`st_apply()`、`geom_stars()` 用 `stars`。
   大栅格先裁剪或降采样，再把小对象交给 `stars`。

补充规则：

- 矢量只作为大栅格的掩膜或分区时，用 `terra::vect()` 接入栅格管线，避免跨引擎复制。
- 同一任务可以换引擎，换点必须显式：先写出中间文件或转换对象，再检查 CRS、范围、分辨率、格数。
- 分类栅格的重采样用最近邻或众数；连续栅格才用双线性或三次卷积。

## 开工前四个检查

| 检查 | 栅格 | 矢量 | 失败后果 |
|---|---|---|---|
| CRS | `crs(x)`、`st_crs(x)` | `st_crs(x)` | 叠加错位、面积错 |
| 范围与分辨率 | `ext()`、`res()`、`ncell()` | `st_bbox()` | 裁错范围、网格不对齐 |
| 几何与维度 | `nlyr()`、`names()`、`inMemory()` | `st_geometry_type()`、`st_is_valid()` | 空结果、无效几何 |
| 单位与量级 | 经纬度、像元面积 | 米、度、`units` | 距离和面积差几个数量级 |

内存估算：

```r
# 一个波段按 8 字节 double 计算，单位 GiB
bytes_needed <- ncell(x) * nlyr(x) * 8
gib_needed <- bytes_needed / 1024^3

# terra 给出当前可用内存和建议分块
mem <- terra::mem_info(x)
mem[["available"]]
```

当 `gib_needed` 超过可用内存的 50%，或任务需要反复邻域运算，改用 terra 的磁盘工作流：`writeRaster()`、`tile_apply()`、`terraOptions()`。

## 标准工作流

1. **定义分析单元。** 明确结果是像元、多边形、点，还是时间切片。分析单元决定引擎和统计口径。
2. **只读元数据。** 先看类、CRS、范围、分辨率、波段、几何类型、有效性和数据量。此时不读全部像元。
3. **选引擎。** 按上面的三条硬规则和 `references/engine-selection.md` 的路由表。
4. **统一空间参照。** 所有输入先对齐 CRS；栅格还要对齐范围、分辨率和原点。
5. **执行最小运算。** 先裁剪到研究区，再计算；先检查有效像元，再统计。
6. **做守恒与边界检查。** 检查行数、面积、格数、NA 比例、分类计数和范围。
7. **写结果与图。** 栅格写 GeoTIFF/COG，矢量写 GeoPackage，图注明 CRS、单位和来源。

## 任务路由

| 任务 | 首选 | 读这份 |
|---|---|---|
| 大栅格读写、裁剪、掩膜、投影、重采样 | terra | `references/terra-raster.md` |
| 邻域、分区统计、地形、距离、栅格代数 | terra | `references/terra-raster.md` |
| 栅格转矢量、矢量转栅格、像元抽取 | terra 或 stars | `references/terra-raster.md`、`references/stars-cube.md` |
| 矢量读写、属性连接、空间连接 | sf | `references/sf-vector.md` |
| 叠加、缓冲、简化、面积、距离、最近邻 | sf | `references/sf-vector.md` |
| 多波段、时间序列、NetCDF/Zarr 数据立方 | stars | `references/stars-cube.md` |
| 中小栅格 tidy 运算、`st_apply()` | stars | `references/stars-cube.md` |
| 栅格地图、分面、与矢量叠加 | stars + geom_stars | `references/visualization.md` |
| 点模式、插值、地统计、面数据、空间回归 | 专用包 + sf/stars | `references/analysis-methods.md` |
| 引擎转换与对象互操作 | terra/sf/stars | `references/engine-selection.md` |
| 结果异常、结果对不上 | 全部 | `references/pitfalls.md` |

## 最小骨架

```r
library(terra)
library(sf)
library(stars)

# ---------- 输入 ----------
raster_path <- "data/input.tif"
vector_path <- "data/boundary.gpkg"

# 只读栅格元数据，不读像元
r <- rast(raster_path)
v <- read_sf(vector_path)

# ---------- 检查 ----------
stopifnot(!is.na(crs(r)), nzchar(crs(r)), !is.na(st_crs(v)))
stopifnot(hasValues(r), nlyr(r) >= 1L, nrow(v) > 0L)
stopifnot(all(st_is_valid(v)))

# ---------- 统一 CRS ----------
v <- st_transform(v, crs(r))

# ---------- 计算 ----------
r_study <- crop(r, v) |>
  mask(mask = v)

zonal_mean <- zonal(r_study, v, fun = "mean", na.rm = TRUE)

# ---------- 检查 ----------
stopifnot(nrow(zonal_mean) == nrow(v))
stopifnot(all(is.finite(zonal_mean[[2]]) | is.na(zonal_mean[[2]])))

# ---------- 输出 ----------
writeRaster(
  r_study,
  "output/study_area.tif",
  filetype = "COG",
  overwrite = TRUE
)
write_sf(v, "output/boundary.gpkg")
```

## 跨引擎转换

```r
# terra -> stars -> terra
r <- terra::rast("input.tif")
s <- stars::st_as_stars(r)
r2 <- terra::rast(s)
stopifnot(terra::ncell(r) == terra::ncell(r2))

# terra 矢量 -> sf -> terra 矢量
v <- terra::vect("boundary.gpkg")
v_sf <- sf::st_as_sf(v)
v2 <- terra::vect(v_sf)

# sf -> stars 栅格：先栅格化，不使用 st_as_stars() 猜分辨率
s_grid <- stars::st_rasterize(v_sf["value"], dx = 100, dy = 100)

# stars 矢量立方 -> sf
s_sf <- sf::st_as_sf(s_grid, as_points = FALSE, merge = TRUE)
```

转换后用 `crs()`、`st_crs()`、`res()`、`dim()`、`ncell()` 四项复核。

## 交付验收

- [ ] 每个输入都打印或记录 CRS、范围、分辨率、行列数、波段数或要素数。
- [ ] 所有跨对象运算的 CRS 一致；需要投影时显式 `st_transform()` 或 `project()`。
- [ ] 栅格对齐检查了 `ext()`、`res()`、`origin()` 和 `ncell()`。
- [ ] 分类重采样使用 `near` 或 `mode`，连续变量使用 `bilinear` 或 `cubic`。
- [ ] 经纬度数据没有直接按度当米算距离、缓冲或面积。
- [ ] 多边形统计处理了边界像元；需要时用 `exact = TRUE` 或 `exactextractr`。
- [ ] 大栅格没有整幅进入内存；检查过 `inMemory()`、`sources()` 和 `mem_info()`。
- [ ] 大栅格绘图先裁剪和降采样；`geom_stars(downsample = )` 已设置。
- [ ] 结果写盘后回读，检查 CRS、范围、格数和 NA 数量。
- [ ] 图有标题、单位、图例和 CRS；色标范围来自数据，不用 `limits` 裁视野。
- [ ] 关键恒等式有 `stopifnot()`；末尾有 `sessioninfo::session_info()`。
- [ ] 运行 `Rscript --vanilla scripts/run_examples.R` 通过。

## 参考文件

| 文件 | 内容 |
|---|---|
| `references/engine-selection.md` | 三引擎对象模型、任务路由、内存判断、转换矩阵 |
| `references/terra-raster.md` | 大栅格读写、代数、邻域、分区、投影、分块、COG/VRT |
| `references/sf-vector.md` | 矢量模型、CRS/s2、谓词、连接、叠加、测量、大矢量 |
| `references/stars-cube.md` | 数据立方、proxy、维度操作、`st_apply()`、栅格化、互操作 |
| `references/visualization.md` | geom_sf、geom_stars、投影、配色、叠加、输出 |
| `references/analysis-methods.md` | 点模式、插值、地统计、面数据、空间回归、空间交叉验证 |
| `references/pitfalls.md` | 高频错误的症状、原因、检查与修复 |
| `references/source-map.md` | 四个来源库的版本、章节映射与验证环境 |

## 已验证环境

本技能示例在以下环境通过 `scripts/run_examples.R`：

- R 4.6.2（1.0.0 在 4.6.1 验证，2026-11-18 在 4.6.2 复验）
- terra 1.9.50
- sf 1.1.3
- stars 0.7.3
- ggplot2 4.0.3
- tidyterra 1.3.0

`terra::tile_apply()`、`filetype = "COG"`、`vrt()`、`st_rasterize()`、`geom_stars()` 已在本机实测。依赖未安装的可选分析包在 `references/analysis-methods.md` 中单独标注。
