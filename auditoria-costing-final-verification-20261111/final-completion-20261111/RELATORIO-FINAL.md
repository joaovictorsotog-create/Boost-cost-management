# Auditoria final — Alianza Costing

**Repositório:** `joaovictorsotog-create/alianza-ai-platform`  
**Branch:** `costing-completion-20261111`  
**Commit-base:** `357fc3226dc784964679c6ce611eaee2f0f9d76b`  
**HEAD antes do commit documental:** `357fc3226dc784964679c6ce611eaee2f0f9d76b`

## Parecer

**APTO COM RESSALVAS para auditoria de integração.**

A rodada apresenta evidências reproduzíveis para o domínio Costing, RLS
PostgreSQL incremental, lifecycle de estruturas, concorrência, rollback e
isolamento entre organizações em bancos descartáveis. Não é aprovação de
produção e não é instalação completa do Alianza.

As principais ressalvas são a cadeia histórica PostgreSQL incompleta, ausência
de uma migration PostgreSQL `0016`, tags históricas duplicadas, dependência
histórica de `public.rls_auto_enable()` sem definição local, ausência de um
E2E HTTP/app real cobrindo todos os passos e duas falhas externas na suíte geral.

## Preservação e proveniência

- O remote configurado é `https://github.com/joaovictorsotog-create/alianza-ai-platform.git`.
- A branch verificada é `costing-completion-20261111`.
- O HEAD é exatamente o commit-base informado e o base é ancestral do HEAD.
- Não existem ficheiros removidos.
- Existem sete alterações rastreadas e quatro ficheiros novos antes do pacote.
- Todas pertencem ao escopo Costing/RLS, harnesses ou documentação desta
  rodada; não foram identificadas alterações alheias.
- Não houve push, merge, PR, deploy, acesso a produção ou banco persistente.

O diff integral da rodada está em
`artifacts/diff-completo-rodada.patch`. Ele foi gerado comparando o commit-base
com as alterações de aplicação e os quatro ficheiros novos, excluindo apenas a
pasta documental criada por esta auditoria para evitar autorreferência.

## Auditoria da migration 0039 e RLS

A migration `source/0039_costing_rls_security.sql` enumera explicitamente oito
tabelas:

1. `cost_groups`
2. `cost_items`
3. `cost_structure_version_counters`
4. `cost_structures`
5. `cost_structure_lines`
6. `cost_calculations`
7. `costing_gamma_settings`
8. `costing_gamma_groups`

Para cada tabela, o código efetivo executa `ENABLE ROW LEVEL SECURITY` e
`FORCE ROW LEVEL SECURITY`, remove grants de `PUBLIC` e, quando existem, de
`anon` e `authenticated`, e cria policies de `SELECT`, `INSERT`, `UPDATE` e
`DELETE`.

- `SELECT` usa `USING (private.has_organization_access("organizationId"))`.
- `INSERT` usa `WITH CHECK` com a mesma função.
- `UPDATE` usa `USING` e `WITH CHECK`.
- `DELETE` usa `USING`.
- `app_runtime` recebe DML nas tabelas de cadastro, estruturas, linhas,
  contadores e Gamma.
- `app_runtime` recebe apenas `SELECT, INSERT` em `cost_calculations`.
- `authenticated` recebe `SELECT` quando a role existe.
- Não há `GRANT` para `anon`.
- A migration não cria nem promove roles a `SUPERUSER` ou `BYPASSRLS`.

As funções `private.current_app_user_id()` e
`private.has_organization_access(varchar)` são `SECURITY DEFINER`, com
`search_path = public`, e têm execução revogada de `PUBLIC`. A função canónica
em `source/rls_multitenant.sql` resolve primeiro `request.app_user_id` e, para
clientes autenticados, usa `auth.uid()` como fallback. O fallback de 0039 é
bootstrap-safe e destina-se ao runner Costing descartável; a aplicação oficial
executa primeiro o SQL canónico e depois 0039.

### Matriz de acesso observada

