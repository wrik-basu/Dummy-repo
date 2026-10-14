// CQ01 [MUST] Risk Steward: Which obligations does this alert change?
MATCH (:RegulatoryAlert {sourceId:'R2-140001'})-[:REPORTS_CHANGE]->(:RegulatoryChange)-[:AFFECTS_OBLIGATION]->(rob)
RETURN rob.sourceId AS rob, rob.label AS label ORDER BY rob;

// CQ02 [MUST] Risk Steward: Which summaries is the alert linked to, at what confidence, and is it human-confirmed?
MATCH (:RegulatoryAlert {sourceId:'R2-140001'})<-[:ASSERTION_SUBJECT]-(la:LinkAssertion {decision:'LINKED'})-[:ASSERTION_OBJECT]->(rsm:RegulatorySummary)
RETURN rsm.sourceId AS rsm, la.relevanceScore AS score, la.confidenceScore AS conf, la.smeStatus AS sme ORDER BY score DESC;

// CQ03 [MUST] Risk Steward: Which controls are impacted, through which library control?
MATCH (:RegulatoryChange {sourceId:'CHG-001'})-[:IMPACTS_CONTROL]->(c:Control)-[:INSTANCE_OF]->(l:LibraryControl)
RETURN c.sourceId AS control, l.sourceId AS l1c;

// CQ04 [MUST] Risk Steward: Which library risks and taxonomy areas are affected?
MATCH (:RegulatoryChange {sourceId:'CHG-001'})-[:AFFECTS_OBLIGATION]->(:RegulatoryObligation)-[:GIVES_RISE_TO]->(r:LibraryRisk)-[:CLASSIFIED_AS]->(t)
OPTIONAL MATCH (t)-[:BROADER_RISK*]->(top)
RETURN DISTINCT r.label AS risk, coalesce(top.label, t.label) AS taxonomy;

// CQ05 [MUST] Risk Steward: Which affected obligations have no control and no policy requirement (gaps)?
MATCH (:RegulatoryChange {sourceId:'CHG-001'})-[:AFFECTS_OBLIGATION]->(r:RegulatoryObligation)
WHERE NOT ()-[:SATISFIES]->(r) AND NOT ()-[:IMPLEMENTS_OBLIGATION]->(r)
RETURN r.sourceId AS rob, r.label AS label;

// CQ06 [SHOULD] Compliance SME: Under which conditions, and with which exceptions, does an obligation apply?
MATCH (r:RegulatoryObligation)
OPTIONAL MATCH (r)-[:HAS_CONDITION]->(c)
OPTIONAL MATCH (e:Exception)-[:OVERRIDES]->(r)
WITH r, c, e WHERE c IS NOT NULL OR e IS NOT NULL
RETURN r.sourceId AS rob, c.statement AS condition, e.statement AS exception;

// CQ07 [SHOULD] Risk Steward: Which legal entities and businesses are in scope?
MATCH (:RegulatoryChange {sourceId:'CHG-001'})-[:AFFECTS_OBLIGATION]->()-[:APPLIES_TO_SCOPE]->(s)
OPTIONAL MATCH (s)-[:SCOPES_LEGAL_ENTITY]->(le)
OPTIONAL MATCH (s)-[:SCOPES_BUSINESS]->(bu)
RETURN DISTINCT le.label AS entity, bu.label AS business;

// CQ08 [SHOULD] Risk Steward: By when must we comply?
MATCH (:RegulatoryChange {sourceId:'CHG-001'})-[:AFFECTS_OBLIGATION]->(r)-[:HAS_TEMPORAL_CONSTRAINT]->(t)
RETURN r.sourceId AS rob, t.temporalType AS type, t.effectiveDate AS date ORDER BY date;

// CQ09 [MUST] Policy Owner: Which policy requirements implement each affected obligation?
MATCH (:RegulatoryChange {sourceId:'CHG-001'})-[:AFFECTS_OBLIGATION]->(r)<-[:IMPLEMENTS_OBLIGATION]-(pr)<-[:HAS_REQUIREMENT]-(p:Policy)
RETURN r.sourceId AS rob, p.label AS policy, pr.sourceId AS requirement;

