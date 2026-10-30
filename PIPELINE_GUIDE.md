# Regulatory Compliance Ontology Pipeline: Run Guide

**What this document is:** everything a person needs to set up, check, run and reuse the pipeline, for the US or for any other country, given the code folder and the data files.
**Owner:** Wrik (HSBC Impact Assessment) · **Version:** US build, Oct 2026 (graph 15,609 nodes / 684,990 edges) · **Read with:** `README.md` (short version), `Ontology_Build_Handover.md` (decisions and history), `Ontology_Model_and_Standards.md` (the model).

---

## 1. What the pipeline builds

It builds one connected graph that links a **regulatory alert** to everything it touches inside the bank, with evidence and a confirmation status on every AI-made link.

```
Rapid2 ALERT ──impacts──▶ Regulation (RGL) ─has summary─▶ Summary (RSM) ─decomposes to─▶ Obligation (ROB)
     │                                                                                    │
     ├──impacts──▶ Policy / Procedure (GPPS) ◀──implemented by (section level)────────────┤
     │                                                                                    │
     └──impacts──▶ Library risk (LR) ─mitigated by─▶ Control standard (L1C) ◀─satisfied by─┤
                                                        │                                 │
                                                        └─has instance─▶ Live control (1C) ◀─operated by─┘
                                                                                          │
                                                                          Gap finding ◀───┘ (rule)
```

- **Facts:** loaded from the systems of record (Rapid2, RegMap, Helios, GPPS).
- **AI links:** found by an LLM and then confirmed by an independent LLM judge. Only confirmed links count: the edge flag is `impact_confirmed` or `structure_confirmed` = True.
- **Gaps:** derived by rules from the confirmed links.

---

## 2. Before you start

| Need | Detail |
|---|---|
| Python | 3.9 or higher; Jupyter or a VS Code notebook |
| Packages | `pandas >= 1.5`, `numpy`, `pyarrow >= 8`, `openpyxl`, `tqdm` (all standard) |
| LLM gateway | Only for notebooks **04, 05, 08, 09, 12**. You need the 2 gateway cells from your working notebook (the "spine" and the "caller"). They must define `call_llm(system, payload, schema, max_tokens)`, `cost_report(stage)`, `USAGE_LOG`, `ERROR_LOG` and `CURRENT_STAGE`. The US run used `gpt-5.6-luna`, 15 parallel calls, and an output ceiling of 20,000 tokens. |
| Disk | At least 5 GB free under the output folder (graph, backups, checkpoints) |
| Access | Read access to the data folders; write access to the output folder |
| Time and cost (US, for scale) | Facts build: minutes, $0 · Phase 3: about $16 · Phase 3b: about $69 · Phase 3c: about $15 · LLM steps run for 1–3 hours each and are checkpointed |

---

## 3. The folder

Keep everything in **one folder**: the notebooks import `pipeline_config.py` and `ia_lib.py` from the folder they run in.

