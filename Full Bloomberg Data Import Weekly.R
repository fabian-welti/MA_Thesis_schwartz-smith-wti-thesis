#############################################################################
# Data Import: Bloomberg WTI Futures (CL1–CL120)
# Date: 17.02.2026
#
# Excel layout per generic contract (after removing spacer cols):
#   [Date_bad, Settlement, Date_good, UnderlyingContract, LastTradeDate]
#
# We will DROP Date_bad and use Date_good as the canonical date.
#
# Outputs:
#   (A) weekly_curve_v2: wide panel (date + one col per generic contract price)
#   (B) underlying_map_v2: long panel (contract, date, underlying_contract, last_trade_date)
#############################################################################

library(tidyverse)
library(readxl)
library(lubridate)
library(stringr)

# ------------------------------------------------------------------ #
# 1) Paths
# ------------------------------------------------------------------ #
DIR_RAW <- "data"

FILE_EXCEL <- file.path(DIR_RAW, "Final Full Weekly Data .xlsx")
SHEET      <- "Data"

OUT_RDS_V2   <- file.path(DIR_RAW, "CL_weekly_by_contract_v2.rds")
OUT_CSV_V2   <- file.path(DIR_RAW, "CL_weekly_by_contract_v2.csv")
OUT_MAP_RDS  <- file.path(DIR_RAW, "CL_weekly_underlying_map_v2.rds")
OUT_MAP_CSV  <- file.path(DIR_RAW, "CL_weekly_underlying_map_v2.csv")

dir.create(DIR_RAW, showWarnings = FALSE, recursive = TRUE)

# ------------------------------------------------------------------ #
# 2) Helper: robust date parser
# ------------------------------------------------------------------ #
safe_parse_date <- function(x) {
  
  if (inherits(x, "Date")) return(x)
  
  # numeric -> Excel serial
  if (is.numeric(x)) {
    return(as.Date(x, origin = "1899-12-30"))
  }
  
  # character that looks numeric -> Excel serial
  x_chr <- as.character(x)
  x_trim <- trimws(x_chr)
  
  num_guess <- suppressWarnings(as.numeric(x_trim))
  if (!all(is.na(num_guess))) {
    return(as.Date(num_guess, origin = "1899-12-30"))
  }
  
  # try common string formats
  out <- suppressWarnings(as.Date(x_trim, format = "%d.%m.%Y"))
  if (all(is.na(out))) out <- suppressWarnings(as.Date(x_trim, format = "%Y-%m-%d"))
  if (all(is.na(out))) out <- suppressWarnings(as.Date(x_trim, format = "%m/%d/%Y"))
  
  out
}

# ------------------------------------------------------------------ #
# 3) Read Excel (raw grid)
# ------------------------------------------------------------------ #
raw <- read_excel(FILE_EXCEL, sheet = SHEET, col_names = FALSE)

# ------------------------------------------------------------------ #
# 3b) Remove completely empty spacer columns
# ------------------------------------------------------------------ #
is_empty_col <- sapply(raw, function(col) {
  v <- as.character(col)
  all(is.na(v) | trimws(v) == "")
})

raw <- raw[, !is_empty_col]

# Split header + data
hdr <- as.character(raw[1, ] %>% unlist(use.names = FALSE))
dat <- raw[-1, , drop = FALSE]

# ------------------------------------------------------------------ #
# 4) Identify blocks by header contract names
# ------------------------------------------------------------------ #
block_starts <- which(!is.na(hdr) & trimws(hdr) != "")

if (length(block_starts) == 0) stop("No contract headers found in first row.")

block_ends <- c(block_starts[-1] - 1, ncol(dat))
block_widths <- block_ends - block_starts + 1

# We need at least 5 columns inside each block:
# [Date_bad, Price, Date_good, Underlying, LTD]
bad_blocks <- which(block_widths < 5)
if (length(bad_blocks) > 0) {
  stop(
    paste0(
      "Some detected blocks are too narrow (<5 cols). Problem blocks: ",
      paste(bad_blocks, collapse = ", "),
      "\nWidths: ", paste(block_widths[bad_blocks], collapse = ", "),
      "\nHeaders: ", paste(hdr[block_starts[bad_blocks]], collapse = ", ")
    )
  )
}

message("Detected ", length(block_starts), " contract blocks. ",
        "Min width=", min(block_widths), ", Max width=", max(block_widths),
        ". Total cols(after spacer removal)=", ncol(dat))

# ------------------------------------------------------------------ #
# 5) Build long tables using Date_good (3rd col) instead of Date_bad (1st col)
#    We conceptually "drop" Date_bad by never using it.
# ------------------------------------------------------------------ #
prices_list <- purrr::map(seq_along(block_starts), function(k) {
  i <- block_starts[k]
  contract <- hdr[i]
  
  tibble(
    contract = contract,
    date     = safe_parse_date(dat[[i + 2]]),                 # Date_good
    price    = suppressWarnings(as.numeric(dat[[i + 1]]))      # Settlement
  )
})

map_list <- purrr::map(seq_along(block_starts), function(k) {
  i <- block_starts[k]
  contract <- hdr[i]
  
  tibble(
    contract             = contract,
    date                 = safe_parse_date(dat[[i + 2]]),      # Date_good
    underlying_contract  = as.character(dat[[i + 3]]),
    last_trade_date      = safe_parse_date(dat[[i + 4]])
  )
})

long_prices <- bind_rows(prices_list) %>%
  filter(!is.na(date)) %>%
  arrange(contract, date)

long_map <- bind_rows(map_list) %>%
  filter(!is.na(date)) %>%
  arrange(contract, date)

