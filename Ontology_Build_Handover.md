# Ontology Build: Handover

**Owner:** Wrik (HSBC, Impact Assessment project) · **Written:** 28 Oct 2026 · **Updated:** 30 Oct 2026 18:30 (phase 3c COMPLETE: obligation → policy / procedure via confirmed control, 537 confirmed and loaded; demo explorer v2.5 with 5 stories delivered, standalone HTML export; model v2.5 + standards alignment written; pipeline 01–13) · **Purpose:** paste into the IA project chat (or a new chat) to continue the ontology build with full context.

> How to use: paste this whole file as the first message, then say what to do next. Everything needed to continue is in here: background, decisions, data sources with exact column names, what exists, what is missing, the build log, the phase 3 method and results, the clean pipeline (files in the project under `claude/ontology_pipeline/`) and the open questions.

---

## 0. TL;DR: where we are right now

1. **The full graph is BUILT on real US data (29 Oct 2026): 15,609 nodes, 526,545 edges.** Phases 1 + 2 (build v3, every ID join resolves) + taxonomy name map (17 names merged) + **phase 3: alert → policy / procedure impact**, found by the LLM and confirmed by an independent judge. Build log in 10b, phase 3 in 10c.
2. **Phase 3 result:** **1,082 judge-confirmed impacts**: policy **448** (84% of 530 LINKED), procedure **634** (58% of 1,098 LINKED). 27 confirmed CHANGE_REQUIRED (policy/procedure text conflicts with the new rule). ~135 alerts with a confirmed policy impact, ~121 with a procedure impact. Total LLM spend ≈ $16.
3. **Clean pipeline packaged** for the team / other countries: `pipeline_config.py` (only file to edit) + `ia_lib.py` + notebooks `01_ontology_build` → `02_taxonomy_alignment` → (01 again) → `03_impact_candidates` → `04_impact_llm` → `05_impact_audit` → `06_load_impacts`, each reading only files from the previous step (README has the lineage). Stored in the project under `claude/ontology_pipeline/`.
5. **Phase 3b (which control satisfies which obligation) COMPLETE:** obligation → control standard **5,327 confirmed** (`satisfiedByControl`) and obligation → live control instance **7,908 confirmed** (`satisfiedByControlInstance`); graph now **677,563 edges**. **Control gap findings** for the 3,180 live obligations: NO_CONTROL 52%, NOT_OPERATED 23%, COVERED only 16% (alert-linked: 46% / 25% / 20%). Cost ≈ $69. Section 10d.
4. **SME review is deferred** (business will do it later).
6. **Phase 3c (30 Oct): obligation → policy / procedure via a confirmed control. COMPLETE.**
   - **537 new judge-confirmed links:** 243 policy, 294 procedure.
   - **Gain:** 32 obligations get their first policy; 70 of the 260 obligations with no procedure get one.
   - **TPRM:** 11 of the 12 rule-only links to POL-47 are now confirmed.
   - **Graph now 684,990 edges.** Cost $14.6. Section 10e.
7. **Demo delivered (30 Oct): explorer v2.5 with 5 stories.** These are the 4 original alerts plus the third-party story (ALERT-120727 → RGL-00011917 → POL-47). It has a standalone-HTML export for sharing. Section 10f.
8. **Model v2.5 + standards alignment written:** `claude/Ontology_Model_and_Standards.md` (OWL / SHACL / SKOS / PROV-O / FIBO / ISO / LegalRuleML / ELI / GQL), with a publishing plan.

---

## 1. Working preferences (Wrik's standing rules; follow them)

- Terse, directive, often on mobile. Wants **complete, senior-ready deliverables**, not partial drafts or architecture-only answers.
- **Refer back to the IA project chat and Ontology chat before answering**; don't re-ask things already established there (Wrik got frustrated when this was missed: GPPS files, RegMap 7 extracts, Helios file layout).
- **Don't guess column names or structure: inspect first.** Explicit paths only; no auto-searching of loaded dataframes.
- **Never truncate text sent to an LLM.** Print proof (char counts) before spending money.
- **Short screen output (~25–30 lines);** detail goes to Excel. Wrik photographs his locked-down office laptop screen, so output must be photo-friendly.
- Code: **properly commented with `#`, well structured and indented**, cell-by-cell, intuitive variable names, house-style prompts (ROLE / ANTI-ANCHORING / SEMANTIC BRIDGING / GUARDS / scoring bands / examples / FORMAT JSON) for any LLM step.
- Iterate: run once, Wrik shares the output, then decide (read-only diagnostic cells before fixing).
- Files to git must be **split < 95 KB** with a self-verifying merge. HTML files get **stripped in transfer**, so send HTML as `.txt` and rename locally.
- parquet from BigQuery: always read with `pq.read_table(p).replace_schema_metadata(None).to_pandas(date_as_object=True)` (dbdate fix).
- Push back with evidence; don't simply agree. Explain to non-technical audiences in very simple terms when asked.
- Wrik hardcodes paths (prefers that to glob/run-tag logic).

---

## 2. Background: what the project is

- **Impact Assessment (IA):** when a regulatory alert (Rapid2) arrives, find what it impacts: regulation (RGL) → regulation summary (RSM) → obligation (ROB) in RegMap, and library risk (LR) → library control (L1C) → control instance (1C) in Helios, plus policies/procedures in GPPS. Every AI link carries evidence quotes, score, reasoning and an independent judge verdict.
- **Ontology:** the RegCompliance ontology (built in the Ontology chat: v1.0 → v2.0 → v2.1 → v2.2 → **v2.3/v2.4**). Interactive explorer HTML with tabs: Overview, Map, Questions it answers, Graph & AI, Governance rules, Classes, Relationships, v1→v2. AI links are reified as **Link Assertions** (decision, scores, evidence, method, SME status); **impact edges are materialised only from CONFIRMED assertions** (ontology rule).
- **Goal now:** build the *complete* ontology with live data (everything on the Map tab connected like the model), bake in the impact assessment, bake in Rapid2 applicability/contextualisation, then scale (US first; later ~60 countries).
- Competing internal team "Codify/CIB": Wrik wants **no mention** of them in deliverables.

---

## 3. What the IA project already produced (reuse, don't rebuild)

From the IA project doc *Alert Linkage: Output Files by Level*. **Counts verified in the v3 build (29 Oct).**