| File | Purpose | LLM | US cost |
|---|---|---|---|
| `00_preflight_checks.txt` | **Run first.** Checks the environment, config, every source file and its columns, the IDs, the outputs from earlier steps, and optionally the gateway. Writes `preflight_report.xlsx` and stops if anything is broken. | no* | $0 |
| `pipeline_config.py` | **The only file you edit:** country, paths, column names, settings, prices | — | — |
| `ia_lib.py` | Shared helpers: file readers, the GPPS visible-section parser, input builder, quote check, confidence interval | — | — |
| `01_ontology_build.txt` | Facts + the existing AI links → `nodes.parquet`, `edges.parquet` | no | $0 |
| `02_taxonomy_alignment.txt` | Risk-type names used by only one system → an editable map (applied by re-running 01) | no | $0 |
| `03_impact_candidates.txt` | Candidate alert → policy / procedure pairs | no | $0 |
| `04_impact_llm.txt` | LLM decision per pair | yes | ~$12 |
| `05_impact_audit.txt` | Independent judge | yes | ~$4 |
| `06_load_impacts.txt` | Loads the impacts into the graph | no | $0 |
| `07_control_candidates.txt` | Live / retired control status, obligation → control-standard candidates (7 routes) | no | $0 |
| `08_control_llm_level1.txt` | Obligation → control standard: LLM + judge | yes | ~$41 |
| `09_control_load_and_instances.txt` | Loads level 1; obligation → live control instance: LLM + judge + load | yes | ~$28 |
| `10_control_gap_findings.txt` | Gap category per active obligation, alerts hitting gaps | no | $0 |
| `11_policy_via_control_scope.txt` | Obligation → policy / procedure pairs implied by a confirmed control + the GPPS mapping | no | $0 |
| `12_policy_via_control_llm.txt` | LLM + judge on the new pairs, then load | yes | ~$15 |
| `13_demo_export.txt` | Chosen alerts → data for the demo explorer HTML | no | $0 |
| `diagnostics/` | ID-join diagnosis cell; an archived, rejected prompt (reference only) | — | — |

\* Only if you switch on the optional one-call gateway test.

**Notebook format.** Each `.txt` file is a notebook written as text. Every `# ====== CELL n: …` line starts a new notebook cell: paste each block into its own cell, in order. Where a notebook says **CELL 0: GATEWAY**, paste your 2 gateway cells there.

---

## 4. Input data

Set every path in `pipeline_config.py → SOURCES`. Formats: parquet, xlsx or csv (detected by the file extension). The preflight checks every column below.

| Key in SOURCES | System | What it holds | Required columns |
|---|---|---|---|
| `rapid2` | Rapid2 | Regulatory alerts for the jurisdiction | `RECORD_ID, TITLE, SUMM_CONTENT, RECORD_JURISDICTION_NAME, REGULATOR_CODE, LEVEL_1/2/3_RISK_TAXONOMY` (+ steward / theme columns if present) |
| `regmap_e1` | RegMap | Regulator → regulation → summary | `Regulation ID` (or `Regulation-ID`), `Regulation Summary ID, Regulator Code, Regulation Title` |
| `regmap_e2` | RegMap | Summary text + taxonomy | `Regulation Summary ID, Regulation Summary Title, Regulation Summary Detail Text` |
| `regmap_e3` | RegMap | Summary → library risk → control standard | `Regulation Summary ID, Regulation Summary Library Risk ID Number, Regulation Summary L1 Library Control ID Number` |
| `regmap_e4` | RegMap | Summary → risk instance, applicable? | `Regulation Summary ID, Risk ID, Risk Instance Applicable?` |
| `regmap_e5` | RegMap | Summary → risk → control instance, applicable? | `Regulation Summary ID, L1 Control ID, L1 Control Instance Applicable?` |
| `regmap_e6` | RegMap | Obligations | `Obligation ID, Regulation Summary ID, Obligation Title, Obligation Detailed Text, Obligation Status` |
| `regmap_e7` | RegMap | Regulation assessments (obligation in scope, by business) | `Regulation ID, Obligation Evaluation Obligation ID` |
| `helios_risk` | Helios | Library risks | columns named in `COLS["risk_*"]` |
| `helios_ctrl` | Helios | Control instances (1C) with their control standard (L1C) | columns in `COLS["ctrl_*"]`; **the 1C ID is in `name`**, not `resource_id` |
| `helios_rtcl` | Helios | Risk → control-standard links | `COLS["rtcl_risk"]`, `COLS["rtcl_l1c"]` |
| `gpps_pol_us`, `gpps_pol_glob`, `gpps_proc` | GPPS | Policies / procedures, one JSON per version | `policy_core_id` or `procedure_core_id`, `version_num, json_data` |
| `ia_rsm`, `ia_rob` (+ audits) | IA project | Alert → summary / obligation linkage and judge labels | `RECORD_ID, RSM_ID, REG_ID` / `RECORD_ID, ROB_ID`; audits `RID` + target + verdict |
| `ia_lr`, `ia_l1c`, `ia_1c`, `ia_helios_audit` | IA project | Alert → risk / control / instance (Helios Run B) | `RID` + target; audit `RID, TARGET, level` + verdict |
| `ia_rob_policy`, `ia_rob_policy_sections`, `ia_rob_proc` | IA project | Obligation → policy / procedure linkage | `rob_id, doc_id` + decision |

