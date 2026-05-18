# Runs the full analysis from the command line: prints a summary and
# writes the figures. Same engine as the report. Usage:
#   Rscript R/run_analysis.R

suppressPackageStartupMessages(library(ggplot2))

# Find the repo root from --file= so it runs from any directory.
args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
root <- if (length(file_arg)) dirname(dirname(normalizePath(file_arg))) else getwd()

source(file.path(root, "R", "echo_survival.R"))

section <- function(title) cat("\n==", title, "==\n")

raw <- load_echocardiogram(file.path(root, "data", "echocardiogram_raw.csv"))
prep <- prepare_survival_data(raw)
dat <- prep$cohort
model_df <- prep$model
plog <- prep$log

section("Data preparation")
cat("Source records:", plog$n_source, "\n")
cat("Malformed (excluded):", plog$n_malformed,
    sprintf("(line %s)\n", paste(plog$malformed_lines, collapse = ", ")))
cat("Well-formed records:", plog$n_wellformed, "\n")
cat("Dropped, missing outcome:", plog$n_dropped_outcome, "\n")
cat("Valid-outcome cohort:", plog$n_valid_outcome, "\n")
cat("Dropped, missing covariate:", plog$n_dropped_covariate, "\n")
cat("Cox complete cases:", plog$n_complete_case, "\n")

section("Cohort and censoring")
co <- summarise_cohort(dat)
cat(sprintf("%d patients, %d deaths (%.1f%%), %d censored\n",
            co$n, co$events, 100 * co$events / co$n, co$censored))
cat("Median survival:",
    ifelse(is.na(co$median_survival), "not reached",
           paste(round(co$median_survival, 1), "months")), "\n")
cat("Median follow-up:",
    ifelse(is.na(co$median_followup),
           sprintf("not reached (max %.0f months)", co$max_followup),
           sprintf("%.1f months", co$median_followup)), "\n")
cat(sprintf("Age at MI: %.1f (SD %.1f)\n", co$age_mean, co$age_sd))

strata_labels <- c(
  pericardial_effusion = "Pericardial effusion",
  wmi_group = "Wall-motion index"
)

for (grp in names(strata_labels)) {
  label <- strata_labels[[grp]]
  section(paste("Kaplan-Meier / log-rank by", label))
  print(as.data.frame(km_counts(dat, grp)), row.names = FALSE)
  km <- fit_km(dat, grp)
  print(km)
  lr <- logrank(dat, grp)
  cat(sprintf("\nLog-rank: chisq = %.2f, df = %d, p = %.5f\n",
              lr$chisq, lr$df, lr$p_value))
  print(risk_table(km, times = c(0, 12, 24, 36, 48)))
  ggsave(file.path(root, "figures", paste0("km_", grp, ".png")),
         km_plot(km, paste("Survival by", tolower(label)), label),
         width = 7, height = 4.5, dpi = 150)
}

section("Multivariable Cox model")
cox <- fit_cox(model_df)
print(summary(cox))
cat("\nHazard ratios (95% CI):\n")
print(as.data.frame(tidy_hazard_ratios(cox)), row.names = FALSE)

section("Proportional-hazards check (cox.zph)")
ph <- check_ph(cox)
print(as.data.frame(ph$table), row.names = FALSE)
cat(sprintf("\nGlobal Schoenfeld test p = %.4f\n", ph$global_p))

png(file.path(root, "figures", "schoenfeld_residuals.png"),
    width = 900, height = 700, res = 110)
op <- par(mfrow = c(2, 3))
plot(ph$object)
par(op)
invisible(dev.off())

cat("\nDone. Figures written to figures/.\n")
