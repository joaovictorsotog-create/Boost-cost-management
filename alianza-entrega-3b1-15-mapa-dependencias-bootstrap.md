# Mapa de dependências do bootstrap PostgreSQL

## Cadeia base

```text
0000 baseline
 ├─ organizations
 ├─ users
 └─ organization_members
       │
       ├─ 0001: users.supabaseAuthId UNIQUE
       ├─ helpers private.* / auth.uid()
       └─ 0036_costing_foundation
             ├─ cost_groups
             ├─ cost_items → cost_groups
             ├─ cost_structures → cost_items
             ├─ cost_structure_lines → structures/items
             ├─ cost_calculations → items/structures
             ├─ costing_gamma_settings → organizations
             └─ costing_gamma_groups → groups
```

## Dependências do RLS global

`drizzle/pg/rls_multitenant.sql` pressupõe:

- schema `public` e tabelas gerais já instaladas;
- `public.users`, `organizations` e `organization_members`;
- roles `authenticated` e `app_runtime`;
- `auth.uid()` resolvível;
- funções `private.current_app_user_id()` e `private.has_organization_access()`;
- possibilidade de alterar grants, RLS e policies em tabelas de módulos diversos;
- funções históricas opcionais detectáveis por `to_regprocedure`.

O bloco global também referencia `public.rls_auto_enable()` para revogar execução, mas essa função não foi definida em nenhum arquivo localizado. Isso é uma dependência não resolvida: `REVOKE ALL ON FUNCTION` falha se a função não existir.

## Dependências de identidade

```text
auth JWT sub
  → public.users.supabaseAuthId
  → public.organization_members.userId
  → organizationId
  → private.has_organization_access()
  → RLS authenticated/app_runtime
```

Para `app_runtime`, o código usa `request.app_user_id` e valida a role sem `BYPASSRLS`/superuser. Isso depende de configuração de sessão PostgreSQL e de grants coerentes.

## Dependências do preflight

```text
VITE_SUPABASE_URL + SUPABASE_DATABASE_URL
  → validação de project ref/hostname
  → normalização pooler Supabase
  → execução transacional do rls_multitenant.sql
```

O preflight pode impedir conexão com destino não autorizado, mas não resolve dependências ausentes do schema e não reduz o payload global ao Costing.

## Dependências de código não refletidas em uma cadeia única

- `schema.budgets.ts` e `schema.catalog.ts` dependem de migrations históricas que não aparecem no journal atual.
- `schema.costing.ts` está presente e coerente com `0036` em linhas gerais, mas `0036` não está no journal.
- O backend usa Supabase Auth, `app_runtime` e helpers de tenancy que exigem objetos fora das sete tabelas Costing.
- A separação entre `drizzle.config.ts` (MySQL) e `drizzle.pg.config.ts` (PostgreSQL) exige seleção explícita de comando/configuração; não há um comando único universal seguro para ambos.
