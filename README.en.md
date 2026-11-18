# R Spatial Skills

[中文](README.md) | [English](README.en.md)

A skill for spatial data work in R. It fixes three rules:

- Large rasters and heavy computation use `terra`.
- Vector geometry uses `sf`.
- Small and medium rasters, data cubes, and visualization use `stars` with `geom_stars`.

The entry point is `SKILL.md`. Detailed procedures live in `references/`; runnable examples live in `scripts/`.

## When to use

- Raster reading, cropping, masking, projection, resampling, aggregation, focal statistics, zonal statistics.
- Vector reading, attribute joins, spatial joins, overlays, buffers, simplification, area and distance.
- Multi-band and temporal data cubes, NetCDF/Zarr, proxies, `st_apply()`.
- Maps with `geom_sf()` and `geom_stars()`, and raster-vector overlays.
- Point patterns, interpolation, geostatistics, areal data, spatial regression, spatial cross-validation.
- Conversion across terra/sf/stars and result acceptance checks.

## Install

Verified on R 4.6.2. The examples use `|>` and `\(x)` syntax, so they need R 4.1 or later.

Install the dependencies:

```r
install.packages(c("terra", "sf", "stars", "ggplot2", "dplyr", "units", "cli", "sessioninfo"))
```

Clone the repository and copy the skill directory into your user skill directory:

```powershell
git clone https://github.com/evanliu3594/r-spatial-skills.git r-spatial-skills
$src = ".\r-spatial-skills"
$dst = "$env:USERPROFILE\.agents\skills\r-spatial-skills"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
```

Restart the session. The skill name is `r-spatial-skills`.

On macOS and Linux, replace `$env:USERPROFILE` with `$HOME`.

## Verify

```powershell
Rscript --vanilla scripts/run_examples.R
Rscript --vanilla scripts/check_code_blocks.R
```

Run both from the repository root. The first command runs three spatial examples. The second parses every R code block in the Markdown files.

When `Rscript` is not on PATH, use the full path. On Windows, for example:

```powershell
& 'C:\Program Files\R\R-4.6.2\bin\Rscript.exe' --vanilla scripts/run_examples.R
```

Verified environment: R 4.6.2, terra 1.9.50, sf 1.1.3, stars 0.7.3, ggplot2 4.0.3, dplyr 1.2.1, units 1.0.1.

## Layout

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

## Rule priority

Project conventions outrank this skill. Follow `yifan-r-code-style` when you write R code. This skill only adds spatial semantics, engine boundaries, and acceptance checks.

## Related

- [yifan-r-code-style](https://github.com/evanliu3594/yifan-r-code-style): R code style guide for scientific computing and visualization. The code style rules in this skill follow it.

## Sources

The four upstream projects differ in version, commit, chapter mapping, and license. Read `references/source-map.md` and `NOTICE.md` before you redistribute this skill.

## License

Code and documentation in this repository are released under the MIT License. See `LICENSE`.

The four upstream sources keep their own licenses. MIT does not cover them. See `NOTICE.md`.

## Version

1.0.0. Examples and APIs were tested on the author's machine on 2026-10-25 and re-verified under R 4.6.2 on 2026-11-18. Re-run the checks after you upgrade packages.
