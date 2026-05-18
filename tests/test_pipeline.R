# Assertions that lock the analysis invariants. Any regression in event
# coding, schema validation, row counts, or headline statistics fails here
# with a non-zero exit. Run: Rscript tests/test_pipeline.R

args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
root <- if (length(file_arg)) dirname(dirname(normalizePath(file_arg))) else getwd()
source(file.path(root, "R", "echo_survival.R"))

raw  <- load_echocardiogram(file.path(root, "data", "echocardiogram_raw.csv"))
prep <- prepare_survival_data(raw)
L    <- prep$log

check <- function(label, ok) {
  if (!isTRUE(ok)) stop("FAIL: ", label, call. = FALSE)
  cat("ok  -", label, "\n")
}

# 1. Strict ingestion: 132 source records, line 50 malformed and excluded.
check("132 source records", L$n_source == 132)
check("1 malformed record", L$n_malformed == 1)
check("malformed record is line 50", identical(L$malformed_lines, 50L))
check("131 well-formed records", L$n_wellformed == 131)

# 2. Event coding: death is still_alive == 0, not the inverse.
ev <- prep$cohort
check("event_death == 1 iff still_alive == 0",
      all(ev$event_death == as.integer(ev$still_alive == 0)))
check("events are deaths, majority of cohort",
      sum(ev$event_death) == 88 && nrow(ev) == 130)

# 3. Filtering accounting is internally consistent.
check("valid-outcome cohort = 130", L$n_valid_outcome == 130)
check("Cox complete cases = 107", L$n_complete_case == 107)
check("dropped counts reconcile",
      L$n_wellformed - L$n_dropped_outcome == L$n_valid_outcome &&
      L$n_valid_outcome - L$n_dropped_covariate == L$n_complete_case)

# 4. Per-comparison denominators.
kc_pe  <- km_counts(ev, "pericardial_effusion")
kc_wmi <- km_counts(ev, "wmi_group")
check("pericardial-effusion KM uses 130 (0 missing)",
      kc_pe$n_used == 130 && kc_pe$n_missing_group == 0)
check("wall-motion KM uses 129 (1 missing)",
      kc_wmi$n_used == 129 && kc_wmi$n_missing_group == 1)

# 5. Headline statistics are stable and remain non-significant.
cox <- fit_cox(prep$model)
check("log-rank (effusion) not significant",
      logrank(ev, "pericardial_effusion")$p_value > 0.05)
check("log-rank (wall motion) not significant",
      logrank(ev, "wmi_group")$p_value > 0.05)
check("Cox concordance near chance",
      abs(summary(cox)$concordance[["C"]] - 0.533) < 0.02)
check("no Cox covariate significant",
      all(tidy_hazard_ratios(cox)$p_value > 0.05))

cat("\nAll pipeline assertions passed.\n")
