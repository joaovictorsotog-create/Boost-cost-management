-- Canonical Alianza RLS helpers. The client identity is only auth.uid();
-- app_runtime identity is only the trusted transaction-local request.app_user_id.

create schema if not exists private;
revoke all on schema private from public;

do $$
begin
  if to_regprocedure('auth.uid()') is null then
    raise exception 'Canonical RLS requires auth.uid()';
  end if;
end $$;

create or replace function private.current_authenticated_user_id()
returns integer
language sql stable security definer set search_path = ''
as $$
  select u.id from public.users as u
  where u."supabaseAuthId" = auth.uid()
  limit 1
$$;

create or replace function private.current_app_runtime_user_id()
returns integer
language sql stable security definer set search_path = ''
as $$
  select u.id from public.users as u
  where u.id = nullif(current_setting('request.app_user_id', true), '')::integer
  limit 1
$$;

create or replace function private.has_authenticated_organization_access(target_organization_id varchar)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.organization_members as membership
    where membership."organizationId" = target_organization_id
      and membership."userId" = private.current_authenticated_user_id()
      and membership.status = 'active'
  )
$$;

create or replace function private.has_app_runtime_organization_access(target_organization_id varchar)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.organization_members as membership
    where membership."organizationId" = target_organization_id
      and membership."userId" = private.current_app_runtime_user_id()
      and membership.status = 'active'
  )
$$;

-- Compatibility for historical policies/functions. New Costing policies never
-- use these names; the session role selects the already-separated identity.
create or replace function private.current_app_user_id()
returns integer
language sql stable security definer set search_path = ''
as $$
  select case when session_user = 'app_runtime'
    then private.current_app_runtime_user_id()
    else private.current_authenticated_user_id()
  end
$$;

create or replace function private.has_organization_access(target_organization_id varchar)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
begin
  if session_user = 'app_runtime' then
    return private.has_app_runtime_organization_access(target_organization_id);
  end if;
  return private.has_authenticated_organization_access(target_organization_id);
end
$$;

revoke all on function private.current_authenticated_user_id() from public, anon, authenticated, app_runtime;
revoke all on function private.current_app_runtime_user_id() from public, anon, authenticated, app_runtime;
revoke all on function private.has_authenticated_organization_access(varchar) from public, anon, authenticated, app_runtime;
revoke all on function private.has_app_runtime_organization_access(varchar) from public, anon, authenticated, app_runtime;
revoke all on function private.current_app_user_id() from public, anon, authenticated, app_runtime;
revoke all on function private.has_organization_access(varchar) from public, anon, authenticated, app_runtime;
grant usage on schema private to authenticated, app_runtime;
grant execute on function private.current_authenticated_user_id() to authenticated;
grant execute on function private.has_authenticated_organization_access(varchar) to authenticated;
grant execute on function private.current_app_runtime_user_id() to app_runtime;
grant execute on function private.has_app_runtime_organization_access(varchar) to app_runtime;
grant execute on function private.current_app_user_id() to authenticated, app_runtime;
grant execute on function private.has_organization_access(varchar) to authenticated, app_runtime;

alter table public.users enable row level security;
alter table public.users force row level security;
revoke all on table public.users from anon, authenticated;
grant select on table public.users to authenticated;
drop policy if exists users_read_self on public.users;
create policy users_read_self on public.users
  for select to authenticated
  using (id = private.current_authenticated_user_id());

-- app_runtime: permite atualizar apenas o nome do próprio utilizador autenticado.
revoke update on table public.users from app_runtime;
grant update (name) on table public.users to app_runtime;
drop policy if exists users_app_runtime_update_self on public.users;
create policy users_app_runtime_update_self on public.users
  for update to app_runtime
  using (id = private.current_app_runtime_user_id())
  with check (id = private.current_app_runtime_user_id());

do $$
declare
  current_table text;
begin
  foreach current_table in array array[
    'ai_agents', 'ai_return_rules', 'ai_runs', 'alerts', 'audit_logs',
    'automation_jobs', 'automations', 'campaign_logs', 'campaign_metrics',
    'campaign_recipients', 'campaigns', 'channels', 'companies', 'contact_tags',
    'contacts', 'conversation_events', 'conversations', 'crm_activities',
    'custom_fields', 'custom_role_permissions', 'custom_roles', 'deals',
    'departments', 'follow_up_rules', 'handoffs', 'integration_configs',
    'kanban_boards', 'kanban_cards', 'kanban_columns', 'knowledge_chunks',
    'knowledge_documents', 'messages', 'organization_access_requests',
    'organization_invitations', 'organization_members',
    'pipeline_stages', 'pipelines', 'prompt_versions', 'service_queues', 'tags',
    'webhook_deliveries', 'webhook_endpoints'
  ]
  loop
    execute format('alter table public.%I enable row level security', current_table);
    execute format('alter table public.%I force row level security', current_table);
    execute format('revoke all on table public.%I from anon, authenticated', current_table);
    execute format('grant select on table public.%I to authenticated', current_table);
    execute format('drop policy if exists tenant_read on public.%I', current_table);
    execute format(
      'create policy tenant_read on public.%I for select to authenticated using (private.has_authenticated_organization_access("organizationId"))',
      current_table
    );
  end loop;
