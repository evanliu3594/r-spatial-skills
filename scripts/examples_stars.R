# examples_stars.R
# 输入：stars 包自带 Landsat 影像与 sf 包 NC 县界
# 输出：临时目录下的 NDVI GeoTIFF 与地图 PNG，仅用于验证
# 运行：Rscript --vanilla scripts/examples_stars.R
# 口径：中小栅格、数据立方和可视化用 stars/geom_stars

library(stars)
library(dplyr)
library(ggplot2)
library(sf)
library(terra)
library(cli)

# ---------- 读入与维度 ----------
tif_path <- system.file("tif/L7_ETMs.tif", package = "stars")
stopifnot(nzchar(tif_path))

image <- read_stars(tif_path)
image_proxy <- read_stars(tif_path, proxy = TRUE)
stopifnot(inherits(image, "stars"), inherits(image_proxy, "stars_proxy"))

dim_text <- paste(names(dim(image)), dim(image), sep = "=", collapse = ", ")
cli::cli_inform(c(
  "i" = "dimensions: {dim_text}",
  "i" = "proxy: {inherits(image_proxy, 'stars_proxy')}"
))

# ---------- 切片、波段运算、按边距归约 ----------
band_1 <- slice(image, along = "band", index = 1)
ndvi <- st_apply(
  image,
  c("x", "y"),
  \(z) (z[4] - z[3]) / (z[4] + z[3])
)
band_mean <- st_apply(image, "band", mean, na.rm = TRUE)
stopifnot(inherits(ndvi, "stars"), inherits(band_mean, "stars"))

# ---------- 裁剪、重采样到规则网格 ----------
bb <- st_bbox(image)
crop_box <- st_bbox(
  c(
    xmin = as.numeric(bb["xmin"]) + 500,
    ymin = as.numeric(bb["ymin"]) + 500,
    xmax = as.numeric(bb["xmax"]) - 500,
    ymax = as.numeric(bb["ymax"]) - 500
  ),
  crs = st_crs(image)
)
image_crop <- st_crop(image, crop_box)

target <- st_as_stars(st_bbox(image_crop), nx = 80, ny = 80)
image_warp <- st_warp(image_crop, target)
stopifnot(inherits(image_warp, "stars"))

# ---------- 点抽取、矢量栅格化 ----------
set.seed(1)
points <- st_sf(
  id = 1:3,
  geometry = st_sample(st_as_sfc(st_bbox(band_1)), 3)
)
point_values <- st_extract(band_1, points)
stopifnot(nrow(point_values) == 3L)

nc <- read_sf(system.file("shape/nc.shp", package = "sf"))
nc_raster <- st_rasterize(nc["BIR74"], dx = 0.1, dy = 0.1)
stopifnot(inherits(nc_raster, "stars"))

# ---------- 写出与回读 ----------
out_dir <- file.path(tempdir(), "r_spatial_skill_stars")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
ndvi_path <- file.path(out_dir, "ndvi.tif")
write_stars(ndvi, ndvi_path)
ndvi_back <- read_stars(ndvi_path)
stopifnot(file.exists(ndvi_path), inherits(ndvi_back, "stars"))

# ---------- 可视化 ----------
map <- ggplot() +
  geom_stars(data = band_1, downsample = 2) +
  coord_equal() +
  scale_fill_viridis_c(na.value = "transparent") +
  labs(fill = "DN", title = "Landsat band 1") +
  theme_void()

map_path <- file.path(out_dir, "landsat_band1.png")
ggsave(map_path, map, width = 7, height = 5, dpi = 300)
stopifnot(file.exists(map_path))

# ---------- 与 terra 互转 ----------
image_terra <- rast(image)
image_stars <- st_as_stars(image_terra)
stopifnot(ncell(image_terra) == prod(dim(image_stars)[1:2]))

cli::cli_inform(c(
  "v" = "stars example passed",
  "i" = "NDVI cells: {prod(dim(ndvi))}",
  "i" = "crop cells: {prod(dim(image_crop))}",
  "i" = "output: {out_dir}"
))

sessioninfo::session_info()
