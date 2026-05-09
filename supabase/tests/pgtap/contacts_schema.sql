BEGIN;
SELECT plan(25);

SELECT has_table('contacts', 'contacts table exists');
SELECT has_column('contacts', 'kind', 'contacts.kind exists');
SELECT col_type_is('contacts', 'kind', 'contact_kind', 'kind is enum');
SELECT has_column('contacts', 'roles', 'roles[] column exists');
SELECT col_type_is('contacts', 'roles', 'text[]', 'roles is text[]');
SELECT has_column('contacts', 'display_name', 'display_name (generated) exists');

PREPARE bad_person AS
  INSERT INTO contacts (kind) VALUES ('person');
SELECT throws_ok('bad_person', '23514',
  NULL, 'CHECK person needs first_name+last_name');

PREPARE bad_org AS
  INSERT INTO contacts (kind) VALUES ('organization');
SELECT throws_ok('bad_org', '23514',
  NULL, 'CHECK org needs legal_name');

SELECT has_table('contact_instructor', 'sidecar exists');
SELECT has_table('contact_student',    'sidecar exists');
SELECT has_table('contact_organization', 'sidecar exists');

SELECT col_is_pk('contact_instructor', 'contact_id');
SELECT col_is_pk('contact_student',    'contact_id');
SELECT col_is_pk('contact_organization', 'contact_id');

SELECT col_is_fk('contact_instructor', 'contact_id');
SELECT col_is_fk('contact_student',    'contact_id');
SELECT col_is_fk('contact_organization', 'contact_id');

SELECT has_column('contact_instructor', 'padi_pro_number');
SELECT has_column('contact_instructor', 'account_balance');
SELECT has_column('contact_student',    'pipeline_stage');

SELECT has_table('contact_relationships', 'relationships table exists');
SELECT has_table('contact_audit_log', 'audit log table exists');
SELECT col_type_is('contact_relationships', 'kind', 'relationship_kind',
                   'kind is relationship_kind enum');
SELECT col_is_pk('contact_audit_log', 'id', 'audit_log has PK on id');
SELECT col_type_is('contact_audit_log', 'changed_fields', 'jsonb',
                   'changed_fields is jsonb');

SELECT * FROM finish();
ROLLBACK;
