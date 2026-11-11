# Relatório de validação — Costing completion

## Alterações validadas

- Migration incremental `0039_costing_rls_security.sql` no journal PostgreSQL.
- RLS físico e grants mínimos nas oito tabelas Costing.
- Script oficial `apply-supabase-rls.mjs` aplica o RLS geral e Costing.
- CRUD tenant-scoped de grupos e itens no DB/router Costing.
- Removida execução duplicada da migration `0038` no harness de correção.

## Execuções

### Typecheck e testes focados

Comandos:

```text
pnpm check
pnpm exec vitest run server/domain/costing/engine.test.ts server/domain/costing/snapshot.test.ts server/routers/costing.test.ts
```

Resultado: **52/52 testes aprovados** em 3 ficheiros.

### PostgreSQL Costing

Comando:

```text
scripts/run-costing-correction-pg.sh
```

Resultado: aprovado. A evidência inclui custo exacto `50.6`, Gamma `0.6`,
lifecycle DRAFT → ACTIVE, rollback `ok`, dez versões concorrentes `[6..15]`,
publicação concorrente e proteção de estruturas/linhas publicadas.

### PostgreSQL runner e concorrência final

Comando:

```text
scripts/run-costing-final-verification-pg.sh
```

Resultado: aprovado em cluster descartável. O runner foi executado duas vezes,
criou seis entradas de journal (`0000`, `0001`, `0036`, `0037`, `0038`, `0039`),
criou as oito tabelas Costing e passou as corridas independentes de INSERT,
UPDATE, DELETE e MOVE contra publicação, além de publicação concorrente para o
mesmo item e para itens independentes.

### RLS A/B

Comando:

```text
scripts/run-costing-rls-pg.sh
```

Resultado: `COSTING_RLS_TEST=PASS`. O teste confirmou oito tabelas com
`ENABLE/FORCE RLS`, leitura isolada por organização, bloqueio de mutações
cross-tenant, authenticated read-only, app_runtime sem superuser/BYPASSRLS e
snapshots append-only.

### Suíte geral

Comando:

```text
pnpm test
```

Resultado: **229 ficheiros aprovados, 2 ficheiros falharam, 837 testes
aprovados e 2 falharam**. As duas falhas são externas a esta rodada:

- `server/app-runtime-password.contract.test.ts`: esperado HTTP 204, recebido
  503;
- `server/supabase-server-client.contract.test.ts`: configuração pública de
  Supabase ausente no ambiente de teste.

Não foram mascaradas nem corrigidas por esta rodada.

## Limitações e decisão

A cadeia histórica PostgreSQL pré-Costing permanece incompleta no repositório:
`0016` PostgreSQL está ausente, há tags numéricos duplicados e `0002` depende
de `public.rls_auto_enable()` que não possui definição local. O relatório de
reconciliação documenta a baseline necessária para ambientes existentes. Não
houve reconstrução especulativa, acesso a produção, migration remota, deploy ou
alteração de banco persistente.

Este relatório não declara a implementação global aprovada; registra apenas os
resultados reproduzíveis desta rodada em ambiente descartável.
