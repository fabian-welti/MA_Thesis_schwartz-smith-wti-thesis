# Evaluating the Schwartz–Smith (2000) Two-Factor Model for Trading Crude Oil Futures

Code for the master thesis by Fabian Welti (University of St. Gallen, MBF). All code is written in R.

## Run order

| Step | File | Purpose |
|---|---|---|
| 1 | `Full Bloomberg Data Import Weekly.R` | Turns the raw Bloomberg export into the weekly CL1–CL120 futures panel (`CL_weekly_full_with_underlying_v2.rds`, already included). |
| 2 | `S&S 2000 Replication.Rmd` | Estimates the model on the original paper's 1990–1995 sample (Chapter 3.1). |
| 3 | `S&S 2000 Analytics.Rmd` | Diagnostics, forecast evaluation and comparison with the paper's tables for the replication (Chapter 3.1). Requires step 2. |
| 4 | `S&S 2000 Full Timeline.Rmd` | Estimates the model on the full 1984–2025 sample (Chapter 3.2). |
| 5 | `S&S 2000 Analytics Full Timeline.Rmd` | Diagnostics and out-of-sample evaluation for the full sample (Chapter 3.2). Requires step 4. |
| 6 | `Final_Directional_Strategy.Rmd` | Backtests the contrarian (H1) and one-week forecast (H3) strategies (Chapters 4–5). |
| 7 | `Final_RV_Strategy.Rmd` | Backtests the CL1–CL17 relative-value calendar-spread strategy (H2) (Chapters 4–5). |
| 8 | `gsci_benchmark.R` | Computes the passive S&P GSCI benchmark. Requires step 6. |
| 9 | `create_appendix_charts.R` | Creates appendix Figures D.1 and F.1–F.3. Requires step 6. |

Steps 6 and 7 re-estimate the model themselves, so they do not depend on steps 2–5.

## Data

| File | Content |
|---|---|
| `Final Full Weekly Data .xlsx` | Raw weekly WTI futures export from Bloomberg (input to step 1). |
| `CL_weekly_full_with_underlying_v2.rds` | Weekly futures panel created in step 1 (input to steps 2 and 4–7). |
| `DTB3.xlsx` | 3-month Treasury bill rate from FRED (steps 6 and 7). |
| `SP_GSCI_Total_Return_weekly_Investing.csv` | S&P GSCI Total Return index from Investing.com (step 8). |

## Running the code

The files are stored in one folder here, but the scripts find their inputs through the folder layout they were run in. To run them, arrange the files like this:

```
data/                                                     the four data files and Full Bloomberg Data Import Weekly.R
output/Bloomi Data/                                       the four S&S 2000 notebooks
output/Strategies/Directional Strategy/Final_Submission/  Final_Directional_Strategy.Rmd
output/Strategies/RV Strategy/Final_Submission/           Final_RV_Strategy.Rmd
output/Strategies/GSCI Benchmark/                         gsci_benchmark.R
Thesis/Appendix Charts/                                   create_appendix_charts.R
```

- Notebooks are knitted from their own folder and write their results to a `results/` folder next to them.
- Steps 2 and 4 set `DATA_ROOT` to a local path near the top of the file. Point it to the top folder (the one that contains `data/`).
- Steps 1, 8 and 9 are run from the top folder. In step 9, set `results_dir` at the top of the script to `output/Strategies/Directional Strategy/Final_Submission/results`.
