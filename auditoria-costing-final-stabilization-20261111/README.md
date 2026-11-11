# Rodada final de estabilização — Alianza Costing

## Proveniência

- Repositório da aplicação: `joaovictorsotog-create/alianza-ai-platform`
- Branch de origem: `costing-integrity-concurrency-round-20261111`
- Commit-base: `e110f98b8298d7732e3424e4b84da09df9bad9ca`
- Branch final local: `costing-final-stabilization-20261111`
- Commit final local: `0fe7df0bcd6412b90bd3bd1d5be2341a7408fb69`
- Pai do commit final: `e110f98b8298d7732e3424e4b84da09df9bad9ca`
- Repositório documental: `joaovictorsotog-create/Boost-cost-management`
- Branch documental: `audit-costing-final-stabilization-20261111`
- Branch documental de origem: `audit-costing-integrity-concurrency-20261111`

A branch da aplicação foi criada a partir do commit-base exato, verificada limpa antes da edição e permaneceu sem push. O diff final contém cinco ficheiros.

## Árvore do pacote

```text
artifacts/
├── changed-files.txt
└── costing-final-stabilization.patch
files/
├── drizzle/pg/0038_costing_final_stabilization.sql
├── scripts/costing-correction-pg.ts
├── scripts/costing-line-publication-race-pg.ts
├── scripts/run-costing-correction-pg.sh
├── server/db/costing.ts
└── reference/
    ├── docs/costing-rls-proposal.md
    ├── drizzle/pg/schema.costing.ts
    ├── server/domain/costing/engine.test.ts
    ├── server/domain/costing/snapshot.test.ts
    ├── server/domain/costing/snapshot.ts
    ├── server/routers/costing.test.ts
    └── server/routers/costing.ts
evidence/
├── commands.txt
├── counter-locking-analysis.md
├── diff-check.txt
├── final-review-and-pendencies.md
├── full-suite.txt
├── postgres-harness.txt
├── prettier.txt
├── provenance-git.txt
├── shell-syntax.txt
├── targeted-tests.txt
├── test-execution-report.md
└── typecheck.txt
manifest.sha256
README.md
```

Os ficheiros em `files/reference/` estavam inalterados no diff final, mas foram incluídos integralmente para permitir revisão conjunta do schema, motor, snapshots, router, testes e proposta RLS.

## Correções realizadas

1. O contador agora retorna exatamente `MAX(version)+1` na primeira criação e mantém armazenada a próxima versão disponível. Foram removidos os saltos artificiais causados pelo incremento duplo.
2. A reserva do contador e o INSERT da estrutura permanecem na mesma transação; rollback real após a reserva não consome versão.
3. A migration `0038_costing_final_stabilization.sql` reconcilia contadores existentes, substitui o trigger de linhas por validação com locks `FOR UPDATE` e é idempotente.
4. A publicação usa `READ COMMITTED`, bloqueia target e ACTIVE em ordem determinística e revalida o status depois da espera pelos locks.
5. Foi adicionado teste PostgreSQL com duas sessões independentes e `pg_backend_pid()` para corrida entre edição de linha e publicação.
6. O harness executa a migration final duas vezes, testa estados de contador vazios/existentes/lacunares, concorrência, rollback e estado final SQL.

As regras de cálculo, conversões, Gama, arredondamento, permissões existentes e snapshots não foram alteradas.

## Resultados reais

- Testes direcionados do motor, snapshots e router: **52/52 aprovados**.
- TypeScript: **aprovado**.
- Prettier: **aprovado**.
- `git diff --check`: **aprovado**.
- Sintaxe shell: **aprovada**.
- Harness PostgreSQL descartável: **aprovado**.
- Casos de contador: `1`, `2`, `4`, rollback seguido de `2`.
- Dez criações concorrentes no mesmo item: `6..15`.
- Criações em itens e organizações diferentes: aprovadas.
- Corrida de linhas/publicação: dois PIDs distintos, linha antes da publicação confirmada, linha após publicação rejeitada.
- Publicação concorrente: resultados individuais verificados e estado final com exatamente uma ACTIVE.
- Suíte geral: **837/839**, com duas falhas externas de configuração documentadas integralmente.

## Pendências e riscos

- **RLS permanece pendente:** não foram criadas policies, grants ou `FORCE ROW LEVEL SECURITY`. O isolamento por tenant na aplicação está coberto pelo router, mas não existe ainda uma segunda barreira SQL para acesso direto ao banco.
- **Integração operacional das migrations:** `0038` é idempotente e passou duas aplicações no harness, mas o pipeline real deve confirmar o registro/aplicação dos ficheiros `0036`/`0037`/`0038`, pois o journal PostgreSQL local não os lista.
- O teste com PIDs independentes cobre a corrida linha/publicação diretamente no banco. Ainda não existe um teste com dois processos independentes chamando simultaneamente a função TypeScript `publishCostStructure`; essa é uma melhoria de cobertura, não uma falha observada do invariant SQL.
- Uma prova adicional de dois movimentos simultâneos de linhas entre DRAFTs, com timeout controlado, é recomendável para elevar a evidência de ausência de deadlocks.

## Manifesto

O manifesto SHA-256 cobre **26 artefactos** em `artifacts/`, `files/` e `evidence/`.

SHA-256 do manifesto:

```text
a41009063d065efdf59cccd061af4675c6038a7a18015d6b8724b2c3ae0cdf71
```

O próprio `manifest.sha256` e este README são excluídos do manifesto para evitar circularidade. Todos os artefactos técnicos exportados estão cobertos.

Este pacote é documental. Não constitui aprovação da implementação para integração ou produção. Nenhuma migration, operação de banco, deploy, alteração de roles/grants ou acesso a produção foi executado.
