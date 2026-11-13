# Entrega 3B.1.13 — Matriz RLS corrigida das sete tabelas Costing

Função auxiliar comum: `private.has_organization_access("organizationId")`.

| Tabela | authenticated | app_runtime SELECT | app_runtime INSERT | app_runtime UPDATE | app_runtime DELETE | Própria | Alheia |
|---|---|---|---|---|---|---:|---:|
| `cost_groups` | SELECT por `costing_tenant_read` | `costing_app_runtime_read` | `costing_app_runtime_insert` | `costing_app_runtime_update` | `costing_app_runtime_delete` | 1 | 0 |
| `cost_items` | SELECT por `costing_tenant_read` | `costing_app_runtime_read` | `costing_app_runtime_insert` | `costing_app_runtime_update` | `costing_app_runtime_delete` | 1 | 0 |
| `cost_structures` | SELECT por `costing_tenant_read` | `costing_app_runtime_read` | `costing_app_runtime_insert` | `costing_app_runtime_update` | `costing_app_runtime_delete` | 1 | 0 |
| `cost_structure_lines` | SELECT por `costing_tenant_read` | `costing_app_runtime_read` | `costing_app_runtime_insert` | `costing_app_runtime_update` | `costing_app_runtime_delete` | 1 | 0 |
| `cost_calculations` | SELECT por `costing_tenant_read` | `costing_app_runtime_read` | `costing_app_runtime_insert` | Não concedido | Não concedido | 1 | 0 |
| `costing_gamma_settings` | SELECT por `costing_tenant_read` | `costing_app_runtime_read` | `costing_app_runtime_insert` | `costing_app_runtime_update` | `costing_app_runtime_delete` | 1 | 0 |
| `costing_gamma_groups` | SELECT por `costing_tenant_read` | `costing_app_runtime_read` | `costing_app_runtime_insert` | `costing_app_runtime_update` | `costing_app_runtime_delete` | 1 | 0 |

## Privilégios de schema e funções

| Objeto | `public` | `anon` | `authenticated` | `app_runtime` |
|---|---|---|---|---|
| Schema `private` USAGE | Revogado | Revogado | Concedido | Concedido |
| `private.current_app_user_id()` EXECUTE | Revogado | Revogado | Concedido | Concedido |
| `private.has_organization_access(varchar)` EXECUTE | Revogado | Revogado | Concedido | Concedido |

Não existe policy `TO PUBLIC`. `anon` não recebeu SELECT nas tabelas Costing nem EXECUTE dos helpers.

## Resultados PostgreSQL observados

A role foi aberta diretamente como `app_runtime`, preservando `session_user=app_runtime` e `current_user=app_runtime`. Para cada uma das sete tabelas, o harness observou uma linha da organização própria e zero linhas da organização alheia.

As escritas autorizadas foram executadas em grupos, itens, estruturas, linhas e configuração/seleção da Gama. Snapshots aceitaram leitura e inserção, mas UPDATE e DELETE falharam com `permission denied for table cost_calculations`. A role `authenticated` usou `auth.uid()` mesmo quando `request.app_user_id` apontava para outro usuário. Sem JWT, a leitura retornou zero; `anon` recebeu `permission denied`.
