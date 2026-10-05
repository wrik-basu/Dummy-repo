# GPPS Policy and Procedure Data: Structure, Quality and Usage Guide

| | |
|---|---|
| **Owner** | Impact Assessment – Analytics (Regulatory Compliance Technology) |
| **Audience** | Data / ML engineers, analysts and model-risk reviewers working with GPPS extracts |
| **Data snapshot** | Policy tables (version history to Sep 2026); procedure table `global_procedure_26_SEP` (snapshots Sep 2025 – Sep 2026) |
| **Status** | Living document. Findings come from systematic profiling of the extracts; items marked *(interpretation)* need confirmation by the GPPS product team |

> **Purpose.** GPPS (Global Policy & Procedure System) holds HSBC's internal policies and procedures. This page documents how the GPPS data we receive is structured, what it contains, its known quality issues, and the rules we use to parse it, so anyone using it gets consistent, correct results without rediscovering the same issues.

---

## 1. At a glance

| | Policies | Procedures |
|---|---|---|
| Source tables | `us_hsbc_gpps_gpps_policy` (US local) + `aa_hsbc_gpps_gpps_policies` (global) | `global_procedure_26_SEP` (single global table) |
| Version rows | 684 (64 US + 620 global) | 2,169 |
| Distinct documents (latest version) | 284 | 1,180 |
| **Published, latest version** | **282** (26 US + 256 global) | **1,097** |
| Status field (JSON) | `versn.versStatCde` | `versn.procVersnStatCde` |
| Content location | `policyApplication.segment[]` + `policyText`, `policyPurpose` | `procedureApplication.segment[]` + `procedureText` |
| Median text length | 26,738 characters | 10,760 characters |
| Risk taxonomy depth | L1 always; L2 rarely (34 of 282); **L3 never** | L1+L2+L3 for 75% (detailed level comes **only** from linked controls/risks) |
| Links to controls | 12,378 (159 policies) | 9,109 (817 procedures) |
| Links to policies | 160 (policy → policy) | 2,080 (305 procedures → 110 policies) |
| Links to regulations | 913 | – |
| Links back to procedures | **none** | – |
| Geography | US local / global by table | All recorded as **GLOBAL** |
| JSON fields shared between the two | 14 of ~220 | |

**Key message: policies and procedures are structurally different documents.** Logic written for one must not be assumed to work for the other.

---

## 2. Source tables

### 2.1 Policy tables

| Column | Type | Notes |
|---|---|---|
| `policy_core_id` | int | Policy ID; equals `plcyCoreId` in the JSON |
| `version_num` | int | Version number |
| `json_data` | string (JSON) | The full policy document |

- Two tables: **US local** and **global**; published: 26 US + 256 global. No policy ID appears in both.
- 284 distinct policies have a latest version; **282 are published**. The other 2 have a non-published latest version (draft or in retirement).

### 2.2 Procedure table

| Column | Type | Notes |
|---|---|---|
| `procedure_core_id` | int64 | Procedure ID; equals `procCoreId` in the JSON (100%) |
| `version_num` | int64 | Version number |
| `snapshot_time` | datetime (UTC) | When the row was captured. Sep 2025 → Sep 2026; 2,167 distinct values |
| `transfer_date` | string | Load date; 183 distinct days |
| `json_data` | string (JSON) | The full procedure document; parses 100% |

- 2,169 rows → **1,180 procedures**. Versions per procedure: mean 1.84, max 16; 56% have one version. No duplicate (procedure, version) rows.
- The table is a **snapshot history**: each version was captured when loaded.
- Latest snapshot per procedure: **1,116 in Q3 2026**, 63 in Q2 2026, 1 in Q4 2025. Of the 64 not refreshed since Q2, only **1 is published**. Staleness corresponds to retirement.
- The highest `version_num` is also the latest snapshot for **99%** of procedures (≈12 exceptions).

### 2.3 Reading the tables

BigQuery-exported parquet files can fail with `data type 'dbdate' not understood`. Read them through pyarrow:

