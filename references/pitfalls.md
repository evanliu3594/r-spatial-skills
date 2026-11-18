# 高频错误与修复

按“症状 → 根因 → 检查 → 修复”排查。标注“实测”的条目已在本机 R 4.6.2、terra 1.9.50、sf 1.1.3、stars 0.7.3 验证。

## 1 CRS 与单位

| 症状 | 根因 | 检查 | 修复 |
|---|---|---|---|
| 叠加结果为空 | CRS 不一致 | `crs(r)`、`st_crs(v)` | `st_transform(v, crs(r))` |
| 坐标只换了标签 | 用了 `st_set_crs()` / `crs<-` | 比较 `st_bbox()` 数量级 | 真变换用 `st_transform()` / `project()` |
| 缓冲大得离谱 | 经纬度按度缓冲 | `sf_use_s2()`、`st_is_longlat()` | 投影后再缓冲 |
| 距离只有几度 | 手写欧氏距离或先转坐标矩阵 | `terra::distance()` 默认 haversine 米 | 改用 `terra::distance()` 或 `sf::st_distance()` |
| 面积差 70% | UTM 带选错 | 查 EPSG 带号与经度 | 按经度选带；跨带用等积投影 |
| 面积标成 km² 但数值没变 | 直接用 `/ 1e6` | `units(st_area(x))` | `units::set_units(st_area(x), "km^2")` |
| `st_crs(a) == st_crs(b)` 进入 `if` 报错 | 一方 CRS 为 NA，比较结果为 NA | `is.na(st_crs(x))` | 先补 CRS 或显式处理 NA |

实测：卢森堡面积在正确带 EPSG:32632 为 2565.5 km²，在错带 EPSG:32617 为 4379.6 km²。

## 2 栅格几何

| 症状 | 根因 | 检查 | 修复 |
|---|---|---|---|
| 结果范围比研究区大 | 只 `crop()` 没 `mask()` | `plot(is.na(r))` | 加 `mask()` |
| 条件掩膜一格没遮 | `mask()` 默认只遮 NA | `maskvalues` | `maskvalues = FALSE` 或 `0` |
| 掩膜后全部 NA | CRS 不一致，`mask()` 只 warning | 比较 `crs()` | 先投影 |
| 分区统计全 NaN | 没给 `na.rm = TRUE` | 分区内 NA | 加 `na.rm = TRUE` |
| 邻域结果全偏高 | `focal()` 默认 `fun = "sum"` | 调用参数 | 明确 `fun = "mean"` |
| 掩膜边界多算一圈 | 边界像元覆盖不完整 | 比较不同 `touches` 设置 | 按分析口径固定边界规则 |
| 栅格化结果全空 | `rasterize()` 不自动投影 | 比较 CRS | 先 `project(v, crs(template))` |
| 分类图出现新类别 | 分类栅格用双线性 | `is.factor(r)`、`levels(r)` | `method = "near"` |
| 栅格与模板错半格 | 原点或分辨率不同 | `res()`、`origin()`、`ext()` | `project(x, template)` 或 `resample()` |
| 缺 CRS 没被检查出来 | `crs(r)` 返回 `""`，不是 `NA` | `nzchar(crs(r))` | 同时检查 `is.na()` 与 `nzchar()` |
| 两幅栅格范围相同但格数不同 | 分辨率不同 | `ncell()`、`dim()` | 对齐后再运算 |
| 面积加权后总量不对 | `global()` 未加权 | 检查是否用 `cellSize()` | 用面积栅格做权重 |
| 经纬度像元面积按常数算 | 每行像元面积随纬度变化 | `cellSize()` | 用 `cellSize()` 或投影 |
| 结果只在临时文件 | 未显式 `writeRaster()` | `sources(r)` | 写到项目目录并回读 |

## 3 栅格-矢量

