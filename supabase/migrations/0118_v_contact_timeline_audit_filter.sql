-- 0118_v_contact_timeline_audit_filter.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Phase 3 Carry-Forward C2: filtert 'updated_at' aus dem
-- audit_edit-Summary in v_contact_timeline raus.
--
-- Background: ein Trigger updated `updated_at` als Side-Effect bei jedem
-- UPDATE — das landet jedes Mal in contact_audit_log.changed_fields und
-- macht das Summary "Daten bearbeitet: updated_at" unbrauchbar als Signal.
-- Filtern wir das Feld raus; wenn nur `updated_at` drin war, schreiben
-- wir '(nur Timestamp)' statt 'Daten bearbeitet: ' mit leerem Tail.
--
-- Strategie: CREATE OR REPLACE VIEW kopiert die View-Definition aus 0114
-- vollständig (CREATE OR REPLACE behält Indices, Comment, security_invoker
-- und GRANTs, aber wir setzen ALTER+GRANT+COMMENT am Ende defensiv neu).
-- Indices an contact_audit_log bleiben unberührt — die hängen nicht an
-- der View.
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_contact_timeline AS

-- ─── 1) User-logged Events (Notiz, Anruf, Mail, Meeting, Task, WhatsApp) ───
SELECT
  ce.id::text                                AS event_id,
  ce.contact_id                              AS contact_id,
  ce.event_type                              AS event_type,
  ce.occurred_at                             AS occurred_at,
  ce.actor_id                                AS actor_contact_id,
  ce.summary                                 AS summary,
  ce.body                                    AS body,
  ce.payload                                 AS payload,
  ce.status                                  AS status,
  'contact_events'::text                     AS source_table,
  ce.id::text                                AS source_id
FROM public.contact_events ce

UNION ALL

-- ─── 2) Course-Enrollment (course_participants JOIN courses) ───
SELECT
  cp.id::text                                AS event_id,
  cp.student_id                              AS contact_id,
  'course_enrollment'::text                  AS event_type,
  cp.enrolled_at                             AS occurred_at,
  NULL::uuid                                 AS actor_contact_id,
  ('Eingeschrieben in ' || c.title)          AS summary,
  NULL::text                                 AS body,
  jsonb_build_object(
    'course_id',    cp.course_id,
    'course_title', c.title,
    'status',       cp.status::text
  )                                          AS payload,
  'open'::text                               AS status,
  'course_participants'::text                AS source_table,
  cp.id::text                                AS source_id
FROM public.course_participants cp
JOIN public.courses c ON c.id = cp.course_id

UNION ALL

-- ─── 3) Certification issued (certifications, Migration 0076) ───
SELECT
  cert.id::text                              AS event_id,
  cert.person_id                             AS contact_id,
  'certification_issued'::text               AS event_type,
  cert.issued_at::timestamptz                AS occurred_at,
  cert.issued_by_person_id                   AS actor_contact_id,
  ('Zertifikat ausgestellt: ' || cert.code || ' (' || cert.agency || ')')
                                             AS summary,
  cert.notes                                 AS body,
  jsonb_build_object(
    'agency',   cert.agency,
    'category', cert.category,
    'code',     cert.code,
    'number',   cert.number,
    'origin',   cert.origin
  )                                          AS payload,
  'open'::text                               AS status,
  'certifications'::text                     AS source_table,
  cert.id::text                              AS source_id
FROM public.certifications cert
WHERE cert.invalidated_at IS NULL

UNION ALL

-- ─── 4) Saldo-Bewegung (account_movements, Migration 0012) ───
SELECT
  am.id::text                                AS event_id,
  am.instructor_id                           AS contact_id,
  'saldo_movement'::text                     AS event_type,
  am.date::timestamptz                       AS occurred_at,
  am.created_by                              AS actor_contact_id,
  ('CHF ' || am.amount_chf::text || ' (' || am.kind::text || ')')
                                             AS summary,
  am.description                             AS body,
  jsonb_build_object(
    'amount_chf',        am.amount_chf,
    'kind',              am.kind::text,
    'ref_assignment_id', am.ref_assignment_id
  )                                          AS payload,
  'open'::text                               AS status,
  'account_movements'::text                  AS source_table,
  am.id::text                                AS source_id
