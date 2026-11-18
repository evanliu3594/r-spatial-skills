# run_examples.R
# 依次运行三个示例，任一失败即停止
# 运行：Rscript --vanilla scripts/run_examples.R

library(cli)

# ---------- 定位 Rscript ----------
rscript_name <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
rscript <- file.path(R.home("bin"), rscript_name)
stopifnot(file.exists(rscript))

# ---------- 依次执行 ----------
examples <- c(
  "examples_terra.R",
  "examples_sf.R",
  "examples_stars.R"
)
work_dir <- file.path("scripts")

for (example in examples) {
  cli::cli_inform("Running {example}")
  status <- system2(
    command = rscript,
    args = c("--vanilla", file.path(work_dir, example))
  )
  if (!identical(status, 0L)) {
    cli::cli_abort("Example failed: {example} (exit {status})")
  }
}

cli::cli_inform(c("v" = "All examples passed"))
