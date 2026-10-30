# ==============================================================================
# pipeline_config.py  -  THE ONLY FILE TO EDIT FOR A NEW RUN / A NEW COUNTRY
# ------------------------------------------------------------------------------
# Every notebook (01-06) starts with:   from pipeline_config import *
# Change paths / country here, never inside the notebooks.
# ==============================================================================

# ------------------------------------------------------------------------------
# 0. Run identity
# ------------------------------------------------------------------------------
COUNTRY      = "US"                       # label written into manifest / outputs
JURISDICTION = "United States Of America" # as written in RegMap / Rapid2
RUN_ID       = "ONTO-US-2026-10"          # change for every full rebuild

OUT_DIR = f"../output/ontology_graph_{COUNTRY}"          # everything is written under here
P3_DIR  = f"{OUT_DIR}/phase3"                            # alert -> policy / procedure impact
AUDIT_DIR = f"{P3_DIR}/audit"


# ------------------------------------------------------------------------------
# 1. Source paths (systems of record + IA project outputs)
# ------------------------------------------------------------------------------
SOURCES = {
    # --- Rapid2 alerts --------------------------------------------------------
    "rapid2":          "../data/Rapid2_REGDEV_US_2020_2025.parquet",

    # --- RegMap: 7 extracts ---------------------------------------------------
    "regmap_e1":       "../data/Tactical_Regmap_Data/<extract 1>",   # regulator / regulation / RSM
    "regmap_e2":       "../data/Tactical_Regmap_Data/<extract 2>",   # RSM text + taxonomy
    "regmap_e3":       "../data/Tactical_Regmap_Data/<extract 3>",   # RSM -> LR -> L1/L2 library control
    "regmap_e4":       "../data/Tactical_Regmap_Data/<extract 4>",   # RSM -> risk instance, applicable?
    "regmap_e5":       "../data/Tactical_Regmap_Data/<extract 5>",   # RSM -> risk -> L1 control inst, applicable?
    "regmap_e6":       "../data/Tactical_Regmap_Data/<extract 6>",   # obligations
    "regmap_e7":       "../data/Tactical_Regmap_Data/<extract 7>",   # regulation assessments

    # --- Helios ---------------------------------------------------------------
    "helios_risk":     "../data/Helios/<US_Risk risk.parquet>",
    "helios_ctrl":     "../data/Helios/<control file: 1C rows + L1C fields>",
    "helios_rtcl":     "../data/Helios/<rtcl.parquet>",

    # --- GPPS -----------------------------------------------------------------
    "gpps_pol_us":     "<gpps folder>/us_policy_26_sep.parquet",
    "gpps_pol_glob":   "<gpps folder>/global_policy_26_sep.parquet",
    "gpps_proc":       "<gpps folder>/global_procedure_26_SEP.parquet",

    # --- IA outputs: alert -> RSM / RGL / ROB ---------------------------------
    "ia_rsm":          "<path>/rsm_linkage_pairs_....parquet",
    "ia_rgl_audit":    "<path>/rgl_output_audit/audit_labelled_predictions.parquet",
    "ia_rob":          "<path>/rob_linkage_pairs_....parquet",
    "ia_rob_audit":    "<path>/rob_output_audit/audit_labelled_predictions.parquet",

    # --- IA outputs: alert -> LR / L1C / 1C (Helios Run B = ..._RT_method2) ---
    "ia_lr":           "<path>/helios_linkage_llm_RT_method2/links_risk.parquet",
    "ia_l1c":          "<path>/helios_linkage_llm_RT_method2/links_control.parquet",
    "ia_1c":           "<path>/helios_linkage_llm_RT_method2/links_instance.parquet",
    "ia_helios_audit": "<path>/helios_audit_B/audit_labelled.parquet",

    # --- IA outputs: ROB -> policy / procedure (ontology structure) -----------
    "ia_rob_policy":   "<path>/policy_v2_verdicts.parquet",
    "ia_rob_proc":     "<path>/procedure_v2_verdicts.parquet",
    "ia_rob_policy_sections": "<path>/obligation_to_policy_links_with_sections.parquet",
}


# ------------------------------------------------------------------------------
# 2. Build options (notebook 01)
# ------------------------------------------------------------------------------
KEEP_HIDDEN_ONLY_POLICY_LINKS = True    # ROB->policy links resting only on GPPS-hidden text: keep, tagged
ROB_PROC_RUN = "core"                   # procedure_v2_verdicts mixes runs: keep this one
INTAKE_EXTRA = None                     # applicability / LOB / legal entity source, when available
# INTAKE_EXTRA = dict(path="<file>", alert_col="RECORD_ID",
#                     applicable_col="<col>", lob_col="<col>", le_col="<col>")