FROM public.account_movements am

UNION ALL

-- ─── 5) Pipeline-Stage-Change (pipeline_stage_changes, Migration 0112) ───
SELECT
  psc.id::text                               AS event_id,
  psc.contact_id                             AS contact_id,
  'pipeline_change'::text                    AS event_type,
  psc.changed_at                             AS occurred_at,
  psc.changed_by                             AS actor_contact_id,
  (COALESCE(psc.from_stage, '∅') || ' → ' || COALESCE(psc.to_stage, '∅'))
                                             AS summary,
  NULL::text                                 AS body,
  jsonb_build_object(
    'from_stage', psc.from_stage,
    'to_stage',   psc.to_stage
  )                                          AS payload,
  'open'::text                               AS status,
  'pipeline_stage_changes'::text             AS source_table,
  psc.id::text                               AS source_id
FROM public.pipeline_stage_changes psc

UNION ALL

-- ─── 6) Intake-Checkliste aktualisiert (intake_checklists, Migration 0050) ───
SELECT
  ic.id::text                                AS event_id,
  ic.student_id                              AS contact_id,
  'intake_checkpoint'::text                  AS event_type,
  ic.updated_at                              AS occurred_at,
  NULL::uuid                                 AS actor_contact_id,
  'Intake-Checkliste aktualisiert'::text     AS summary,
  NULL::text                                 AS body,
  jsonb_build_object(
    'medical_received',   ic.medical_received,
    'medical_signed',     ic.medical_signed,
    'logbook_seen',       ic.logbook_seen,
    'id_seen',            ic.id_seen,
    'insurance_proof',    ic.insurance_proof,
    'liability_signed',   ic.liability_signed,
    'safe_diving_signed', ic.safe_diving_signed
  )                                          AS payload,
  'open'::text                               AS status,
  'intake_checklists'::text                  AS source_table,
  ic.id::text                                AS source_id
FROM public.intake_checklists ic
WHERE ic.student_id IS NOT NULL  -- defensive: legacy rows could have NULL FK

UNION ALL

-- ─── 7) PADI-Skill abgehakt (padi_skill_records, Migration 0090) ───
SELECT
  psr.id::text                               AS event_id,
  cp2.student_id                             AS contact_id,
  'skill_checked'::text                      AS event_type,
  psr.completed_on::timestamptz              AS occurred_at,
  psr.instructor_id                          AS actor_contact_id,
  ('Skill abgehakt: ' || psr.skill_code)     AS summary,
  psr.notes                                  AS body,
  jsonb_build_object(
    'course_id',       psr.course_id,
    'participant_id',  psr.participant_id,
    'skill_code',      psr.skill_code,
    'course_day_kind', psr.course_day_kind,
    'tg_number',       psr.tg_number,
    'quiz_passed',     psr.quiz_passed,
    'video_watched',   psr.video_watched
  )                                          AS payload,
  'open'::text                               AS status,
  'padi_skill_records'::text                 AS source_table,
  psr.id::text                               AS source_id
FROM public.padi_skill_records psr
JOIN public.course_participants cp2 ON cp2.id = psr.participant_id
WHERE psr.completed_on IS NOT NULL

UNION ALL

-- ─── 8) Card-Lead-Import (card_leads, Migration 0105) ───
SELECT
  cl.id::text                                AS event_id,
  cl.imported_contact_id                     AS contact_id,
  'card_lead_imported'::text                 AS event_type,
  cl.captured_at                             AS occurred_at,
  NULL::uuid                                 AS actor_contact_id,
  ('Erste Berührung via AtollCard (' || cd.title || ')')
                                             AS summary,
  cl.message                                 AS body,
  jsonb_build_object(
    'card_id',    cl.card_id,
    'card_slug',  cd.slug,
    'card_title', cd.title,
    'topic',      cl.topic,
    'email',      cl.email,
    'phone',      cl.phone
  )                                          AS payload,
  'open'::text                               AS status,
  'card_leads'::text                         AS source_table,
  cl.id::text                                AS source_id
