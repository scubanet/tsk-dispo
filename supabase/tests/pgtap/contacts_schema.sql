BEGIN;
SELECT plan(8);

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

SELECT * FROM finish();
ROLLBACK;
