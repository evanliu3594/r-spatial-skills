# examples_terra.R
# 输入：terra 包自带示例栅格与矢量
# 输出：临时目录下的 COG、VRT 与分块结果，仅用于验证
# 运行：Rscript --vanilla scripts/examples_terra.R
# 口径：大栅格走磁盘，所有结果检查 CRS、格数与来源

library(terra)
library(cli)

# ---------- 准备 ----------
out_dir <- file.path(tempdir(), "r_spatial_skill_terra")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

elev_path <- system.file("ex/elev.tif", package = "terra")
lux_path <- system.file("ex/lux.shp", package = "terra")
stopifnot(nzchar(elev_path), nzchar(lux_path))

elev <- rast(elev_path)
lux <- vect(lux_path)
stopifnot(nlyr(elev) == 1L, !is.na(crs(elev)), nrow(lux) > 0)

cli::cli_inform(c(
  "i" = "cells: {ncell(elev)}",
  "i" = "resolution: {paste(res(elev), collapse = ' x ')}",
  "i" = "in memory: {inMemory(elev)}"
))

# ---------- 裁剪、掩膜、聚合 ----------
elev_lux <- crop(elev, lux) |>
  mask(mask = lux)

elev_agg <- aggregate(elev_lux, fact = 2, fun = "mean", na.rm = TRUE)
stopifnot(ncell(elev_agg) < ncell(elev_lux))

# ---------- 对齐、重采样、投影 ----------
template <- rast(ext(elev_lux), resolution = 0.02, crs = crs(elev_lux))
elev_res <- resample(elev_lux, template, method = "bilinear")

elev_proj <- project(elev_lux, "EPSG:2169", method = "bilinear")
stopifnot(!is.na(crs(elev_proj)))

# ---------- 邻域、地形、分区统计 ----------
elev_focal <- focal(
  elev_lux,
  w = 3,
  fun = "mean",
  na.policy = "only",
  na.rm = TRUE
)

elev_terrain <- terrain(elev_lux, v = c("slope", "aspect"), unit = "degrees")

zone_mean <- zonal(elev_lux, lux, fun = "mean", na.rm = TRUE)
poly_mean <- extract(
  elev_lux,
  lux,
  fun = "mean",
  na.rm = TRUE,
  exact = TRUE,
  ID = FALSE
)
stopifnot(nrow(zone_mean) == nrow(lux), nrow(poly_mean) == nrow(lux))

# ---------- 栅格化与矢量化 ----------
pop_template <- rast(ext(lux), resolution = 0.01, crs = crs(lux))
pop_raster <- rasterize(lux, pop_template, field = "POP", fun = "sum")

highland <- as.polygons(elev_agg > 350, dissolve = TRUE)
stopifnot(nrow(highland) >= 1L)

# ---------- 磁盘写出与 COG ----------
cog_path <- file.path(out_dir, "elev_agg_cog.tif")
writeRaster(
  elev_agg,
  cog_path,
  filetype = "COG",
  overwrite = TRUE,
  datatype = "FLT4S"
)
cog <- rast(cog_path)
stopifnot(file.exists(cog_path), ncell(cog) == ncell(elev_agg))

# ---------- 多文件 VRT ----------
extent_values <- as.vector(ext(elev_lux))
mid_x <- mean(extent_values[1:2])
left_path <- file.path(out_dir, "elev_left.tif")
right_path <- file.path(out_dir, "elev_right.tif")
left_extent <- ext(extent_values[1], mid_x, extent_values[3], extent_values[4])
right_extent <- ext(mid_x, extent_values[2], extent_values[3], extent_values[4])
writeRaster(crop(elev_lux, left_extent), left_path, overwrite = TRUE)
writeRaster(crop(elev_lux, right_extent), right_path, overwrite = TRUE)

vrt_path <- file.path(out_dir, "elev_mosaic.vrt")
elev_vrt <- vrt(c(left_path, right_path), vrt_path)
stopifnot(file.exists(vrt_path), ncell(elev_vrt) == ncell(elev_lux))

# ---------- 分块邻域运算 ----------
tile_path <- file.path(out_dir, "elev_tile_focal.tif")
elev_tile <- tile_apply(
  elev_lux,
  fun = function(x) focal(x, w = 3, fun = "mean"),
  cores = 2,
  filename = tile_path,
  overwrite = TRUE
)
stopifnot(file.exists(tile_path), ncell(elev_tile) == ncell(elev_lux))

# ---------- 面积与内存核对 ----------
cell_area <- mask(cellSize(elev_lux, unit = "km"), elev_lux)
area_total <- global(cell_area, "sum", na.rm = TRUE)[[1]]
poly_area <- sum(expanse(lux, unit = "km"))
mem <- mem_info(elev_lux)
stopifnot(area_total > 0, poly_area > 0, "available" %in% names(mem))

# ---------- 与 stars 互转 ----------
elev_stars <- stars::st_as_stars(elev_agg)
elev_back <- rast(elev_stars)
stopifnot(ncell(elev_back) == ncell(elev_agg))

cli::cli_inform(c(
  "v" = "terra example passed",
  "i" = "raster area (km2): {round(area_total, 2)}",
  "i" = "polygon area (km2): {round(poly_area, 2)}",
  "i" = "output: {out_dir}"
))

sessioninfo::session_info()
