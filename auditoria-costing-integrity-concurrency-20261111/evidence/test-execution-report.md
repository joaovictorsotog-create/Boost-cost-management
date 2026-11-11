# D. Execução dos testes — relatório independente

As saídas integrais foram preservadas nos ficheiros desta pasta:

- `targeted-tests.txt`
- `typecheck.txt`
- `prettier.txt`
- `diff-check.txt`
- `postgres-harness.txt`
- `postgres-extra-org-structure-and-final-state.txt`
- `full-suite.txt`

## Testes direcionados

Comando:

```bash
pnpm exec vitest run server/domain/costing/engine.test.ts server/domain/costing/snapshot.test.ts server/routers/costing.test.ts
```

Resultado real: **52/52 testes aprovados**.

- engine: 28 testes;
- snapshots: 6 testes;
- router: 18 testes.

## TypeScript

Comando:

```bash
pnpm check
```

Resultado real: **EXIT_CODE=0**.

## Prettier

Comando preservado em `commands.txt`.

Resultado real: **todos os ficheiros verificados usam o estilo Prettier**.

## Diff check

Comando:

```bash
git diff --check b9fc34b1c58b5bb76d104ebeddf4675c88dec536..e110f98b8298d7732e3424e4b84da09df9bad9ca
```

Resultado real: **EXIT_CODE=0**.

## PostgreSQL descartável

Comando:

```bash
scripts/run-costing-correction-pg.sh
```

Resultado real: **EXIT_CODE=0**.

Foram demonstrados snapshots, lifecycle DRAFT, rollback, dez criações concorrentes no mesmo item, dez criações em escopos diferentes, publicação concorrente e operações SQL diretas nos triggers.

A execução adicional, baseada temporariamente no executor auditado, também passou e produziu `simultaneous-org-structure-protection-ok`, a consulta SQL final e `active_count = 1`.

## Suíte geral

Comando:

```bash
pnpm test
```

Resultado real: **837/839 testes aprovados; 2 falhas externas**.

Falha 1:

```text
server/app-runtime-password.contract.test.ts
expected 204, received 503
```

Causa observada: configuração da role `app_runtime` ausente no ambiente de teste.

Falha 2:

```text
server/supabase-server-client.contract.test.ts
expected isServerSupabaseConfigured=true, received false
```

Causa observada: configuração pública Supabase ausente no ambiente de teste.

Nenhum teste de Costing falhou. As saídas completas, incluindo stack traces e contagens, estão em `full-suite.txt`.