| Tabela/operação | `authenticated` | `app_runtime` | Sem membership tenant | Observação observada |
|---|---|---|---|---|
| Todas as 8 / SELECT | permitido apenas via grant e policy | permitido via grant e policy | negado por policy | A/B confirmou isolamento |
| Todas as 8 / INSERT | negado por grant | permitido no tenant | negado por `WITH CHECK` | Testado no harness RLS |
| Todas as 8 / UPDATE | negado por grant | permitido no tenant, sujeito a triggers | negado por `USING/WITH CHECK` | Testado cross-tenant |
| Todas as 8 / DELETE | negado por grant | permitido no tenant, sujeito a triggers | negado por `USING` | Testado cross-tenant |
| `cost_calculations` / UPDATE | negado por grant | negado por ausência de grant | negado | snapshot append-only |
| `cost_calculations` / DELETE | negado por grant | negado por ausência de grant | negado | snapshot append-only |
| Estrutura publicada / alteração | grant pode existir para `app_runtime` | trigger rejeita | negado | mensagem de imutabilidade observada |
| Linha publicada / alteração | grant pode existir para `app_runtime` | trigger rejeita | negado | corrida publication/mutation testada |

O harness RLS A/B criou duas organizações, duas memberships e fixtures
separados. Observou oito tabelas protegidas, leitura isolada, escritas
cross-tenant rejeitadas, `authenticated` read-only e `app_runtime` sem
`SUPERUSER`/`BYPASSRLS`. O resultado foi `COSTING_RLS_TEST=PASS`.

Não foi possível auditar privilégios herdados de um ambiente Supabase real,
porque não há catálogo remoto nem roles persistentes nesta rodada. O harness
cria `app_runtime` como `NOINHERIT NOBYPASSRLS`; o deployment real deve ser
verificado separadamente.

## Auditoria do CRUD e autorização

O router `source/costing-router.ts` passa sempre por
`requireTenantPermission(ctx.user.id, input.organizationId, permission)` antes
de chamar o DB. `requireTenantPermission` procura membership pelo par
`organizationId/userId` e verifica as permissões efetivas no servidor. A
manipulação de um ID de outro tenant não atravessa essa barreira e as queries
DB repetem a condição por organização.

Procedures verificadas:

- `groups`: lista grupos tenant-scoped;
- `createGroup`: cria grupo com `workspace.manage`;
- `items`: lista itens tenant-scoped;
- `createItem`: cria item, unidade e preço manual, validando `groupId` no mesmo
  tenant;
- `setItemActive`: ativa/desativa item com `workspace.manage`;
- estruturas e linhas: create/update/delete somente DRAFT;
- publicação: exige `workspace.manage`;
- cálculo, Gamma e snapshots: exigem `costing.read`.

O schema preserva o histórico: estruturas e snapshots referenciam itens com
`ON DELETE RESTRICT`; linhas publicadas e snapshots são protegidos por triggers
e grants. Não existe procedure de exclusão física de item, nem procedure de
edição de grupo/item ou edição do preço manual após criação nesta rodada. A
“gestão” implementada para itens é listagem, criação e ativação/desativação;
estas lacunas permanecem explícitas e não foram mascaradas como CRUD completo.

Os testes do router cobrem autorização de leitura, negação de escrita sem
`workspace.manage`, tenant incorreto, cadastro de grupo/item, ativação e
encaminhamento de lifecycle DRAFT. São testes com mocks de serviço, não são
prova E2E de banco.

## Instalação em banco vazio

### Runner Drizzle Costing

Comando:

```text
scripts/run-costing-final-verification-pg.sh
```

Estado inicial: cluster PostgreSQL temporário novo, sem tabelas Costing e sem
schema `drizzle`. O runner aplicou a cadeia registada no journal:

```text
0000 -> 0001 -> 0036 -> 0037 -> 0038 -> 0039
```

Criou as oito tabelas Costing e o schema de migrations. A segunda execução
foi bem-sucedida e idempotente. O log completo está em
`evidence/final-verification-pg.log`.

Isto é uma instalação específica e parcial do Costing, não uma instalação
completa do Alianza. O banco descartável foi usado somente para prova local;
não é Supabase nem produção.

### RLS A/B

Comando:

```text
scripts/run-costing-rls-pg.sh
```

O script usa outro cluster descartável, cria roles e fixtures de teste, aplica
o runner e executa as verificações A/B. O log está em
`evidence/final-verification-pg.log` e a implementação do harness em
`source/run-costing-rls-pg.sh`.

### Problemas históricos

A árvore ainda não contém `0016` PostgreSQL. Há tags numéricos duplicados
(`0007`, `0021`, `0027`, `0032`) e `0002` referencia
`public.rls_auto_enable()`, cuja definição não foi localizada. Um ensaio de
execução estrita dos SQL históricos parou em `0002` por essa ausência.
Nenhuma migration foi inventada, renumerada ou reescrita.

## Fluxo integrado de ponta a ponta

