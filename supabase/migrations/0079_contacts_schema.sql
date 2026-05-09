-- 0079: Contacts unified CRM schema (Part 1 — enums + main table)

CREATE TYPE contact_kind AS ENUM ('person', 'organization');

CREATE TYPE relationship_kind AS ENUM (
  'works_at', 'owns', 'spouse_of', 'child_of', 'parent_of',
  'referred_by', 'subsidiary_of', 'partner_of', 'supplier_of',
  'student_of', 'mentor_of'
);

CREATE TABLE public.contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind contact_kind NOT NULL,

  -- Person fields
  first_name TEXT,
  last_name TEXT,
  birth_date DATE,
  gender TEXT,

  -- Org fields
  legal_name TEXT,
  trading_name TEXT,

  -- Generated display name
  display_name TEXT GENERATED ALWAYS AS (
    CASE
      WHEN kind = 'organization' THEN COALESCE(trading_name, legal_name)
      ELSE last_name || ', ' || first_name
    END
  ) STORED,

  primary_email TEXT,
  emails JSONB NOT NULL DEFAULT '[]',
  phones JSONB NOT NULL DEFAULT '[]',
  addresses JSONB NOT NULL DEFAULT '[]',

  languages TEXT[] NOT NULL DEFAULT '{}',
  roles TEXT[] NOT NULL DEFAULT '{}',
  tags TEXT[] NOT NULL DEFAULT '{}',

  notes TEXT,
  owner_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,

  consent_marketing BOOLEAN NOT NULL DEFAULT false,
  consent_marketing_at TIMESTAMPTZ,
  consent_marketing_source TEXT,

  source TEXT,

  archived_at TIMESTAMPTZ,
  merged_into_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID,

  CONSTRAINT contacts_person_fields_check CHECK (
    kind = 'organization'
    OR (first_name IS NOT NULL AND last_name IS NOT NULL)
  ),
  CONSTRAINT contacts_org_fields_check CHECK (
    kind = 'person' OR legal_name IS NOT NULL
  ),
  CONSTRAINT contacts_no_self_merge CHECK (id <> merged_into_id)
);

CREATE INDEX idx_contacts_kind     ON public.contacts(kind);
CREATE INDEX idx_contacts_owner    ON public.contacts(owner_id);
CREATE INDEX idx_contacts_roles    ON public.contacts USING GIN(roles);
CREATE INDEX idx_contacts_tags     ON public.contacts USING GIN(tags);
CREATE INDEX idx_contacts_archived ON public.contacts(archived_at)
  WHERE archived_at IS NULL;
CREATE INDEX idx_contacts_search   ON public.contacts USING GIN(
  to_tsvector('simple',
    COALESCE(first_name,'') || ' ' ||
    COALESCE(last_name,'')  || ' ' ||
    COALESCE(legal_name,'') || ' ' ||
    COALESCE(trading_name,'') || ' ' ||
    COALESCE(primary_email,'') || ' ' ||
    COALESCE(notes,'')
  )
);

COMMENT ON TABLE public.contacts IS
  'Unified CRM contacts table. Replaces instructors, people, organizations.';

-- contact_instructor sidecar
-- Uses existing padi_level enum (defined in 0001, extended in 0029/0033)
-- with values: Instructor, Staff Instructor, DM, Shop Staff, Andere Funktion,
-- AI, OWSI, MSDT, MI, CD, Andere, IDC Staff
CREATE TABLE public.contact_instructor (
  contact_id UUID PRIMARY KEY REFERENCES public.contacts(id) ON DELETE CASCADE,
  auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  padi_pro_number TEXT,
  padi_level padi_level,
  account_balance NUMERIC(10,2) NOT NULL DEFAULT 0,
  hourly_rate_chf NUMERIC(8,2),
  daily_rate_chf NUMERIC(8,2),
  active BOOLEAN NOT NULL DEFAULT true,
  hire_date DATE,
  termination_date DATE,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  notes_internal TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_instructor_active ON public.contact_instructor(active);
CREATE INDEX idx_contact_instructor_auth   ON public.contact_instructor(auth_user_id);

-- contact_student sidecar
CREATE TABLE public.contact_student (
  contact_id UUID PRIMARY KEY REFERENCES public.contacts(id) ON DELETE CASCADE,
  pipeline_stage TEXT,
  lead_source TEXT,
  highest_brevet TEXT,
  intake_status TEXT,
  external_brevet_history JSONB NOT NULL DEFAULT '[]',
  is_candidate BOOLEAN NOT NULL DEFAULT false,
  candidate_target_level padi_level,
  medical_clearance_at DATE,
  insurance_provider TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_student_pipeline  ON public.contact_student(pipeline_stage);
CREATE INDEX idx_contact_student_candidate ON public.contact_student(is_candidate)
  WHERE is_candidate = true;

-- contact_organization sidecar
CREATE TABLE public.contact_organization (
  contact_id UUID PRIMARY KEY REFERENCES public.contacts(id) ON DELETE CASCADE,
  org_kind TEXT NOT NULL,
  tax_id TEXT,
  billing_email TEXT,
  parent_org_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,
  contract_type TEXT,
  contract_until DATE,
  payment_terms TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_org_kind   ON public.contact_organization(org_kind);
CREATE INDEX idx_contact_org_parent ON public.contact_organization(parent_org_id);

-- contact_relationships: n:m relationships between contacts (Hybrid model)
CREATE TABLE public.contact_relationships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_contact_id UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  to_contact_id   UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  kind relationship_kind NOT NULL,
  role_at_org TEXT,
  started_at DATE,
  ended_at DATE,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT no_self_relationship CHECK (from_contact_id <> to_contact_id),
  CONSTRAINT valid_period CHECK (ended_at IS NULL OR started_at IS NULL OR ended_at >= started_at)
);

CREATE INDEX idx_contact_rel_from ON public.contact_relationships(from_contact_id);
CREATE INDEX idx_contact_rel_to   ON public.contact_relationships(to_contact_id);
CREATE INDEX idx_contact_rel_kind ON public.contact_relationships(kind);

-- contact_audit_log: every change to contacts/sidecars is logged.
-- NOTE: contact_id has NO FK to contacts(id) on purpose — audit entries
-- must survive when their source contact is deleted. The DELETE-trigger
-- writes its final audit entry AFTER the contact row is gone, so a CASCADE
-- or strict FK would create a chicken-and-egg constraint violation.
CREATE TABLE public.contact_audit_log (
  id BIGSERIAL PRIMARY KEY,
  contact_id UUID NOT NULL,
  changed_by UUID,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  changed_fields JSONB,
  old_row JSONB,
  new_row JSONB
);

CREATE INDEX idx_audit_contact ON public.contact_audit_log(contact_id, changed_at DESC);
