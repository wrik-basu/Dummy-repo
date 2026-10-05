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

Each policy version is one JSON document in `json_data`. Text fields contain **HTML**.

### 4.1 Structure (tree)

```
policy (object)
├── plcyCoreId                      int      policy ID (= table policy_core_id)
├── policyTitle                     string   title
├── policyRiskTypePrimary           string   primary risk area (taxonomy L1)
├── policyUniqueDocRef              string   FIM reference of this document, e.g. UKWEDRDK8T14411717022026
├── policyParentDocRef              string   FIM reference of a parent document (often empty)
├── versn                           object   version block
│   ├── versNum                     int      version number
│   └── versStatCde                 string   status: PUBL = published
├── policyText                      object   policy statement
│   ├── sgmntTitlText               string   e.g. "Policy Statement"
│   └── sgmntText                   string   HTML text
├── policyPurpose                   object   risk lineage / purpose (same shape as policyText)
└── policyApplication               object   the body of the policy
    ├── riskTxnmyL2Text             string   sub-area (taxonomy L2), rarely filled
    ├── multiRiskDetls[]            list     additional risk areas
    │   ├── risk                    string   L1
    │   ├── riskTxnmyL2Text         string   L2
    │   └── riskTxnmyL3Text         string   L3 (empty in all extracts so far)
    ├── segment[]                   list     the policy sections, in order
    │   ├── sgmntTitlText           string   section title, e.g. "Minimum Control Requirements"
    │   ├── sgmntText               string   section text (HTML)
    │   ├── sgmntTypeCde            string   section ID, e.g. NHSGMNT101025163733 (used by procedures to point here)
    │   └── objRel[]                list     links from this section
    │       ├── plcyObjTypeCde      string   CNTRL (control) | REG (regulation) | PLCY (policy)
    │       └── cntlId              string   linked object ID, e.g. L1C-00000769
    ├── termDefin[]                 list     definitions
    ├── guidance[]                  list     attached guidance documents (metadata only, no text)
    └── appendix[]                  list     attached appendices (metadata only, no text)
```

### 4.2 Annotated example (shortened, illustrative values)

```jsonc
{
  "plcyCoreId": 431,                                   // policy ID
  "policyTitle": "US Business Interruption and Incident Risk",
  "policyRiskTypePrimary": "Resilience Risk",          // L1 - the only taxonomy level reliably present
  "policyUniqueDocRef": "UKWED…17022026",              // FIM-style reference (ends with a date)
  "versn": { "versNum": 5, "versStatCde": "PUBL" },    // use PUBL only
  "policyText": {                                      // duplicated as a segment -> de-duplicate
    "sgmntTitlText": "Policy Statement",
    "sgmntText": "<p>The Group must …</p>"
  },
  "policyApplication": {
    "riskTxnmyL2Text": "Business Interruption and Incident Risk",   // L2 - present for only ~34 of 282 policies
    "multiRiskDetls": [ { "risk": "Resilience Risk", "riskTxnmyL2Text": null, "riskTxnmyL3Text": null } ],
    "segment": [
      {
        "sgmntTitlText": "Third Party Service Provider Business Continuity",
        "sgmntText": "<p>Third Party Engagement Managers must perform ongoing monitoring …</p>",
        "sgmntTypeCde": "NHSGMNT…",                    // section ID - procedures reference this
        "objRel": [ { "plcyObjTypeCde": "CNTRL", "cntlId": "L1C-00000769" } ]   // controls governed by this section
      }
    ],
    "termDefin": [ /* definitions */ ],
    "guidance":  [ /* attached files - no text */ ],
    "appendix":  [ /* attached files - no text */ ]
  }
}
```

### 4.3 Field dictionary