# Candidate column names: the first one that exists is used (build_checks.xlsx -> columns_used).
COLS = {
    # Helios control file (1C rows + L1C fields)
    "ctrl_instance_id":    ["name"],                    # holds '1C-...' (resource_id is a different number)
    "ctrl_instance_title": ["l1_control_title_alias"],
    "ctrl_instance_text":  ["description", "control_description", "l1_control_description"],
    "ctrl_library_id":     ["l1_library_control_id"],
    "ctrl_library_title":  ["l1_library_control_title"],
    "ctrl_library_text":   ["l1_library_control_description"],
    "ctrl_library_status": ["l1_library_control_status"],
    "ctrl_status":         ["l1_control_status"],
    "ctrl_business":       ["business", "business_short_name"],
    "ctrl_le":             ["legal_entity_short_name", "legal_entity"],
    "ctrl_owner":          ["control_owner"],
    "ctrl_steward":        ["primary_risk_steward"],
    # Helios risk file
    "risk_id":             ["library_risk_id", "library_id"],
    "risk_title":          ["title"],
    "risk_text":           ["library_risk_description", "library risk description"],
    "risk_status":         ["risk_status"],
    "risk_l1":             ["risk_taxonomy_l1", "risk_taxonomy_11"],
    "risk_l2":             ["risk_taxonomy_l2", "risk_taxonomy_12"],
    "risk_l3":             ["risk_taxonomy_l3", "risk_taxonomy_13"],
    "risk_steward":        ["risk_steward"],
    "risk_owner":          ["risk_owner"],
    # RTCL
    "rtcl_risk":           ["risk_library_id"],
    "rtcl_l1c":            ["l1_control_library_id", "l1_control library_id"],
    # IA outputs
    "verdict":             ["audit_verdict_final", "audit_verdict"],
    "decision":            ["final_decision", "model_decision_label", "decision", "model_decision"],
}


# ------------------------------------------------------------------------------
# 3. Phase 3: alert -> policy / procedure impact (notebooks 03-06)
# ------------------------------------------------------------------------------
DOC_TYPES      = ["policy", "procedure"]
RUN_SCOPE      = "B"        # "A" | "A+DISPUTED" | "B" : B = every model-LINKED alert->ROB link (rows flagged)
DISPUTED_SAMPLE = 50        # disputed alert->ROB links tagged as DISPUTED_SAMPLE (judge-strictness check)
FALLBACK_TOP_K = 10         # direct TF-IDF search for alerts with no obligation route, per doc type
LINK_THRESHOLD = 5          # LINKED = model LINKED + link_score >= 5 + both quotes verified (every level)
SEED           = 42

# LLM gateway (the gateway cell itself is pasted in notebook 04 / 05)
CONCURRENCY = 15
MAX_TOKENS  = 20000         # output ceiling per call (reasoning model); you pay only for what is used
SAVE_EVERY  = 50
TOKEN_PRICE = {"in": 0.20 / 1e6, "out": 1.20 / 1e6}        # set to your gateway rates
MAX_INPUT_TOKENS = 150_000  # context limit of the gateway model

# Judge audit (notebook 05)
AUDIT_SETTINGS = {
    "rejected_sample_per_type": 300,   # NOT_LINKED pairs judged per doc type (miss-rate estimate)
    "probes_per_type": 30,             # planted wrong links per doc type (judge leniency test)
    "seed": 7,
}


# ------------------------------------------------------------------------------
# 4. Phase 3b: which CONTROL satisfies which OBLIGATION (notebooks 07-09)
# ------------------------------------------------------------------------------
P3B_DIR = f"{OUT_DIR}/phase3b"
LIVE_INSTANCE_STATUS = ["Assessed", "Pending Assessment"]   # live instances (text 'demised' also excluded)
LIVE_LIBRARY_STATUS  = ["Published", "(blank)"]             # 'Retired' library controls dropped
P3B_SCOPE      = "all"          # level 1 run: "alert" (alert-linked obligations) | "all"
P3B_TIERS      = ["T1", "T2", "T3"]   # keep all; dropping summary-only pairs = scaling lever (see README)
P3B_BATCH_SIZE = 10             # controls (level 1) / instances (level 2) per LLM call
THIN_CHARS     = 200            # library control text below this -> its live instances' text appended
EXCLUDE_REGMAP_N = True         # level 2: drop obligation -> instance pairs RegMap ext 5 marks 'N'
P3B_MAX_COST_USD = 60           # level 2 cost gate (notebook 09 stops above this)
P3B_AUDIT = {"rejected_sample": 300, "probes": 30, "seed": 7}
ACTIVE_OBLIGATION_STATUSES = ["PUBLISHED"]   # notebook 10: obligations counted in the gap report


# ------------------------------------------------------------------------------
# 5. Phase 3c: obligation -> policy / procedure VIA a confirmed control (notebooks 11-12)
# ------------------------------------------------------------------------------
# Notebook 12 is self-contained and carries its own settings in CELL 1 (US run:
# MAX_COST_USD 45, CALIB_PER_TYPE 50, audit 200 rejected + 30 probes per type).
P3C_DIR = f"{OUT_DIR}/phase3c"
P3C_PROCEDURE_SCOPE = "gap_fill"   # "gap_fill" = obligations with no linked procedure | "all" (~3x the cost)