```python
import pyarrow.parquet as pq
df = pq.read_table(path).replace_schema_metadata(None).to_pandas(date_as_object=True)
```

When reading Excel exports, use `dtype=object` so numeric-looking IDs stay as text.

---

## 3. Selecting the current documents

| Rule | Policies | Procedures |
|---|---|---|
| Latest version | Highest `version_num` | **Latest `snapshot_time`** (tie-break: `version_num`) |
| Published only | `versn.versStatCde == "PUBL"` | `versn.procVersnStatCde == "PUBL"` |
| Result | 282 | 1,097 |

### 3.1 Procedure status values

| Code | Count | Meaning *(interpretation)* |
|---|---|---|
| `PUBL` | 1,097 | Published, live |
| `DEM` | 66 | Demised (decommissioned) |
| `RDYDEM` | 5 | Ready for decommissioning |
| `STGDEM` | 4 | Staged for decommissioning |
| `DRFT` | 4 | Draft |
| `STGPUBL` | 3 | Staged for publication |
| `RDYPUBL` | 1 | Ready for publication |

> **Do not use the decommission date to find retired procedures.** `actlDemDt` (actual decommission date) is filled for only **13** of the 75 decommissioned or decommissioning procedures. The status is the reliable field. `trgtDemDt` (target date, 22) and `demCmnt` (comment, 22) hold planned decommissioning and its reason (e.g. *"replaced with…"*, *"approved for decommissioning"*).

---

## 4. Policy JSON structure

### 4.1 Main fields

| Path | Content |
|---|---|
| `plcyCoreId` | Policy ID |
| `policyTitle` | Title |
| `policyRiskTypePrimary` | Primary risk area (L1) |
| `policyApplication.riskTxnmyL2Text` | Sub-area (L2), rarely filled |
| `policyApplication.multiRiskDetls[]` | Additional risk areas (`risk` = L1; `riskTxnmyL2Text`, `riskTxnmyL3Text`) |
| `versn.versNum`, `versn.versStatCde` | Version and status (`PUBL` = published) |
| `policyText` | Policy statement (`sgmntTitlText`, `sgmntText`) |
| `policyPurpose` | Risk lineage / purpose section |
| `policyApplication.segment[]` | **Main content**: `sgmntTitlText`, `sgmntText` (HTML), `sgmntTypeCde`, `objRel[]` |
| `policyApplication.segment[].sgmntTypeCde` | Holds the **section ID** (`NHSGMNT…`), which procedures use to reference a policy section |
| `policyApplication.segment[].objRel[]` | Links from the section: `cntlId`, `plcyObjTypeCde` (`CNTRL`, `REG`, `PLCY`) |
| `policyApplication.termDefin[]` | Definitions |
| `policyApplication.guidance[]`, `.appendix[]` | Attached documents (metadata only, no text) |
| `policyUniqueDocRef`, `policyParentDocRef` | FIM-style references (e.g. `UKWEDRDK8T14411717022026`) |

### 4.2 Policy links (`objRel`)

| `plcyObjTypeCde` | Links | Meaning |
|---|---|---|
| `CNTRL` | 12,378 | Library controls (L1C) governed by the section |
| `REG` | 913 | Regulations *(potential policy → regulation evidence; not yet exploited)* |
| `PLCY` | 160 | Other policies |

159 of 282 published policies have at least one control link. **Policies do not link to procedures.**

---

## 5. Procedure JSON structure

**113 distinct key paths. No field changes type (dict vs list), and no field appears or disappears across versions.** The "non-uniform procedure JSON" seen in earlier extracts does not occur in this table.

### 5.1 Identity and metadata

