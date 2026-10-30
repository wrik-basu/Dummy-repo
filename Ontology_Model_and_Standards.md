# Regulatory Compliance Ontology: Model v2.5 and Standards Alignment

**Owner:** Wrik (HSBC, Impact Assessment) · **Date:** 30 Oct 2026 · **Status:** model as built on US data (15,609 nodes, 684,990 edges)

This note answers two questions:
1. **What is in the model now?** The relationships added by phases 3, 3b and 3c and the demo, on top of the v2.4 model.
2. **Does the model follow global standards?** It maps each part of the model to an external standard and sets out how it would be published.

---

## 1. How the model is held

- **Working store: a property graph.** It is held as `nodes.parquet` + `edges.parquet`, loadable into any graph database (Neo4j, Neptune, Spanner Graph) or queried in pandas.
- **Every link carries its provenance.** Each edge has its `layer`, `source_system` and `run_id`. AI links also carry the model's decision, score, verbatim quotes, reasoning, the judge verdict and the SME status.
- **One rule decides what counts.** Only links that were model-LINKED with both quotes verified AND confirmed by the independent judge count as facts (`impact_confirmed` / `structure_confirmed`). Every other assertion stays in the graph, labelled.

| Layer | What it holds | Source |
|---|---|---|
| FACT | system-of-record content and its own links | Rapid2, RegMap, Helios, GPPS |
| INTAKE | alert tags (jurisdiction, steward, theme, risk taxonomy, business, legal entity) | Rapid2 + ML classifiers |
| REFERENCE | RegMap's own mappings (extracts 3–5) | RegMap |
| AI_IMPACT | alert → record impact assertions | IA LLM runs + judge |
| AI_STRUCTURE | obligation → policy / procedure / control / instance assertions | IA LLM runs + judge |
| DERIVED | rule outputs (gap findings, links derived via a control) | rules, no AI |

---

## 2. Model v2.5: what changed since v2.4

**Classes:** 47 in v2.4, plus 1 new (**Gap**, with categories) and 1 made explicit (**RegulationAssessment**).

| Relationship (as built) | From → to | Ontology property | Layer | Status |
|---|---|---|---|---|
| `assertsImpact:RGL / RSM / ROB` | Alert → regulation / summary / obligation | LinkAssertion (granularity RGL / RSM / ROB) → `affectsObligation` / `affectsSummary` when confirmed | AI_IMPACT | built |
| `assertsImpact:LR / L1C / 1C` | Alert → library risk / control standard / control instance | LinkAssertion → `impactsControl` when confirmed | AI_IMPACT | built |
| `assertsImpact:POLICY / PROCEDURE` | Alert → policy / procedure | LinkAssertion → `impactsPolicyRequirement` when confirmed; with `impact_type` (CHANGE_REQUIRED / REVIEW_REQUIRED) and `change_needed` | AI_IMPACT | **new (phase 3)** |
| `implementedByPolicy` | Obligation → policy (section level) | inverse of `PolicyRequirement implementsObligation RegulatoryObligation` | AI_STRUCTURE | built; **+ via-control run (phase 3c)** |
| `governsActivity` | Obligation → procedure (section level) | `Requirement governsActivity ProcedureStep` | AI_STRUCTURE | built; **+ via-control run (phase 3c)** |
| `satisfiedByControl` | Obligation → control standard | inverse of `Control satisfies Requirement` (`satisfiedBy`), with `coverage` FULL / PARTIAL | AI_STRUCTURE | **new (phase 3b)** |
| `satisfiedByControlInstance` | Obligation → live control instance | `satisfiedBy` at instance level, with `coverage` | AI_STRUCTURE | **new (phase 3b)** |
| `implementedByPolicyViaControl` | Obligation → policy, through a confirmed control and the GPPS mapping | derivation of `implementedByPolicy` (no AI) | DERIVED | **new (stopgap; 11 of 12 now LLM + judge-confirmed)** |
| `hasGap` + Gap category | Obligation → Gap (NO_CONTROL / DESIGN_ONLY / NOT_OPERATED / PARTIAL_ONLY) | `ImpactAssessment identifiesGap Gap`, `Gap onRequirement Requirement`, `Gap hasCoverage` | DERIVED | **new (phase 3b)**; exported for the demo, computed in notebook 10 |
| `policyMapsToControl`, `procedureMapsToControl`, `policyMapsToRegulation`, `relatedPolicy` | GPPS document → control / regulation / policy | new GPPS properties (the GPPS objRel table) | FACT | built; **added to the model** |
| `implementsPolicy` | Procedure → policy | `Procedure implementsPolicy Policy` | FACT | built |
| `addressesRiskType` | Procedure → risk taxonomy node | new | FACT | built; **added to the model** |
| `assessesRegulation`, `assessedFor`, `evaluatesObligation` | RegulationAssessment → regulation / entity / obligation | class RegulationAssessment | FACT | built; **added to the model** |
| `instance_status`, `instance_live` | on alert → instance impact links | Control lifecycle status | FACT attribute | **new (30 Oct)** |
| `leadsTo` (explorer only) | Alert → head of an impacted chain | navigation aid, not a model relationship | — | demo explorer only |