| Path | Type | Present | Meaning / notes |
|---|---|---|---|
| `plcyCoreId` | int | all | Policy ID; equals `policy_core_id` |
| `policyTitle` | string | all | Title |
| `policyRiskTypePrimary` | string | all | Primary risk area (L1) |
| `policyUniqueDocRef` | string | most | FIM reference of the document |
| `policyParentDocRef` | string | some | FIM reference of a parent document |
| `versn.versNum` | int | all | Version number |
| `versn.versStatCde` | string | all | Status; `PUBL` = published |
| `policyText.sgmntTitlText` / `.sgmntText` | string | all | Policy statement (also appears as a segment) |
| `policyPurpose.*` | object | most | Risk lineage / purpose |
| `policyApplication.riskTxnmyL2Text` | string | **34 of 282** (24 of 26 US, 10 of 256 global) | Sub-area (L2) |
| `policyApplication.multiRiskDetls[].risk` | string | some | Additional L1 areas (e.g. policy 83 lists 8) |
| `policyApplication.multiRiskDetls[].riskTxnmyL3Text` | string | **0** | L3: never populated in the extract (shown in the GPPS UI) |
| `policyApplication.segment[]` | list | all | Sections in document order |
| `…segment[].sgmntTitlText` | string | all | Section title |
| `…segment[].sgmntText` | string (HTML) | most | Section text; some empty |
| `…segment[].sgmntTypeCde` | string | most | **Section ID** (`NHSGMNT…`); 1,845 found |
| `…segment[].objRel[].plcyObjTypeCde` | string | – | `CNTRL` 12,378 · `REG` 913 · `PLCY` 160 links |
| `…segment[].objRel[].cntlId` | string | – | Linked control / regulation / policy ID |
| `policyApplication.termDefin[]` | list | some | Definitions |
| `policyApplication.guidance[]`, `.appendix[]` | list | some | Attachments (metadata only) |

> **Full inventory.** This dictionary covers the fields used in analysis. The complete list of policy key paths (107 policy-only + 14 shared), with fill rates and types, is produced by the exploration notebook (sheet `04_policy_key_paths` of `procedure_exploration_report.xlsx`). Attach it to this page.

### 4.4 Text facts

- Median **26,738** characters (US 13,553; global 27,770); **97%** exceed 4,000 characters.
- `policyText` is repeated as a segment: **de-duplicate**.
- HTML in text fields: **strip**.

---

## 5. Procedure JSON structure

Each procedure version is one JSON document in `json_data`. **113 distinct key paths. No field changes type (dict vs list) between procedures, and no field appears or disappears across versions.** Text fields contain **HTML**.

### 5.1 Structure (tree)

Counts are from the latest version of each of the 1,180 procedures. "(n)" = number of procedures where the field is filled; for list items, the number of items.

