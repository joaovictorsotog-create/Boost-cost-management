# Execução final dos testes

As saídas integrais estão preservadas nesta pasta:

- `targeted-tests.txt`
- `typecheck.txt`
- `prettier.txt`
- `diff-check.txt`
- `shell-syntax.txt`
- `postgres-harness.txt`
- `full-suite.txt`

## Resultados

### Testes direcionados

```bash
pnpm exec vitest run server/domain/costing/engine.test.ts server/domain/costing/snapshot.test.ts server/routers/costing.test.ts
```

Resultado: **52/52 aprovados**.

### TypeScript

```bash
pnpm check
```

Resultado: **EXIT_CODE=0**.

### Prettier

Todos os ficheiros TypeScript/documentação verificados passaram no Prettier.

### Shell e diff

```bash
bash -n scripts/run-costing-correction-pg.sh
git diff --check
```

Ambos passaram.

### PostgreSQL descartável

```bash
scripts/run-costing-correction-pg.sh
```

Resultado: **EXIT_CODE=0**.

O harness passou por:

- migration final aplicada duas vezes;
- contador vazio, existente, lacunar e por tenant;
- dez criações concorrentes no mesmo item com versões `6..15`;
- rollback artificial e rollback real depois da reserva;
- corrida linha/publicação com dois PIDs independentes;
- snapshots e Gama;
- publicação concorrente;
- imutabilidade direta de estruturas e linhas;
- estado final consultado diretamente por SQL.

Resultado principal:

```json
{"edgeCaseVersions":{"empty":1,"singleExisting":2,"nonContiguous":4,"afterRollback":2},"counterBeforeConcurrency":6,"tenConcurrentVersions":[6,7,8,9,10,11,12,13,14,15],"scopedConcurrentCreations":10,"concurrentPublication":["fulfilled","fulfilled"],"rollback":"ok"}
```

### Suíte geral

```bash
pnpm test
```

Resultado: **837/839 testes aprovados; 2 falhas externas**.

Falhas não pertencentes à rodada:

1. `server/app-runtime-password.contract.test.ts`: configuração da role `app_runtime` ausente, recebeu `503` em vez de `204`.
2. `server/supabase-server-client.contract.test.ts`: configuração pública Supabase ausente, `isServerSupabaseConfigured=false`.

Nenhum teste Costing falhou. A saída integral e os stack traces estão em `full-suite.txt`.