A evidência realmente executada cobre o domínio e o banco descartável, mas não
um fluxo HTTP completo do frontend até o banco com autenticação Supabase real.

| Etapa | Estado | Evidência |
|---|---|---|
| Autenticação Supabase real | NÃO EXECUTADO | Não havia credenciais/ambiente remoto |
| Identificação real da organização | PARCIAL | `requireTenantPermission` em mocks; membership no harness RLS |
| Permissões server-side | EXECUTADO | `costing-router.test.ts` e harness A/B |
| Grupos | PARCIAL | CRUD de criação/listagem em router mockado; não E2E |
| Itens e preço manual | PARCIAL | criação/listagem/ativação; não E2E |
| Unidades e conversões | EXECUTADO | testes do motor Costing |
| Estruturas DRAFT | EXECUTADO | harness PostgreSQL |
| Inclusão/alteração/exclusão de linhas | EXECUTADO | harness Costing e corrida final |
| Cálculo de custos | EXECUTADO | 28 testes do motor + harness |
| Gamma | EXECUTADO | testes direcionados + harness |
| Publicação | EXECUTADO | harness Costing e publicação concorrente |
| Snapshots | EXECUTADO | snapshots persistidos e append-only |
| Imutabilidade | EXECUTADO | triggers SQL e corrida mutation/publication |
| Nova versão | EXECUTADO | versões vazia, existente, não contígua e rollback |
| Concorrência | EXECUTADO | dez criações e workers independentes |
| Isolamento entre organizações | EXECUTADO | harness RLS A/B |
| Operações negadas | EXECUTADO | cross-tenant, grants, triggers e permissões |

Não se deve converter os testes unitários mockados em alegação de E2E.

## Testes e falhas

| Comando | Resultado |
|---|---|
| `pnpm check` | aprovado |
| Vitest motor/snapshot/router | 52 aprovados, 0 reprovados |
| `scripts/run-costing-correction-pg.sh` | aprovado; rollback `ok`, versões 6–15, publicação concorrente |
| `scripts/run-costing-final-verification-pg.sh` | aprovado; runner duas vezes e 8 corridas mutation/publication |
| `scripts/run-costing-rls-pg.sh` | aprovado; `COSTING_RLS_TEST=PASS` |
| `pnpm test` | 229 ficheiros aprovados, 2 reprovados; 837 testes aprovados, 2 reprovados |

As duas falhas gerais continuam externas a esta rodada:

1. `server/app-runtime-password.contract.test.ts`: endpoint interno retornou
   `503` onde o contrato esperava `204`.
2. `server/supabase-server-client.contract.test.ts`: configuração pública
   Supabase ausente, `isServerSupabaseConfigured` falso.

Elas não foram ignoradas, enfraquecidas ou alteradas pela rodada. O log
completo está em `evidence/full-suite.log`.

## Riscos técnicos reais

1. A cadeia PostgreSQL completa do Alianza não é reprodutível a partir da
   árvore atual sem recuperar fontes históricas ausentes.
2. A função fallback de 0039 usa `request.app_user_id`; o deployment deve usar
   o helper canónico com `auth.uid()` e proteger a forma como o contexto é
   definido pelo runtime.
3. O CRUD de itens não possui edição de preço/grupo nem exclusão física; isto é
   uma limitação funcional explícita, não uma aprovação de CRUD completo.
4. O fluxo HTTP/frontend autenticado contra Supabase não foi executado.
5. A suíte geral ainda falha nos dois contratos ambientais descritos acima.

## Artefatos

A pasta contém:

- este relatório executivo;
- `artifacts/diff-completo-rodada.patch`;
- migration 0039 e SQL canónico de contexto;
- script oficial de aplicação RLS;
- router, DB e testes do Costing;
- harnesses PostgreSQL e RLS;
- logs das execuções;
- reconciliação histórica;
- resultados da suíte geral;
- `manifest.sha256`.

O pacote não inclui credenciais, URLs privadas, `.env`, dumps de produção ou
bundle Git. O manifesto cobre todos os artefatos do pacote, exceto o próprio
manifesto e este relatório quando o hash autorreferente seria impossível.

## Estado final

Após o commit local documental:

- branch: `costing-completion-20261111`;
- commit-base: `357fc3226dc784964679c6ce611eaee2f0f9d76b`;
- commit final local da aplicação: `d9ff4dd7024674c54af128e4bdc816a0b459e22a`;
- working tree: deverá ficar limpa;
- push: não realizado;
- main: não alterada;
- produção: não acessada.