// CQ10 [MUST] Risk Steward: What are the findings and gaps in this assessment, and who remediates?
MATCH (:ImpactAssessment {sourceId:'IA-001'})-[:IDENTIFIES_GAP]->(g:Gap)
OPTIONAL MATCH (g)-[:REMEDIATED_BY]->(a)
RETURN g.sourceId AS gap, g.coverage AS coverage, a.label AS action;

// CQ11 [SHOULD] Management: What is the blast radius of this change?
MATCH (:ImpactAssessment {sourceId:'IA-001'})-[:HAS_BLAST_RADIUS]->(b)
RETURN b.nObligations, b.nControls, b.nPolicyRequirements, b.nLegalEntities, b.nBusinesses;

// CQ12 [COULD] Compliance SME: Which regulator issued the regulation and where does it apply?
MATCH (rg:Regulator)-[:ISSUES]->(r:Regulation)-[:APPLIES_IN_JURISDICTION]->(j)
RETURN r.label AS regulation, rg.label AS regulator, j.label AS jurisdiction;

// CQ13 [SHOULD] Risk Steward: Which alerts in my risk area arrived, and which changes do they report?
MATCH (a:RegulatoryAlert)-[:REPORTS_CHANGE]->(c), (a)-[:TAGGED_RISK]->(t)
RETURN a.sourceId AS alert, c.sourceId AS change, t.label AS risk;

// CQ14 [SHOULD] Risk Steward: Which impacted controls already have open issues or failed tests?
MATCH (:RegulatoryChange {sourceId:'CHG-001'})-[:IMPACTS_CONTROL]->(c)-[:HAS_ISSUE]->(i {status:'OPEN'})
RETURN c.sourceId AS control, i.label AS issue;

// CQ15 [MUST] Risk Steward: Who owns each impacted control, and who must sign off?
MATCH (ch)-[:INITIATES_ASSESSMENT]->(ia:ImpactAssessment {sourceId:'IA-001'})-[:ASSIGNED_TO]->(s)
MATCH (ch)-[:IMPACTS_CONTROL]->(c)-[:OWNED_BY]->(o)
RETURN c.sourceId AS control, o.label AS owner, s.label AS steward;

// CQ16 [COULD] Compliance SME: Which provision and defined terms does an obligation rest on?
MATCH (r:RegulatoryObligation)-[:CITES_PROVISION]->(p)
OPTIONAL MATCH (p)-[:DEFINES_TERM]->(t)
RETURN r.sourceId AS rob, p.label AS provision, t.term AS term;

// CQ17 [COULD] Process Owner: How is the obligation met day to day: which procedure steps, roles and systems?
MATCH (s:ProcedureStep)-[:SATISFIES]->(r)
OPTIONAL MATCH (s)-[:PERFORMED_BY]->(ro)
OPTIONAL MATCH (s)-[:USES_SYSTEM]->(sy)
RETURN r.sourceId AS rob, s.label AS step, ro.label AS role, sy.label AS system;

// CQ18 [MUST] Model Risk (MRM): Why is this control in the assessment: show the evidence and the model run.
MATCH (la:LinkAssertion {sourceId:'LA-003'})-[:HAS_EVIDENCE]->(e), (la)-[:PRODUCED_BY]->(run)
RETURN e.evidenceSide AS side, e.verbatimText AS quote, run.modelId AS model, run.promptVersion AS prompt;

// CQ19 [MUST] SME Reviewer: What is waiting for human review, highest confidence first?
MATCH (la:LinkAssertion {decision:'LINKED', smeStatus:'UNREVIEWED'})
RETURN la.sourceId AS assertion, la.relevanceScore AS score ORDER BY score DESC;

// CQ20 [SHOULD] Model Risk (MRM): How does the AI perform against human decisions, per model run?
MATCH (la:LinkAssertion)-[:PRODUCED_BY]->(run)
WHERE la.smeStatus <> 'UNREVIEWED'
RETURN run.sourceId AS run, count(la) AS reviewed, sum(CASE WHEN la.smeStatus = 'CONFIRMED' THEN 1 ELSE 0 END) AS confirmed;