| 症状 | 根因 | 检查 | 修复 |
|---|---|---|---|
| 多边形统计偏高 | 边界像元按整格计入 | 比较 `exact = FALSE/TRUE` | `extract(..., exact = TRUE)` |
| 类别面积不等于多边形面积 | 只按像元计数 | 按 `fraction` 加权 | `exact = TRUE`，按覆盖比例汇总 |
| 大栅格提取很慢 | 逐多边形调用 | 是否一次传入全部多边形 | 一次 `extract()`；或 `exactextractr` |
| CRS 不一致但未报错 | `terra::extract()` 对 SpatVector 可能静默转换 | 显式比较 CRS | 先 `st_transform()`，再 `vect()` |
| `st_extract()` 报 no applicable method | 传入 SpatRaster | `class(x)` | 先 `st_as_stars(r)`，或改用 `terra::extract()` |
| 矢量栅格化后没有值 | 字段名错或 `fun` 不匹配 | `names(v)`、`rasterize()` 参数 | 指定 `field` 与 `fun` |
| 栅格化边界缺像元 | `touches` 默认设置 | 像元计数 | 需要压边时 `touches = TRUE` |
| 多边形化结果无效 | 栅格转多边形产生自交 | `st_is_valid()` | `st_make_valid()` |
| `st_as_stars(sf)` 不是栅格 | 默认生成矢量立方 | `st_dimensions()` | 用 `st_rasterize()` |

## 4 矢量几何

| 症状 | 根因 | 检查 | 修复 |
|---|---|---|---|
| 面积静默为 0 | 无效几何 | `st_is_valid(reason = TRUE)` | `st_make_valid()` |
| 空间连接行数翻倍 | 一对多命中 | `lengths(st_intersects())` | 先聚合；或 `largest = TRUE` |
| `st_union()` 丢属性 | 返回 `sfc` | `class()` | 用 `summarise()` 或 `st_sf()` |
| 质心落在面外 | 环状或 C 形多边形 | 画图 | `st_point_on_surface()` |
| 简化后面积变了 | 容差过大或几何类型变化 | 比较顶点数与面积 | 降低 `dTolerance`；统计用原几何 |
| 换日线 bbox 横跨全球 | bbox 按平面范围返回 | `st_bbox()` | 用 s2 边界；必要时 `st_wrap_dateline()` |
| 经度 0 到 360 与 -180 到 180 混用 | 环方向或坐标范围不统一 | 检查坐标范围 | 统一到 [-180, 180] 或 [0, 360] |
| 空几何进入连接 | 匹配为空 | `st_is_empty()` | 显式过滤或单独处理 |

## 5 数据立方与维度

| 症状 | 根因 | 检查 | 修复 |
|---|---|---|---|
| `slice()` 找不到函数 | 没有加载 dplyr | `search()` | `library(dplyr)` |
| `filter()` 报缺 cubelyr | stars 的可选依赖 | `requireNamespace("cubelyr")` | 用 `[` 或 `st_crop()` |
| 图上下翻转 | 矩阵行列顺序与 stars 维度相反 | `dim(stars)` 是 `c(x, y, ...)`，terra 是 `c(nrow, ncol, nlyr)` | 用 `array(values(r), dim = dim(s))` 写入 |
| `rast(stars)` 报维度错误 | 对象是矢量立方或维度不完整 | `st_dimensions()` | 先得到规则 x/y 栅格 |
| `geom_stars()` 画得极慢 | 没有降采样 | `prod(dim(x))` | `downsample =` |
| `geom_stars` 加 `coord_sf(crs=)` 后空白 | coord_sf 不重投影栅格 | `st_crs(x)` 是否已等于目标 | 先 `st_warp()`，再 `coord_sf(datum = NA)` |
| proxy 操作后内存暴涨 | 某个操作触发取数 | `class(x)` | 只用 `st_crop()`；预览用 `plot()` |
| `st_downsample(proxy)` 后不是 proxy | 该函数会取数 | `class()` | 预览用 `plot(proxy, downsample=)` |

## 6 性能与工程

| 症状 | 根因 | 检查 | 修复 |
|---|---|---|---|
| 大栅格内存爆 | 整幅读入 stars 或 `as.array()` | `ncell * nlyr * 8` | 先在 terra 分块、裁剪、聚合 |
| 分块邻域有接缝 | 分块没有缓冲 | 比较接缝两侧 | `tile_apply(buffer=)` 覆盖窗口半径 |
| 分块数量异常多 | `getTileExtents(x, 4)` 的 4 是每块行列数 | `nrow(getTileExtents())` | 传 `c(2000, 2000)` |
| 并行报 C++ 指针错误 | 跨进程传 SpatRaster | 工作进程是否收到对象 | 传文件名，或 `wrap(proxy = FALSE)` |
| Windows fork 并行失败 | 平台不支持 fork | 并行后端 | 用 PSOCK，或 `tile_apply()` |
| VRT 打不开 | 原始瓦片被移动 | `sources()` | 保持瓦片路径 |
| 临时文件丢失 | 只写 tempfile | 输出路径 | 显式写项目目录 |
| 同一脚本重跑结果不同 | 随机数或并行顺序 | `set.seed()` | 固定种子，固定分块策略 |
| 空间 CV 分数虚高 | 随机折泄漏 | 测试点到训练点距离 | 空间折 + 缓冲区 |

