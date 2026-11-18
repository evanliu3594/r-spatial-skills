# 来源、版本与许可

本技能是方法性总结与原创示例。事实、函数用法和边界条件来自以下文档库；长段原文没有复制。再分发或商业使用前，按原始许可逐项核对。

## 1 来源快照

| 来源 | 本地目录 | Commit | 内容 | 许可 |
|---|---|---|---|---|
| R Spatial（terra 版） | `rspatial-terra-web` | `1f6d332` | terra 教程、分析篇、案例 | 文本与图片 CC BY-SA 4.0；R 代码 GPL-3.0 |
| Geocomputation with R | `geocompr` | `e4ddb2f` | sf、栅格-矢量、投影、读写、制图 | CC BY-NC-ND 4.0 |
| Spatial Data Science | `sdsr` | `3108521` | sf/stars 模型、数据立方、空间统计 | CC BY-NC-SA 4.0 |
| stars 包 | `stars` | `367f051` | stars 类、proxy、维度、转换、绘图 | Apache-2.0 |

原始地址：

- <https://rspatial.org/>
- <https://github.com/rspatial/rspatial-terra-web>
- <https://github.com/geocompx/geocompr>
- <https://github.com/edzer/sdsr>
- <https://github.com/r-spatial/stars>

## 2 各来源负责什么

| 主题 | 主要来源 | 本技能落点 |
|---|---|---|
| terra 对象、读写、代数、邻域、分区、投影 | rspatial-terra-web、geocompr | `terra-raster.md` |
| 大栅格磁盘工作流、分块、并行、COG/VRT | rspatial-terra-web | `terra-raster.md` |
| sf 对象、谓词、连接、叠加、测量 | geocompr、sdsr | `sf-vector.md` |
| CRS、s2、球面与平面 | geocompr、sdsr | `sf-vector.md`、`pitfalls.md` |
| stars 数据立方、proxy、st_apply | stars、sdsr | `stars-cube.md` |
| geom_stars、geom_sf、地图 | sdsr、geocompr、stars | `visualization.md` |
| 点模式、插值、地统计、面数据、回归 | sdsr、rspatial-terra-web | `analysis-methods.md` |
| 空间交叉验证 | geocompr、sdsr | `analysis-methods.md` |
| 栅格-矢量互操作 | geocompr、sdsr、stars | `sf-vector.md`、`stars-cube.md` |

## 3 版本差异

| 组件 | 文档库版本 | 本机验证版本 | 处理 |
|---|---|---|---|
| R | 文档未锁 | 4.6.2 | 1.0.0 在 4.6.1 验证，2026-11-18 在 4.6.2 复验 |
| terra | 文档对应 2026 版 | 1.9.50 | `tile_apply()` 按 1.9.50 写 |
| sf | 文档对应 1.1-3 | 1.1.3 | 一致 |
| stars | 仓库 DESCRIPTION 为 0.7-4 | 0.7.3 | 示例避开 0.7.3 未导出的功能 |
| ggplot2 | 文档未锁 | 4.0.3 | 用 `linewidth`、`after_stat()` |
| tidyterra | 文档未锁 | 1.3.0 | 只作为 terra 原生绘图备选 |

stars 仓库是开发版，安装版是 0.7.3。`filter()` 依赖 `cubelyr`，本机未装；示例改用 `[` 与 `st_crop()`。

## 4 本机验证记录

运行（在仓库根目录）：

```powershell
Rscript --vanilla scripts/run_examples.R
Rscript --vanilla scripts/check_code_blocks.R
```

首次验证在 R 4.6.1。2026-11-18 在 R 4.6.2 下复验：三个示例全通过，Markdown 里 122 个 R 代码块全部可解析。

通过内容：

- terra：裁剪、掩膜、聚合、重采样、投影、邻域、地形、分区、抽取、栅格化、多边形化、COG、VRT、`tile_apply()`、stars 互转。
- sf：读取、有效性、投影、面积、缓冲、空间连接、最近邻、叠加、简化、聚合、GeoPackage、`st_rasterize()`。
- stars：读写、proxy、维度、切片、`st_apply()`、NDVI、裁剪、`st_warp()`、点抽取、栅格化、写盘、`geom_stars()`、terra 互转。

未在本机实测：

- `gstat`、`spdep`、`spatialreg`、`spatstat`、`blockCV`、`spgwr`、`GWmodel` 的可选分析流程。
- 数据库、云路径 `/vsicurl/`、GeoParquet、Zarr 的端到端流程。
- 大规模并行集群与 HPC 调度。

这些条目在 `analysis-methods.md` 中标注为流程骨架，首次运行需自证。

## 5 引用方式

引用本技能时，同时引用原始来源。示例：

> 本分析使用 R Spatial Skills 中的 terra/sf/stars 工作流；方法来源为 R Spatial（Hijmans）、Geocomputation with R（Lovelace et al.）、Spatial Data Science（Pebesma & Bivand）与 stars 包文档（Pebesma）。

书目信息：

- Hijmans, R. J. *Spatial Data Science with R and terra*. <https://rspatial.org/>
- Lovelace, R., Nowosad, J., & Muenchow, J. (2025). *Geocomputation with R* (2nd ed.). CRC Press. <https://r.geocompx.org/>
- Pebesma, E., & Bivand, R. *Spatial Data Science: With Applications in R*. CRC Press. <https://r-spatial.org/book/>
- Pebesma, E. *stars: Spatiotemporal Arrays, Raster and Vector Data Cubes*. <https://r-spatial.github.io/stars/>

正式论文按各书要求引用印刷版，不只引用本技能。

## 6 许可边界

本仓库原创内容按 MIT 发布，见 `LICENSE` 与 `NOTICE.md`。以下条款约束来源材料。

- 四个来源的许可不同，其中 Geocomputation with R 为 CC BY-NC-ND 4.0，Spatial Data Science 为 CC BY-NC-SA 4.0。
- 本技能不复制原书长段文字；代码示例为按方法重写的最小片段。
- 商业使用、再分发改写版、打包进商业产品前，分别核对 NC、ND、SA 条款。
- terra 的 R 代码为 GPL-3.0；把 terra 代码并入其他项目时核对 GPL 义务。
- stars 为 Apache-2.0，保留 NOTICE 与许可文本。

本技能不单独授予来源材料的再许可权。

## 7 未纳入范围

- 已过时的 raster/sp 版本网站。
- tmap、mapview、leaflet 的完整制图语法；只保留与 ggplot2 的分工提示。
- GDAL/PROJ 命令行、QGIS、GRASS、SAGA 的桥接。
- 云计算平台的认证、计费与大规模调度。
- 遥感影像分类的完整建模流程；只保留栅格运算与预测接口。