```
procedure (object)
├── procCoreId                         int      procedure ID (= table procedure_core_id)                          (1,180)
├── procedureTitle                     string   title                                                (1,111; 69 missing)
├── procedureDocType                   string   GLOBAL | XPROC | COMBPROC                                        (1,180)
├── region                             string   always "GLOBAL"                                                  (1,180)
├── country[]                          list     impact geography                                                 (1,180)
│   ├── procImpctCtryCde               string   always "GLOBAL"
│   └── procLglEntyCde                 string   legal entity code
├── glblBusFuncCde                     string   business function, 26 values (MSS, GTRF, FINANCE…)               (1,180)
├── impctBusFunc[]                     list     impacted business functions                                        (131)
│   ├── procImpctBusFuncCde            string
│   ├── aprvlReqInd                    string   approval-required flag
│   └── procGbgfOmplyId                string
├── procedurePublisher                 string   "GPPS" or an employee ID                                         (1,180)
├── procedureUniqueDocRef              string   FIM reference of this procedure                                  (1,077)
├── procedureParentDocRef              string   FIM reference of a parent document (NOT a policy)                  (517)
├── procedureSortKey                   int      sort key                                                           (516)
├── objLink                            string   URL of the GPPS page                                             (1,097)
├── gmsLink                            string   URL of the FIM page                                              (1,180)
├── prmryRiskType                      string   primary risk area (L1)                                             (987)
├── procedureRiskType[]                list     own risk tags (L1 + L2, NO L3; repeated entries)                   (985)
│   ├── riskTxnmyL1Text                string
│   └── riskTxnmyL2Text                string
├── procedureCreatReasonCde            string   creation reason, 20 codes                                        (1,176)
├── procedureCreatReasonOthrText       string   free-text reason                                                   (219)
├── procedureSignificantChange         int      always 0                                                         (1,180)
├── dmaScope                           string   Y / N                                                            (1,078)
├── isEdit / isOwnrDisInd              string   flags
├── trgtDemDt / actlDemDt / demCmnt    string   target / actual decommission date, comment                    (22 / 13 / 22)
├── versn                              object   version block                                                    (1,180)
│   ├── procVersnStatCde               string   STATUS: PUBL | DEM | RDYDEM | STGDEM | DRFT | STGPUBL | RDYPUBL
│   ├── versnNum                       int      version number
│   ├── procVersnTypeCde               string   EDT | NEW
│   ├── procVersnChngTypeCde           string   ADMINCHG | NMTRL | MTRL | NEW
│   ├── procVersnChngTypeJustText      string   change justification                                                (56)
│   ├── procPrpsdImplPrdText           string   implementation period, e.g. "0 months from publication"
│   ├── procVersnActlPubDt             string   actual publication date                                          (1,099)
│   ├── procVersnTrgtPubDt             string   target publication date                                          (1,139)
│   ├── procVersnExpctPubDt            string   expected publication date                                        (1,175)
│   ├── procVersnDispNum               -        always empty
│   ├── actvDt                         string   activation date
│   └── creatByEmplyId                 string   creator ("GPPS" or employee ID)
├── procedureText                      object   procedure statement (duplicated as a segment)                    (1,180)
│   ├── sgmntTitlText                  string   "Procedure Statement"
│   └── sgmntText                      string   HTML
└── procedureApplication               object   the body of the procedure                                         (1,180)
    ├── procAuthrEmplyId               string   author                                                           (1,180)
    ├── versExpctPublDt                string   expected publication date                                        (1,175)
    ├── grco[]                         list     governance owners                                     (1,180; 1,266 items)
    │   ├── procOwnrEmplyId            string   procedure owner
    │   └── taskDecsnByEmplyId         string   decision-maker
    ├── apblCtry[]                     list     applicable countries (mostly empty items; US on 8)                 (265)
    │   ├── ctryCde / ctryName         string   e.g. HK / Hong Kong
    │   ├── entyInd                    string
    │   ├── prmblVrtnsText             string   permissible local variations (text)                                 (91)
    │   └── apblEnty[]                 list     legalEntyCde, legalEntyName
    ├── termDefin[]                    list     definitions (termDefinText)                                        (475)
    ├── guidance[]                     list     attached guidance documents (no text)                              (104)
    ├── appendix[]                     list     attached appendices (no text)                                      (287)
    │   └── docId, oldDocId, docName, docNam, gppsDocName, grpsDocName, docTitlText, docDesc,
    │       docUrl, docGmsUrl, docRefNum, actvFlg
    └── segment[]                      list     THE SECTIONS, in order                          (1,180; 8,212 items)
        ├── procSgmntTitlText          string   section title
        ├── procSgmntText              string   section text (HTML)
        ├── procSgmntTypeCde           string   STMT | WTAT | QMC | KPR-n
        ├── procSgmntReasonText        string   reason text                                                         (16)
        ├── procSortOrdrNum            int      order                                                    (4,523 of 8,212)
        ├── procDispSortOrdrNum        string   display order, e.g. "17.1"                               (6,941 of 8,212)
        ├── langCde                    string   language                                                         (8,212)
        ├── tag[]                      list     tags                                                                (12)
        └── objRel[]                   list     LINKS from this section                      (3,412 sections; 12,943 links)
            ├── objTypeCde             string   CNTRL (9,109) | PLCY (2,080) | RISK (1,754)
            ├── objId                  string   CNTRL: control ID | PLCY: POLICY ID (plcyCoreId)
            ├── cntlId                 string   CNTRL: L1C ID | PLCY: target inside the policy (NHSGMNT section ID or L1C)
            ├── cntlTitl               string   control title (CNTRL)
            ├── cntlDesc               string   control description, often long (CNTRL)
            ├── riskTxnmyL1Text        string   L1 (100% of CNTRL/PLCY/RISK links)
            ├── riskTxnmyL2Text        string   L2 (CNTRL 99% · PLCY 29% · RISK 66%)
            ├── riskTxnmyL3Text        string   L3 (CNTRL 97% · PLCY 16% · RISK 47%) - the ONLY source of L3
            ├── docType                string   PLCY: "GLOBAL"
            ├── mcrName                string   PLCY: name of the referenced item (2%)
            ├── thirdPartyApplicability string  CNTRL: e.g. "Internal (Internal Third Party/HSBC Group member)"
            ├── mtrlUpdtInd            string   material-update flag (3%)
            └── sgmntTitlText          string   (rarely filled)
```

### 5.2 Annotated example (shortened, illustrative values)