| Path | Content / values |
|---|---|
| `procCoreId` | Procedure ID |
| `procedureTitle` | Title; **missing on 69** procedures |
| `procedureDocType` | `GLOBAL` 1,049 · `XPROC` 108 · `COMBPROC` 23 *(global, cross-business, combined procedure)* |
| `glblBusFuncCde` | Business function; 26 values (MSS 175, GTRF 161, FINANCE 101, ASSET_MGMT 99, WHOLESALE 84, GCIO 84, GCOO 82, WPB 67…) |
| `impctBusFunc[]` | Impacted business functions (131 procedures) |
| `procedurePublisher` | `GPPS` 896, or an employee ID |
| `procedureUniqueDocRef` | Procedure's own FIM reference (1,077) |
| `procedureParentDocRef` | Parent document reference (517; see 5.6) |
| `objLink`, `gmsLink` | URLs to the procedure's own GPPS and FIM pages |
| `procedureApplication.grco[]` | `procOwnrEmplyId` (owner), `taskDecsnByEmplyId` (decision-maker) |
| `procedureApplication.procAuthrEmplyId` | Author |
| `procedureCreatReasonCde` | Creation reason (20 codes; `ADMINCHG` 644, `OTHER` 194…) |
| `dmaScope`, `isEdit`, `procedureSignificantChange`, `procedureSortKey` | Flags and sort keys; no analytical use found |

### 5.2 Version block (`versn`)

| Field | Content |
|---|---|
| `procVersnStatCde` | **Status** (section 3.1) |
| `versnNum` | Version number |
| `procVersnTypeCde` | `EDT` (edit) / `NEW` |
| `procVersnChngTypeCde` | `ADMINCHG`, `NMTRL` (non-material), `MTRL` (material), `NEW` |
| `procVersnActlPubDt` | Actual publication date (empty for the 81 not yet or no longer published) |
| `procVersnTrgtPubDt`, `procVersnExpctPubDt`, `actvDt` | Target / expected publication and activation dates |
| `procPrpsdImplPrdText` | Implementation period (e.g. *"0 months from publication"*) |
| `procVersnChngTypeJustText` | Justification for the change type |

### 5.3 Geography

| Path | Finding |
|---|---|
| `region` | **GLOBAL** for all 1,180 |
| `country[].procImpctCtryCde` | **GLOBAL** for all 1,180 |
| `country[].procLglEntyCde` | Legal entity code |
| `procedureApplication.apblCtry[]` | Applicable countries (`ctryCde`, `ctryName`, `apblEnty[]`, `prmblVrtnsText` = permissible variations). On 265 procedures but **mostly empty**; only **8 mention the US** |

> **Procedures cannot be filtered by country.** Every procedure is recorded as global.

### 5.4 Content

| Path | Content |
|---|---|
| `procedureText` | Procedure statement (`sgmntTitlText`, `sgmntText`), on all procedures |
| `procedureApplication.segment[]` | **Main content**: `procSgmntTitlText`, `procSgmntText` (HTML), `procSgmntTypeCde`, `procSortOrdrNum`, `procDispSortOrdrNum`, `langCde`, `procSgmntReasonText`, `objRel[]` |
| `procedureApplication.termDefin[]` | Definitions (`termDefinText`), 475 procedures |
| `procedureApplication.appendix[]`, `.guidance[]` | Attached documents: `docId`, `docName`, `docTitlText`, `docDesc`, `docUrl`, `docGmsUrl`, `actvFlg`; **no document text** (287 / 104 procedures) |

**Section type codes (`procSgmntTypeCde`)** *(interpretation)*:

| Code | Occurrences | Likely meaning |
|---|---|---|
| `STMT` | 1,180 | Procedure statement |
| `WTAT` | 1,180 | "Who this applies to" (scope) |
| `QMC` | 1,112 | Query management contact |
| `KPR-n` | many | Key procedural requirements (numbered) |

**Text characteristics:**
- Length: median **10,760** characters; 90th percentile 38,376; max 167,473. **79%** exceed 4,000 characters.
- **HTML markup** in all procedures; strip before use.
- **Duplicated text in 1,175 procedures:** the procedure statement appears both in `procedureText` and as a segment. De-duplicate.
- Empty sections in 75 procedures.

**Standard sections:**

