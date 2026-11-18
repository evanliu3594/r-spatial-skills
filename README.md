# R Spatial Skills

[中文](README.md) | [English](README.en.md)

一个给 R 空间数据任务使用的技能。它规定三件事：

- 超大栅格和重计算用 `terra`。
- 矢量几何用 `sf`。
- 中小栅格、数据立方和可视化用 `stars` 与 `geom_stars`。

技能入口是 `SKILL.md`。详细操作在 `references/`，可运行示例在 `scripts/`。

## 适用任务

- 栅格读取、裁剪、掩膜、投影、重采样、聚合、邻域、分区统计。
- 矢量读取、属性连接、空间连接、叠加、缓冲、简化、面积与距离。
- 多波段/时间数据立方、NetCDF/Zarr、proxy、`st_apply()`。
- `geom_sf()`、`geom_stars()` 地图与栅格叠加。
- 点模式、插值、地统计、面数据、空间回归、空间交叉验证。
- 跨 terra/sf/stars 转换与结果验收。

## 安装

验证环境：R 4.6.2。示例使用 `|>` 与 `\(x)` 语法，需要 R 4.1 或更高版本。

安装依赖：

```r
install.packages(c("terra", "sf", "stars", "ggplot2", "dplyr", "units", "cli", "sessioninfo"))
```

克隆仓库，把技能目录复制到用户技能目录：

```powershell
git clone https://github.com/evanliu3594/r-spatial-skills.git r-spatial-skills
$src = ".\r-spatial-skills"
$dst = "$env:USERPROFILE\.agents\skills\r-spatial-skills"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
```

重启会话。技能名是 `r-spatial-skills`。

macOS 与 Linux 把 `$env:USERPROFILE` 换成 `$HOME`。

## 验证

```powershell
Rscript --vanilla scripts/run_examples.R
Rscript --vanilla scripts/check_code_blocks.R
```

在仓库根目录运行。第一行运行三个空间示例。第二行解析所有 Markdown 里的 R 代码块。

`Rscript` 不在 PATH 时改用完整路径，例如 Windows 下：

```powershell
& 'C:\Program Files\R\R-4.6.2\bin\Rscript.exe' --vanilla scripts/run_examples.R
```

本机验证环境：R 4.6.2、terra 1.9.50、sf 1.1.3、stars 0.7.3、ggplot2 4.0.3、dplyr 1.2.1、units 1.0.1。

## 目录

```text
R-spatial-skills/
├─ SKILL.md
├─ README.md
├─ README.en.md
├─ LICENSE
├─ NOTICE.md
├─ references/
│  ├─ engine-selection.md
│  ├─ terra-raster.md
│  ├─ sf-vector.md
│  ├─ stars-cube.md
│  ├─ visualization.md
│  ├─ analysis-methods.md
│  ├─ pitfalls.md
│  └─ source-map.md
└─ scripts/
   ├─ examples_terra.R
   ├─ examples_sf.R
   ├─ examples_stars.R
   ├─ run_examples.R
   └─ check_code_blocks.R
```

## 规则优先级

项目约定高于本技能。写 R 代码时同时遵守 `yifan-r-code-style`；本技能只补充空间语义、引擎边界与验收。

## 相关项目

- [yifan-r-code-style](https://github.com/evanliu3594/yifan-r-code-style)：R 代码风格规范，本技能的代码风格部分服从它。

## 来源

四个来源的版本、commit、章节映射和许可不同。使用或再分发前读 `references/source-map.md` 和 `NOTICE.md`。

## 许可

本仓库的代码与文档按 MIT 许可发布，见 `LICENSE`。

四个上游材料保留各自许可，MIT 不覆盖它们，见 `NOTICE.md`。

## 版本

1.0.0。示例与 API 已按 2026-10-25 本机环境实测。2026-11-18 在 R 4.6.2 下复验通过。包升级后重新运行验证。