```jsonc
{
  "procCoreId": 1634,
  "procedureTitle": "Third Party Contract Management",          // missing on 69 procedures
  "procedureDocType": "GLOBAL",                                 // GLOBAL | XPROC | COMBPROC
  "region": "GLOBAL",                                           // always GLOBAL
  "country": [ { "procImpctCtryCde": "GLOBAL", "procLglEntyCde": "…" } ],
  "glblBusFuncCde": "GCOO",                                     // business function
  "prmryRiskType": "Resilience Risk",                           // own L1
  "procedureRiskType": [                                        // own tags: L1 + L2 only; entries may repeat
    { "riskTxnmyL1Text": "Resilience Risk", "riskTxnmyL2Text": "Third Party Risk" },
    { "riskTxnmyL1Text": "Resilience Risk", "riskTxnmyL2Text": "Third Party Risk" }
  ],
  "procedureParentDocRef": "UKWED…24092025",                    // NOT a policy - points outside the extracts
  "versn": {
    "procVersnStatCde": "PUBL",                                 // use PUBL only
    "versnNum": 7, "procVersnTypeCde": "EDT", "procVersnChngTypeCde": "NMTRL",
    "procVersnActlPubDt": "2026-03-02"
  },
  "procedureText": {                                            // duplicated as the first segment -> de-duplicate
    "sgmntTitlText": "Procedure Statement", "sgmntText": "<p>This procedure sets out …</p>"
  },
  "procedureApplication": {
    "grco": [ { "procOwnrEmplyId": "4xxxxxxx", "taskDecsnByEmplyId": "4xxxxxxx" } ],   // owners
    "segment": [
      { "procSgmntTypeCde": "STMT", "procSgmntTitlText": "Procedure Statement", "procSgmntText": "<p>…</p>" },
      { "procSgmntTypeCde": "WTAT", "procSgmntTitlText": "Who this applies to",
        "procSgmntText": "<p>This Mandatory Procedure is applicable to MSS Sales and Trading.</p>" },  // SCOPE - keep
      { "procSgmntTypeCde": "QMC",  "procSgmntTitlText": "Query management contact",
        "procSgmntText": "MSS Governance (mss.governance@…)" },                                        // contact - drop
      { "procSgmntTypeCde": "KPR-3", "procSgmntTitlText": "Key Procedural Requirements",
        "procDispSortOrdrNum": "3.1",
        "procSgmntText": "<p>Third Party Engagement Managers must …</p>",
        "objRel": [
          { "objTypeCde": "CNTRL", "objId": "L1C-00000769", "cntlId": "L1C-00000769",
            "cntlTitl": "Third Party Engagement - Monitoring",
            "cntlDesc": "Objective: A detective control which …",
            "riskTxnmyL1Text": "Resilience Risk", "riskTxnmyL2Text": "Third Party Risk",
            "riskTxnmyL3Text": "Failure to Manage External Third Parties",            // L3 only appears here
            "thirdPartyApplicability": "Both" },
          { "objTypeCde": "PLCY", "objId": "47",                                         // -> policy 47
            "cntlId": "NHSGMNT101025163733",                                             // -> a section of policy 47
            "docType": "GLOBAL", "riskTxnmyL1Text": "Resilience Risk" },
          { "objTypeCde": "RISK", "riskTxnmyL1Text": "Resilience Risk",
            "riskTxnmyL2Text": "Third Party Risk", "riskTxnmyL3Text": null }
        ]
      }
    ],
    "termDefin": [ { "termDefinText": "…" } ],
    "appendix":  [ { "docId": 9649, "docName": "…", "docUrl": "…", "actvFlg": "Y" } ],   // file, no text
    "apblCtry":  [ { "ctryCde": null, "ctryName": null, "prmblVrtnsText": null } ]      // usually empty
  }
}
```

### 5.3 How the links fit together

```
                 RegMap (Extract 3)                         GPPS policies                       GPPS procedures
      regulation summary ──► library control L1C ◄── objRel CNTRL ── policy section ◄── objRel PLCY (cntlId = NHSGMNT… or L1C) ── procedure section
                                     ▲                                    ▲                                                          │
                                     │                                    └──────────── objRel PLCY (objId = policy ID) ─────────────┤
                                     └──────────────────────────────────────────── objRel CNTRL (cntlId = L1C) ──────────────────────┘
```