**Rules the code relies on:**
1. **RegMap's blank marker.** RegMap writes `-` for "none"; it is treated as blank.
2. **GPPS: latest version, visible sections only.** Each GPPS document is deduplicated to its highest `version_num`. Sections with `sgmntDispInd = N` are hidden in the GPPS UI and are excluded everywhere.
3. **GPPS object relations.** The relation target field depends on the type: control (CNTRL) → `cntlId`; policy / regulation (PLCY / REG) → `objId`; a procedure's PLCY relation → `objId`. RISK relations carry taxonomy text only.
4. **Helios control status.** A live instance is Assessed or Pending Assessment, excluding any whose text says "demised". Retired control standards are dropped.
5. **Gap report scope.** Only obligations with status PUBLISHED count as active.

**When a column name is different in your extract:** don't edit the notebooks. Add the name to the matching `COLS[...]` list in `pipeline_config.py`: the first name that exists is used. `build_checks.xlsx → columns_used` shows which one was picked.

---

## 5. Configuration (`pipeline_config.py`)

| Section | What to set | Notes |
|---|---|---|
| 0 Run identity | `COUNTRY`, `JURISDICTION` (exactly as in Rapid2 / RegMap), `RUN_ID` (new value for every full rebuild) | `OUT_DIR = ../output/ontology_graph_<COUNTRY>`: every output goes under it |
| 1 Sources | every path in `SOURCES` | no `<…>` placeholders may remain (the preflight fails on them) |
| 2 Build options | `KEEP_HIDDEN_ONLY_POLICY_LINKS`, `ROB_PROC_RUN`, `INTAKE_EXTRA`, `COLS` | `COLS` = candidate column names per field |
| 3 Phase 3 | `RUN_SCOPE` (B), `LINK_THRESHOLD` (5), `FALLBACK_TOP_K`, gateway settings (`CONCURRENCY`, `MAX_TOKENS`, `TOKEN_PRICE`), `AUDIT_SETTINGS` | keep `LINK_THRESHOLD = 5`: every audited run used it |
| 4 Phase 3b | live statuses, `P3B_SCOPE`, `P3B_TIERS`, `P3B_BATCH_SIZE`, `THIN_CHARS`, `EXCLUDE_REGMAP_N`, `P3B_MAX_COST_USD`, `ACTIVE_OBLIGATION_STATUSES` | the cost cap stops notebook 09 before any call |
| 5 Phase 3c | `P3C_DIR`, `P3C_PROCEDURE_SCOPE` | notebook 12 keeps its own cost cap and test settings in its CELL 1 |

Notebooks 11–13 read `OUT_DIR` (and 12 reads the GPPS paths) from `pipeline_config.py` when it's present. Otherwise they use the path set in their own CELL 1.

---

## 6. How to run

### 6.1 Run order

```
00_preflight_checks (START_STEP = 1)                    must PASS
01_ontology_build                                       facts + existing AI links
02_taxonomy_alignment -> (optional SME edit of map_to) -> 01_ontology_build again
03 -> 04 -> 05 -> 06                                    alert -> policy / procedure impact
07 -> 08 -> 09 -> 10                                    obligation -> control, gaps
11 -> 12                                                obligation -> policy / procedure via control
13                                                      demo export (optional)
```
- **03–06 and 07–10 are independent of each other;** both need 01.
- **11–12 need 09,** because they use the confirmed control links.
- **Before resuming at any step,** run `00_preflight_checks` with `START_STEP` set to that step. It checks that the earlier outputs are there and that the graph has the links the step needs.

