# Alianza Costing — Final Verification 2026-11-11

Pacote exclusivamente documental da rodada final de verificação de concorrência e migrations. O pacote foi publicado no repositório `joaovictorsotog-create/Boost-cost-management`, preservando os pacotes de auditoria anteriores.

## Proveniência

- Repositório da aplicação: `joaovictorsotog-create/alianza-ai-platform`
- SHA-base: `0fe7df0bcd6412b90bd3bd1d5be2341a7408fb69`
- Branch local de trabalho: `costing-final-verification-20261111`
- SHA final local: `357fc3226dc784964679c6ce611eaee2f0f9d76b`
- Pai do SHA final: `0fe7df0bcd6412b90bd3bd1d5be2341a7408fb69`
- Branch documental anterior: `audit-costing-final-stabilization-20261111`
- Branch documental desta rodada: `audit-costing-final-verification-20261111`

A branch da aplicação não foi enviada ao GitHub. Não foram executadas migrations, operações SQL, deploys, alterações de RLS, roles, grants, policies ou secrets em produção.

## Correção entregue

A rodada encontrou e corrigiu uma divergência real no pipeline: o Drizzle não carregava o schema Costing e o journal PostgreSQL não registrava `0036–0038`. A configuração foi corrigida, as três migrations foram registradas em ordem e a sequência foi executada duas vezes num PostgreSQL descartável.

A auditoria também adicionou provas com sessões independentes para INSERT, UPDATE, DELETE e movimentação de linhas, em duas ordens de concorrência, além de duas chamadas reais a `publishCostStructure` e um cenário de itens independentes.

## Índice

```text
artifacts/
  commit-357fc32.patch
  verification-round.patch
files/
  drizzle.pg.config.ts
  drizzle/pg/meta/_journal.json
  scripts/costing-final-verification-pg.ts
  scripts/costing-publish-worker.ts
  scripts/run-costing-final-verification-pg.sh
evidence/
  application-git-state.txt
  costing-complete-harness.txt
  final-review.md
  full-suite.txt
  initial-state.txt
  migration-pipeline-report.md
  postgres-verification-harness.txt
  targeted-tests.txt
  validation-commands.txt
manifest.sha256
```

## Rodada Security Bootstrap & CRUD

A subpasta [`security-bootstrap-20261111/`](security-bootstrap-20261111/) documenta o commit local `3350e6e884be85b410d31e5ca9e6d133b643bf7f`, baseado em `d9ff4dd7024674c54af128e4bdc816a0b459e22a`. Ela responde explicitamente às sete perguntas obrigatórias, demonstra a fronteira `auth.uid()` versus `request.app_user_id`, cobre o CRUD de grupos/itens e inclui a migration incremental `0040`. A publicação da RLS em produção continua **pending**; a branch da aplicação não foi enviada.

## Resultados resumidos

- Testes Costing direcionados: **52/52 aprovados**.
- Harness PostgreSQL final: **aprovado**.
- Quatro operações de mutação em duas ordens: **aprovadas**.
- Publicação pelo serviço real: **aprovada**, com serialização coerente no mesmo item.
- Publicação de itens independentes: **aprovada**, com PIDs distintos e sobreposição temporal.
- Runner Drizzle: **aprovado** para `0000`, `0001`, `0036`, `0037`, `0038`.
- Segunda execução pelo journal: **sem hashes adicionais**.
- Harness Costing completo, incluindo rollback: **aprovado**.
- Suíte geral: **837/839 testes aprovados**; as duas falhas são as dependências externas já conhecidas de `app_runtime` e configuração Supabase pública.

## Limitações

O journal global continua sem as migrations históricas `0002–0035`. Esta rodada comprova e corrige a sequência Costing `0036–0038`, mas não declara reconciliação completa de toda a história PostgreSQL do projeto. RLS, roles, grants, policies, integração e produção continuam fora de autorização.

Consulte [`evidence/final-review.md`](evidence/final-review.md) para a matriz aprovado/reprovado/não comprovado e [`evidence/migration-pipeline-report.md`](evidence/migration-pipeline-report.md) para a auditoria do journal.

## Integridade

Os hashes de todos os artefactos, exceto este README, o próprio manifesto e o ficheiro autorreferente `evidence/manifest-sha256.txt`, estão em [`manifest.sha256`](manifest.sha256). O hash SHA-256 do manifesto é `80a359ff42b9c9b55bdf3daf5a90a635de328d9acc14c9f094006c20bd808fd3`.