实测：随机 5 折中 26.2% 的测试点距训练点不足 1 km；空间 5 折为 0%。

## 7 空间分析

| 症状 | 根因 | 检查 | 修复 |
|---|---|---|---|
| Moran's I 很高但无意义 | 未控制趋势/协变量 | 先做非空间基线 | 加协变量，检查残差 |
| 克里金预测异常 | 变差函数外推 | 变程与预测范围 | 限制预测范围，标外推区 |
| 条件模拟内存爆 | 未设 `nmax` | 邻域规模 | 设 `nmax` 与种子 |
| 局部热点太多 | 未做多重比较校正 | p 值分布 | FDR/BY/Bonferroni，写 cutoff |
| 面数据结果与栅格不一致 | 支持不同 | 面积/像元口径 | 面积加权或重采样 |
| 投影带选错 | 按经度选带错误 | 面积与形状 | 等积投影或正确 UTM 带 |
| 点模式窗口不当 | 用 bbox 替代研究区 | 窗口面积 | 用真实边界窗口 |
| `ppp` 转换后 CRS 丢失 | `as.ppp()` 不保留 CRS | `st_crs()` | 回写时补 CRS |

## 8 最小检查函数

```r
# 矢量有效性
check_sf <- function(x) {
  stopifnot(inherits(x, "sf"), nrow(x) > 0L)
  if (is.na(st_crs(x))) {
    cli::cli_abort("Missing CRS.")
  }
  bad <- !st_is_valid(x)
  if (any(bad)) {
    cli::cli_warn("{sum(bad)} invalid geometries.")
  }
  invisible(x)
}

# 栅格对齐
check_grid <- function(x, y, tolerance = 1e-6) {
  stopifnot(inherits(x, "SpatRaster"), inherits(y, "SpatRaster"))
  stopifnot(terra::compareGeom(x, y, stopOnError = FALSE))
  stopifnot(isTRUE(all.equal(terra::res(x), terra::res(y), tolerance = tolerance)))
  stopifnot(isTRUE(all.equal(as.vector(terra::ext(x)), as.vector(terra::ext(y)), tolerance = tolerance)))
  invisible(x)
}

# stars 维度与 CRS
check_stars <- function(x) {
  stopifnot(inherits(x, "stars"))
  stopifnot(!is.na(sf::st_crs(x)))
  stopifnot(all(c("x", "y") %in% names(stars::st_dimensions(x))))
  invisible(x)
}
```

## 9 交付前最后一遍

```r
# 1. 结果回读
r_out <- terra::rast("output/result.tif")
stopifnot(terra::ncell(r_out) > 0, !is.na(terra::crs(r_out)))

# 2. 与模板对齐
stopifnot(terra::compareGeom(r_out, template, stopOnError = FALSE))

# 3. 面积守恒或范围检查
stopifnot(terra::global(r_out, "sum", na.rm = TRUE)[[1]] >= 0)

# 4. 矢量有效性
v_out <- sf::read_sf("output/result.gpkg")
stopifnot(all(sf::st_is_valid(v_out)))

# 5. 记录环境
sessioninfo::session_info()
```

检查通过只说明结构正确。数值合理性、边界规则和业务口径仍要人工核对。

## 10 来源索引

- `geocompr/04-spatial-operations.Rmd`
- `geocompr/05-geometry-operations.Rmd`
- `geocompr/06-raster-vector.Rmd`
- `geocompr/07-reproj.Rmd`
- `sdsr/03-Geometries.qmd`
- `sdsr/04-Spherical.qmd`
- `sdsr/09-Large.qmd`
- `sdsr/12-Interpolation.qmd`
- `sdsr/14-Areal.qmd`
- `sdsr/15-Measures.qmd`
- `rspatial-terra-web/source/pkg/_R/10-parallel.rmd`
- `stars/vignettes/stars2.Rmd`
- `stars/vignettes/stars5.Rmd`
- 本机实测记录：2026-10-25 的 sf、stars、terra 探针结果（已合并进本文件与 `source-map.md`）
