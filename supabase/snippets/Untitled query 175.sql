BEGIN;
SELECT set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', (SELECT ci.auth_user_id::text
              FROM public.contact_instructor ci
              JOIN public.contacts c ON c.id = ci.contact_id
              WHERE c.display_name ILIKE '%weckherlin%' LIMIT 1),
    'role', 'authenticated'
  )::text,
  true
);
SET LOCAL ROLE authenticated;
SELECT public.current_tenant_id()                          AS my_tenant,
       (SELECT count(*) FROM public.product_categories)    AS sichtbare_kategorien;
ROLLBACK;