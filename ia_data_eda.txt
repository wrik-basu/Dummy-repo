# ==========================================================================
# IA / Reg-Management  —  Structured EDA
# --------------------------------------------------------------------------
# Three data sources:
#   A) RAPID2  — BigQuery. Regulatory-development alerts (REGDEV/news/etc.)
#   B) Regmap  — Excel extracts (pandas). Internal HSBC regulation model.
#   C) Helios  — BigQuery. Internal risks + L1/L2 controls.
#
# Design principle: push every aggregation that CAN run in BigQuery INTO
# BigQuery (SQL keywords capitalised). Only small result frames land locally.
# Regmap is Excel-based, so it is profiled in pandas.
#
# Nothing here mutates data. Read-only profiling. Drop straight into the
# notebook cell-by-cell (`# %%` markers delimit cells).
# ==========================================================================

# %% [markdown]
# ## 0. Setup — client, config, helpers

# %%
import os
import pandas as pd
from google.cloud import bigquery

pd.set_option("display.max_columns", None)
pd.set_option("display.width", 200)

# --- Connection (identical to the collation notebook) ----------------------
ANALYTICS_PROJECT = "hsbc-12211200-cmlpwb-prod"
DATA_PROJECT      = "hsbc-11545401-cmpdatcwrs1-prod"
DATASET           = "rc_curated_prod"
LOCATION          = "europe-west2"

os.environ["GOOGLE_CLOUD_PROJECT"] = ANALYTICS_PROJECT
bq_client = bigquery.Client(project=ANALYTICS_PROJECT, location=LOCATION)

# Fully-qualified table prefix, e.g. FQ("aa_hsbc_rapid2_hzn_record")
def FQ(table: str) -> str:
    return f"`{DATA_PROJECT}.{DATASET}.{table}`"


# --- Thin BigQuery helpers -------------------------------------------------
def bq(sql: str) -> pd.DataFrame:
    """Run SQL in BigQuery, return a DataFrame. Aggregation stays server-side."""
    return bq_client.query(sql).to_dataframe(create_bqstorage_client=False)


def value_counts_sql(table: str, column: str, top: int = 50) -> pd.DataFrame:
    """Server-side GROUP BY count + share. Use for categorical profiling."""
    sql = f"""
        SELECT
            {column}                                   AS value,
            COUNT(*)                                   AS n,
            ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
        FROM {FQ(table)}
        GROUP BY {column}
        ORDER BY n DESC
        LIMIT {top}
    """
    return bq(sql)


def null_profile_sql(table: str, columns: list[str]) -> pd.DataFrame:
    """One-pass null + distinct profile for the listed columns, server-side."""
    total = f"COUNT(*) AS row_count"
    parts = [total]
    for c in columns:
        parts.append(f"COUNTIF({c} IS NULL)          AS {c}__nulls")
        parts.append(f"COUNT(DISTINCT {c})           AS {c}__distinct")
    sql = f"SELECT {', '.join(parts)} FROM {FQ(table)}"
    wide = bq(sql)

    # Reshape wide -> tidy (one row per column) for readability.
    rows = int(wide["row_count"].iloc[0])
    recs = []
    for c in columns:
        nulls = int(wide[f"{c}__nulls"].iloc[0])
        recs.append({
            "column":     c,
            "row_count":  rows,
            "nulls":      nulls,
            "null_pct":   round(100 * nulls / rows, 2) if rows else None,
            "distinct":   int(wide[f"{c}__distinct"].iloc[0]),
        })
    return pd.DataFrame(recs)


# --- Pandas helpers (for Regmap Excel extracts) ----------------------------
def profile_df(df: pd.DataFrame, name: str) -> pd.DataFrame:
    """Per-column null %, distinct count and dtype for an in-memory frame."""
    n = len(df)
    out = pd.DataFrame({
        "dtype":    df.dtypes.astype(str),
        "nulls":    df.isna().sum(),
        "null_pct": (100 * df.isna().mean()).round(2),
        "distinct": df.nunique(dropna=True),
    })
    out.insert(0, "table", name)
    out.index.name = "column"
    return out.reset_index()


def key_uniqueness(df: pd.DataFrame, keys: list[str], name: str) -> dict:
    """Is `keys` a unique key of `df`? Report duplicate fan-out."""
    n = len(df)
    n_unique = df.drop_duplicates(subset=keys).shape[0]
    return {
        "table":         name,
        "keys":          keys,
        "rows":          n,
        "unique_keys":   n_unique,
        "is_unique_key": n == n_unique,
        "dup_rows":      n - n_unique,
    }


