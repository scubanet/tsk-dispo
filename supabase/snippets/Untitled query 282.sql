SELECT u.email,
       ci.app_role,
       ci.tenant_id,
       t.slug AS tenant
FROM auth.users u
JOIN public.contact_instructor ci ON ci.auth_user_id = u.id
LEFT JOIN public.tenants t ON t.id = ci.tenant_id
ORDER BY u.email;