| Section | Count | Content | Recommended treatment |
|---|---|---|---|
| "Who this applies to" | 1,180 | Procedure-specific scope (724 distinct; median 92 characters, e.g. *"applicable to MSS Sales and Trading"*) | **Keep and use as scope**; valuable for judging relevance |
| "Query management contact" | 1,112 | A contact line (median 40 characters, e.g. a team mailbox) | **Exclude**; no content |

### 5.5 Links (`procedureApplication.segment[].objRel[]`): the richest part of the data

12,943 links in total:

| `objTypeCde` | Links | Procedures | Fields |
|---|---|---|---|
| `CNTRL` | 9,109 | 817 (69%) | `cntlId` (L1C), `cntlTitl`, `cntlDesc` (long text, 804 procedures), **`riskTxnmyL1/L2/L3Text` (100% / 99% / 97% filled)**, `thirdPartyApplicability`, `mtrlUpdtInd` |
| `PLCY` | 2,080 | 305 (293 published) | **`objId` = policy ID (100% valid; 110 policies)**, `cntlId` = target within the policy, `docType`, `mcrName`, taxonomy (L1) |
| `RISK` | 1,754 | 567 | `riskTxnmyL1/L2/L3Text` (L2 66%, L3 47%) |

**Policy links point to specific parts of a policy:**

| `cntlId` on a PLCY link | Links | Resolution |
|---|---|---|
| A **policy section ID** (`NHSGMNT…`) | 730 | Matches a policy segment's `sgmntTypeCde` **96%** of the time |
| A **library control** (`L1C-…`) | 1,317 | Traceable to the policy section that lists that control in its `objRel` |
| Other | 33 | – |

**Controls:** 744 procedures carry L1C IDs, covering **348 distinct controls**. **271 (78%)** also appear in RegMap's regulation-summary control mappings (Extract 3), covering 82% of RegMap's 329 controls.

> **Widely-shared controls.** Some controls are linked from very many procedures (e.g. `L1C-00000951` *Financial Crime Unusual Activity Reports* from 283). Treat such controls as weak evidence of any specific relationship.

### 5.6 Parent reference (`procedureParentDocRef`)

- On 517 procedures; **157 distinct parents**, up to 20 children each.
- Same FIM reference format as policies, but **it is not a policy link**: 0 matches against any policy reference in any version, against policies' own parent references, or on reference prefixes. 7 match other procedures.
- The parents are documents outside the policy/procedure extracts *(interpretation: legacy FIM manuals or standards)*.

> **Use `objRel` (`objTypeCde = PLCY`, `objId`) for procedure → policy relationships, not `procedureParentDocRef`.**

### 5.7 Risk taxonomy

| Source | Content |
|---|---|
| `procedureRiskType[]` | The procedure's own tags: `riskTxnmyL1Text`, `riskTxnmyL2Text`. **No L3.** Empty on 195 procedures; contains repeated entries (median **1** distinct entry after de-duplication; 90th percentile 4; max 16) |
| `prmryRiskType` | Primary risk area (string), empty on 193 |
| `objRel[]` (CNTRL, RISK) | Full L1/L2/L3 from linked controls and risks: **the only source of L3** |

**Depth, all sources combined (latest versions):** L1+L2+L3 **881** · L1+L2 73 · L1 only 120 · none 106. 306 procedures span more than one main risk area.

**Published procedures without taxonomy:** 108 lack their own; control/risk links fill 16; **92 have none from any source.**

**Match against RegMap's taxonomy names (Extract 2):**

| Level | Match | Cause of mismatches |
|---|---|---|
| L1 | ~100% | 4 odd values (`Enterprise Risk`, `Model Risk L1`, `Transaction Processing Risk`) |
| L2 | 94% | Different taxonomy version (e.g. `Failure to Manage Third Parties` vs RegMap `Third Party Risk`; `People Management`, `Pension Risk`, `Structural Foreign Exchange Risk`) |
| L3 | **74%** | RegMap names prefixed **"(TO BE RETIRED)"** for the same concept, plus genuine version differences (e.g. *"Failure to deter, detect and protect against money laundering…"*) |

