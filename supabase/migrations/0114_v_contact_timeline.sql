-- 0114_v_contact_timeline.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: unified Read-Side Timeline-View für Contacts.
-- Vereint 1 User-Logs-Branch (contact_events, Migration 0110) mit
-- 9 System-Event-Branches via UNION ALL — alles, was zu einem
-- Contact "passiert" ist, in einer chronologisch sortierbaren View.
--
-- System-Event-Quellen:
--   • course_participants  → 'course_enrollment'
--   • certifications       → 'certification_issued'  (Migration 0076)
--   • account_movements    → 'saldo_movement'        (Migration 0012)
--   • pipeline_stage_changes → 'pipeline_change'     (Migration 0112)
--   • intake_checklists    → 'intake_checkpoint'     (Migration 0050)
--   • padi_skill_records   → 'skill_checked'         (Migration 0090)
--   • card_leads           → 'card_lead_imported'    (Migration 0105)
--   • contact_audit_log    → 'role_change'           (Rollen-Operationen)
--   • contact_audit_log    → 'audit_edit'            (PII-UPDATEs auf contacts)
--
-- Spec: docs/superpowers/specs/2026-05-27-contacts-crm-redesign.md §4.1, §8.2
-- Plan: docs/superpowers/plans/2026-05-27-phase-g-foundation.md §10 Task 6
-- Audit-Notes: docs/superpowers/plans/2026-05-27-phase-g-foundation-schema-audit-notes.md
--
-- Spalten-Signatur (uniform über alle UNION-Branches):
--   event_id          TEXT         -- pro Source-Table eindeutig (cast::text)
--   contact_id        UUID
--   event_type        TEXT         -- Diskriminator (siehe oben)
--   occurred_at       TIMESTAMPTZ
--   actor_contact_id  UUID         -- nullable; User-Logs: actor_id, System: NULL
--   summary           TEXT
--   body              TEXT         -- nullable
--   payload           JSONB        -- nullable
--   status            TEXT         -- 'open' | 'resolved' | 'archived'
--   source_table      TEXT         -- Source-of-Truth-Tabelle
--   source_id         TEXT         -- Source-PK ::text (uniform für UNION ALL)
--
-- RLS: security_invoker = on → die RLS jeder Basistabelle wird vom Caller
-- angewendet (kein Bypass). authenticated bekommt SELECT.
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
-- person_id ist UUID-unified mit contacts(id) (Phase F1).
-- issued_at ist DATE → Cast nach timestamptz.
-- invalidated_at = NULL filtert Soft-Deletes raus.
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
-- instructor_id ist UUID, identisch mit contacts(id) (Phase F1, Audit §3).
-- Spalte heisst `date` (NICHT movement_date — Audit-Notes).
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
-- Coarse: ein Event pro updated_at-Stand. Payload bleibt minimal —
-- keine PII (medical_notes, insurance_provider) ins Payload schreiben.
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
-- FK-Kette: psr.participant_id → course_participants.id → student_id (contact).
-- Time-Spalte: completed_on (DATE) — nur Records mit completed_on IS NOT NULL.
-- instructor_id zeigt auf instructors(id), das ist UUID-unified mit contacts(id).
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
-- Nur Leads, die in Address-Book importiert wurden (imported_contact_id NOT NULL).
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
-- Operations INSERT/DELETE auf Junction-Tables, die eine Rolle markieren.
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
SELECT
  cal.id::text                               AS event_id,
  cal.contact_id                             AS contact_id,
  'audit_edit'::text                         AS event_type,
  cal.changed_at                             AS occurred_at,
  cal.changed_by                             AS actor_contact_id,
  ('Daten bearbeitet: ' || COALESCE(
    (SELECT string_agg(k, ', ' ORDER BY k)
     FROM jsonb_object_keys(cal.changed_fields) AS k),
    '(keine Felder)'
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

-- RLS-NOTE (Cross-Branch-Sichtbarkeit unter security_invoker):
--   • contact_events     — owner-only (contact_events_owner, 0111)
--   • course_participants — alle authenticated (public read, participants_read_all)
--   • certifications     — staff-scoped (certs_full_access_for_staff)
--   • account_movements  — self-only ODER dispatcher (movements_read_own + movements_dispatcher_all)
--   • pipeline_stage_changes — owner-only (0112)
--   • intake_checklists  — alle authenticated Instructors (0096 ist FOR ALL — bekannt permissiv)
--   • padi_skill_records — alle authenticated
--   • card_leads         — card-owner only (0097)
--   • contact_audit_log  — alle authenticated (0084 — bekannt permissiv)
-- Konsequenz: useGlobalActivity ist asymmetrisch — Pipeline-Changes sind
-- owner-scoped, Audit-Edits leaken über die Org. Bewusst akzeptiert für
-- Phase G; Tightening (audit_log/intake) ist separates Spec-Item.
ALTER VIEW public.v_contact_timeline SET (security_invoker = on);

GRANT SELECT ON public.v_contact_timeline TO authenticated;

-- Performance: partial-Indizes für useGlobalActivity-Pfad. Ohne diese müsste
-- der globale Feed contact_audit_log voll scannen + sortieren bei jedem Aufruf.
CREATE INDEX IF NOT EXISTS idx_audit_role_changes_changed
  ON public.contact_audit_log(changed_at DESC)
  WHERE operation IN ('INSERT','DELETE')
    AND table_name IN ('contact_instructor','contact_student','contact_organization');

CREATE INDEX IF NOT EXISTS idx_audit_pii_edits_changed
  ON public.contact_audit_log(changed_at DESC)
  WHERE operation = 'UPDATE'
    AND table_name = 'contacts'
    AND changed_fields IS NOT NULL;

COMMENT ON VIEW public.v_contact_timeline IS
  'Unified Read-Side Timeline pro Contact. Vereint contact_events (User-Logs) mit 9 System-Event-Quellen via UNION ALL. Always order by (occurred_at DESC, event_id DESC) am Call-Site — die View imposed keine Sortierung. Siehe Spec §4.1, §8.2. RLS: security_invoker — siehe RLS-NOTE oben für Cross-Branch-Sichtbarkeit.';
