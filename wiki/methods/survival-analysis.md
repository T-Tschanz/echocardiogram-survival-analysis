# Survival Analysis — Methods Notes

---

## Core Concepts

### Event and Censoring
- **Event:** the outcome of interest (e.g., death). Coded as `1`.
- **Censored:** patient left the study before event occurred (alive at last contact). Coded as `0`.
- **Critical:** the event indicator must code the *event*, not the *absence* of event. Inverting it is the central bug this project corrects.

### Kaplan-Meier Estimator
- Non-parametric estimate of the survival function S(t) = P(T > t).
- At each event time, updates the estimate using the risk set.
- Compared across groups with the **log-rank test** (chi-squared statistic).
- Confidence intervals: Greenwood's formula.
- **Median follow-up** estimated via reverse KM (swap event/censoring indicator) to avoid bias from unequal follow-up.

### Cox Proportional Hazards Model
- Semi-parametric: models the hazard ratio as `h(t) = h₀(t) · exp(Xβ)`.
- Baseline hazard `h₀(t)` is unspecified — only the ratio is estimated.
- Coefficients are log hazard ratios; `exp(coef)` = hazard ratio.
- **C-statistic (Harrell's C):** concordance index. 0.5 = random; 1.0 = perfect discrimination. In this project: C = 0.53 (effectively random).

### Proportional Hazards Assumption
- The Cox model assumes hazard ratios are constant over time.
- Tested with **Schoenfeld residuals** via `cox.zph()`.
- A significant p-value for a term means the HR changes over time → PH violated for that term.
- In this project: global Schoenfeld p = 0.73 → no evidence of violation.

---

## Common Pitfalls

| Pitfall | Description | This Project |
|---------|-------------|-------------|
| **Inverted event coding** | Coding alive as the event instead of death | The central error being corrected |
| **Target leakage** | Using a variable derived from the outcome as a predictor | `alive_at_1yr` excluded — it's derived from `survival_months` + `still_alive` |
| **Immortal-time bias** | Subjects must survive to be measured (echocardiogram timing) | Acknowledged as a limitation; not correctable in this dataset |
| **Silent mis-parsing** | Malformed rows silently absorbed by `read.csv` | Detected and excluded explicitly in `load_echocardiogram()` |
| **Underpowered null result** | Absence of evidence ≠ evidence of absence | Stated explicitly in the report and README |

---

## R Implementation Patterns

### Survival object (one definition, used everywhere)
```r
SURV_RESPONSE <- "Surv(survival_months, event_death)"
# Used via reformulate() so KM, log-rank, and Cox share the same string
```

### Kaplan-Meier
```r
fit <- survfit(reformulate(by, response = SURV_RESPONSE), data = df)
```

### Log-rank test
```r
res <- survdiff(reformulate(by, response = SURV_RESPONSE), data = df)
p <- pchisq(res$chisq, df = length(res$n) - 1, lower.tail = FALSE)
```

### Cox model
```r
cox <- coxph(reformulate(predictors, response = SURV_RESPONSE), data = model_df)
```

### Schoenfeld residuals (PH test)
```r
zph <- cox.zph(cox_fit)
zph$table  # per-term and GLOBAL p-values
```

### Custom KM plot (no survminer)
- Built in plain ggplot2 with `geom_step()`.
- Step-plot with dashed 95% CI bands and `+` marks for censoring events.
- NA confidence bounds in sparse tails collapsed to estimate rather than dropped.
- See `km_plot()` in `R/echo_survival.R`.

---

## References

*(Claude appends papers and resources as they come up in sessions)*