| Level | Base file (every decision) | Audit (judge verdict) |
|---|---|---|
| **RSM** (and **RGL rolled up from it**) | `rsm_linkage_pairs_{model}_{comment}_{runid}.parquet`: **8,297 rows** (decision column `final_decision`: 1,334 LINKED / 6,910 NOT_LINKED / **53 ERROR**). *The earlier figure 6,297 was wrong.* | RGL audit: `rgl_output_audit/audit_labelled_predictions.parquet` (995 rows; RSM evidence judged inside it) |
| RGL | rolled up from the RSM file: an alert→RGL is LINKED if any of its RSMs is LINKED (4,961 alert×RGL pairs, 888 LINKED). `results_with_truth_….parquet` is only a cross-check. | RGL audit |
| **ROB** | `rob_linkage_pairs_….parquet` (11,336 rows, 1,628 LINKED; carries parent RSM_ID / REG_ID) | `rob_output_audit/audit_labelled_predictions.parquet` (1,727 rows; `audit_verdict`: AGREE 441 / DISAGREE 1,238 / UNCERTAIN 42) |
| **LR / L1C / 1C** (Helios **Run B** = folder `helios_linkage_llm_RT_method2`, adopted) | `links_risk.parquet` (3,730 rows, 370 LINKED), `links_control.parquet` (3,084, 1,105), `links_instance.parquet` (23,102, 2,650) | `helios_audit_B/audit_labelled.parquet` (5,715 rows; `level`, `RID`, `TARGET`, `audit_verdict`, `audit_verdict_final`; includes planted test pairs, which never match the base files) |
| **ROB → policy** (ontology STRUCTURE, GenAI) | `policy_v2_verdicts.parquet` (127,210 rows, 17,056 LINKED; `rob_id, doc_id, tier, source, decision, link_score, confidence_score, linked_sections, evidence_from_obligation, evidence_from_document, reasoning, sections_sent, section_coverage`) + section view `obligation_to_policy_links_with_sections.parquet` (`link_support`, `primary_section_no`, `primary_clause_no`, `sections_visible`) | none (NOT_AUDITED) |
| **ROB → procedure** (ontology STRUCTURE, GenAI) | `procedure_v2_verdicts.parquet` (173,291 rows; mixes runs: **use `run == "core"`**: 166,291 rows = **10,663 LINKED** / 155,379 NOT_LINKED / 249 INSUFFICIENT_EVIDENCE; `calibration` 7,000 rows / 122 LINKED excluded). *The earlier figure 16,663 was wrong.* | none |

Other IA findings to keep in mind:
- Helios Run B found 4–7× more judge-confirmed impacts than Run A (taxonomy-only); **instance-level scope errors** (wrong country/LE/business) are the main failure mode (instance precision ~50%). The fix = scope check using legal entity / LOB.
- RegMap silver check: 344 library controls and 712 instances confirmed by both the AI judge and RegMap.
- GPPS: **57% of policy segments are UI-hidden junk** (`sgmntDispInd = N`, e.g. "Accidentally added when creating and linking new MCR"); 8,486 of 17,056 ROB→policy links rest only on hidden text. The build tags them (`link_support = HIDDEN TEXT ONLY`).
- SME review packs exist (200 RGL + 200 ROB items).

---

## 4. Key decisions

1. **Two different things, never mix:**
   - **Ontology structure**: how artefacts relate regardless of alerts (RGL has summary RSM, RSM decomposes to ROB, ROB implemented by policy, ROB governs procedure, LR mitigated by L1C, 1C instance of L1C, …). ROB→policy/procedure GenAI links are structure (layer `AI_STRUCTURE`).
   - **Impact assessment**: what an alert touches (alert → RGL/RSM/ROB/LR/L1C/1C, layer `AI_IMPACT`). Alert → policy/procedure impact is **to be built** (phase 3).
