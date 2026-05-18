# Analysis engine for the echocardiogram survival re-analysis.
# Sourced by run_analysis.R, the Rmd report, and the tests, so every
# reported number comes from one place.

suppressPackageStartupMessages({
  library(survival)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Raw column order; the source file has no header.
RAW_COLUMNS <- c(
  "survival_months", "still_alive", "age_at_mi", "pericardial_effusion",
  "fractional_shortening", "epss", "lvdd", "wall_motion_score",
  "wall_motion_index", "mult", "name", "group", "alive_at_1yr"
)

# Columns we keep. Dropped: wall_motion_score (superseded by the index),
# mult (undocumented derivative), name (constant "name"), group (UCI says
# meaningless), alive_at_1yr (defined from survival + status at 12 months,
# so using it to predict survival is leakage).
ANALYTIC_COLUMNS <- c(
  "survival_months", "still_alive", "age_at_mi", "pericardial_effusion",
  "fractional_shortening", "epss", "lvdd", "wall_motion_index"
)

COX_PREDICTORS <- setdiff(ANALYTIC_COLUMNS, c("survival_months", "still_alive"))

# One definition of the response so KM, log-rank, and Cox can't drift apart.
SURV_RESPONSE <- "Surv(survival_months, event_death)"

# read.csv silently wraps the one malformed source row (line 50: a stray
# leading comma -> 14 fields) across two corrupted rows. So parse strictly:
# keep only lines with the expected field count and record what was dropped.
load_echocardiogram <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  fields <- strsplit(lines, ",", fixed = TRUE)
  conforms <- lengths(fields) == length(RAW_COLUMNS)

  mat <- do.call(rbind, fields[conforms])
  colnames(mat) <- RAW_COLUMNS
  full <- as.data.frame(mat, stringsAsFactors = FALSE)
  full[full == "?"] <- NA  # "?" is the source's missing token

  analytic <- full[ANALYTIC_COLUMNS]
  analytic[] <- lapply(analytic, as.numeric)
  out <- tibble::as_tibble(analytic)
  attr(out, "ingest") <- list(
    n_source = length(lines),
    n_malformed = sum(!conforms),
    malformed_lines = which(!conforms),
    n_wellformed = sum(conforms)
  )
  out
}

# The crux of the whole repo: still_alive == 1 means alive at last contact
# (right-censored), 0 means dead. The event is death, i.e. still_alive == 0.
# Coding the event as still_alive (alive) is the bug this project corrects.
prepare_survival_data <- function(df) {
  ingest <- attr(df, "ingest")
  n_raw <- nrow(df)

  cohort <- df %>%
    filter(
      !is.na(survival_months), survival_months > 0,
      !is.na(still_alive), still_alive %in% c(0, 1)
    ) %>%
    mutate(
      event_death = as.integer(still_alive == 0),
      pericardial_effusion = factor(
        pericardial_effusion, levels = c(0, 1),
        labels = c("absent", "present")
      ),
      # Display split only (1.0 = all segments normal, > 1.0 = abnormal).
      # The Cox model keeps wall_motion_index continuous.
      wmi_group = factor(
        if_else(wall_motion_index > 1, "abnormal", "normal"),
        levels = c("normal", "abnormal")
      )
    )

  model <- cohort %>%
    select(survival_months, event_death, all_of(COX_PREDICTORS)) %>%
    filter(if_all(everything(), ~ !is.na(.)))

  list(
    cohort = cohort,
    model = model,
    log = list(
      n_source = ingest$n_source,
      n_malformed = ingest$n_malformed,
      malformed_lines = ingest$malformed_lines,
      n_wellformed = n_raw,
      n_dropped_outcome = n_raw - nrow(cohort),
      n_valid_outcome = nrow(cohort),
      n_complete_case = nrow(model),
      n_dropped_covariate = nrow(cohort) - nrow(model)
    )
  )
}

# Median follow-up uses reverse KM; it is NA when fewer than half are
# censored, so max_followup is reported alongside it.
summarise_cohort <- function(df) {
  fit <- survfit(stats::reformulate("1", SURV_RESPONSE), data = df)
  rev <- survfit(Surv(survival_months, 1 - event_death) ~ 1, data = df)
  list(
    n = nrow(df),
    events = sum(df$event_death),
    censored = sum(df$event_death == 0),
    median_survival = summary(fit)$table[["median"]],
    median_followup = summary(rev)$table[["median"]],
    max_followup = max(df$survival_months),
    age_mean = mean(df$age_at_mi, na.rm = TRUE),
    age_sd = stats::sd(df$age_at_mi, na.rm = TRUE)
  )
}

fit_km <- function(df, by) {
  survfit(stats::reformulate(by, response = SURV_RESPONSE), data = df)
}

# Rows actually used in a stratified comparison vs dropped for a missing
# grouping value, so the report can state honest denominators.
km_counts <- function(df, by) {
  used <- df[!is.na(df[[by]]), ]
  tibble::tibble(
    comparison = by,
    n_used = nrow(used),
    events = sum(used$event_death),
    censored = sum(used$event_death == 0),
    n_missing_group = sum(is.na(df[[by]]))
  )
}

logrank <- function(df, by) {
  res <- survdiff(stats::reformulate(by, response = SURV_RESPONSE), data = df)
  k <- length(res$n) - 1L
  tibble::tibble(
    chisq = unname(res$chisq),
    df = k,
    p_value = stats::pchisq(res$chisq, k, lower.tail = FALSE)
  )
}

fit_cox <- function(model_df, predictors = COX_PREDICTORS) {
  coxph(stats::reformulate(predictors, response = SURV_RESPONSE),
        data = model_df)
}

tidy_hazard_ratios <- function(cox_fit) {
  s <- summary(cox_fit)
  tibble::tibble(
    term = rownames(s$coefficients),
    hazard_ratio = s$coefficients[, "exp(coef)"],
    ci_low = s$conf.int[, "lower .95"],
    ci_high = s$conf.int[, "upper .95"],
    p_value = s$coefficients[, "Pr(>|z|)"]
  )
}

check_ph <- function(cox_fit) {
  zph <- cox.zph(cox_fit)  # scaled Schoenfeld test of proportional hazards
  tbl <- as.data.frame(zph$table)
  tbl$term <- rownames(tbl)
  list(
    object = zph,
    table = tibble::as_tibble(tbl)[, c("term", "chisq", "df", "p")],
    global_p = tbl["GLOBAL", "p"]
  )
}

.clean_strata <- function(x) sub("^[^=]+=", "", as.character(x))

km_step_data <- function(km_fit) {
  td <- broom::tidy(km_fit)
  if (!"strata" %in% names(td)) td$strata <- "Overall"
  td$strata <- .clean_strata(td$strata)
  anchor <- td %>%
    distinct(strata) %>%
    mutate(time = 0, estimate = 1, conf.low = 1, conf.high = 1, n.censor = 0)
  bind_rows(anchor, td) %>%
    arrange(strata, time) %>%
    # survfit gives NA CI bounds once the tail risk set is tiny; collapse
    # the band onto the estimate there instead of dropping the tail.
    mutate(
      conf.low = coalesce(conf.low, estimate),
      conf.high = coalesce(conf.high, estimate)
    )
}

# Built in plain ggplot2 because survminer wasn't available in the
# environment; dashed steps are the 95% CI, "+" marks censoring.
km_plot <- function(km_fit, title, legend_title) {
  d <- km_step_data(km_fit)
  cens <- filter(d, n.censor > 0)
  ggplot(d, aes(time, estimate, colour = strata)) +
    geom_step(linewidth = 0.8) +
    geom_step(aes(y = conf.low), linewidth = 0.3, linetype = "dashed") +
    geom_step(aes(y = conf.high), linewidth = 0.3, linetype = "dashed") +
    geom_point(data = cens, shape = 3, size = 2, show.legend = FALSE) +
    scale_y_continuous(limits = c(0, 1), labels = scales::percent_format()) +
    labs(
      title = title, colour = legend_title,
      x = "Time since myocardial infarction (months)",
      y = "Survival probability"
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top")
}

risk_table <- function(km_fit, times) {
  s <- summary(km_fit, times = times, extend = TRUE)
  strata <- if (is.null(s$strata)) rep("Overall", length(s$time))
            else .clean_strata(s$strata)
  tibble::tibble(stratum = strata, time = s$time, n_risk = s$n.risk) %>%
    pivot_wider(names_from = time, values_from = n_risk)
}
