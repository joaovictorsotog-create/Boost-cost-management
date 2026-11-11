# RLS PostgreSQL — Alianza Costing

## Estado

A proteção física do Costing está implementada pela migration incremental
`0039_costing_rls_security.sql`. As migrations históricas anteriores não foram
reescritas. O script `scripts/apply-supabase-rls.mjs` aplica o RLS geral e,
na mesma transação, reaplica a migration Costing de forma idempotente.

## Tabelas protegidas

A migration habilita e força RLS (`ENABLE ROW LEVEL SECURITY` e `FORCE ROW
LEVEL SECURITY`) nas oito tabelas tenant-scoped:

- `cost_groups`
- `cost_items`
- `cost_structure_version_counters`
- `cost_structures`
- `cost_structure_lines`
- `cost_calculations`
- `costing_gamma_settings`
- `costing_gamma_groups`

Todas as policies usam `private.has_organization_access("organizationId")`.
A função verifica uma membership ativa para o utilizador identificado por
`request.app_user_id`. Quando `rls_multitenant.sql` é aplicado no ambiente
Supabase, a implementação canónica da função também considera `auth.uid()`.

## Grants e invariantes

- `authenticated` recebe apenas `SELECT`, quando a role existe.
- `app_runtime` recebe DML nas tabelas de cadastro, estruturas, linhas,
  contadores e Gamma, sempre sujeito a RLS e aos triggers de lifecycle.
- `app_runtime` recebe apenas `SELECT, INSERT` em `cost_calculations`;
  snapshots não podem ser atualizados ou removidos.
- `anon` não recebe privilégios nas tabelas Costing.
- A role `app_runtime` deve continuar com `rolsuper = false` e
  `rolbypassrls = false`; a readiness da aplicação verifica essas condições.

As policies são tenant-scoped para SELECT, INSERT, UPDATE e DELETE. As
restrições de lifecycle — DRAFT editável, ACTIVE/SUPERSEDED/INACTIVE imutáveis
e linhas congeladas após publicação — permanecem nos triggers `0037`/`0038`.

## Autorização de produto

RLS não substitui o router tRPC. O router exige:

- `costing.read` para listas, consulta de estruturas, cálculo e snapshots;
- `workspace.manage` para cadastro de grupos/itens, alteração de ativo,
  criação/edição de estruturas e linhas e publicação.

O módulo agora oferece procedures tenant-scoped para `groups`, `createGroup`,
`items`, `createItem` e `setItemActive`, além do lifecycle de estruturas.

## Evidência descartável

`scripts/run-costing-rls-pg.sh` executa duas vezes o runner Drizzle num cluster
local vazio e verifica:

1. oito tabelas com RLS habilitado e forçado;
2. leitura de uma organização sem visibilidade da outra;
3. INSERT/UPDATE/DELETE cross-tenant rejeitados;
4. leitura autenticada tenant-scoped;
5. escrita autenticada rejeitada por grant;
6. snapshot append-only;
7. roles sem superuser/BYPASSRLS;
8. policies presentes nas oito tabelas.

O teste foi executado com `COSTING_RLS_TEST=PASS`. Não usa Supabase, produção,
credenciais externas ou banco persistente.

## Limitações remanescentes

Este teste comprova o mecanismo PostgreSQL com `app_runtime` e a identidade
`request.app_user_id`, mas não é um teste HTTP contra Supabase Auth. A
validação de `auth.uid()` depende de aplicar o `rls_multitenant.sql` canónico
no ambiente Supabase e deve ser repetida em homologação autorizada.

A role base `supervisor` e `agent` continua sem `costing.read` por decisão
explícita do RBAC atual; custom roles podem receber a permissão. A publicação
continua condicionada a `workspace.manage`.

A árvore PostgreSQL ainda contém artefactos históricos `0002–0035` fora do
journal Drizzle e não existe uma migration PostgreSQL autoritativa `0016`.
Essa lacuna não foi preenchida por uma migration inventada. Ambientes
existentes devem ser validados e baselineados separadamente antes de qualquer
replay; bancos vazios devem usar uma cadeia canónica futura que preserve os
SQL comprovados e trate os nomes duplicados com tags únicas.

Nada nesta documentação autoriza execução em produção ou declara a
implementação global aprovada.