### 6.2 Each notebook: what to expect

| NB | Writes | Gates and safety | You should see |
|---|---|---|---|
| 00 | `preflight_report.xlsx` | stops on any FAIL | `PREFLIGHT PASSED: safe to run step N` |
| 01 | `nodes.parquet`, `edges.parquet`, `manifest.json`, `build_checks.xlsx` | rule checks in the build summary | every AI-link target found ≈ 100%; if one is low, run `diagnostics/diag_id_joins.txt` |
| 02 | `taxonomy_alignment.xlsx` | — | names used by only one system, with a suggested `map_to` |
| 03 | `phase3/candidates_alert_{policy,procedure}.parquet`, cost sheet | — | pair counts per set + cost estimate |
| 04 | `phase3/alert_impact_*.parquet` (+ checkpoints) | **no-truncation proof**; 10-pair test cell before the full run | `NONE TRUNCATED`; LINKED / NOT_LINKED per set |
| 05 | `phase3/audit/audit_labelled.parquet`, results xlsx | planted wrong links must be caught (≥ 70%) | confirmed % with confidence interval; probes caught |
| 06 | `edges.parquet` (backup `edges_before_impacts.parquet`) | pre-load checks | number of impacts loaded / confirmed |
| 07 | `phase3b/l1c_candidates.parquet`, `instance_pool.parquet` | — | candidates per route, level 1 / 2 cost |
| 08 | `phase3b/l1c_results.parquet`, `l1c_audit_labelled.parquet` | test cell; CELL 6c rebuilds the results after a disconnect | confirmed %, precision per route |
| 09 | `edges.parquet` (+ `satisfiedByControl`, `satisfiedByControlInstance`; backup first) | **cost gate** + **automatic test gate** (built to run unattended) | level 2 confirmed %, edges loaded |
| 10 | `phase3b/control_gap_findings.xlsx` | — | NO_CONTROL / DESIGN_ONLY / NOT_OPERATED / PARTIAL_ONLY / COVERED |
| 11 | `phase3c/via_control_candidates.parquet`, `phase3c_scope.xlsx` | — | ALREADY_LINKED / PREV_REJECTED / NEW per type |
| 12 | `phase3c/vc_results*.{parquet,xlsx}`, `edges.parquet` (backup first) | no-truncation, **cost gate**, **test gate**, calibration against the original run, refuses to load twice | confirmed %, probes caught, gain |
| 13 | `demo/ontology_demo_data_partNN.json`, `demo_story_review.xlsx` | every record reachable from its alert; story checks | per-story counts; load the parts into the explorer HTML |

### 6.3 Restarts, re-runs and backups

- **Checkpoints.** The LLM cells (04, 05, 08, 09, 12) save every 25–50 calls, writing to a temp file first so a crash can't leave a corrupt checkpoint. **To resume, re-run the same cell:** finished pairs are skipped and ERROR rows are retried.
- **Backups before loading.** Every notebook that writes `edges.parquet` first copies it to `edges_before_<step>.parquet`. To undo a load, copy the backup back over `edges.parquet`.
- **No double loads.** The load cells refuse to load the same links twice (they assert). The preflight warns about it in advance.
- **Snapshot before big steps.** Copy the whole `OUT_DIR` before a big step (the US run kept `ontology_graph_snapshot_<date>`).

---

## 7. What comes out (graph schema)

**`nodes.parquet`:** `id, type, title, text, source_system, record, props`.
- `text` is full, never truncated.
- `record` = False marks a stub that is only referenced.
- `props` holds extra fields as a JSON string.

**ID patterns:**
- Alerts: `ALERT-<RECORD_ID>`.
- RegMap and Helios records keep their source IDs (`RGL-`, `RSM-`, `ROB-`, `LR-`, `L1C-`, `1C-`).
- GPPS documents: `POL-<core id>`, `PROC-<core id>`.
- Value nodes: `TAX-L1|L2|L3-…`, `JUR-…`, `STEW-…`, `THEME-…`, `LOB-…`, `LE-…`.

