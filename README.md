# Survival After Myocardial Infarction: A Reproducible Re-Analysis

A time-to-event analysis of the public UCI Echocardiogram cohort, written
as a **methodological case study**: it shows how an inverted event
indicator can manufacture statistically significant findings, and what
the data actually support once the analysis is done correctly.

**Rendered report:** https://t-tschanz.github.io/echocardiogram-survival-analysis/

## The point of this repo

An earlier analysis of this dataset defined the survival event as a
patient being *alive* rather than having *died*:

```r
Surv(time = survival, event = still_alive)   # alive coded as the event
```

In this dataset `still_alive == 1` means the patient was alive at last
contact (right-censored) and `0` means death (the event). The line above
inverts that, so every Kaplan-Meier curve, log-rank test, and Cox model
estimates the hazard of *remaining alive*. The scrambled event structure
stayed correlated with the covariates, so the broken model still emitted
small p-values, which were read as clinical findings.

With the event specified correctly:

```r
Surv(time = survival_months, event = (still_alive == 0))
```

**every one of those significant associations disappears.** There is no
statistically significant evidence that any echocardiographic variable
stratifies survival in this small cohort, and the multivariable Cox model
has effectively no discriminative ability (Harrell's C = 0.53). This is
absence of evidence in an underpowered cohort, not proof of no effect.
What *is* firm is the negative methodological result: the earlier
"significant" findings were artifacts of the inverted event coding, not
signal. Reporting that honestly is the deliverable.

## What the corrected analysis shows

| Result | Finding |
|---|---|
| Cohort | 130 patients, 88 deaths (67.7%), median survival 29 months |
| KM by pericardial effusion | log-rank p = 0.89 (not significant) |
| KM by wall-motion index | log-rank p = 0.56 (not significant) |
| Multivariable Cox | no covariate significant; C = 0.53; LR test p ≈ 0.9 |
| Proportional hazards | no evidence of a PH violation (global Schoenfeld p = 0.73) |

Methodological care demonstrated: correct event/censoring specification,
strict schema-validated ingestion (the one malformed source record is
detected and excluded, not silently mis-parsed), reverse-Kaplan-Meier
follow-up estimation, leakage-aware covariate selection (the
1-year-survival field is a post-outcome label, excluded as target
leakage), proportional-hazards diagnostics, complete-case accounting,
and a single-source design so the report and the script cannot disagree.

## Repository layout

```
R/echo_survival.R       Analysis engine (pure functions; the one source of truth)
R/run_analysis.R        CLI runner: console summary + figures
tests/test_pipeline.R   Assertions: event coding + row counts at every step
report/                 R Markdown report and rendered HTML
data/                   Vendored raw dataset + data dictionary
figures/                Generated Kaplan-Meier and Schoenfeld plots
```

`R/run_analysis.R` and `report/survival_analysis.Rmd` both `source()` the
same engine, so every reported number is produced by the same code path.

## Reproduce

Requires R (>= 4.1) with `survival`, `dplyr`, `tidyr`, `ggplot2`,
`broom`, `scales`; the report additionally needs `rmarkdown` and pandoc.

```sh
Rscript R/run_analysis.R          # console summary + figures
Rscript tests/test_pipeline.R     # assertions (non-zero exit on failure)
Rscript -e 'rmarkdown::render("report/survival_analysis.Rmd")'
```

## Limitations

- **Predictor timing / immortal-time bias.** The time origin is the
  myocardial infarction, but the dataset does not record when each
  echocardiogram was taken relative to it. Variable post-infarction
  imaging means patients had to survive to be measured, so these results
  are a retrospective association exercise, not causal or prospective
  clinical prediction.
- Small underpowered cohort (130 patients; 107 complete cases) with few
  events per covariate; absence of evidence is not evidence of absence.
- Single-source observational data with documented quality issues
  (one malformed source record, placeholder/meaningless columns).
- No external validation cohort; findings describe this dataset only.

## Data and licensing

UCI Machine Learning Repository, Echocardiogram dataset
(https://archive.ics.uci.edu/dataset/38/echocardiogram), public and
de-identified, distributed under **CC BY 4.0** (DOI 10.24432/C5QW24);
the vendored copy in `data/` retains that license. See
[`data/DATA_DICTIONARY.md`](data/DATA_DICTIONARY.md) for every field and
the rationale for each exclusion. The code in this repository is released
separately under the MIT License (see [`LICENSE`](LICENSE)).
