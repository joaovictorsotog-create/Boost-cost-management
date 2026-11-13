# Entrega 3B.1.13 — Correção final da policy SELECT RLS de app_runtime

## Status

**Correção aplicada e validada em PostgreSQL descartável.** Não houve push da aplicação, PR, merge, rebase, cherry-pick, deploy, migration persistente, conexão Supabase ou produção.

## Proveniência da aplicação

- Branch local: `costing-security-preflight-final-20261112`
- SHA inicial desta rodada: `16fde337f707734fbca13ac311f1ebe2d01a2472`
- Pai do SHA inicial: `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285`
- SHA final local: `ecbd686b2c58c46ec7c114c07e3bf22fdfbab028`
- Pai do SHA final: `16fde337f707734fbca13ac311f1ebe2d01a2472`
- Working tree após o commit: limpa

O patch completo entre o SHA inicial e o SHA final está em
`alianza-entrega-3b1-13-diff-correcao-rls.patch` e contém somente os dois arquivos da correção. Seu tamanho é 3.310 bytes e seu SHA-256 é `4ec805e3ebc7f90e8b2e98f00ef9b161049f38d96e68b515702e64ef4dc2b918`.

## Defeito corrigido

O bloco Costing já concedia `SELECT` a `app_runtime`, mas possuía apenas a policy `costing_tenant_read` para `authenticated`. A correção adiciona, para cada uma das sete tabelas:

```sql
create policy costing_app_runtime_read on public.%I
  for select to app_runtime
  using (private.has_organization_access("organizationId"));
```

A policy é tenant-scoped e usa a mesma função auxiliar das operações de inserção, atualização e exclusão. Nenhuma policy `TO PUBLIC` foi criada.

Também foi corrigido o privilégio das funções auxiliares:

```sql
revoke all on schema private from public, anon, authenticated, app_runtime;
grant usage on schema private to authenticated, app_runtime;
revoke all on function private.current_app_user_id() from public, anon, authenticated, app_runtime;
revoke all on function private.has_organization_access(varchar) from public, anon, authenticated, app_runtime;
grant execute on function private.current_app_user_id() to authenticated, app_runtime;
grant execute on function private.has_organization_access(varchar) to authenticated, app_runtime;
```

`authenticated` continua usando `auth.uid()` porque `current_app_user_id()` só consulta `request.app_user_id` quando `session_user = 'app_runtime'`. `cost_calculations` continua com somente SELECT/INSERT para `app_runtime`; UPDATE/DELETE são bloqueados por ausência de grant e RLS, além do trigger de imutabilidade existente.

## Teste PostgreSQL real

O harness iniciou PostgreSQL 16 descartável, criou as roles `app_runtime`, `authenticated` e `anon`, conectou diretamente com `-U app_runtime` e registrou:

```text
session_user | current_user
-------------+--------------
app_runtime  | app_runtime
```

Não foi usado `SET ROLE` para simular o runtime.

Resultados observados:

- sete tabelas com RLS habilitado e forçado: PASS;
- policy `costing_app_runtime_read` presente nas sete tabelas: PASS;
- `private` USAGE para `app_runtime`: `true`;
- EXECUTE do helper para `app_runtime`: `true`;
- EXECUTE do helper para `public`: `false`;
- EXECUTE do helper para `anon`: `false`;
- leitura dos sete conjuntos de dados na própria organização: PASS;
- leitura da organização alheia: zero registros, PASS;
- INSERT/UPDATE/DELETE autorizados em grupos, itens, estruturas, linhas e configuração Gama: PASS;
- UPDATE de snapshot: bloqueado por `permission denied`;
- DELETE de snapshot: bloqueado por `permission denied`;
- `authenticated` com JWT da organização A e `request.app_user_id=2`: leu somente A, PASS;
- `authenticated` sem JWT: zero registros, PASS;
- `anon`: `permission denied`, PASS;
- segunda aplicação do SQL RLS: PASS, idempotente;
- `postgresql_rls_correction=PASS`.

O SQL/harness e o log completo desta execução estão nos arquivos documentais desta entrega.

## Testes locais executados nesta rodada

- Testes direcionados Costing/RLS/identidade/preflight: **9 arquivos, 78 testes, PASS**.
- `pnpm check`: PASS.
- `prettier --check server/supabase-rls.contract.test.ts`: PASS.
- `git diff --check`: PASS.
- Harness PostgreSQL descartável com conexões reais: PASS.

Não foi executado E2E HTTP real nem autenticação via navegador. Os resultados acima não devem ser descritos como E2E.

## Revisão das sete tabelas

As sete tabelas usam a função `private.has_organization_access("organizationId")` em todas as policies tenant-scoped:

| Tabela | authenticated SELECT | app_runtime SELECT | app_runtime INSERT | app_runtime UPDATE/DELETE | Resultado próprio/alheio |
|---|---|---|---|---|---|
| `cost_groups` | `costing_tenant_read` | `costing_app_runtime_read` | Sim, com `with check` | Sim, com `using`/`with check` | 1 / 0 |
| `cost_items` | `costing_tenant_read` | `costing_app_runtime_read` | Sim, com `with check` | Sim, com `using`/`with check` | 1 / 0 |
| `cost_structures` | `costing_tenant_read` | `costing_app_runtime_read` | Sim, com `with check` | Sim, com `using`/`with check` | 1 / 0 |
| `cost_structure_lines` | `costing_tenant_read` | `costing_app_runtime_read` | Sim, com `with check` | Sim, com `using`/`with check` | 1 / 0 |
| `cost_calculations` | `costing_tenant_read` | `costing_app_runtime_read` | Sim, com `with check` | Sem grant/policy; trigger preservado | 1 / 0 |
| `costing_gamma_settings` | `costing_tenant_read` | `costing_app_runtime_read` | Sim, com `with check` | Sim, com `using`/`with check` | 1 / 0 |
| `costing_gamma_groups` | `costing_tenant_read` | `costing_app_runtime_read` | Sim, com `with check` | Sim, com `using`/`with check` | 1 / 0 |

## Limitações

A validação é PostgreSQL local descartável e não substitui uma chamada HTTP real no ambiente de produção. Não houve conexão Supabase, execução de migration persistente, deploy ou validação de grants administrados externamente.

O Costing não é declarado aprovado para produção. Esta rodada fecha a lacuna específica de leitura RLS do `app_runtime` e deixa evidência reproduzível.
