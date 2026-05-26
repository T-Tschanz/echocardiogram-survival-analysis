# Project: Echocardiogram Survival Re-Analysis

**Repo:** `t-tschanz/echocardiogram-survival-analysis`
**Published report:** https://t-tschanz.github.io/echocardiogram-survival-analysis/
**Branch convention:** `claude/<feature>-<ID>`

---

## Purpose

A reproducible methodological case study demonstrating that inverted event coding manufactures statistically significant findings. The re-analysis of the UCI Echocardiogram dataset shows that once the event indicator is specified correctly, every previously "significant" association disappears.

---

## The Core Bug This Project Corrects

```r
# Wrong (original analysis): codes alive as the event
Surv(time = survival, event = still_alive)

# Correct: still_alive == 1 means alive (censored); 0 means dead (event)
Surv(time = survival_months, event = (still_alive == 0))
```

`still_alive` is an *alive* flag, not a *death* flag. The inversion scrambled the event structure while preserving covariate correlation, so the broken model still emitted small p-values — read as clinical findings.

---

## Key Findings

| Result | Value |
|--------|-------|
| Cohort | 130 patients, 88 deaths (67.7%), median survival 29 months |
| KM by pericardial effusion | log-rank p = 0.89 (NS) |
| KM by wall-motion index | log-rank p = 0.56 (NS) |
| Multivariable Cox | no significant covariate; C = 0.53; LR test p ≈ 0.9 |
| Proportional hazards | no violation (global Schoenfeld p = 0.73) |

---

## Architecture

```
R/echo_survival.R       ← single source of truth: all pure analysis functions
R/run_analysis.R        ← CLI runner: sources echo_survival.R, prints + saves figures
report/survival_analysis.Rmd  ← report: sources echo_survival.R
tests/test_pipeline.R   ← assertions: event coding invariants, row counts
data/echocardiogram_raw.csv   ← vendored UCI dataset (CC BY 4.0)
data/DATA_DICTIONARY.md       ← field docs, exclusion rationale
figures/                ← generated KM and Schoenfeld plots
```

**Key invariant:** `run_analysis.R` and `survival_analysis.Rmd` both `source()` the same engine — no numbers can diverge between script and report.

---

## Data Notes

- **Source defect:** Line 50 has a spurious leading comma (14 fields, not 13). `load_echocardiogram()` validates field counts strictly and excludes it — not silently re-parsed.
- **Missing token:** `"?"` in the source CSV is converted to `NA`.
- **Excluded columns:** `wall_motion_score` (superseded by index), `mult` (undocumented), `name` (constant placeholder), `group` (UCI says meaningless), `alive_at_1yr` (**target leakage** — derived from outcome).
- **Complete cases:** 107 of 130 cohort patients have all covariates; 23 dropped for covariate missingness in Cox model.

---

## Tech Stack

- R ≥ 4.1
- `survival` — KM, Cox, `cox.zph` (Schoenfeld)
- `dplyr`, `tidyr` — data manipulation
- `ggplot2`, `scales` — plots (built without survminer; custom KM step plot)
- `broom` — tidy model output (`tidy()`, `glance()`)
- `rmarkdown` + pandoc — report rendering

---

## Decision Log

- **2026-05-26:** Wiki created. Personal wiki (`wiki/`) + `CLAUDE.md` schema added to repo as a knowledge layer for future sessions.

---

## Open Questions / TODO

*(Claude appends as work surfaces new items)*