2. **Library Risk (LR) ≠ Risk taxonomy (L1/L2/L3).** LR is a *record* (Helios US_Risk `risk.parquet`, IDs `LR-…`). Taxonomy is a *classification* used as a tag on many things (alerts via Rapid2 ML, library risks via Helios fields, RSM/ROB via RegMap, **procedures via GPPS objRel RISK**). Bridge = LR *classified as* taxonomy node.
3. **Helios file layout:** one control file (3,763 rows) holds **both** control instance (1C) rows and their library-control (L1C) fields. **The 1C ID (`1C-…`) is in the `name` column** (`resource_id` is a different numeric ID). L1C records = group that file by `l1_library_control_id`. **RTCL** only maps **LR ↔ L1C**. The risk file has 948 rows for **119 distinct library risks** (several rows per risk); one node per risk.
4. **Base = full linkage output; audit verdict joined on.** Unaudited pairs → `NOT_AUDITED`. Keep all decisions (LINKED, NOT_LINKED, ERROR, INSUFFICIENT_EVIDENCE) with a `decision` column; consumers filter.
5. **RegMap extracts 3/4/5** (RSM → risk / control mappings) are RegMap's own human mappings: kept as `REFERENCE` edges (candidates and checks), **not** as truth.
6. **Rapid2 has no applicability / LOB / legal-entity columns.** The demo values for 4 alerts came from elsewhere (Wrik's table). Builder has an optional `INTAKE_EXTRA` slot; need the source file.
7. **Full build first (all data), HTML later** with a sample Wrik will choose.
8. Use the ontology's own relationship list (Map tab, `D.rels`) as the **build checklist** (107 items: 95 ontology relationships + alert-impact rows + GPPS objRel bridges).
9. **GPPS hidden segments** (`sgmntDispInd = N`) are not part of the published document: their objRel is skipped; ROB→policy links resting only on them are kept but tagged (switch `KEEP_HIDDEN_ONLY_POLICY_LINKS`).

---

## 5. Data sources: exact files and columns (from Step 0, 25/25 readable, + section view)

**Rapid2:** `../data/Rapid2_REGDEV_US_2020_2025.parquet`, 2,391 alerts, 24 cols:
`RECORD_ID, ALERT_ID, INGEST_RULE_TYPE, RECORD_JURISDICTION_CODE, RECORD_JURISDICTION_NAME, RECORD_START_DATE, RECORD_END_DATE, ACTIVE_INDICATOR, RECORD_CATEGORY_CODE, RECORD_STATUS_CODE, RECORD_STATUS, REGULATOR_CODE, RISK_STEWARD_AREA_CODE, RISK_STEWARD_AREA_NAME, RECORD_THEME_CODES, RECORD_THEMES, LEVEL_1_RISK_TAXONOMY, LEVEL_2_RISK_TAXONOMY, LEVEL_3_RISK_TAXONOMY, TITLE, SUMM_CONTENT, SUMM_UPDATE, URL_TEXT, INTRO_TEXT`
(No applicability, LOB, legal entity. All US: the build has a single Jurisdiction node.)

**RegMap: 7 extracts in `../data/Tactical_Regmap_Data/`** (Excel; exact filenames in Wrik's folder):

| # | Rows | Holds | Key columns |
|---|---|---|---|
| 1 | 2,706 | Regulator → Regulation → RSM | `Regulator Name, Regulator Code, Regulator Status, Regulation Jurisdiction, Regulation ID, Regulation Title, Regulation Description, Regulation Status, Regulation Record Administrator, Regulation Control Mapping Approach, Regulation Version, Regulation Summary ID, Regulation Summary Status, Regulation Summary Control Mapping Approach, Regulation Summary Version` |
| 2 | 3,398 | RSM text + taxonomy | `Regulation-ID, Regulation Summary ID, Regulation Summary Title, Regulation Summary Detail Text, Regulation Summary Status, Regulation Summary Regulation Type, Regulation Summary Risk Steward Area, …, Regulation Summary Risk Taxonomy l1 / L2 / L3` |
| 3 | 248,459 | RSM → LR → L1/L2 library control | `Regulation Summary ID, …Taxonomy l1/L2/L3, Regulation Summary Applicability Unique Key, Regulation Summary Library Risk ID Number, Regulation Summary L1 Library Control ID Number, Regulation Summary L2 Library Control ID Number` |
| 4 | 39,989 | RSM → risk instance, applicable? | `…, Risk ID, Risk Instance Applicable?` |
| 5 | 251,830 | RSM → risk → L1 control instance, applicable? | `…, Risk ID, Risk Instance Applicable?, L1 Control ID, L1 Control Instance Applicable?, L2 Control ID` |
| 6 | 3,628 | Obligations | `Regulation ID, Regulation Summary ID, Obligation ID, Obligation Version, Obligation Status, Obligation Title, Obligation Detailed Text, Obligation Citation, Obligation Expected Controls Description, Obligation Last Modified Date, Obligation Creation Date, Obligation Risk Taxonomy L1/L2/L3, Regulation Obligation Library Risk ID Number` (**ROB → LR in RegMap; `-` means none**; only ~37 distinct LR IDs used, 1,954 ROB→LR edges) |
| 7 | 9,707 | Regulation assessments → obligation in scope, by business | `Regulation ID, Regulation Assessment ID, Regulation Assessment Title, Regulation Assessment Business, Regulation Assessment LoB Path, Regulation Assessment Status, Regulation Assessment Last Assessed Date, Obligation Evaluation Obligation ID, Obligation Evaluation In-Scope?` |

**Helios: `../data/Helios/`**
- `risk.parquet` (US_Risk), 948 rows / **119 distinct `library_risk_id`**, 132 cols. Key: `library_risk_id` (also `library_id`), `title`, `library risk description`, `risk_status`, `risk_taxonomy_l1/l2/l3` (+ `_id`, `_short_name`), `risk_steward`, `risk_owner`, `business`, `business_short_name`, `legal_entity`, `legal_short_name`, `risk_business_l1..l5`, `risk_legal_entity_l1..l5`, `applicable locations`, basel/orx taxonomies.
- Control file (1C rows + L1C fields), 3,763 rows, 85 cols. Key: **`name` = 1C ID (`1C-00196042`)**, `resource_id` (numeric, NOT the 1C ID), `l1_control_title_alias` (instance title), `l1_library_control_id`, `l1_library_control_title`, `l1_library_control_description`, `l1_library_control_status`, `l1_control_status`, `business`, `business_short_name`, `l1_control_business_l1..l5`, `legal_entity`, `legal_entity_short_name`, `l1_control_legal_entity_l1..l5`, `control_owner`, `primary_risk_steward`, `control_type`, `control_effectiveness`, `design_effectiveness`, `covered_business`, `local_business_function`, `saracen_entity`.
- RTCL, 4,834 rows, 48 cols. Key: `risk_library_id`, `l1_control_library_id` (may appear as `l1_control library_id`), `l2_control_library_id`, `risk_resource_id`, `l1_control_resource_id`, `risk_taxonomy_l1/l2/l3` (+ids), titles/descriptions/status for risk, L1 and L2 library controls, `primary_risk_steward`, `consumed_business(_path)`, `owned_business(_path)`.

**GPPS** (each: `*_core_id, version_num, snapshot_time, transfer_date, json_data`):
- `us_policy_26_sep.parquet` (64 rows) + `global_policy_26_sep.parquet` (620 rows) → **284 policies** after latest-version dedup. JSON: id `plcyCoreId`, `policyTitle`, sections `policyApplication.segment[]` (`sgmntTitlText`, `sgmntText`, **`sgmntDispInd`** N = hidden, `sgmntReasonText`), `policyText` / `policyPurpose` `{sgmntText, sgmntTitlText}`, `policyRiskTypePrimary`, `policyDocType`, `policyApplication.multiRiskDetls[]`, `termDefin[]`, `versn.versNum` / `versStatCde` (PUBL), **`segment[].objRel[]`**.
- `global_procedure_26_SEP.parquet`: 2,169 rows → **1,180 procedures** (dedup on `procedure_core_id`, highest `version_num`; the JSON version is unreliable). JSON: `procCoreId`, `procedureTitle` (69 missing), sections `procedureApplication.segment[]` with **`proc`-prefixed** fields, `procedureRiskType`, `procedurePurpose`, no status field, country mostly GLOBAL; **`segment[].objRel[]`**.
- **objRel: which field holds the target, per type (verified 29 Oct):**

| Where | Type (`objTypeCde` / `plcyObjTypeCde`) | Count | Target field | Graph edge |
|---|---|---|---|---|
| policy | CNTRL | 3,635 (1,153 edges after hidden skip/dedup) | `cntlId` | `policyMapsToControl` (75% found in Helios: GPPS is global, Helios file is US) |
| policy | REG | 346 | `objId` = RegMap Regulation ID | `policyMapsToRegulation` (100% found) |
| policy | PLCY | 70 | `objId` = policy core id | `relatedPolicy` |
| procedure | PLCY | 2,080 | **`objId`** = policy core id (96% match). `cntlId` in the same entry is the policy MCR's control; `mcrName` = the MCR | `implementsPolicy` (99.5% found; MCR name + control kept as attributes) |
| procedure | CNTRL | 9,109 | `cntlId` | `procedureMapsToControl` (62% found: global vs US) |
| procedure | RISK | 1,754 | **no ID**: only `riskTxnmyL1Text / L2Text / L3Text` | `addressesRiskType` → risk taxonomy node (1,747 edges) |

**IA outputs:** see section 3 (paths under `../Impact_assessment_WB/IA_RSM_RGL_AG_vF/…` and `../Impact_assessment_WB/IA_Risk_Control_Revamped/output/…`). Helios Run B = `helios_linkage_llm_RT_method2` (confirmed).

---

## 6. Ontology model (v2.4, as in the explorer)

> **v2.5 (30 Oct) is in `claude/Ontology_Model_and_Standards.md`.** It covers every relationship added by phases 3 / 3b / 3c, the Gap class and categories, the GPPS properties that are now in the model, the standards alignment table and the publishing plan. The list below is the v2.4 baseline.

- **v2.2 base:** 46 classes, 87 relationships, 10 modules (Regulatory Source, Requirement Semantics, Regulatory Change, Impact Assessment, Risk, Control, Policy & Procedure, Business Context, Accountability, Provenance & AI Governance), vocabularies, SHACL-style shapes, competency questions, Cypher.
- **v2.4 changes:** new class **Regulatory Theme**; new relationships on Regulatory Alert (`hasApplicability`, `hasCategory`, `taggedSteward`, `hasTheme`, `taggedBusiness`, `taggedLegalEntity`, `contextualisedBy`); `Jurisdiction broaderJurisdiction Jurisdiction`; LegalEntity PARTIAL, BusinessUnit AVAILABLE, Role AVAILABLE; sources for Library Risk / Library Control / `mitigatedBy` = Helios. Total: 47 classes, 95 relationships.
- **Properties the build uses that the ontology does not have yet (phase 0, add to the model):** `assertsImpact:RGL/LR/L1C` (impact at RGL / LR / L1C level; ontology only has RSM `affectsSummary`, ROB `affectsObligation`, 1C `impactsControl`), `policyMapsToControl`, `policyMapsToRegulation`, `relatedPolicy`, `procedureMapsToControl`, `addressesRiskType` (procedure → risk taxonomy), class **RegulationAssessment** (`assessesRegulation`, `assessedFor`, `evaluatesObligation`), REFERENCE properties `regmapMaps*`. Policy/procedure links are document-level vs the ontology's PolicyRequirement/ProcedureStep (section level); ROB→policy now carries section/clause numbers, so PolicyRequirement nodes can be added.

---

## 7. The explorer HTML (parked; resume after the build)

- File: `RegCompliance_Ontology_v2_4.html` (send as `.txt`, rename locally). Base = the RegCompliance Ontology artifact + a **Live data add-on**; the ontology data block `const D = {…}` was extended to v2.4.
- **Loads data** via "Load live data" (one JSON or all split parts selected together; NaN/Infinity → null). Page width / size controls.
- **Map tab:** classes with data light up with count badges. **Live data tab:** lanes (Regulatory chain / Alert context / Risk & control), layers (Everything / Alert context / Ontology structure / Alert impact), step-by-step reveal, ontology relationship names on lines, side panel with evidence, 7-step alert journey strip.
- Demo JSON format: `{meta, nodes:[{id,type,title,text}], edges:[{source,target,relation,kind,score,confidence,evidence_from,evidence_to,reasoning,grounding,route,tier,judge_verdict,sections}]}`. **The full build uses a richer schema; a small exporter will convert a chosen sample to this JSON.**
- Demo sample so far: alerts **133999** (hero), **119934** (fan-out), **125919** (many-to-many), **159982** (gap). Intake values for these 4 alerts:

| Ref | Applicable | Cat | Title | Location | Steward | Theme | L1 | L2 | L3 | LOB | LE |
|---|---|---|---|---|---|---|---|---|---|---|---|
| RD-00000133999 | Yes | RD | Pennsylvania Amends Insurance Producer Continuing Education Requirements (SB 1241) | Global/United States | Regulatory Compliance | Insurance | Regulatory Compliance Risk | Breach of regulatory duty to clients and other counterparties | Failure to ensure sales outcomes are appropriate | Group Insurance | HSBC North America Holdings Inc. |
| RD-00000159982 | Yes | RD | Ohio Amends Request for Information Procedures | Global/United States | Regulatory Compliance | Consumer Protection | Regulatory Compliance Risk | Breach of regulatory duty to clients and other counterparties | Failure to protect client assets | Wealth and Distribution | HSBC North America Holdings Inc. |
| RD-00000119934 | Yes | RD | SEC Approves FINRA's Amendments to Maintain Qualification Program | Global/United States | Regulatory Compliance | Licensing, Registration and Permissions | Regulatory Compliance Risk | Regulatory Licensing, Permissions & Rules | Regulatory Compliance Regulatory Reporting Risk | Wealth and Distribution | HSBC North America Holdings Inc. |
| RD-00000125919 | Yes | RD | California Amends Law on Reservist Deferred Compensation | Global/United States | Regulatory Compliance | Consumer Protection | Regulatory Compliance Risk | Breach of regulatory duty to clients and other counterparties | Failure to protect client assets | Wealth and Distribution | HSBC North America Holdings Inc. |

- Business talk track for intake: applicability first (stop if not applicable), then category, then ML tags (steward, theme, L1–L3, LOB, LE).

---

## 8. Build plan to the ideal state (phases)

| Phase | What | Status |
|---|---|---|
| 0 | Ontology fixes: add the properties/class listed in section 6 | **✅ written** (Model v2.5 doc); publish as OWL / SHACL / SKOS when approved |
| **1** | **Load the facts, no LLM**: Rapid2 + intake; RegMap 7 extracts; Helios (LR, 1C/L1C, RTCL); GPPS (policies, procedures, objRel); taxonomy tree | **✅ done (v3)**; intake applicability/LOB/LE still missing a source |
| **2** | **Load existing GenAI links**: alert→RSM/RGL/ROB/LR/L1C/1C (AI_IMPACT, verdict joined); ROB→policy/procedure (AI_STRUCTURE, policy links with section numbers + link_support) | **✅ done (v3)** |
| 2b | **Taxonomy name alignment**: 203 names used by one system only (Rapid2 95, Helios 54, GPPS 54; only 289 links on them) → 18 safe auto-maps, 17 merged (CELL 7b) | **✅ done**; rest (PARTIAL / other level / no match) for an SME pass before the demo |
| 3 | **Alert → policy / procedure impact** | **✅ done** (10c): find (v1 prompts) + confirm (judge) + fallback; loaded as `assertsImpact:POLICY / PROCEDURE` |
| 3b | **Control satisfies ROB**: library control (level 1) + live instance (level 2) + gap findings | **✅ done** (10d) |
| 3c | **Obligation → policy / procedure via a confirmed control** (fills the gaps left by text search) | **✅ done** (10e) |
| 4 | Requirement semantics from ROB text (modality, conditions, triggers, exceptions, deadlines, scope, responsible party) | later |
| 5 | Impact assessment as data: Regulatory Change + Impact Assessment per alert; Impact Finding per impacted node; **LE/LOB scope filter** on instances; gaps by rule; blast radius | later |
| 6 | SME loop: load SME pack outcomes; confirmed = new golden; sign-off | **deferred by the business**; when it happens start with the 27 confirmed CHANGE_REQUIRED and a stratified sample of confirmed / disputed / NEEDS_SME phase 3 links |
| 7 | Explorer v2.5 + sample → HTML | **✅ done** (10f); rule checks as SHACL later |
| 8 | Regulation lineage, provisions, defined terms, procedure roles, automation | later |
| 9 | Blocked (no data): control tests, issues, remediation, product/process/system masters, HR | blocked |

**Checklist page:** claude.ai artifact "Ontology Build Plan" (107 items, filter by phase/status/method).

Scaling (management message already drafted): library-level linkage once globally; per-country alert linkage filtered by jurisdiction; mandatory scope check; multilingual GPPS; graph DB required; data residency, MRM/IMR, SME capacity are the dependencies.

---

## 9. Output schema of the build (`OUT_DIR = ../output/ontology_graph`)

- `nodes.parquet`: `id, type (ontology class), title, text (full, never truncated), source_system, record (True = loaded from its own system; False = stub, only referenced), props (JSON string)`.
  - ID conventions: alerts `ALERT-<RECORD_ID>`; RegMap and Helios IDs as in source (`RGL-…`, `RSM-…`, `ROB-…`, `LR-…`, `L1C-…`, `1C-…`); `POL-<core id>`, `PROC-<core id>`; value nodes `TAX-L1|L2|L3-<name>`, `JUR-<name>`, `STEW-<name>`, `THEME-<name>`, `LOB-<name>`, `LE-<name>`, `PERSON-<name>`, `REGULATOR-<code>`, `RA-<assessment id>`.
- `edges.parquet`: `source, target, property, layer, source_system, run_id` + for AI links `decision, score, confidence, evidence_from, evidence_to, reasoning, grounding, judge_verdict (AGREE/DISAGREE/UNCERTAIN/NOT_AUDITED), sme_status (UNREVIEWED)` + extras (`parent_rsm, parent_rgl, provenance, parent_control, linked_sections, tier, linked_rsms, applicable, in_scope, section, link_support, primary_section_no, primary_clause_no, sections_visible, policy_mcr, policy_mcr_control`).
- Layers: `FACT` (system of record), `INTAKE` (Rapid2 tags), `AI_IMPACT` (alert impact), `AI_STRUCTURE` (ROB→policy/procedure), `REFERENCE` (RegMap ext 3–5 mappings).
- `manifest.json` and `build_checks.xlsx` (notes, nodes_by_type, edges_and_coverage, rule_checks, columns_used, stubs).

---

## 10. Open questions / next actions

1. ✅ ~~Run the build on real data~~ (v3 clean). ✅ ~~Helios run folder~~ (Run B `…_RT_method2`). ✅ ~~1C ID column~~ (`name`). ✅ ~~Policy sections~~ (section view joined).
2. ✅ ~~Taxonomy name alignment~~ (17 merged; the rest needs an SME, before the demo).
3. ✅ ~~Phase 3 alert → policy / procedure impact~~ (1,082 confirmed; section 10c).
4. ✅ ~~Clean pipeline for the team / other countries~~ (`claude/ontology_pipeline/`).
5. **Procedure precision is 58% before the judge.** The judge filter makes the confirmed set reliable; a stricter prompt (v2/v2.1) was rejected because it also removed 50–67% of confirmed links. The open question of where "review needed" stops for procedures is for the SMEs.
6. ✅ ~~Demo sample → explorer HTML~~ (v2.5, 5 stories, standalone export; 10f).
7. Source for **applicability, LOB, legal entity** at alert intake (not in Rapid2) → `INTAKE_EXTRA`.
8. **53 ERROR rows** in alert→RSM: loaded with `decision = ERROR`; re-run or exclude.
9. **8,486 hidden-text-only ROB→policy links**: kept and tagged (phase 3 used visible-text links only).
10. ✅ ~~Phase 3b control satisfies ROB~~ (10d). ✅ ~~Phase 3c via-control policy / procedure~~ (10e). ✅ ~~Model update + standards alignment~~ (written; publishing on approval).
11. **Remaining:**
    - SME pack when the business is ready (27 CHANGE_REQUIRED, gap sheets, a sample of confirmed / disputed links);
    - publish OWL / SHACL / SKOS (about 3 days, no LLM);
    - final end-to-end run of the clean pipeline (01–13) on a fresh folder;
    - optional: the ~19k remaining procedure via-control pairs (about $35);
    - an intake source for applicability / LOB / LE.

---

## 10b. Build log: v1 → v3 (29 Oct 2026)

| Run | Nodes / edges | What broke / changed |
|---|---|---|
| v1 | 16,109 / 523,562 | alert→1C **0%** (joined on `resource_id`; Run B IDs are in `name`); ROB→LR (RegMap) **0%** (RegMap writes `-` for none); procedure→policy **0%** (used `cntlId`, the policy ID is `objId`); 540 phantom policies; rule "264 instances with no library control" counted GPPS stubs |
| v2 | 15,573 / 517,977 | Fixed all three joins (1C 100%, ROB→LR 100%, procedure→policy 99.5%); hidden GPPS segments skipped; ROB→policy tagged with section view; policy objRel REG (→ regulation, 100%) and PLCY loaded; rule counts Helios instances only (3,763 of 3,763). Procedure RISK collapsed to 1 edge: entries have no ID |
| **v3** | **15,626 / 519,858** | Procedure RISK → `addressesRiskType` taxonomy node (1,747 edges, 100%). Taxonomy nodes 278 → 332 (GPPS names not matching Rapid2/Helios). **Clean.** |

**v3 coverage (target is a real record):** all `assertsImpact:*` 100% (RSM 8,297 / 1,334 linked; RGL 4,961 / 888; ROB 11,336 / 1,628; LR 3,730 / 370; L1C 3,084 / 1,105; 1C 23,102 / 2,650) · `implementedByPolicy` 127,210 / 17,056 linked, 100% · `governsActivity` 166,291 / 10,663 linked, 100% · `givesRiseTo` 1,954, 100% · `implementsPolicy` 1,894, 99.5% · `instanceOf` 3,763, 100% · `mitigatedBy` 2,052, 100% · `policyMapsToControl` 1,153, 75.1% · `policyMapsToRegulation` 346, 100% · `procedureMapsToControl` 6,998, 62.2% · `addressesRiskType` 1,747, 100% · `relatedPolicy` 15, 100%.

**v3 nodes:** Control 4,027 (3,763 Helios + 264 GPPS-only stubs) · RegulatoryObligation 3,352 · RegulatoryAlert 2,391 · Procedure 1,180 · RegulatorySummary 849 · RegulationAssessment 760 · Person 705 · LibraryControl 704 · RiskTaxonomyNode 332 · Regulation 315 · Policy 289 (284 + 5 stubs) · BusinessUnit 209 · Regulator 205 · LibraryRisk 193 · Role 71 · RegulatoryTheme 43 · Jurisdiction 1.

**v3 rules:** control instances with a library control 3,763 of 3,763 · no library control 0 · **library risks with no mitigating control 9** (real gap) · obligations with no parent summary 0 · stubs 269 (expected: GPPS global vs US Helios).

Files: `ontology_build_v3_NOTEBOOK.txt` (full code, section 11), `CELL_9_diagnose_id_joins.txt` (read-only join diagnosis, reusable for new sources). The v3 code now lives in the pipeline as `01_ontology_build.txt` (section 11).

---

## 10c. Phase 3: alert → policy / procedure impact (29 Oct 2026)

**Method (final, same as every other level of the project)**
- **Candidates (no LLM):** alert → obligation (assertsImpact:ROB, LINKED) → policy (implementedByPolicy LINKED, **visible text only**) / procedure (governsActivity LINKED). One candidate per (alert, document); all bridging obligations kept. **Run B** = every model-LINKED alert → obligation link, each pair flagged `run_set` A (judge-agreed bridge) / DISPUTED_SAMPLE (50 disputed links sampled) / B_rest. **Fallback**: alerts impacted at RSM level with no obligation route to a document type → TF-IDF top 10 (Helios settings).
- **LLM (find):** one call per pair: FULL alert + metadata, FULL bridging obligation text (context only), FULL visible document text by GPPS section `[S<n> | <number> <title>]`. Nothing truncated (proof printed: 0 pairs short). House prompt structure (ROLE / INPUT / ANTI-ANCHORING / SEMANTIC BRIDGING / TWO GUARDS / INSTRUCTIONS / EXAMPLES / FORMAT); same fields (reasoning, decision, link_score, confidence_level, evidence_from_alert / _policy / _procedure) + linked_sections, impact_type (CHANGE_REQUIRED / REVIEW_REQUIRED), change_needed. LINKED = model LINKED + score ≥ 5 + both quotes verified (GROUNDED).
- **Judge (confirm):** independent assurance-reviewer prompt on EVERY LINKED pair + 300 rejected / type + 30 planted wrong links / type; AGREE / DISAGREE / UNCERTAIN + error type; judge quotes verified. **Only CONFIRMED links count as impacts** (`impact_confirmed`).
- Model `gpt-5.6-luna`, MAX_TOKENS 20,000 (ceiling), concurrency 15. Cost: LLM $11.12 + audit $3.95 + fallback ≈ $0.55 + gate tests $0.41.

**Results**

| | Pairs | LINKED | Confirmed | Precision (CI) |
|---|---|---|---|---|
| Policy (main) | 1,829 | 527 | 445 | 84.4% (81–87) |
| Procedure (main) | 4,578 | 1,078 | 620 | 57.5% (55–60) |
| Policy (fallback) | 40 | 3 | 3 | – |
| Procedure (fallback) | 250 | 20 | 14 | 70% |
| **Total** | **6,697** | **1,628** | **1,082** | |

- By bridge: policy A 88% / B_rest 78% / disputed sample 86%; procedure A 58% / B_rest 55% / disputed 72% → the ROB judge was NOT too strict; disputed obligation links still lead to real impacts, so run B was right.
- Score band: policy 5–6 → 59%, 7–10 → 87%; procedure 5–6 → 22%, 7–10 → 60%.
- CHANGE_REQUIRED 27/33 confirmed (82%); REVIEW_REQUIRED 66%.
- Disputed error types (procedure): FALSE_LINK_THEMATIC 276 (neighbouring activity in the same domain), WRONG_SCOPE 133 (e.g. CIB procedure vs retail rule), UNSUPPORTED 39. Not concentrated: top 10 procedures = 19% of disputes, top 5 alerts = 26%.
- Recall: possible misses 9/300 policy, 2/300 procedure. Judge caught 97–100% of planted wrong links.
- **Procedure prompt v2 / v2.1 (strict "same activity / same scope / a step" tests) REJECTED at an A/B gate** on 60 audited links: v2 rejected 30/30 disputed but kept only 10/30 confirmed; v2.1 28/30 and 14/30. The remaining disagreement is where "review needed" stops (judge accepts perimeter-level links) → kept find + confirm. Archived in `diagnostics/`.
- Loaded into the graph: 6,697 `assertsImpact:POLICY / PROCEDURE` edges (all decisions, judge verdict, `impact_confirmed`, linked_sections, impact_type, change_needed, run_set, via_robs). Pre-load checks all 0; backups `edges_v3_before_phase3.parquet`, `edges_before_fallback.parquet`.

---

## 10d. Phase 3b: obligation → control (29 Oct 2026, evening)

**Question:** which library control (L1C) is designed to make the bank comply with which obligation (ROB)? Structure, not alert impact.

**Data checks that set the method (all $0):**
- L1C text mostly sufficient (median 1,082 chars; 42 < 200 → their live instances' text appended).
- **Instances are NOT copies of the library control**: 91% add ≥ 40% new words (local steps, specific reports); some are retired with live-looking text → instances need their own decision later (level 2), not inheritance.
- Instance status: Retired 1,787, Assessed 1,673, Cancelled 241, Pending Assessment 57, Draft 5 → **live = Assessed + Pending Assessment, text not "demised" = 1,706**. Library controls: Published 330, blank 317, Retired 57 → 647 kept. 434 library controls have no live instance.
- **Bug found and fixed:** Helios judge verdicts were never joined in the build (audit levels are risk / control / instance, not LR / L1C / 1C). Patched in edges.parquet (risk 300 / control 765 / instance 1,338 AGREE) and fixed in pipeline `01_ontology_build.txt`.

**Candidates (7 routes, union, route kept per pair):** B1 RegMap ext6 obligation → risk → RTCL; B2 RegMap ext3 summary → risk → RTCL; B3 taxonomy; B4 same alert ROB + LR both AGREE; C1 RegMap ext3 summary → control; C3 GPPS obligation → policy (visible) → policy objRel control; C4 same alert ROB + L1C both AGREE. 102,114 pairs, 3,197 obligations.

**Level 1 (library control), find + confirm, all obligations:** one LLM call per obligation × 10 controls (house prompt; decision, coverage FULL / PARTIAL, link_score, confidence, verbatim quotes; LINKED = model LINKED + score ≥ 5 + quotes verified) → independent judge on every LINKED pair + 300 rejected + 30 planted.

| | Value |
|---|---|
| Pairs judged | 102,114 (3 ERROR) |
| LINKED (model) | 9,437 |
| **Judge-CONFIRMED** | **5,327 (56.4%, CI 55–57)** across **1,568 obligations** |
| Obligations with no confirmed control | **1,629** (gap candidates) |
| Confirmed controls with 0 live instances | **95** (design-only) |
| Score 5–6 / 7–10 confirmed | 43% / 79% |
| Disputes | THEMATIC 3,677 (neighbouring requirement), WRONG_SCOPE 308 |
| Judge reliability | planted wrong links caught 100%; possible misses 2/300 |
| Cost | LLM $33.2 + judge $7.7 ≈ **$41** |

**Per route** (precision / found alone / yield = confirmed per candidate): **C3 GPPS 60% / 2,510 alone @ 61% (≈ 29% of all confirmed links come only via GPPS) / 11%**; C4 same alert 60% / – / 19%; B4 60% / – / 11%; C1 RegMap summary → control 55% / 22 / 4.9%; B2 summary → risk 55% / 272 / 4.5%; B1 RegMap obligation → risk 52% / 5 / 10%; B3 taxonomy 50% / 0 / 10%.
- No route is precise alone → judge always needed. Tiers by route count were a poor signal (T2 48%).
- **Scaling lever:** dropping pairs found only by summary-level routes (B2 / C1) halves the calls for ≈ 2–5% of confirmed links lost. Kept for the US full run.

**Files** (`OUT_DIR/phase3b/`): `l1c_candidates.parquet`, `instance_pool.parquet`, `l1c_results.parquet` (+ ckpt), `l1c_audit_labelled.parquet` (+ ckpt), `l1c_results.xlsx`, `l1c_precision_per_route.xlsx`. Notebooks: `PHASE3B_NB1_control_candidates.txt`, `PHASE3B_NB2_control_llm_level1.txt` (standalone; NB2 CELL 6c rebuilds results from the checkpoint after a disconnect). Snapshot of all outputs: `../output/ontology_graph_snapshot_2026-10-29_1818`.

**Done 30 Oct 00:00 (notebook "3. Ontology build part 2 v3" = PHASE3B_NB3):** level 1 loaded into the graph as `satisfiedByControl`, layer AI_STRUCTURE (102,114 edges with decision, coverage, score, routes, judge verdict, `structure_confirmed`); pre-load checks all 0; backup `edges_before_satisfiedByControl.parquet`; graph now 628,659 edges. Snapshot `ontology_graph_snapshot_2026-10-29_1818` was taken BEFORE this load.

**Level 2 (obligation → live control instance), run overnight 29→30 Oct (PHASE3B_NB3):**
- Candidates: live instances of the 5,327 confirmed controls → 66,842 pairs; RegMap ext5 'N' dropped 17,938 → **48,904 judged** (RegMap 'Y' 1,397; no RegMap row 47,507 → ext5 covers few pairs). 7,676 calls.
- LLM: 13,866 LINKED (28%; the 5-batch test's 2% was not representative), 19 ERROR, 164 insufficient evidence. $17.45.
- Judge: **7,908 CONFIRMED (57.0%, CI 56–58)**; disputes THEMATIC 4,777 (instance runs a different sub-activity of the standard), WRONG_SCOPE 546, UNSUPPORTED 340; score 5–6 → 40%, 7–10 → 77%; RegMap 'Y' 63% vs no row 57%; possible misses 1/300; planted wrong links caught 97%. $10.76.
- Confirmed: **761 obligations, 1,096 live instances, via 180 library controls.**
- Loaded as `satisfiedByControlInstance` (AI_STRUCTURE; 48,904 edges with decision, coverage, judge verdict, `structure_confirmed`, via_library_control, regmap_applicable, business, legal_entity); pre-load checks 0; backup `edges_before_satisfiedByControlInstance.parquet`; **graph 677,563 edges**.
- Phase 3b total cost ≈ **$69** (level 1 $41, level 2 $28).

**Control gap findings (PHASE3B_NB4 / pipeline 10; `phase3b/control_gap_findings.xlsx`)** - judge-confirmed links only; gap counts on **PUBLISHED** obligations (3,180 of 3,352; the rest cancelled / draft / retired):

| Category | Meaning | Live obligations | Alert-linked (825, all live) |
|---|---|---|---|
| NO_CONTROL | no confirmed control standard | 1,660 (52%) | 376 (46%) |
| DESIGN_ONLY | standard confirmed, none with a live US instance | 68 (2%) | 18 (2%) |
| NOT_OPERATED | standards with live instances, none confirmed to perform it | 726 (23%) | 206 (25%) |
| PARTIAL_ONLY | 1 confirmed live instance, PARTIAL coverage only | 220 (7%) | 60 (7%) |
| COVERED | confirmed live instance with FULL somewhere, or >= 2 instances | 506 (16%) | 165 (20%) |

- 95 confirmed control standards have **no live US instance** (726 obligation links rely on them); **96 of 123 alerts** with judge-agreed obligations hit at least one gap (sheet "alerts hitting gaps" = review start list); 1,629 NO_CONTROL obligations have a closest rejected candidate as an SME hint, 155 had no candidate route at all.
- **Caveats (present as an upper bound, for SME validation):** US-only Helios extract and library subset; judge strictness (≈ 9,700 disputed links across both levels); obligations that need no control; 155 obligations unreachable by any route (mapping gap, not a judgement).

**Checked 30 Oct:** all 1,338 judge-confirmed Helios Run B alert → instance impacts are on **Assessed (live)** instances (0 on retired / cancelled); flag written on the edges (`instance_status`, `instance_live`; backup `edges_before_instance_status_flag.parquet`).

**Next:** (1) ~~live-status flag on Run B instance links~~ done; (2) demo export: pick alerts, ideally one from "alerts hitting gaps" so the demo shows alert → obligation → policy / procedure → control standard → live control and a gap; (3) ontology model update + standards alignment (OWL / SHACL / SKOS / PROV-O / FIBO; see below); (4) SME pack when the business is ready (27 confirmed CHANGE_REQUIRED, gap sheets); (5) final clean-pipeline end-to-end run.

**Third-party risk demo story (30 Oct):** RS TPRM regulation RGL-00011917 (1 summary, 13 obligations: 11 COVERED, 1 PARTIAL_ONLY, 1 NO_CONTROL) and POL-47 Global Third Party Risk Policy (11 implementing procedures, 5 GPPS-mapped controls). The 5 control standards judge-confirmed for the TPRM obligations are **exactly POL-47's 5 GPPS controls** (68 live instances): RegMap and GPPS converge independently. Alert: **ALERT-120727** SEC Reg S-P (service-provider oversight) → POL-47 confirmed impact (score 7, REVIEW_REQUIRED) on S5 Third Party Agreements (L1C-00000767) and S6 Third Party Monitoring (L1C-00000769). **Known gap:** the old obligation → policy run (v2) proposed POL-47 as a candidate for only 1 of the 13 obligations (taxonomy-based candidate step); 12 were never judged. **Stopgap:** 12 `implementedByPolicyViaControl` edges (layer DERIVED, decision DERIVED, no LLM): obligation → its judge-confirmed control → the same control mapped in GPPS to POL-47; covers the full lifecycle (risk assessment L1C-766, agreements L1C-767, monitoring L1C-769, exit management L1C-770, + L1C-1206); backup `edges_before_derived_via_control.parquet`; graph 677,575 edges. Proper fix later: judge the missing pairs with the v2 judge (~45 min) and count obligations with no policy candidate at all.

**Demo set (agreed 30 Oct):** the original 4 alerts (133999 hero, 119934 fan-out, 125919 many-to-many, 159982 gap), now with their policy / procedure / control layers, **+ the third-party story** above as an add-on. Shortlist alternatives (demo_shortlist.xlsx): 151294 Oklahoma breach notification, 114648 California annuity best interest (3 CHANGE_REQUIRED), 121567 Florida financial exploitation (7 gaps), 85162 CFTC swaps UPI.

**Standards alignment (discussed 30 Oct, not built):** keep the property graph for work; publish the model as OWL/Turtle with HSBC IRIs; alignment file mapping our classes to FIBO (legal entity, regulator, regulation), the risk taxonomy to SKOS, Link Assertions to PROV-O (generated by model run, checked by judge, reviewed by SME); governance rules as SHACL shapes; later LegalRuleML / LKIF for obligation modality (phase 4), ELI / Akoma Ntoso for provisions and lineage, LEI / ISO 3166-2 for keys; query via ISO GQL / openCypher, or SPARQL after an RDF export.

---

## 10e. Phase 3c: obligation → policy / procedure via a confirmed control (30 Oct 2026)

**Why.** In the TPRM story, the original obligation → policy run (taxonomy-based candidates, then text search) had proposed POL-47 for only 1 of the 13 TPRM obligations. Yet the control structure made the link obvious:
- each obligation is satisfied by a judge-confirmed control standard;
- GPPS maps those same controls to POL-47.

**Scope (notebook 11, $0).** There are 45,943 implied (obligation, document) pairs.

| | ALREADY_LINKED | PREV_REJECTED | NEW | All |
|---|---|---|---|---|
| Policy | 3,436 | 2,623 | 2,276 | 8,335 |
| Procedure | 4,438 | 8,834 | 24,336 | 37,608 |

- **Prior precision:** where the original run had already judged these pairs, 57% of policy pairs were linked but only 33% of procedure pairs. So the structure is a hint, not proof, and every pair is checked by the LLM + judge.
- **Run set:** all 2,276 NEW policy pairs, plus 5,139 NEW procedure pairs for the 260 obligations with no linked procedure (gap-fill). The other ~19k procedure pairs were not run, because they only add procedures to obligations that already have one.

**Method (notebook 12).** A new house-style prompt; the original v2 linking prompt wasn't recoverable.
- **Input:** the full obligation text, the full visible GPPS text by section, and the confirmed control as a hint only. Guard 2(b) says a shared control alone is not a link.
- **Fields:** coverage (FULL / PARTIAL), sections and quotes.
- **LINKED rule:** the same as every level (model LINKED, score ≥ 5, both quotes verified).
- **Judge:** an independent judge, with all LINKED pairs, 200 rejected pairs and 30 planted wrong links per type. A new error type, FALSE_LINK_CONTROL_ONLY, covers links that rest only on the shared control.

**Calibration.** 100 already-decided pairs per type were re-judged with the new prompt.
- **Agreement with the original run:** 78% for policies, 79% for procedures.
- **Direction:** where they differ, the new prompt is mostly stricter (14–15 pairs the original run linked are now NOT_LINKED, against 6–8 the other way).

**Results**

| | Model LINKED | Judge-confirmed | 95% CI |
|---|---|---|---|
| Policy | 449 | **243** (54%) | 49–59% |
| Procedure | 542 | **294** (54%) | 50–58% |

- **Judge reliability:** 100% of planted wrong links caught; possible misses 2 of 400.
- **Disputed links, by cause:** thematic 273, wrong scope 142, shared-control-only 33, unsupported 2.
- **Gain:** 32 obligations get their first confirmed policy; 70 of the 260 gap obligations get a confirmed procedure.
- **TPRM:** 11 of the 12 rule-only links ROB → POL-47 are confirmed. ROB-00021828 was disputed.
- **Cost:** $14.6 (linking $12.2, judge $2.5).

**Loaded:** 7,415 edges as `implementedByPolicy` / `governsActivity`, with `run_id ONTO-US-2026-10-VIA-CONTROL` and `tier VIA_CONTROL`. `structure_confirmed` is set for LINKED + judge AGREE. Backup: `edges_before_via_control.parquet`. The graph now has **684,990 edges**. Outputs are in `phase3c/`: `vc_results.xlsx`, `vc_audit_labelled.parquet`.

**Open (optional).** The remaining ~19k NEW procedure pairs on obligations that already have a procedure would cost about $35. Run them only if the business wants complete procedure coverage.

---

## 10f. Demo explorer v2.5 (30 Oct 2026)

**Stories.**
- **The 4 original alerts:** 133999 (hero), 119934 (fan-out), 125919 (many-to-many), 159982 (gap).
- **The third-party story:** ALERT-120727, SEC Reg S-P. It brings in RGL-00011917, RS TPRM, with its 13 obligations, and POL-47 with its 11 procedures and 5 controls.
- **The third-party alert shows only part of its links:** judge-agreed and never-judged impacts. Disputed ones are hidden. Its summary level was never judged, so those links show as "not judged".

**Exporter: `13_demo_export.txt`** ($0). Each story is built on its own: no leakage between alerts.
- **Chains are always complete:** regulation → summary → obligation → policy / procedure / control standard → live instance (top 8 per obligation) → gap.
- **Parents that aren't impacted** show as dashed "in chain" boxes, reached by a grey "leads to" line.
- **Story membership** is written to `meta.stories`.
- **The cell checks itself:** every record must be reachable from its alert, and the TPRM count must be 13 | 13.
- **It also writes `demo_story_review.xlsx`:** every record and link per story, with full text.

**HTML: `RegCompliance_Ontology_v2_5.html`** (sent as 3 `.txt` parts; join them as bytes with `glob`).
- **New relationships:** alert → policy / procedure (CHANGE REQUIRED badge, change needed); satisfied by / operated by; implemented by (via control); procedure, maps control; gap boxes.
- **Labels:** colour-coded pills drawn on top of the boxes, visible in Show all.
- **Selection:** bold borders on the selected box and its neighbours.
- **Size:** bigger boxes, 16 px text.
- **Step-by-step:** only the alerts show at the start.
- **"Save as standalone HTML"** embeds the loaded data in one file (about 1.2 MB) for sharing. That file contains the record texts and the AI evidence, so share it with care.

---

## 11. Code: the clean pipeline (project folder `claude/ontology_pipeline/`)

| File | Role |
|---|---|
| `README.md` | run order, lineage table (reads / writes per notebook), how to run for another country, method decisions |
| `pipeline_config.py` | **only file to edit**: COUNTRY, RUN_ID, OUT_DIR, all SOURCES, build options, COLS, phase 3 / LLM / audit settings |
| `ia_lib.py` | shared helpers (readers, GPPS visible-section parser, payload builder, quote check, Wilson CI) |
| `01_ontology_build.txt` | build v3 + CELL 7b taxonomy map (phases 1 + 2) |
| `02_taxonomy_alignment.txt` | single-system risk-type names → `taxonomy_alignment.xlsx` |
| `03_impact_candidates.txt` | obligation-route + fallback candidates, cost |
| `04_impact_llm.txt` | final v1 prompts, truncation proof, 10-pair test, checkpointed run |
| `05_impact_audit.txt` | independent judge, labels, precision |
| `06_load_impacts.txt` | pre-load checks, load into the graph |
| `07_control_candidates.txt` | phase 3b: control status, obligation → library control candidates (7 routes), cost |
| `08_control_llm_level1.txt` | phase 3b level 1: LLM + judge, precision per route, recovery cell 6c, scaling-lever cell 11 |
| `09_control_load_and_instances.txt` | load level 1 into the graph; level 2 instances LLM + judge (unattended, cost + test gates); CELL 11 loads level 2 |
| `10_control_gap_findings.txt` | gap categories per live obligation, alerts hitting gaps, closest-candidate hints |
| `11_policy_via_control_scope.txt` | phase 3c: implied (obligation, document) pairs via a confirmed control + GPPS mapping; ALREADY_LINKED / PREV_REJECTED / NEW |
| `12_policy_via_control_llm.txt` | phase 3c: LLM + judge on the NEW pairs, calibration, load (self-contained; cost + test gates) |
| `13_demo_export.txt` | demo stories → explorer JSON parts + `demo_story_review.xlsx` |
| `diagnostics/` | `diag_id_joins.txt` (ID-join diagnosis), `ARCHIVED_procedure_prompt_v2_rejected.txt` |

Run order: 01 → 02 → 01 (again, applies the map) → 03 → 04 → 05 → 06, and 07 → 08 → 09 → 10 (control structure; independent of 03–06), then 11 → 12 (needs 09), then 13 (demo, optional). `01` now includes the Helios verdict fix. Phase 3b settings are in `pipeline_config.py` section 4 (live statuses, scope, tiers, batch size, cost cap). The standalone versions actually run on 29–30 Oct are in `claude/phase3b/` (PHASE3B_NB1–NB4). Each notebook reads only files from the previous step; 04 / 05 need the gateway cells pasted as CELL 0. Every file is < 95 KB (git-safe); the zip `pipeline_US_2026-10.zip` is 115 KB, so use the individual files for git. 03–06 mock-tested end to end; 01 / 02 are the code that ran on the real data with only the config import changed.

---

## 12. Utility: merge split JSON parts (used for the demo data)

```python
# Merge ontology_demo_data.json.part01..NN into one valid JSON (NaN -> null)
import glob, json, math, os
PARTS_DIR = r"C:\path\to\git_parts_demo"
OUT_FILE  = r"C:\path\to\ontology_demo_data.json"
PATTERN   = "ontology_demo_data.json.part*"

def clean(v):
    if isinstance(v, float) and (math.isnan(v) or math.isinf(v)): return None
    if isinstance(v, dict): return {k: clean(x) for k, x in v.items()}
    if isinstance(v, list): return [clean(x) for x in v]
    return v

parts = sorted(glob.glob(os.path.join(PARTS_DIR, PATTERN)))
assert parts, "no parts found"
text = "".join(open(p, encoding="utf-8", newline="").read() for p in parts)
data = clean(json.loads(text))
json.dump(data, open(OUT_FILE, "w", encoding="utf-8"), ensure_ascii=False, allow_nan=False)
print("MERGED OK", len(data["nodes"]), "nodes", len(data["edges"]), "edges")
```

---

## 13. Session history (for context)

1. Confirmed access to the Ontology and IA chats. Goal: ontology v2.2 demo with **real US data** in one day, no graph DB.
2. **Step 1** (find showcase alerts): 727 ROBs linked from alerts also link to a policy, 507 to a procedure, 500 to both; 140 alerts in both RegMap and Helios chains; 89 alerts cover all 8 layers. Picked 133999, 119934, 125919, 159982.
3. **Step 3** (extract demo sample): 143 nodes, 288 edges, 12 gaps.
4. JSON split into 95 KB parts for git; HTML transfer stripped scripts → send as `.txt`; NaN in JSON fixed in the loader.
5. Built on Wrik's existing RegCompliance explorer: v2.3 add-on (Live data, step-by-step reveal, evidence panel, ontology relationship labels, structure vs impact layers).
6. v2.4: intake standardisation + contextualisation in the model and live data; journey strip and talk track.
7. Clarified: LR vs taxonomy; Helios file layout; GPPS three parquets; RegMap 7 extracts; IA output files per level; ROB→policy/procedure = structure, not alert impact.
8. Drafted a management Teams message (scaling to 60 countries) and the exhaustive linkage list.
9. Step 0 inspection of all 25 sources; wrote and mock-tested `ontology_build_v1`.
10. **29 Oct (IA project chat):** code restructured; v1 run → CELL 9 join diagnosis → v2 (three ID fixes, hidden segments, section view, REG/PLCY objRel) → CELL 10 (RISK objRel has no ID; RSM and procedure counts corrected) → **v3 clean** (section 10b).
11. **29 Oct (afternoon/evening):** taxonomy alignment (v1 → v2 check, 17 names merged) → phase 3 candidates and cost → prompts re-aligned with the house structure / schema → 10-pair test → full run → judge audit → procedure disputes diagnosed → prompt v2 / v2.1 rejected at A/B gate → find + confirm adopted → impacts loaded → fallback → clean pipeline packaged (section 10c, 11). SME review deferred by the business.
