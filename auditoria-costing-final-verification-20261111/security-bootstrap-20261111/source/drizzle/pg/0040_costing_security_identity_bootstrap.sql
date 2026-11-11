-- Incremental security bootstrap for databases that already applied 0039.
-- Re-applies the fail-closed identity-separated Costing RLS definition.
-- Costing RLS: identities are deliberately separated.
-- authenticated -> auth.uid() -> public.users.supabaseAuthId
-- app_runtime -> trusted transaction-local request.app_user_id
-- This migration fails closed when the Supabase auth dependency is absent.

DO $$
BEGIN
  IF to_regclass('public.users') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regprocedure('auth.uid()') IS NULL THEN
    RAISE EXCEPTION
      'Costing RLS requires public.users, public.organization_members and auth.uid()';
  END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.current_authenticated_user_id()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.id
  FROM public.users AS u
  WHERE u."supabaseAuthId" = auth.uid()
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION private.current_app_runtime_user_id()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.id
  FROM public.users AS u
  WHERE u.id = NULLIF(current_setting('request.app_user_id', true), '')::integer
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION private.has_authenticated_organization_access(target_organization_id varchar)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.organization_members AS membership
    WHERE membership."organizationId" = target_organization_id
      AND membership."userId" = private.current_authenticated_user_id()
      AND membership.status = 'active'
  )
$$;

CREATE OR REPLACE FUNCTION private.has_app_runtime_organization_access(target_organization_id varchar)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.organization_members AS membership
    WHERE membership."organizationId" = target_organization_id
      AND membership."userId" = private.current_app_runtime_user_id()
      AND membership.status = 'active'
  )
$$;

REVOKE ALL ON FUNCTION private.current_authenticated_user_id() FROM PUBLIC, anon, authenticated, app_runtime;
REVOKE ALL ON FUNCTION private.current_app_runtime_user_id() FROM PUBLIC, anon, authenticated, app_runtime;
REVOKE ALL ON FUNCTION private.has_authenticated_organization_access(varchar) FROM PUBLIC, anon, authenticated, app_runtime;
REVOKE ALL ON FUNCTION private.has_app_runtime_organization_access(varchar) FROM PUBLIC, anon, authenticated, app_runtime;

GRANT USAGE ON SCHEMA private TO authenticated, app_runtime;
GRANT EXECUTE ON FUNCTION private.current_authenticated_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_authenticated_organization_access(varchar) TO authenticated;
GRANT EXECUTE ON FUNCTION private.current_app_runtime_user_id() TO app_runtime;
GRANT EXECUTE ON FUNCTION private.has_app_runtime_organization_access(varchar) TO app_runtime;

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
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated, app_runtime', current_table);

    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_select ON public.%I', current_table, current_table);
    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_insert ON public.%I', current_table, current_table);
    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_update ON public.%I', current_table, current_table);
    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_delete ON public.%I', current_table, current_table);
    EXECUTE format('DROP POLICY IF EXISTS %I_authenticated_select ON public.%I', current_table, current_table);
    EXECUTE format('DROP POLICY IF EXISTS %I_app_runtime_select ON public.%I', current_table, current_table);
    EXECUTE format('DROP POLICY IF EXISTS %I_app_runtime_insert ON public.%I', current_table, current_table);
    EXECUTE format('DROP POLICY IF EXISTS %I_app_runtime_update ON public.%I', current_table, current_table);
    EXECUTE format('DROP POLICY IF EXISTS %I_app_runtime_delete ON public.%I', current_table, current_table);

    EXECUTE format(
      'CREATE POLICY %I_authenticated_select ON public.%I FOR SELECT TO authenticated USING (private.has_authenticated_organization_access("organizationId"))',
      current_table, current_table
    );
    EXECUTE format(
      'CREATE POLICY %I_app_runtime_select ON public.%I FOR SELECT TO app_runtime USING (private.has_app_runtime_organization_access("organizationId"))',
      current_table, current_table
    );
    EXECUTE format(
      'CREATE POLICY %I_app_runtime_insert ON public.%I FOR INSERT TO app_runtime WITH CHECK (private.has_app_runtime_organization_access("organizationId"))',
      current_table, current_table
    );
    IF current_table <> 'cost_calculations' THEN
      EXECUTE format(
        'CREATE POLICY %I_app_runtime_update ON public.%I FOR UPDATE TO app_runtime USING (private.has_app_runtime_organization_access("organizationId")) WITH CHECK (private.has_app_runtime_organization_access("organizationId"))',
        current_table, current_table
      );
      EXECUTE format(
        'CREATE POLICY %I_app_runtime_delete ON public.%I FOR DELETE TO app_runtime USING (private.has_app_runtime_organization_access("organizationId"))',
        current_table, current_table
      );
    END IF;
  END LOOP;
END $$;

GRANT USAGE ON SCHEMA public TO authenticated, app_runtime;
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
    'costing_gamma_settings',
    'costing_gamma_groups'
  ] LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO app_runtime', current_table);
  END LOOP;
  GRANT SELECT, INSERT ON TABLE public.cost_calculations TO app_runtime;
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
END $$;
