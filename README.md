# Evaluating the Schwartz–Smith (2000) Two-Factor Model for Trading Crude Oil Futures

Code for the master thesis by Fabian Welti (University of St. Gallen, MBF). All code is written in R.

## Run order

1. `data/Full Bloomberg Data Import Weekly.R`: turns the raw Bloomberg export into the weekly CL1–CL120 futures panel (`CL_weekly_full_with_underlying_v2.rds`, already included).
2. `output/Bloomi Data/S&S 2000 Replication.Rmd`: estimates the model on the original paper's 1990–1995 sample (Chapter 3.1).
3. `output/Bloomi Data/S&S 2000 Analytics.Rmd`: diagnostics, forecast evaluation and comparison with the paper's tables for the replication (Chapter 3.1). Requires step 2.
4. `output/Bloomi Data/S&S 2000 Full Timeline.Rmd`: estimates the model on the full 1984–2025 sample (Chapter 3.2).
5. `output/Bloomi Data/S&S 2000 Analytics Full Timeline.Rmd`: diagnostics and out-of-sample evaluation for the full sample (Chapter 3.2). Requires step 4.
6. `output/Strategies/Directional Strategy/Final_Submission/Final_Directional_Strategy.Rmd`: backtests the contrarian (H1) and one-week forecast (H3) strategies (Chapters 4–5).
7. `output/Strategies/RV Strategy/Final_Submission/Final_RV_Strategy.Rmd`: backtests the CL1–CL17 relative-value calendar-spread strategy (H2) (Chapters 4–5).
8. `output/Strategies/GSCI Benchmark/gsci_benchmark.R`: computes the passive S&P GSCI benchmark. Requires step 6.
9. `Thesis/Appendix Charts/create_appendix_charts.R`: creates appendix Figures D.1 and F.1–F.3. Requires step 6.

Steps 6 and 7 re-estimate the model themselves, so they do not depend on steps 2–5.

## Data (`data/`)

Weekly WTI futures from Bloomberg, the 3-month T-bill rate (DTB3) from FRED, and the S&P GSCI Total Return index from Investing.com.

## Notes

- Steps 2 and 4 set `DATA_ROOT` to a local path near the top of the file. Point it to this folder before running.
- Step 8 is run from this folder. Step 9 expects the results of step 6 under `MA Code /Master Thesis 1.1/`, so `results_dir` at the top of that script needs to point to the Directional Strategy results folder.
