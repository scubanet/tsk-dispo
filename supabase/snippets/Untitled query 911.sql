UPDATE public.contact_instructor
SET auth_user_id = (SELECT id FROM auth.users ORDER BY created_at DESC LIMIT 1)
WHERE contact_id = (
  SELECT ci.contact_id
  FROM public.contact_instructor ci
  JOIN public.contacts c ON c.id = ci.contact_id
  WHERE c.display_name ILIKE '%weckherlin%'
    AND ci.app_role IN ('owner','cd','dispatcher')
  ORDER BY ci.app_role
  LIMIT 1
);