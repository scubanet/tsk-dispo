SELECT
  (SELECT count(*) FROM public.product_categories pc
     JOIN public.tenants t ON t.id = pc.tenant_id WHERE t.slug = 'tsk-zrh') AS tsk_kategorien,
  (SELECT count(*) FROM public.contact_instructor WHERE tenant_id IS NULL)   AS sidecars_ohne_tenant;