def join_readiness(left, right, left_keys, right_keys, left_name, right_name):
    """
    Pre-merge integrity check. Replaces the commented-out `validate=` in the
    teammate's join_tables(). Tells you the CORRECT validate= for each stage
    and how many left rows would find no match (orphans).
    """
    lk = key_uniqueness(left,  left_keys,  left_name)
    rk = key_uniqueness(right, right_keys, right_name)

    l_index = left.set_index(left_keys).index
    r_index = right.set_index(right_keys).index
    orphans = (~l_index.isin(r_index)).sum()

    if lk["is_unique_key"] and rk["is_unique_key"]:
        validate = "one_to_one"
    elif lk["is_unique_key"]:
        validate = "one_to_many"
    elif rk["is_unique_key"]:
        validate = "many_to_one"
    else:
        validate = "many_to_many  <-- fan-out risk"

    return {
        "join":                f"{right_name} -> {left_name}",
        "left_key_unique":     lk["is_unique_key"],
        "right_key_unique":    rk["is_unique_key"],
        "left_dup_rows":       lk["dup_rows"],
        "right_dup_rows":      rk["dup_rows"],
        "left_orphans":        int(orphans),
        "left_orphan_pct":     round(100 * orphans / len(left), 2) if len(left) else None,
        "recommended_validate": validate,
    }


# ==========================================================================
# %% [markdown]
# ## A. RAPID2  (BigQuery)
# Fact table `aa_hsbc_rapid2_hzn_record`. We profile the FULL base table
# first (all categories / all jurisdictions), THEN confirm the notebook's
# filtered slice (REGDEV, single juris, 2020–2025) reproduces (1607, 24).
# ==========================================================================

RAPID2_RECORD = "aa_hsbc_rapid2_hzn_record"

# %% A.1 — shape, grain, date span (whole table, no filters)
bq(f"""
    SELECT
        COUNT(*)                       AS total_rows,
        COUNT(DISTINCT record_id)      AS distinct_records,
        COUNT(DISTINCT orign_alert_id) AS distinct_alerts,
        MIN(created_on_dtm)            AS min_created,
        MAX(created_on_dtm)            AS max_created,
        MAX(updated_on_dtm)           AS max_updated
    FROM {FQ(RAPID2_RECORD)}
""")

# %% A.2 — is record_id the grain? (duplicates would break every downstream join)
bq(f"""
    SELECT record_id, COUNT(*) AS n
    FROM {FQ(RAPID2_RECORD)}
    GROUP BY record_id
    HAVING COUNT(*) > 1
    ORDER BY n DESC
    LIMIT 20
""")

# %% A.3 — categorical distributions (the filters your teammate applied live here)
value_counts_sql(RAPID2_RECORD, "record_cat_cde")   # REGDEV is the chosen slice
# %%
value_counts_sql(RAPID2_RECORD, "jris_cde")         # jurisdiction spread
# %%
value_counts_sql(RAPID2_RECORD, "stat_cde")         # status
# %%
value_counts_sql(RAPID2_RECORD, "is_actv_ind")      # active vs inactive
# %%
value_counts_sql(RAPID2_RECORD, "risk_stwrd_area_cde")
# %%
value_counts_sql(RAPID2_RECORD, "rglt_bdy_cde")     # regulator body

# %% A.4 — jurisdiction spread WITH names (across all 3 approved juris + rest)
bq(f"""
    SELECT
        c.name                              AS jurisdiction,
        r.jris_cde                          AS jris_cde,
        COUNT(*)                            AS n,
        COUNTIF(r.record_cat_cde = 'REGDEV') AS regdev_n
    FROM {FQ(RAPID2_RECORD)} r
    LEFT JOIN {FQ('aa_hsbc_rapid2_reg_ref_jris')} c
           ON r.jris_cde = c.jris_cde
    GROUP BY jurisdiction, jris_cde
    ORDER BY n DESC
""")

# %% A.5 — ingest rule type (requires the alert join). Check alert grain too.
bq(f"""
    SELECT
        h.INGEST_RULE_TYPE       AS ingest_rule_type,
        COUNT(*)                 AS n
    FROM {FQ(RAPID2_RECORD)} r
    LEFT JOIN {FQ('aa_hsbc_rapid2_hzn_alert')} h
           ON r.orign_alert_id = h.ALERT_ID
    GROUP BY ingest_rule_type
    ORDER BY n DESC
""")

