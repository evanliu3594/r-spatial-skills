# check_code_blocks.R
# 扫描技能目录里的 Markdown，解析所有 ```r 代码块，报告语法错误
# 运行：Rscript --vanilla scripts/check_code_blocks.R

library(cli)

# ---------- 枚举 Markdown ----------
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
files <- list.files(
  root,
  pattern = "\\.md$",
  recursive = TRUE,
  full.names = TRUE
)
files <- files[!grepl("(^|/)\\.research/", files)]

# ---------- 抽取 R 代码块 ----------
extract_r_blocks <- function(path) {
  lines <- readLines(path, warn = FALSE)
  starts <- grep("^```\\{?r", lines)
  ends <- grep("^```\\s*$", lines)
  if (length(starts) == 0L) {
    return(list())
  }
  blocks <- vector("list", length(starts))
  for (i in seq_along(starts)) {
    after <- ends[ends > starts[i]]
    if (length(after) == 0L) {
      cli::cli_abort("Unclosed R chunk in {path} at line {starts[i]}.")
    }
    blocks[[i]] <- list(
      line = starts[i] + 1L,
      code = paste(lines[(starts[i] + 1L):(after[1] - 1L)], collapse = "\n")
    )
  }
  blocks
}

# ---------- 解析 ----------
errors <- list()
total <- 0L

for (path in files) {
  blocks <- extract_r_blocks(path)
  for (block in blocks) {
    total <- total + 1L
    result <- tryCatch(
      {
        parse(text = block$code)
        NULL
      },
      error = function(e) conditionMessage(e)
    )
    if (!is.null(result)) {
      errors[[length(errors) + 1L]] <- list(
        file = sub(paste0(root, "/"), "", path, fixed = TRUE),
        line = block$line,
        message = result
      )
    }
  }
}

if (length(errors) > 0L) {
  for (err in errors) {
    cli::cli_alert_danger("{err$file}:{err$line}: {err$message}")
  }
  cli::cli_abort("{length(errors)} of {total} R chunks failed to parse.")
}

cli::cli_alert_success(
  "Parsed {total} R chunks in {length(files)} Markdown files."
)