**`edges.parquet`:**
- **Every edge:** `source, target, property, layer, source_system, run_id`.
- **AI links also carry:** `decision, score, confidence, evidence_from, evidence_to, reasoning, grounding, judge_verdict, sme_status, impact_confirmed / structure_confirmed, coverage, linked_sections, impact_type, change_needed, audit_label`, and the run extras.

| Layer | Properties (main) |
|---|---|
| FACT | `partOfRegulation, derivedFromSummary, mitigatedBy, instanceOf, implementsPolicy, policyMapsToControl, procedureMapsToControl, policyMapsToRegulation, relatedPolicy, addressesRiskType, assessesRegulation, …` |
| INTAKE | `inJurisdiction, issuedByRegulator, taggedRisk, taggedSteward, hasTheme, taggedBusiness, taggedLegalEntity` |
| AI_IMPACT | `assertsImpact:RGL / RSM / ROB / LR / L1C / 1C / POLICY / PROCEDURE` |
| AI_STRUCTURE | `implementedByPolicy, governsActivity, satisfiedByControl, satisfiedByControlInstance` |
| DERIVED | `implementedByPolicyViaControl` (rule; superseded by notebook 12) |
| REFERENCE | RegMap's own mappings (extracts 3–5) |

**Which links to use:**
- **For analysis or reports**, filter AI links on `impact_confirmed == "True"` (alert impacts) or `structure_confirmed == "True"` (structure).
- **Every other AI row is a labelled assertion:** model NOT_LINKED, disputed by the judge, or never judged.

---

## 8. Method and quality controls (the same at every level)

1. **Find.** One LLM call per pair. It gets the full texts, never truncated (each notebook proves this before calling), and GPPS documents section by section (`[S<n> | <number> <title>]`). The prompt follows the house structure: ROLE / INPUT / ANTI-ANCHORING / SEMANTIC BRIDGING / TWO GUARDS / INSTRUCTIONS / EXAMPLES / FORMAT.
2. **LINKED rule.** The model says LINKED **and** its score is ≥ 5 **and** both verbatim quotes are found in the texts by code (GROUNDED).
3. **Confirm.** An independent judge reviews every LINKED pair, a sample of rejected pairs (to measure misses), and 30 planted wrong links per type (to measure leniency). A judge AGREE without verified quotes is downgraded to UNCERTAIN.
4. **Report.** Confirmed % with a Wilson 95% confidence interval, plus possible misses and the share of planted links caught. These are the run's acceptance numbers.
5. **Load.** Every pair is kept. Only LINKED + judge AGREE is flagged confirmed. The SME status starts as UNREVIEWED.

**US acceptance numbers, for comparison on a new run:**

| Step | Judge-confirmed of LINKED | Planted wrong links caught |
|---|---|---|
| Phase 3 alert → policy | 84% | 97–100% |
| Phase 3 alert → procedure | 58% | 97–100% |
| Phase 3b obligation → control standard | 56% | 100% |
| Phase 3b obligation → live instance | 57% | 97% |
| Phase 3c via control, policy | 54% | 100% |
| Phase 3c via control, procedure | 54% | 100% |

---

## 9. Running it for another country

1. **Copy the folder.** Start from a fresh `OUT_DIR`; `COUNTRY` sets the folder name.
2. **Edit `pipeline_config.py`:** `COUNTRY`, `JURISDICTION` (exact text as in Rapid2 / RegMap) and `RUN_ID`. Point `SOURCES` at that country's Rapid2, RegMap, Helios and IA outputs. **GPPS stays global:** same files.
3. **Run `00_preflight_checks` with `START_STEP = 1`.** Fix every FAIL, usually paths or column names (add the names to `COLS`).
4. **Run 01.** Check the build summary: every AI link should show target found ≈ 100%. If a join is low, run `diagnostics/diag_id_joins.txt` before going further.
5. **Run the LLM phases in order.** Before each LLM notebook, read its cost line. Notebooks 09 and 12 stop by themselves above the cap; raise the cap in the config only if the estimate is acceptable.
6. **Compare the acceptance numbers with section 8.** If the confirmed % or the share of planted links caught is far off, stop and review a sample before loading.