# %% A.6 — FAN-OUT audit of the join to hzn_alert.
# The main query does r LEFT JOIN alert ON orign_alert_id = ALERT_ID. If
# ALERT_ID is not unique in the alert table, records get duplicated.
bq(f"""
    SELECT
        COUNT(*)                     AS alert_rows,
        COUNT(DISTINCT ALERT_ID)     AS distinct_alert_ids,
        COUNT(*) - COUNT(DISTINCT ALERT_ID) AS dup_rows
    FROM {FQ('aa_hsbc_rapid2_hzn_alert')}
""")

# %% A.7 — FAN-OUT audit of the two string_agg subqueries.
# theme_map and record_risk_txnmy are many-per-record; the main query
# collapses them with STRING_AGG. Quantify the fan-out being collapsed.
bq(f"""
    SELECT 'theme_map' AS src,
           COUNT(*) AS rows, COUNT(DISTINCT record_id) AS records,
           ROUND(COUNT(*) / COUNT(DISTINCT record_id), 2) AS avg_per_record,
           MAX(cnt) AS max_per_record
    FROM (
        SELECT record_id, COUNT(*) AS cnt
        FROM {FQ('aa_hsbc_rapid2_hzn_record_theme_map')}
        GROUP BY record_id
    )
    UNION ALL
    SELECT 'risk_txnmy' AS src,
           COUNT(*), COUNT(DISTINCT record_id),
           ROUND(COUNT(*) / COUNT(DISTINCT record_id), 2), MAX(cnt)
    FROM (
        SELECT record_id, COUNT(*) AS cnt
        FROM {FQ('aa_hsbc_rapid2_hzn_record_risk_txnmy')}
        GROUP BY record_id
    )
""")

# %% A.8 — risk taxonomy L1 distribution (from the raw taxonomy table)
value_counts_sql("aa_hsbc_rapid2_hzn_record_risk_txnmy", "risk_txnmy_lvl_1")

# %% A.9 — null / distinct profile of the substantive record columns
null_profile_sql(RAPID2_RECORD, [
    "record_id", "orign_alert_id", "jris_cde", "created_on_dtm",
    "updated_on_dtm", "is_actv_ind", "record_cat_cde", "stat_cde",
    "rglt_bdy_cde", "risk_stwrd_area_cde", "title", "summ_contnt",
    "summ_updt", "srce_url", "intro",
])

# %% A.10 — text-length profile of free-text fields (drives LLM cost/chunking)
bq(f"""
    SELECT
        'title'       AS field, ROUND(AVG(LENGTH(title)),1)      AS avg_len, MAX(LENGTH(title))      AS max_len FROM {FQ(RAPID2_RECORD)}
    UNION ALL SELECT
        'summ_contnt', ROUND(AVG(LENGTH(summ_contnt)),1),        MAX(LENGTH(summ_contnt))        FROM {FQ(RAPID2_RECORD)}
    UNION ALL SELECT
        'intro',       ROUND(AVG(LENGTH(intro)),1),              MAX(LENGTH(intro))              FROM {FQ(RAPID2_RECORD)}
""")

# %% A.11 — CONFIRM the notebook slice reproduces (expected ~1607 rows).
# Change RAPID2_JURIS to sanity-check each approved jurisdiction.
RAPID2_JURIS = "Hong Kong (HSBC)"   # or 'United States Of America' / 'United Kingdom (Ring-Fenced Bank)'
bq(f"""
    SELECT COUNT(*) AS slice_rows, COUNT(DISTINCT r.record_id) AS distinct_records
    FROM {FQ(RAPID2_RECORD)} r
    LEFT JOIN {FQ('aa_hsbc_rapid2_reg_ref_jris')} c ON r.jris_cde = c.jris_cde
    WHERE r.created_on_dtm >= '2020-01-01'
      AND r.created_on_dtm <= '2025-12-31'
      AND c.name = "{RAPID2_JURIS}"
      AND r.record_cat_cde = 'REGDEV'
""")

# %% A.12 — records per year (volume trend, drives sampling for the LLM pipeline)
bq(f"""
    SELECT
        EXTRACT(YEAR FROM created_on_dtm) AS yr,
        COUNTIF(record_cat_cde = 'REGDEV') AS regdev,
        COUNT(*)                          AS all_records
    FROM {FQ(RAPID2_RECORD)}
    WHERE created_on_dtm >= '2020-01-01' AND created_on_dtm <= '2025-12-31'
    GROUP BY yr
    ORDER BY yr
""")