**Granularity note.** Policy and procedure links are recorded at document level, but they carry the GPPS section numbers (`linked_sections`). That means PolicyRequirement and ProcedureStep nodes can be created later, at section level, with no new LLM run.

---

## 3. Standards alignment

| Part of the model | Standard | How it maps | When |
|---|---|---|---|
| The model itself (classes, properties, cardinalities) | **W3C OWL 2 / RDFS** | Publish as OWL / Turtle under HSBC IRIs. Classes become `owl:Class`, relationships `owl:ObjectProperty` (inverses declared, e.g. `satisfies` / `satisfiedBy`). | Can be done now. The model is in the explorer's `D` block and exports directly. |
| Governance rules ("an impact needs a confirmed assertion", "every obligation has ≥ 1 control or a Gap", cardinalities) | **W3C SHACL** | One SHACL shape per rule. The rule checks in `build_checks.xlsx` become shapes that validate the graph. | Can be done now. The rules already exist as Python checks. |
| Risk taxonomy (L1 → L2 → L3), regulatory themes, Gap categories, decision / verdict vocabularies | **W3C SKOS** | Each taxonomy becomes a `skos:ConceptScheme`. `broaderRisk` maps to `skos:broader`. The 17 merged names map to `skos:altLabel` or `skos:exactMatch`. | Can be done now. |
| AI link provenance (which model run made it, which judge checked it, SME review) | **W3C PROV-O** | A LinkAssertion is a `prov:Entity`, `prov:wasGeneratedBy` the model run (`prov:Activity`, `run_id`), `prov:wasInfluencedBy` the judge run, with `prov:wasAttributedTo` the SME when reviewed. | Can be done now. The fields are already on every AI edge. |
| Legal entity, regulator, regulation, jurisdiction | **EDM Council FIBO** (FND, BE, LEI modules) | LegalEntity → `fibo-be-le-lp:LegalEntity`; Regulator → `fibo-fbc-fct-rga:RegulatoryAgency`; Regulation → `fibo-fnd-law-lcap:Regulation`. | Alignment file only (no data change). |
| Entity keys, location keys | **ISO 17442 (LEI)**, **ISO 3166-1 / 3166-2** | Add the LEI to LegalEntity nodes and ISO codes to Jurisdiction nodes, as attributes. | Needs an LEI source; ISO codes can be added now. |
| Obligation semantics (modality, conditions, deadlines, exceptions) | **OASIS LegalRuleML**, **LKIF Core** | Phase 4: obligation text → modality (MUST / MUST_NOT / MAY), conditions, triggers, deadlines, responsible party. | Later (phase 4). |
| Regulation identity, provisions, versions and lineage | **ELI** (European Legislation Identifier), **OASIS Akoma Ntoso** | Phase 8: provision-level IDs and amendment lineage. | Later (phase 8). |
| Query | **ISO/IEC 39075 GQL**, openCypher; **SPARQL 1.1** after an RDF export | The competency questions are already written in Cypher in the model; GQL is the standard successor. | Can be done now. |

**Position for seniors:**
- **We work as a property graph, which suits volume and analytics.**
- **We publish as standards-aligned semantics:** OWL for the model, SHACL for the rules, SKOS for the taxonomies, PROV-O for the AI audit trail, FIBO and ISO for the shared keys.
- **Other banks and vendors can map to us without changing how we work.**

---

## 4. Publishing plan (when approved)

| # | Deliverable | Content | Effort | LLM? |
|---|---|---|---|---|
| 1 | `ontology_v2_5.ttl` | 49 classes and their relationships, inverses, labels and definitions, from the explorer's `D` block | ~0.5 day | none |
| 2 | `shapes.ttl` | The existing rule checks rewritten as SHACL shapes; validation report on the US graph with `pyshacl` | ~1 day | none |
| 3 | `taxonomy_skos.ttl` | Risk taxonomy L1–L3, themes, the Gap / decision / verdict vocabularies | ~0.5 day | none |
| 4 | `alignment.ttl` | FIBO / PROV-O / SKOS mappings (`owl:equivalentClass`, `rdfs:subClassOf`, `skos:exactMatch`) | ~0.5 day | none |
| 5 | Optional RDF export of a sample (the demo stories) | `rdflib`, SPARQL competency-question checks | ~1 day | none |
