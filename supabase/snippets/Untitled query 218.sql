UPDATE public.contact_instructor
   SET tenant_id = (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh')
 WHERE tenant_id IS NULL;