# ==========================================================================
# %% [markdown]
# ## C. Helios  (BigQuery)
# risk -> mapping bridge (`aa_hsbc_helios_rtcl`) -> L1 control -> L2 control.
# Country-parametrised. We profile the risk table across all 3 countries
# cheaply, then do the join fan-out audit for the selected country.
# ==========================================================================

# %% C.0 — config (mirrors the Helios cell)
COUNTRY = "us"     # 'us' | 'uk' | 'hk'
l1_control_table = f"{COUNTRY}_hsbc_helios_l1_control"
l2_control_table = f"{COUNTRY}_hsbc_helios_l2_control"
risk_table       = f"{COUNTRY}_hsbc_helios_risk"
mapping_table    = "aa_hsbc_helios_rtcl"   # country-agnostic bridge

# %% C.1 — table sizes for the selected country + the shared bridge
bq(f"""
    SELECT 'risk'    AS tbl, COUNT(*) AS rows, COUNT(DISTINCT library_risk_id)      AS distinct_key FROM {FQ(risk_table)}
    UNION ALL
    SELECT 'l1_ctrl',        COUNT(*),        COUNT(DISTINCT l1_library_control_id)         FROM {FQ(l1_control_table)}
    UNION ALL
    SELECT 'l2_ctrl',        COUNT(*),        COUNT(DISTINCT l2_library_control_id)         FROM {FQ(l2_control_table)}
    UNION ALL
    SELECT 'mapping',        COUNT(*),        COUNT(DISTINCT risk_library_id)               FROM {FQ(mapping_table)}
""")

# %% C.2 — risk taxonomy L1 spread (this is the filter used: 'Financial Crime')
value_counts_sql(risk_table, "risk_taxonomy_l1")

# %% C.3 — bridge fan-out: how many controls does one risk map to?
bq(f"""
    SELECT
        COUNT(*)                          AS mapping_rows,
        COUNT(DISTINCT risk_library_id)   AS distinct_risks,
        ROUND(COUNT(*) / COUNT(DISTINCT risk_library_id), 2) AS avg_controls_per_risk,
        COUNTIF(l1_control_library_id IS NULL) AS null_l1_ctrl,
        COUNTIF(l2_control_library_id IS NULL) AS null_l2_ctrl
    FROM {FQ(mapping_table)}
""")

# %% C.4 — reproduce the Helios join, but COUNT the true row multiplication
# (the notebook used SELECT DISTINCT * ... LIMIT 10, which hides the fan-out).
bq(f"""
    SELECT
        COUNT(*)                        AS joined_rows,
        COUNT(DISTINCT a.library_risk_id) AS distinct_risks,
        COUNTIF(c.l1_library_control_id IS NULL) AS rows_missing_l1,
        COUNTIF(d.l2_library_control_id IS NULL) AS rows_missing_l2
    FROM {FQ(risk_table)} a
    LEFT JOIN {FQ(mapping_table)}    b ON a.library_risk_id       = b.risk_library_id
    LEFT JOIN {FQ(l1_control_table)} c ON b.l1_control_library_id = c.l1_library_control_id
    LEFT JOIN {FQ(l2_control_table)} d ON b.l2_control_library_id = d.l2_library_control_id
    WHERE a.risk_taxonomy_l1 IN UNNEST(['Financial Crime'])
""")

# %% C.5 — null profile of risk table taxonomy columns
null_profile_sql(risk_table, [
    "library_risk_id",
    "risk_taxonomy_l1_id", "risk_taxonomy_l1",
    "risk_taxonomy_l2_id", "risk_taxonomy_l2",
    "risk_taxonomy_l3_id", "risk_taxonomy_l3",
])


# ==========================================================================
# %% [markdown]
# ## B. Regmap  (Excel extracts, pandas)
# 7 extracts (e1–e7). We profile each extract, then measure join-key
# integrity for every planned merge — this is what the commented-out
# `validate=` was supposed to guard. Do NOT trust the join chain until
# join_readiness() reports the expected validate= per stage.
# ==========================================================================

# %% B.0 — load extracts (assumes files already landed locally)
INPUT_PATH = "./regmap_extracts/"   # <-- point at your local copy of the DSW-1261 extracts

extracts = {
    "e1": "Extract1_INTERNAL.xlsx",
    "e2": "Extract2 US Summaries and Taxonomy 1 (1)_INTERNAL.xlsx",
    "e3": "Extract3 US Summaries and Library Controls 1_INTERNAL.xlsx",
    "e4": "Extract4 US Summaries and Applicabilities 2_INTERNAL.xlsx",
    "e5": "Extract5 US Summaries and Risk & Controls 2_INTERNAL.xlsx",
    "e6": "Extract6 US Obligations 3_INTERNAL.xlsx",
    "e7": "Extract7 US Assessments 1_INTERNAL.xlsx",
}
E = {k: pd.read_excel(f"{INPUT_PATH}{v}") for k, v in extracts.items()}