> **Do not use similarity scores to map taxonomy names.** *"Lending Fraud (3rd Party)"* scores 0.92 against *"Lending Fraud (1st Party)"*, a different risk. Normalise (strip "(TO BE RETIRED)", treat "&" as "and"), then match exactly. Where a level still doesn't match, fall back to the level above.

---

## 6. Data quality summary

| # | Issue | Scope | Impact | Handling |
|---|---|---|---|---|
| 1 | Policy L3 taxonomy not in the extract (though shown in the GPPS UI, e.g. policy 54 *Market Abuse*) | All 282 policies | Exact taxonomy matching impossible for policies | **Escalate**; match at L1/L2 |
| 2 | Policy L2 mostly missing | 246 of 256 global policies | Matching broader than the business view | **Escalate** |
| 3 | Duplicated statement text | Policies; 1,175 procedures | Repeated content | De-duplicate |
| 4 | HTML markup | All documents | Noise in text | Strip HTML |
| 5 | Attachments (guidance, appendix) have no text | 287 / 104 procedures; policies too | Content not analysable | Note as limitation |
| 6 | Decommission dates sparse | 13 of 75 retiring procedures | Date unreliable for retirement | Use status |
| 7 | Procedure titles missing | 69 procedures | Reporting | Fall back to ID / first section |
| 8 | Procedures with no risk taxonomy | 92 published | Can't be matched by risk area | Reach via policy links or text |
| 9 | Procedure ↔ policy link recorded on the procedure side only | 27% of published procedures | Policies can't list their procedures | **Escalate** |
| 10 | Different taxonomy versions between procedures and RegMap | 6% L2, 26% L3 names | Exact matching blocked | Normalise + fall back |
| 11 | Parent references point outside the extracts | 517 procedures | Can't resolve hierarchy | Ignore for linkage |
| 12 | Applicable-country lists mostly empty | 265 procedures | No geographic scoping | Treat all as global |
| 13 | The GPPS UI's policy ↔ regulation-summary linking rule is undocumented (links are computed at display time from taxonomy; not stored in RegMap) | – | Reproduced by inference | **Request documentation** |

---

## 7. Recommended parsing rules

**Both document types**
1. Use the **latest version**: policies by `version_num`; procedures by **`snapshot_time`**.
2. Keep **published** documents only (`PUBL`).
3. Build sections from the document's own structure, **strip HTML**, **drop empty sections**, **remove exact-duplicate text**, and number sections in document order.
4. Never truncate text by position (e.g. "first N characters"). If text must be reduced, select whole sections by relevance and **never cut a section mid-text**.

**Procedures specifically**
5. Treat **"Who this applies to"** as the scope statement; **exclude "Query management contact"**.
6. Add **linked-control titles and descriptions** (`objRel` CNTRL) as an evidence section.
7. Taxonomy = `procedureRiskType` + `prmryRiskType` + control and risk link taxonomy; normalise names; fall back one level on mismatches.
8. Procedure → policy relationships: `objRel` with `objTypeCde = PLCY`; policy ID in `objId`; section-level target in `cntlId` (`NHSGMNT…` → policy segment `sgmntTypeCde`, or `L1C-…` → the policy section listing that control).
9. Down-weight very widely-shared controls as evidence.

> **Normalising titles:** when comparing section titles, don't use a normaliser that drops stop-words. A taxonomy normaliser that removes words like "management" turns "Query management contact" into "query contact" and breaks exact title matching.

---

## 8. Code snippets

**Latest published procedures**
```python
import json, pandas as pd
raw = read_table(PROC_PATH)                                    # see 2.3
raw["ts"] = pd.to_datetime(raw.snapshot_time, utc=True)
latest = raw.sort_values(["ts", "version_num"]).drop_duplicates("procedure_core_id", keep="last")
latest["j"] = latest.json_data.map(json.loads)
latest["status"] = latest.j.map(lambda o: (o.get("versn") or {}).get("procVersnStatCde"))
published = latest[latest.status == "PUBL"]
```