# Deduplicate (contract, date)
long_prices <- long_prices %>%
  group_by(contract, date) %>%
  summarize(
    price = {
      px <- price[!is.na(price)]
      if (length(px) == 0) NA_real_ else dplyr::last(px)
    },
    .groups = "drop"
  ) %>%
  arrange(contract, date)

long_map <- long_map %>%
  group_by(contract, date) %>%
  summarize(
    underlying_contract = {
      u <- underlying_contract[!is.na(underlying_contract) & underlying_contract != ""]
      if (length(u) == 0) NA_character_ else dplyr::last(u)
    },
    last_trade_date = {
      ltd <- last_trade_date[!is.na(last_trade_date)]
      if (length(ltd) == 0) as.Date(NA) else dplyr::last(ltd)
    },
    .groups = "drop"
  ) %>%
  arrange(contract, date)

# ------------------------------------------------------------------ #
# 6) Wide price panel (same output idea as before)
# ------------------------------------------------------------------ #
weekly_curve_v2 <- long_prices %>%
  pivot_wider(names_from = contract, values_from = price) %>%
  arrange(date) %>%
  distinct(date, .keep_all = TRUE)

# Reorder columns numerically if contracts contain digits (CL1, CL2, ...)
all_cols      <- names(weekly_curve_v2)
contract_cols <- setdiff(all_cols, "date")

has_num      <- str_detect(contract_cols, "\\d+")
non_numbered <- contract_cols[!has_num]
numbered     <- contract_cols[has_num]
numbered_sorted <- numbered[order(as.numeric(str_extract(numbered, "\\d+")))]

weekly_curve_v2 <- weekly_curve_v2 %>%
  select(date, all_of(non_numbered), all_of(numbered_sorted))

# ------------------------------------------------------------------ #
# 6b) FULL wide panel: price + underlying + last trade date
# ------------------------------------------------------------------ #

weekly_full_v2 <- long_prices %>%
  left_join(long_map, by = c("contract", "date")) %>%
  mutate(
    PX  = price,
    UND = underlying_contract,
    LTD = last_trade_date
  ) %>%
  select(contract, date, PX, UND, LTD) %>%
  pivot_wider(
    names_from  = contract,
    values_from = c(PX, UND, LTD),
    names_glue  = "{contract}__{.value}"
  ) %>%
  arrange(date) %>%
  distinct(date, .keep_all = TRUE)

# Optional: reorder columns by contract number (CL1..CL120), keeping PX/UND/LTD grouped
full_cols <- names(weekly_full_v2)
other_cols <- setdiff(full_cols, "date")

# extract contract name part before "__"
contract_name <- str_replace(other_cols, "__.*$", "")

# unique contracts in order (numeric-aware)
uniq_contracts <- unique(contract_name)

has_num <- str_detect(uniq_contracts, "\\d+")
non_num <- uniq_contracts[!has_num]
num     <- uniq_contracts[has_num]
num_sorted <- num[order(as.numeric(str_extract(num, "\\d+")))]

ordered_contracts <- c(non_num, num_sorted)

# build ordered column list: for each contract, PX then UND then LTD
ordered_cols <- c(
  "date",
  unlist(lapply(ordered_contracts, function(cn) {
    c(paste0(cn, "__PX"), paste0(cn, "__UND"), paste0(cn, "__LTD"))
  }))
)

# keep only columns that exist (safety)
ordered_cols <- ordered_cols[ordered_cols %in% names(weekly_full_v2)]
weekly_full_v2 <- weekly_full_v2 %>% select(all_of(ordered_cols))

# ------------------------------------------------------------------ #
# 7) Underlying mapping output (long)
# ------------------------------------------------------------------ #
underlying_map_v2 <- long_map


# ------------------------------------------------------------------ #
# 7b) Build FULL dataset: price + underlying + LTD (wide format)
# ------------------------------------------------------------------ #

weekly_full_v2 <- weekly_curve_v2 %>%
  pivot_longer(cols = -date, names_to = "contract", values_to = "PX") %>%
  left_join(underlying_map_v2, by = c("contract", "date")) %>%
  rename(
    UND = underlying_contract,
    LTD = last_trade_date
  ) %>%
  pivot_wider(
    names_from  = contract,
    values_from = c(PX, UND, LTD),
    names_glue  = "{contract}__{.value}"
  ) %>%
  arrange(date)


# ------------------------------------------------------------------ #
# 8) Save
# ------------------------------------------------------------------ #
write_rds(weekly_curve_v2, OUT_RDS_V2)
write_csv(weekly_curve_v2, OUT_CSV_V2)

write_rds(underlying_map_v2, OUT_MAP_RDS)
write_csv(underlying_map_v2, OUT_MAP_CSV)

OUT_FULL_RDS <- file.path(DIR_RAW, "CL_weekly_full_with_underlying_v2.rds")
OUT_FULL_CSV <- file.path(DIR_RAW, "CL_weekly_full_with_underlying_v2.csv")

write_rds(weekly_full_v2, OUT_FULL_RDS)
write_csv(weekly_full_v2, OUT_FULL_CSV)


message("Import complete (V2):",
        "\n\n(A) Prices panel:",
        "\n  Rows (dates): ", nrow(weekly_curve_v2),
        "\n  Contracts: ", ncol(weekly_curve_v2) - 1L,
        "\n  Saved to:",
        "\n    - ", OUT_RDS_V2,
        "\n    - ", OUT_CSV_V2,
        "\n\n(B) Underlying mapping (long):",
        "\n  Rows: ", nrow(underlying_map_v2),
        "\n  Saved to:",
        "\n    - ", OUT_MAP_RDS,
        "\n    - ", OUT_MAP_CSV)