**What changes by country:**
- the alerts and obligations;
- the local control instances (Helios extract);
- the IA linkage outputs;
- the jurisdiction text.

**What stays the same:**
- GPPS (global);
- the prompts (they name HSBC United States in the ROLE line: change "(United States)" to the country);
- the method, thresholds and the code.

---

## 10. Troubleshooting (errors actually met on the US run)

| Symptom | Cause | Fix |
|---|---|---|
| Preflight FAIL "no <placeholders> left" | template paths still in `SOURCES` | set every path |
| Preflight FAIL on a column | the extract names it differently | add the name to `COLS[...]` (Helios / decision / verdict) or rename the column |
| Alert → LR / L1C / 1C loaded without judge verdicts | the Helios audit names its levels risk / control / instance | fixed in 01 (`LEVEL_NAMES`); check `judge_verdict` counts in `build_checks.xlsx` |
| Notebook disconnects after the LLM calls but before the results file is written | kernel / session dropped | re-run the cell (it resumes from the checkpoint); in 08 use **CELL 6c** to rebuild the results from the checkpoint |
| `ArrowTypeError` when saving parquet | a column mixes True / False and text | the notebooks save with `save_text_safe` (object columns cast to text); use it for any new save |
| `KeyError 'section'` after a merge | pandas creates `section_x` / `section_y` | select or rename columns before merging |
| `AssertionError … MAX_COST_USD` | the cost gate stopped the run before any call | review the estimate; raise the cap in the config if acceptable |
| `AssertionError … already loaded` | the load cell was run twice | skip it, or restore `edges_before_<step>.parquet` first |
| Windows `UnicodeDecodeError` joining split files | Windows reads text as cp1252 by default | join parts as **bytes** (`open(p, "rb")`) |
| Too many ERROR rows in an LLM run | gateway errors / timeouts | re-run the cell: ERROR rows are retried; check `ERROR_LOG` |
| A phase shows far lower or higher confirmed % than the US run | data or prompt drift | read 20 disputed and 20 confirmed rows in the results xlsx before loading |

---

## 11. Governance notes

- **No text is cut** anywhere in the LLM inputs; every LLM notebook proves this before calling.
- **Every AI link keeps its evidence:** quotes, reasoning, model run (`run_id`), judge verdict and SME status. That's the audit trail (it maps to W3C PROV-O; see the model document).
- **AI findings are labelled as findings.** Confirmed links and gap categories are AI findings for SME validation, not conclusions. Gap counts are an upper bound: an obligation may need no control, or its control may sit outside Helios.
- **Data handling.** Outputs and demo exports contain the full source texts and the AI evidence. Treat them with the same classification as the source systems.

---

## 12. Glossary

| Term | Meaning |
|---|---|
| RGL / RSM / ROB | RegMap regulation / regulation summary / regulatory obligation |
| LR / L1C / 1C | Helios library risk / library control (the control standard) / control instance (the live control) |
| GPPS | Global Policy & Procedure System (policies, procedures, their sections and control mappings) |
| LINKED | the model linked the pair with score ≥ 5 and both quotes verified |
| Confirmed | LINKED + the independent judge AGREEs (with verified quotes) |
| Probe | a planted wrong link used to test that the judge isn't too lenient |
| Coverage | FULL / PARTIAL: how much of the obligation the control or document meets |
| Gap categories | NO_CONTROL, DESIGN_ONLY (no live instance), NOT_OPERATED (no instance confirmed to perform it), PARTIAL_ONLY, COVERED |
| Via control (phase 3c) | obligation → policy / procedure pairs proposed because a confirmed control of the obligation is mapped in GPPS to that document |