FROM public.card_leads cl
JOIN public.cards cd ON cd.id = cl.card_id
WHERE cl.imported_contact_id IS NOT NULL

UNION ALL

-- ─── 9) Rollen-Wechsel via contact_audit_log (Migration 0079, gefiltert) ───
SELECT
  cal.id::text                               AS event_id,
  cal.contact_id                             AS contact_id,
  'role_change'::text                        AS event_type,
  cal.changed_at                             AS occurred_at,
  cal.changed_by                             AS actor_contact_id,
  CASE
    WHEN cal.operation = 'INSERT' AND cal.table_name = 'contact_instructor'
      THEN 'Wurde Instructor'
    WHEN cal.operation = 'DELETE' AND cal.table_name = 'contact_instructor'
      THEN 'Ist nicht mehr Instructor'
    WHEN cal.operation = 'INSERT' AND cal.table_name = 'contact_student'
      THEN 'Wurde Student'
    WHEN cal.operation = 'DELETE' AND cal.table_name = 'contact_student'
      THEN 'Ist nicht mehr Student'
    WHEN cal.operation = 'INSERT' AND cal.table_name = 'contact_organization'
      THEN 'Wurde Organisation'
    WHEN cal.operation = 'DELETE' AND cal.table_name = 'contact_organization'
      THEN 'Ist nicht mehr Organisation'
    ELSE cal.operation || ' on ' || cal.table_name
  END                                        AS summary,
  NULL::text                                 AS body,
  jsonb_build_object(
    'table_name', cal.table_name,
    'operation',  cal.operation
  )                                          AS payload,
  'open'::text                               AS status,
  'contact_audit_log'::text                  AS source_table,
  cal.id::text                               AS source_id
FROM public.contact_audit_log cal
WHERE cal.operation IN ('INSERT', 'DELETE')
  AND cal.table_name IN ('contact_instructor', 'contact_student', 'contact_organization')

UNION ALL

-- ─── 10) PII-Edits via contact_audit_log (Migration 0079, gefiltert) ───
-- UPDATEs auf contacts: zeige Liste geänderter Felder.
-- Phase G Phase 3 Carry-Forward C2: filtert 'updated_at' raus (Trigger-Noise).
-- Wenn nur 'updated_at' drin war → string_agg = '' → NULLIF → COALESCE → '(nur Timestamp)'.
SELECT
  cal.id::text                               AS event_id,
  cal.contact_id                             AS contact_id,
  'audit_edit'::text                         AS event_type,
  cal.changed_at                             AS occurred_at,
  cal.changed_by                             AS actor_contact_id,
  ('Daten bearbeitet: ' || COALESCE(
    NULLIF(
      (SELECT string_agg(k, ', ' ORDER BY k)
       FROM jsonb_object_keys(cal.changed_fields) AS k
       WHERE k != 'updated_at'),
      ''
    ),
    '(nur Timestamp)'
  ))                                         AS summary,
  NULL::text                                 AS body,
  jsonb_build_object(
    'changed_fields', cal.changed_fields
  )                                          AS payload,
  'open'::text                               AS status,
  'contact_audit_log'::text                  AS source_table,
  cal.id::text                               AS source_id
FROM public.contact_audit_log cal
WHERE cal.operation = 'UPDATE'
  AND cal.table_name = 'contacts'
  AND cal.changed_fields IS NOT NULL
;

-- Defensive re-apply (CREATE OR REPLACE behält das schon, aber wir setzen
-- nochmal, falls je ein Edge-Case die Einstellung droppen würde):
ALTER VIEW public.v_contact_timeline SET (security_invoker = on);

GRANT SELECT ON public.v_contact_timeline TO authenticated;

COMMENT ON VIEW public.v_contact_timeline IS
  'Unified Read-Side Timeline pro Contact. Vereint contact_events (User-Logs) mit 9 System-Event-Quellen via UNION ALL. Always order by (occurred_at DESC, event_id DESC) am Call-Site — die View imposed keine Sortierung. Siehe Spec §4.1, §8.2. RLS: security_invoker — siehe RLS-NOTE in 0114. audit_edit-Summary filtert updated_at raus (0118).';
