#############################################################################
# S&P GSCI Total Return index as an external passive benchmark (Sections 4.4 and 5.4,
# Appendix C.8)
#
# Data: S&P GSCI Total Return (SPGSCITR), weekly, downloaded from
#   https://www.investing.com/indices/sp-gsci-commodity-total-return-historical-data
#   on 1 November 2026 and stored unchanged in
#   data/SP_GSCI_Total_Return_weekly_Investing.csv
#
# The performance measures use the same definitions and the same weekly
# Treasury bill series as the total-account results of the strategies
# (Final_Directional_Strategy.Rmd, period summary):
#   CAGR        = (end level / start level)^(52 / weeks) - 1
#   Volatility  = sd(weekly return) * sqrt(52)
#   Sharpe      = mean(weekly excess return) / sd(weekly excess return) * sqrt(52)
#   Max DD      = largest decline from the running peak, starting at the
#                 level at the beginning of the period
#############################################################################

# Run from the project root (the folder that contains data/ and output/)
root <- "."
gsci_path <- file.path(root, "data", "SP_GSCI_Total_Return_weekly_Investing.csv")
strategy_results <- file.path(root, "output", "Strategies", "Directional Strategy",
                              "Final_Submission", "results")
out_dir <- file.path(root, "output", "Strategies", "GSCI Benchmark", "results")

# --- 1) Index levels --------------------------------------------------------
# Investing.com labels weekly bars by the Sunday that starts the week; the
# closing level is the Friday close of that week, so shift the date by 5 days.
gsci <- read.csv(gsci_path, check.names = FALSE, fileEncoding = "UTF-8-BOM")
gsci$date  <- as.Date(gsci$Date, "%m/%d/%Y") + 5
gsci$level <- as.numeric(gsub(",", "", gsci$Price))
gsci <- gsci[order(gsci$date), c("date", "level")]
stopifnot(all(diff(gsci$date) == 7))

gsci_ret <- data.frame(
  date = gsci$date[-1],
  index_return = diff(gsci$level) / head(gsci$level, -1)
)

# --- 2) Align with the strategy weeks and the T-bill series ----------------
annual_cache <- readRDS(file.path(strategy_results, "ss2000_annual_model_cache.rds"))
tbill <- annual_cache$results_df[, c("date", "tbill_rate_weekly")]
weekly <- merge(tbill, gsci_ret, by = "date")
# The first strategy week (7 Jan 2000) has no index return because the
# downloaded series starts with that week's level.

# Consistency check: weekly correlation with a long CL1 position
frozen <- read.csv(file.path(strategy_results, "30_optimization_weekly_frozen.csv"))
frozen$date <- as.Date(frozen$date)
cl1 <- frozen[frozen$run_id == "DEV_CONTRARIAN_CL1", c("date", "unit_long_gross", "price_prev")]
cl1$cl1_long_return <- cl1$unit_long_gross / (cl1$price_prev * 1000)
check <- merge(weekly, cl1[, c("date", "cl1_long_return")], by = "date")
cat("Weekly correlation with a long CL1 position:",
    round(cor(check$index_return, check$cl1_long_return), 3), "\n")

# --- 3) Period performance --------------------------------------------------
period_stats <- function(d, label) {
  r <- d$index_return
  wealth <- cumprod(1 + r)
  excess <- r - d$tbill_rate_weekly
  path <- c(1, wealth)
  drawdown <- path / cummax(path) - 1
  trough <- which.min(drawdown)
  peak <- which.max(path[seq_len(trough)])
  recovery <- which(path[trough:length(path)] >= path[peak])[1]
  dates <- c(d$date[1] - 7, d$date)
  data.frame(
    period = label, start = min(d$date), end = max(d$date), weeks = length(r),
    cumulative_return_pct = 100 * (tail(wealth, 1) - 1),
    cagr_pct = 100 * (tail(wealth, 1)^(52 / length(r)) - 1),
    volatility_pct = 100 * sd(r) * sqrt(52),
    sharpe_ratio = mean(excess) / sd(excess) * sqrt(52),
    max_drawdown_pct = 100 * min(drawdown),
    drawdown_peak = dates[peak], drawdown_trough = dates[trough],
    drawdown_recovered = if (is.na(recovery)) as.Date(NA) else dates[trough + recovery - 1]
  )
}

perf <- rbind(
  period_stats(weekly[weekly$date <= as.Date("2016-12-31"), ], "Calibration 2000-2016"),
  period_stats(weekly[weekly$date >= as.Date("2017-01-01"), ], "OOS 2017-2025"),
  period_stats(weekly, "Full 2000-2025")
)

# --- 4) Calendar-year returns (Friday closes) -------------------------------
weekly$year <- as.integer(format(weekly$date, "%Y"))
annual <- aggregate(index_return ~ year, weekly, function(r) 100 * (prod(1 + r) - 1))
names(annual)[2] <- "annual_return_pct"

print(perf, digits = 4)
print(annual, digits = 3)

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
write.csv(perf, file.path(out_dir, "gsci_period_performance.csv"), row.names = FALSE)
write.csv(annual, file.path(out_dir, "gsci_annual_returns.csv"), row.names = FALSE)
