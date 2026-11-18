# examples_sf.R
# 输入：sf 包自带 NC 县界
# 输出：临时目录下的 GeoPackage 与 stars 栅格，仅用于验证
# 运行：Rscript --vanilla scripts/examples_sf.R
# 口径：矢量操作用 sf；面积与缓冲在投影坐标下计算

library(sf)
library(dplyr)
library(units)
library(cli)

# ---------- 读入与检查 ----------
nc_path <- system.file("shape/nc.shp", package = "sf")
stopifnot(nzchar(nc_path))

nc <- read_sf(nc_path)
stopifnot(inherits(nc, "sf"), nrow(nc) > 0L)
stopifnot(all(st_is_valid(nc)))

cli::cli_inform(c(
  "i" = "features: {nrow(nc)}",
  "i" = "geometry type: {unique(as.character(st_geometry_type(nc)))}",
  "i" = "CRS: {st_crs(nc)$input}"
))

# ---------- 投影、面积、缓冲 ----------
nc_proj <- st_transform(nc, 32119)
area_km2 <- set_units(st_area(nc_proj), "km^2")
stopifnot(all(as.numeric(area_km2) > 0))

county_points <- st_sf(
  name = nc_proj$NAME,
  geometry = st_centroid(st_geometry(nc_proj))
)
buffers <- st_buffer(county_points, dist = 1000)
stopifnot(all(as.numeric(st_area(buffers)) > 0))

# ---------- 空间谓词与空间连接 ----------
within_hits <- st_join(
  county_points,
  nc_proj["NAME"],
  join = st_within
)
stopifnot(nrow(within_hits) == nrow(county_points))

nearest <- st_nearest_feature(county_points[1:3, ], nc_proj)
distance_km <- set_units(st_distance(county_points[1:3, ], nc_proj[1, ]), "km")
stopifnot(length(nearest) == 3L, all(as.numeric(distance_km) >= 0))

# ---------- 几何修复、叠加、简化 ----------
bad <- st_sfc(
  st_polygon(list(rbind(c(0, 0), c(1, 1), c(1, 0), c(0, 1), c(0, 0)))),
  crs = 3857
)
stopifnot(!st_is_valid(bad))
fixed <- st_make_valid(bad)
stopifnot(st_is_valid(fixed))

overlap <- st_intersection(
  st_geometry(nc_proj[1:2, ]),
  st_geometry(nc_proj[2:3, ])
)
county_union <- st_union(nc_proj[1:2, ])
county_diff <- st_difference(
  st_geometry(nc_proj[1, ]),
  st_geometry(nc_proj[2, ])
)
county_simple <- st_simplify(
  nc_proj,
  dTolerance = 100,
  preserveTopology = TRUE
)
stopifnot(length(overlap) >= 1L, inherits(county_union, "sfc"))

# ---------- 属性聚合 ----------
county_summary <- nc_proj |>
  group_by(high_sid74 = SID74 > 0) |>
  summarise(
    n = n(),
    area_km2 = sum(as.numeric(set_units(st_area(geometry), "km^2")))
  )
stopifnot(inherits(county_summary, "sf"), nrow(county_summary) == 2L)

# ---------- 写出与回读 ----------
gpkg_path <- file.path(tempdir(), "nc_counties.gpkg")
write_sf(nc_proj[1:10, ], gpkg_path, quiet = TRUE)
nc_back <- read_sf(gpkg_path)
stopifnot(nrow(nc_back) == 10L)

# ---------- 与 stars 互操作：栅格化 ----------
nc_raster <- stars::st_rasterize(nc["BIR74"], dx = 0.1, dy = 0.1)
stopifnot(inherits(nc_raster, "stars"))

# ---------- 球面与平面语义 ----------
s2_was_on <- sf_use_s2()
sf_use_s2(TRUE)
area_s2 <- st_area(nc[1, ])
sf_use_s2(FALSE)
area_planar <- st_area(nc[1, ])
sf_use_s2(s2_was_on)

cli::cli_inform(c(
  "v" = "sf example passed",
  "i" = "first county area (km2): {round(as.numeric(area_km2[1]), 2)}",
  "i" = "s2 area: {round(as.numeric(area_s2), 1)}",
  "i" = "planar area: {round(as.numeric(area_planar), 1)}",
  "i" = "geometry package links: GEOS/GDAL/PROJ"
))

sessioninfo::session_info()