end $$;

alter table public.organizations enable row level security;
alter table public.organizations force row level security;
revoke all on table public.organizations from anon, authenticated;
grant select on table public.organizations to authenticated;
drop policy if exists organization_read on public.organizations;
create policy organization_read on public.organizations
  for select to authenticated
  using (private.has_authenticated_organization_access(id));

-- As operações de convite já passam por RBAC no tRPC. Estas políticas mantêm
-- o limite de tenant no PostgreSQL para a role app_runtime, que herda authenticated.
drop policy if exists organization_invitations_insert on public.organization_invitations;
create policy organization_invitations_insert on public.organization_invitations
  for insert to authenticated
  with check (private.has_authenticated_organization_access("organizationId"));

drop policy if exists organization_invitations_update on public.organization_invitations;
create policy organization_invitations_update on public.organization_invitations
  for update to authenticated
  using (private.has_authenticated_organization_access("organizationId"))
  with check (private.has_authenticated_organization_access("organizationId"));

drop policy if exists organization_invitations_delete on public.organization_invitations;
create policy organization_invitations_delete on public.organization_invitations
  for delete to authenticated
  using (private.has_authenticated_organization_access("organizationId"));

-- A auditoria é gravável apenas para ações já autorizadas dentro do próprio tenant.
drop policy if exists audit_logs_insert on public.audit_logs;
create policy audit_logs_insert on public.audit_logs
  for insert to authenticated
  with check (private.has_authenticated_organization_access("organizationId"));

do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end $$;

-- app_runtime: escrita tenant-scoped para criação de Agents e prompts.
drop policy if exists ai_agents_app_runtime_insert on public.ai_agents;
create policy ai_agents_app_runtime_insert
  on public.ai_agents
  for insert
  to app_runtime
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists prompt_versions_app_runtime_insert on public.prompt_versions;
create policy prompt_versions_app_runtime_insert
  on public.prompt_versions
  for insert
  to app_runtime
  with check (private.has_app_runtime_organization_access("organizationId"));

-- app_runtime: atualização tenant-scoped de Agents e versões de prompt.
drop policy if exists ai_agents_app_runtime_update on public.ai_agents;
create policy ai_agents_app_runtime_update
  on public.ai_agents
  for update
  to app_runtime
  using (private.has_app_runtime_organization_access("organizationId"))
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists prompt_versions_app_runtime_update on public.prompt_versions;
create policy prompt_versions_app_runtime_update
  on public.prompt_versions
  for update
  to app_runtime
  using (private.has_app_runtime_organization_access("organizationId"))
  with check (private.has_app_runtime_organization_access("organizationId"));

-- app_runtime: escrita tenant-scoped do CRM.
drop policy if exists contacts_app_runtime_insert on public.contacts;
create policy contacts_app_runtime_insert
  on public.contacts
  for insert
  to app_runtime
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists contacts_app_runtime_update on public.contacts;
create policy contacts_app_runtime_update
  on public.contacts
  for update
  to app_runtime
  using (private.has_app_runtime_organization_access("organizationId"))
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists companies_app_runtime_insert on public.companies;
create policy companies_app_runtime_insert
  on public.companies
  for insert
  to app_runtime
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists companies_app_runtime_update on public.companies;
create policy companies_app_runtime_update
  on public.companies
  for update
  to app_runtime
  using (private.has_app_runtime_organization_access("organizationId"))
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists crm_activities_app_runtime_insert on public.crm_activities;
create policy crm_activities_app_runtime_insert
  on public.crm_activities
  for insert
  to app_runtime
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists crm_activities_app_runtime_update on public.crm_activities;
create policy crm_activities_app_runtime_update
  on public.crm_activities
  for update
  to app_runtime
  using (private.has_app_runtime_organization_access("organizationId"))
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists pipelines_app_runtime_insert on public.pipelines;
create policy pipelines_app_runtime_insert
  on public.pipelines
  for insert
  to app_runtime
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists pipelines_app_runtime_update on public.pipelines;
create policy pipelines_app_runtime_update
  on public.pipelines
  for update
  to app_runtime
  using (private.has_app_runtime_organization_access("organizationId"))
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists pipeline_stages_app_runtime_insert on public.pipeline_stages;
create policy pipeline_stages_app_runtime_insert
  on public.pipeline_stages
  for insert
  to app_runtime
  with check (private.has_app_runtime_organization_access("organizationId"));

drop policy if exists pipeline_stages_app_runtime_update on public.pipeline_stages;
create policy pipeline_stages_app_runtime_update
  on public.pipeline_stages
  for update
  to app_runtime
  using (private.has_app_runtime_organization_access("organizationId"))
  with check (private.has_app_runtime_organization_access("organizationId"));