**Procedure links (controls, policies, risks)**
```python
rows = []
for o in published.j:
    for seg in (o.get("procedureApplication") or {}).get("segment") or []:
        for x in seg.get("objRel") or []:
            rows.append({"procedure": o["procCoreId"], "type": x.get("objTypeCde"), "obj_id": x.get("objId"),
                         "target": x.get("cntlId"), "control_title": x.get("cntlTitl"),
                         "L1": x.get("riskTxnmyL1Text"), "L2": x.get("riskTxnmyL2Text"), "L3": x.get("riskTxnmyL3Text")})
links = pd.DataFrame(rows)
proc_to_policy = links[links.type == "PLCY"][["procedure", "obj_id", "target"]]
```

**Policy section IDs (to resolve procedure → policy-section links)**
```python
section_of = {}
for o in policies_json:
    for seg in (o.get("policyApplication") or {}).get("segment") or []:
        sid = seg.get("sgmntTypeCde")
        if isinstance(sid, str) and sid.startswith("NHSGMNT"):
            section_of[sid] = (o["plcyCoreId"], seg.get("sgmntTitlText"))
```

---

## 9. How we use this data

**Obligation → policy linkage (v2).** 3,180 published US obligations were matched to 282 policies through the regulation summary's risk taxonomy (the same hierarchical rule as the GPPS UI) plus the obligation's own taxonomy. An AI judge assessed 127,210 candidate pairs and proposed 17,056 links. An independent audit estimates **77–80% correct**, **92% for high-confidence links**.

**Obligation → procedure linkage (v2).** The rule used for policies would generate ~809,000 candidate pairs for procedures (broad L1/L2 matches; ~250 "blanket" procedures). The procedure design therefore uses:
- a **core** of the **policy route** (obligation → linked policy → procedures implementing it) plus **exact L3 matches**, about 124,600 pairs reaching 96% of obligations;
- **calibration samples** of broader matches, extended only if their measured yield justifies the cost.

**Atlas ontology.** Policy and procedure links feed the Atlas graph as `supports` / `applies to` relationships, with provenance (taxonomy rule vs AI-validated) and status "proposed".

---

## 10. Open questions for the GPPS product team

1. What is the source of the **policy L2/L3 taxonomy** displayed in the UI, and can it be added to the extract?
2. How does the UI link policies to regulation summaries (rule and data source)?
3. Can policies record the **procedures that implement them** (currently only procedures record the link)?
4. What do `procedureParentDocRef` values refer to, and can those documents be provided?
5. Confirm the meaning of the status codes (`DEM`, `RDYDEM`, `STGDEM`, `STGPUBL`, `RDYPUBL`) and section type codes (`STMT`, `WTAT`, `QMC`, `KPR-n`).
6. Which **taxonomy version** do procedures use, and is a mapping to RegMap's version available?
7. Can attachment (guidance / appendix) **text** be included?
8. What do `dmaScope` and `procedureDocType` = `XPROC` / `COMBPROC` mean?

---

## 11. Glossary

| Term | Meaning |
|---|---|
| **GPPS** | Global Policy & Procedure System |
| **RegMap** | Regulatory mapping system: regulations (RGL), regulation summaries (RSM), obligations (ROB) |
| **L1 / L2 / L3** | Risk taxonomy levels: main risk area / sub-area / detailed risk |
| **L1C** | Library control ID (`L1C-xxxxxxxx`) |
| **objRel** | A section's links to other objects (controls, policies, risks, regulations) |
| **FIM reference** | Document reference format `UKWE…<date>` used for unique and parent document IDs |
| **Blanket document** | A document whose taxonomy matches more than half of all regulation summaries |
| **Published (PUBL)** | The live, approved version |

---

## 12. Change log

| Date | Change |
|---|---|
| Oct 2026 | First version: policy and procedure profiling, data quality findings, parsing rules |