- **Procedure → policy:** `objRel` with `objTypeCde = PLCY`. `objId` is the policy ID (100% valid). `cntlId` narrows it to a **policy section** (`NHSGMNT…`, matches the policy segment's `sgmntTypeCde` 96% of the time) or to a **control** the policy governs.
- **Procedure → control:** `objRel` with `objTypeCde = CNTRL`. `cntlId` / `objId` is the L1C ID; 78% of procedure controls also appear in RegMap's regulation-summary control mappings.
- **Policy → control / regulation / policy:** `objRel` with `plcyObjTypeCde`.
- **Not linked:** policies never point to procedures, and `procedureParentDocRef` does not point to policies.

### 5.4 Metadata details

| Field | Values and counts |
|---|---|
| `procedureDocType` | `GLOBAL` 1,049 · `XPROC` 108 · `COMBPROC` 23 *(global, cross-business, combined; interpretation)* |
| `glblBusFuncCde` | 26 values: MSS 175 · GTRF 161 · FINANCE 101 · ASSET_MGMT 99 · WHOLESALE 84 · GCIO 84 · GCOO 82 · WPB 67 · CREDIT_AND_CAPITAL_MANAGEMENT 56 · GBL_PVT_BANKING 50 · RISK_COMPLIANCE 45 · RETAIL_BANKING 34 … |
| `procedurePublisher` | `GPPS` 896; the rest employee IDs |
| `procedureCreatReasonCde` | 20 codes: ADMINCHG 644 · OTHER 194 · MRGPSP 73 · CIPOSOC 73 · CINTFMT 36 · OTHNEW 30 … |
| `versn.procVersnChngTypeCde` | ADMINCHG 645 · NMTRL 232 · MTRL 193 · NEW 107 |
| `versn.procVersnTypeCde` | EDT 1,073 · NEW 107 |
| `dmaScope` | N 1,029 · Y 47 · empty 104 |
| `isEdit` | N 1,157 · Y 23 |
| `procedureSignificantChange` | always 0 |

### 5.5 Section types and standard sections

| `procSgmntTypeCde` | Occurrences | Meaning *(interpretation)* |
|---|---|---|
| `STMT` | 1,180 | Procedure statement |
| `WTAT` | 1,180 | "Who this applies to" (scope) |
| `QMC` | 1,112 | Query management contact |
| `KPR-n` | many (KPR-3 on 983 procedures) | Key procedural requirements (numbered) |

| Section | Count | Content | Treatment |
|---|---|---|---|
| "Who this applies to" | 1,180 | Procedure-specific scope (724 distinct; median 92 characters) | **Keep: the scope statement** |
| "Query management contact" | 1,112 | Contact line (median 40 characters) | **Exclude** |

### 5.6 Text facts

| Measure | Value |
|---|---|
| Where content lives | `procedureApplication.segment[].procSgmntText` (all) + `procedureText.sgmntText` (1,117 non-trivial) |
| Other text | `cntlDesc` (804 procedures), `termDefinText` (438), `prmblVrtnsText` (91), `docDesc` (25) |
| Length | median **10,760**; p90 38,376; max 167,473 characters; **79%** over 4,000 |
| HTML | all procedures: strip |
| Duplicated statement | 1,175 procedures: de-duplicate |
| Empty sections | 75 procedures |

### 5.7 Status and versions

See section 3.1 for status codes. `actlDemDt` (13), `trgtDemDt` (22) and `demCmnt` (22) record decommissioning; **status is the reliable field**.

### 5.8 Parent reference (`procedureParentDocRef`)

- 517 procedures; **157 distinct parents**; up to 20 children each.
- Same FIM format as policy references, but **0 matches** to any policy (any version), to policy parent references, or on reference prefixes; 7 match other procedures.
- **Do not use it as a policy link.**

### 5.9 Risk taxonomy

| Source | Levels | Coverage |
|---|---|---|
| `procedureRiskType[]` | L1 + L2 (no L3) | 985 procedures; median **1** distinct entry (p90 4, max 16) after removing repeats |
| `prmryRiskType` | L1 | 987 |
| `objRel[]` CNTRL / RISK | L1 + L2 + L3 | the **only** source of L3 |

**Depth, all sources combined:** L1+L2+L3 **881** · L1+L2 73 · L1 only 120 · none 106. 306 procedures span more than one main risk area. Among published procedures, **92 have no taxonomy from any source**.

**Match against RegMap names (Extract 2):** L1 ~100% · L2 **94%** · L3 **74%**.

| Mismatch type | Example (procedure → RegMap) | Treatment |
|---|---|---|
| RegMap prefix | *Failure to process or settle valid manual transactions…* → *(TO BE RETIRED) Failure to process or settle…* | Strip the prefix, then exact match |
| Spelling | *Banks and Financial Institution Credit Risk* → *Banks & Financial Institution Credit Risk* | Treat "&" = "and" |
| Different taxonomy version | *Failure to Manage Third Parties* (L2) vs *Third Party Risk*; *Failure to deter, detect and protect against money laundering…* (L3) | No mapping; fall back one level |
| False similarity | *Lending Fraud (3rd Party)* vs *Lending Fraud (1st Party)* (0.92 similar, different risk) | **Never** map by similarity |

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
