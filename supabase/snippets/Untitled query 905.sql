SELECT
  (SELECT count(*) FROM auth.users)                                          AS n_auth_users,
  (SELECT count(*) FROM public.contact_instructor WHERE auth_user_id IS NOT NULL) AS sidecars_mit_authid,
  (SELECT count(*) FROM public.contact_instructor ci
     WHERE EXISTS (SELECT 1 FROM auth.users u WHERE u.id = ci.auth_user_id))  AS sidecars_real_verknuepft,
  (SELECT string_agg(email, ', ') FROM auth.users)                           AS auth_emails;