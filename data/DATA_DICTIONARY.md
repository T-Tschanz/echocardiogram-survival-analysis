# Data Dictionary

Source: UCI Machine Learning Repository, Echocardiogram dataset
(https://archive.ics.uci.edu/dataset/38/echocardiogram). Public,
de-identified, distributed under CC BY 4.0 (DOI 10.24432/C5QW24); the
vendored copy retains that license. `echocardiogram_raw.csv` is the
unmodified source file (no header row; `?` denotes missing). Columns
below are in source order.

**Known source defect:** the file has 132 records, but line 50 has a
spurious leading comma (14 fields instead of 13). Ingestion validates
each line's field count and excludes that single malformed record
explicitly (`load_echocardiogram()` in `R/echo_survival.R`); it is not
silently re-parsed. This leaves 131 well-formed records before the
outcome/covariate filtering documented in the report.

| # | Field | Used | Description |
|---|-------|------|-------------|
| 1 | `survival_months` | yes | Months from infarction to death or last contact. A follow-up (censoring) time when the patient was still alive. |
| 2 | `still_alive` | yes | Vital status at last contact: `1` = alive (right-censored), `0` = died. The event for survival analysis is `still_alive == 0`. |
| 3 | `age_at_mi` | yes | Age (years) at the myocardial infarction. |
| 4 | `pericardial_effusion` | yes | Binary: `0` = absent, `1` = present. |
| 5 | `fractional_shortening` | yes | Measure of left-ventricular contractility; lower is worse. |
| 6 | `epss` | yes | E-point septal separation (mm); higher is worse. |
| 7 | `lvdd` | yes | Left-ventricular end-diastolic dimension (cm). |
| 8 | `wall_motion_score` | no | Raw wall-motion score; superseded by the index (field 9). |
| 9 | `wall_motion_index` | yes | Wall-motion score divided by segments visualised. `1.0` = all segments normal; `> 1.0` = abnormal. Used continuously in the Cox model. |
| 10 | `mult` | no | Undocumented derivative of the wall-motion fields. No analytic value. |
| 11 | `name` | no | Constant placeholder (literally `"name"`). |
| 12 | `group` | no | Documented by UCI as meaningless; also contains stray non-numeric tokens. |
| 13 | `alive_at_1yr` | no | Alive at 12 months. A **post-outcome derived label** determined by `survival_months` and `still_alive` at the 12-month mark. **Excluded as target leakage**: predicting survival from a function of survival is circular. |

## Event definition

`still_alive` is an *alive* flag, not an *event* flag. The single most
important modelling decision in this dataset is:

```r
event_death <- as.integer(still_alive == 0)
Surv(time = survival_months, event = event_death)
```

Coding `event = still_alive` (alive as the event) inverts the entire
analysis and is the error this project exists to demonstrate and correct.

## Derived variable

`wmi_group` — a pre-specified two-level split of `wall_motion_index`
(`normal` = 1.0, `abnormal` > 1.0). Used **only** for Kaplan-Meier
display; the Cox model uses the continuous index with no cut-point.
