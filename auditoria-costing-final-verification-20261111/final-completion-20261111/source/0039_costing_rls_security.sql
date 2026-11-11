-- Costing tenant isolation and least-privilege grants.
-- This is intentionally incremental: historical migrations are not rewritten.

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;

-- A bootstrap-safe fallback is created only when the canonical helper has not
-- been installed yet by rls_multitenant.sql. The canonical helper later
-- replaces this body with Supabase auth.uid() support.
DO $$
BEGIN
  IF to_regprocedure('private.current_app_user_id()') IS NULL THEN
    EXECUTE $fn$
      CREATE FUNCTION private.current_app_user_id()
      RETURNS integer
      LANGUAGE sql
      STABLE
      SECURITY DEFINER
      SET search_path = public
      AS $body$
        SELECT id
        FROM public.users
        WHERE id = NULLIF(current_setting('request.app_user_id', true), '')::integer
        LIMIT 1
      $body$
    $fn$;
  END IF;

  IF to_regprocedure('private.has_organization_access(character varying)') IS NULL THEN
    EXECUTE $fn$
      CREATE FUNCTION private.has_organization_access(target_organization_id varchar)
      RETURNS boolean
      LANGUAGE sql
      STABLE
      SECURITY DEFINER
      SET search_path = public
      AS $body$
        SELECT EXISTS (
          SELECT 1
          FROM public.organization_members membership
          WHERE membership."organizationId" = target_organization_id
            AND membership."userId" = private.current_app_user_id()
            AND membership.status = 'active'
        )
      $body$
    $fn$;
  END IF;
END $$;

REVOKE ALL ON FUNCTION private.current_app_user_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.has_organization_access(varchar) FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA private TO authenticated';
    EXECUTE 'GRANT EXECUTE ON FUNCTION private.current_app_user_id() TO authenticated';
    EXECUTE 'GRANT EXECUTE ON FUNCTION private.has_organization_access(varchar) TO authenticated';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_runtime') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA private TO app_runtime';
    EXECUTE 'GRANT EXECUTE ON FUNCTION private.current_app_user_id() TO app_runtime';
    EXECUTE 'GRANT EXECUTE ON FUNCTION private.has_organization_access(varchar) TO app_runtime';
  END IF;
END $$;

DO $$
DECLARE
  current_table text;
BEGIN
  FOREACH current_table IN ARRAY ARRAY[
    'cost_groups',
    'cost_items',
    'cost_structure_version_counters',
    'cost_structures',
    'cost_structure_lines',
    'cost_calculations',
    'costing_gamma_settings',
    'costing_gamma_groups'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', current_table);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', current_table);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC', current_table);
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
      EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon', current_table);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
      EXECUTE format('REVOKE ALL ON TABLE public.%I FROM authenticated', current_table);
    END IF;

    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_select ON public.%I', current_table, current_table);
    EXECUTE format(
      'CREATE POLICY %I_tenant_select ON public.%I FOR SELECT TO PUBLIC USING (private.has_organization_access("organizationId"))',
      current_table,
      current_table
    );

    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_insert ON public.%I', current_table, current_table);
    EXECUTE format(
      'CREATE POLICY %I_tenant_insert ON public.%I FOR INSERT TO PUBLIC WITH CHECK (private.has_organization_access("organizationId"))',
      current_table,
      current_table
    );

    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_update ON public.%I', current_table, current_table);
    EXECUTE format(
      'CREATE POLICY %I_tenant_update ON public.%I FOR UPDATE TO PUBLIC USING (private.has_organization_access("organizationId")) WITH CHECK (private.has_organization_access("organizationId"))',
      current_table,
      current_table
    );

    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_delete ON public.%I', current_table, current_table);
    EXECUTE format(
      'CREATE POLICY %I_tenant_delete ON public.%I FOR DELETE TO PUBLIC USING (private.has_organization_access("organizationId"))',
      current_table,
      current_table
    );
  END LOOP;
END $$;

-- Authenticated clients are read-only. The backend runtime receives the
-- narrowly required DML privileges and remains subject to FORCE RLS.
DO $$
DECLARE
  current_table text;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA public TO authenticated';
    FOREACH current_table IN ARRAY ARRAY[
      'cost_groups',
      'cost_items',
      'cost_structure_version_counters',
      'cost_structures',
      'cost_structure_lines',
      'cost_calculations',
      'costing_gamma_settings',
      'costing_gamma_groups'
    ] LOOP
      EXECUTE format('GRANT SELECT ON TABLE public.%I TO authenticated', current_table);
    END LOOP;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_runtime') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA public TO app_runtime';
    FOREACH current_table IN ARRAY ARRAY[
      'cost_groups',
      'cost_items',
      'cost_structure_version_counters',
      'cost_structures',
      'cost_structure_lines',
      'costing_gamma_settings',
      'costing_gamma_groups'
    ] LOOP
      EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO app_runtime', current_table);
    END LOOP;
    -- Calculation snapshots are append-only: no UPDATE/DELETE privilege.
    EXECUTE 'GRANT SELECT, INSERT ON TABLE public.cost_calculations TO app_runtime';
  END IF;
END $$;
