// Neo4j 5 schema for the Regulatory Compliance Ontology v2.2.0
// Every node carries :Entity plus its class and superclass labels; uid = stable key; sourceId = system-of-record id.
CREATE CONSTRAINT entity_uid IF NOT EXISTS FOR (n:Entity) REQUIRE n.uid IS UNIQUE;
CREATE CONSTRAINT regulation_source_id IF NOT EXISTS FOR (n:Regulation) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT regulatory_summary_source_id IF NOT EXISTS FOR (n:RegulatorySummary) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT regulatory_obligation_source_id IF NOT EXISTS FOR (n:RegulatoryObligation) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT regulatory_alert_source_id IF NOT EXISTS FOR (n:RegulatoryAlert) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT regulatory_change_source_id IF NOT EXISTS FOR (n:RegulatoryChange) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT library_risk_source_id IF NOT EXISTS FOR (n:LibraryRisk) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT library_control_source_id IF NOT EXISTS FOR (n:LibraryControl) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT control_source_id IF NOT EXISTS FOR (n:Control) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT policy_requirement_source_id IF NOT EXISTS FOR (n:PolicyRequirement) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT link_assertion_source_id IF NOT EXISTS FOR (n:LinkAssertion) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT impact_assessment_source_id IF NOT EXISTS FOR (n:ImpactAssessment) REQUIRE n.sourceId IS UNIQUE;
CREATE CONSTRAINT model_run_source_id IF NOT EXISTS FOR (n:ModelRun) REQUIRE n.sourceId IS UNIQUE;
CREATE INDEX link_assertion_status IF NOT EXISTS FOR (n:LinkAssertion) ON (n.decision, n.smeStatus);
CREATE INDEX entity_valid IF NOT EXISTS FOR (n:Entity) ON (n.validFrom, n.validTo);
CREATE FULLTEXT INDEX entity_text IF NOT EXISTS FOR (n:RegulatoryObligation|RegulatorySummary|Control|LibraryControl|LibraryRisk|PolicyRequirement|ProcedureStep|RegulatoryAlert) ON EACH [n.label, n.statement];
// GraphRAG: vector indexes on text embeddings (dimension = the gateway embedding model's size)
CREATE VECTOR INDEX regulatory_obligation_embedding IF NOT EXISTS FOR (n:RegulatoryObligation) ON (n.embedding) OPTIONS {indexConfig: {`vector.dimensions`: 1536, `vector.similarity_function`: 'cosine'}};
CREATE VECTOR INDEX regulatory_summary_embedding IF NOT EXISTS FOR (n:RegulatorySummary) ON (n.embedding) OPTIONS {indexConfig: {`vector.dimensions`: 1536, `vector.similarity_function`: 'cosine'}};
CREATE VECTOR INDEX control_embedding IF NOT EXISTS FOR (n:Control) ON (n.embedding) OPTIONS {indexConfig: {`vector.dimensions`: 1536, `vector.similarity_function`: 'cosine'}};
CREATE VECTOR INDEX policy_requirement_embedding IF NOT EXISTS FOR (n:PolicyRequirement) ON (n.embedding) OPTIONS {indexConfig: {`vector.dimensions`: 1536, `vector.similarity_function`: 'cosine'}};
CREATE VECTOR INDEX regulatory_alert_embedding IF NOT EXISTS FOR (n:RegulatoryAlert) ON (n.embedding) OPTIONS {indexConfig: {`vector.dimensions`: 1536, `vector.similarity_function`: 'cosine'}};
CREATE VECTOR INDEX evidence_occurrence_embedding IF NOT EXISTS FOR (n:EvidenceOccurrence) ON (n.embedding) OPTIONS {indexConfig: {`vector.dimensions`: 1536, `vector.similarity_function`: 'cosine'}};
