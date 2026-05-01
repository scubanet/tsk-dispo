-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums for type safety
CREATE TYPE padi_level AS ENUM (
  'Instructor',
  'Staff Instructor',
  'DM',
  'Shop Staff',
  'Andere Funktion'
);

CREATE TYPE app_role AS ENUM (
  'dispatcher',
  'instructor',
  'owner'
);

CREATE TYPE course_status AS ENUM (
  'confirmed',
  'tentative',
  'cancelled'
);

CREATE TYPE assignment_role AS ENUM (
  'haupt',
  'assist',
  'dmt'
);

CREATE TYPE pool_location AS ENUM (
  'mooesli',
  'langnau'
);

CREATE TYPE movement_kind AS ENUM (
  'vergütung',
  'übertrag',
  'korrektur'
);

CREATE TYPE availability_kind AS ENUM (
  'urlaub',
  'abwesend',
  'verfügbar'
);

-- Shared updated_at trigger function (used by multiple tables)
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