# %% B.1 — shape of each extract
pd.DataFrame(
    [{"extract": k, "rows": df.shape[0], "cols": df.shape[1]} for k, df in E.items()]
)

# %% B.2 — full per-column profile of each extract (null %, distinct, dtype)
regmap_profile = pd.concat([profile_df(df, k) for k, df in E.items()], ignore_index=True)
regmap_profile
# (Filter interactively, e.g. regmap_profile.query("extract=='e2' and null_pct > 0"))

# %% B.3 — join keys, exactly as defined in the collation notebook
E2_E1_KEYS = [
    "Regulation Jurisdiction", "Regulation ID", "Regulation Status",
    "Regulation Version", "Regulation Summary ID",
    "Regulation Summary Status", "Regulation Summary Version",
]
E3_E2_KEYS = E2_E1_KEYS + [
    "Regulation Summary Library Risk ID Number",
    "Regulation Summary Risk Taxonomy L1",
    "Regulation Summary Risk Taxonomy L2",
    "Regulation Summary Risk Taxonomy L3",
]
E4_E2_KEYS = E2_E1_KEYS + [
    "Regulation Summary Risk Taxonomy L1",
    "Regulation Summary Risk Taxonomy L2",
    "Regulation Summary Risk Taxonomy L3",
]
E4_E3_KEYS = E4_E2_KEYS + ["Regulation Summary Applicability Unique Key"]
E5_E4_KEYS = E4_E3_KEYS + ["Risk ID", "Risk Instance Applicable?"]
E6_E2_KEYS = E2_E1_KEYS.copy()
E7_E1_KEYS = [
    "Regulation Jurisdiction", "Regulation ID",
    "Regulation Status", "Regulation Version",
]
E7_E6_KEYS_LEFT  = E7_E1_KEYS + ["Obligation ID"]
E7_E6_KEYS_RIGHT = E7_E1_KEYS + ["Obligation Evaluation Obligation ID"]

# %% B.4 — is each key list a unique key of its own extract?
pd.DataFrame([
    key_uniqueness(E["e1"], E2_E1_KEYS,  "e1"),
    key_uniqueness(E["e2"], E2_E1_KEYS,  "e2"),
    key_uniqueness(E["e3"], E3_E2_KEYS,  "e3"),
    key_uniqueness(E["e4"], E4_E3_KEYS,  "e4"),
    key_uniqueness(E["e5"], E5_E4_KEYS,  "e5"),
    key_uniqueness(E["e6"], E6_E2_KEYS,  "e6"),
    key_uniqueness(E["e7"], E7_E6_KEYS_RIGHT, "e7"),
])

# %% B.5 — pre-merge readiness for every planned join (THE key output).
# recommended_validate tells you what to pass to validate= ; left_orphans
# tells you how many rows will go unmatched under the LEFT joins.
join_plan = pd.DataFrame([
    join_readiness(E["e1"], E["e2"], E2_E1_KEYS, E2_E1_KEYS, "e1", "e2"),
    join_readiness(E["e2"], E["e3"], E3_E2_KEYS, E3_E2_KEYS, "e2(via join1)", "e3"),
    join_readiness(E["e3"], E["e4"], E4_E3_KEYS, E4_E3_KEYS, "e3(via join2)", "e4"),
    join_readiness(E["e4"], E["e5"], E5_E4_KEYS, E5_E4_KEYS, "e4(via join3)", "e5"),
    join_readiness(E["e2"], E["e6"], E6_E2_KEYS, E6_E2_KEYS, "e2", "e6"),
    join_readiness(E["e1"], E["e6"], E2_E1_KEYS, E2_E1_KEYS, "e1", "e6"),
    join_readiness(E["e1"], E["e7"], E7_E6_KEYS_LEFT, E7_E6_KEYS_RIGHT, "e1/e6", "e7"),
])
join_plan

# %% [markdown]
# ### Cross-source linkage (for later, not part of this EDA run)
# - RAPID2 `LEVEL_1/2/3_RISK_TAXONOMY` vs Helios `risk_taxonomy_l1/2/3` vs
#   Regmap `Regulation Summary Risk Taxonomy L1/2/3` — confirm these use the
#   SAME controlled vocabulary before any cross-source mapping. A quick
#   set-difference on distinct L1 values across the three is the first check.
