# Auditoria independente — Costing Integrity & Concurrency Round

## Proveniência

- Repositório da aplicação: `joaovictorsotog-create/alianza-ai-platform`
- Branch auditada: `costing-integrity-concurrency-round-20261111`
- Commit-base: `b9fc34b1c58b5bb76d104ebeddf4675c88dec536`
- Commit final auditado: `e110f98b8298d7732e3424e4b84da09df9bad9ca`
- Branch documental: `audit-costing-integrity-concurrency-20261111`
- Branch documental de origem: `audit-costing-reconstruction-20261111`
- Repositório documental: `joaovictorsotog-create/Boost-cost-management`

A verificação local confirmou que o HEAD auditado e o pai correspondem aos SHAs acima, que a working tree da aplicação estava limpa e que o diff contém somente cinco ficheiros da rodada.

## Árvore

```text
artifacts/
├── changed-files.txt
└── costing-integrity-concurrency.patch
files/
├── drizzle/pg/0037_costing_correction_integrity.sql
├── drizzle/pg/schema.costing.ts
├── scripts/costing-correction-pg.ts
├── scripts/run-costing-correction-pg.sh
└── server/db/costing.ts
evidence/
├── commands.txt
├── concurrent-publication-analysis.md
├── diff-check.txt
├── full-suite.txt
├── postgres-extra-command.txt
├── postgres-extra-org-structure-and-final-state.txt
├── postgres-harness.txt
├── prettier.txt
├── provenance-git.txt
├── targeted-tests.txt
├── test-execution-report.md
├── trigger-integrity-analysis.md
├── typecheck.txt
└── version-counter-analysis.md
manifest.sha256
README.md
```

## Artefactos

- `artifacts/costing-integrity-concurrency.patch`: diff binário integral entre base e commit auditado.
- `artifacts/changed-files.txt`: lista de caminhos e estados Git.
- `files/`: blobs integrais extraídos diretamente do commit `e110f98...`, mantendo os caminhos originais.
- `evidence/provenance-git.txt`: status, log, proveniência, diff stat e diff check.
- `evidence/version-counter-analysis.md`: análise do contador, SQL, retry, concorrência e salto inicial observado.
- `evidence/trigger-integrity-analysis.md`: SQL integral dos triggers, matriz e operações testadas.
- `evidence/concurrent-publication-analysis.md`: publicação concorrente, estado final e limitações de instrumentação.
- `evidence/test-execution-report.md`: resumo dos comandos e resultados reais.
- `evidence/*.txt`: saídas integrais dos comandos executados.
- `manifest.sha256`: SHA-256 dos 21 artefactos em `artifacts/`, `files/` e `evidence/`.

SHA-256 do manifesto:

```text
b6790da6964324054e0b35c86aabb6e8c5e0b7df3c94c32b2357781d18ef254c
```

O manifesto exclui deliberadamente `README.md` e o próprio `manifest.sha256` para evitar circularidade. Todos os artefactos técnicos exportados estão cobertos pelo manifesto.

## Resultados principais

- Testes direcionados: 52/52 aprovados.
- TypeScript: aprovado.
- Prettier: aprovado.
- `git diff --check`: aprovado.
- Harness PostgreSQL descartável: aprovado.
- Dez criações concorrentes no mesmo item: versões observadas `7..16`, todas únicas e sequenciais.
- Dez criações concorrentes em dois itens/organizações: concluídas.
- Publicação concorrente: uma transação aprovada e uma rejeitada; estado final com exatamente uma ACTIVE.
- Testes SQL diretos de imutabilidade: aprovados.
- Suíte geral: 837/839; duas falhas externas de configuração documentadas em `evidence/full-suite.txt`.

## Respostas às questões obrigatórias

1. **Por que as versões foram 7 a 16?** As fixtures tinham estruturas nas versões 1 a 4. A migration semeou `nextVersion=5`; a primeira criação encontrou o contador existente e incrementou antes de retornar, produzindo a versão 6. As dez criações seguintes retornaram 7 a 16. A versão 5 ficou sem utilização.
2. **Quais versões existiam antes?** Existiam as estruturas 1, 2, 3 e 4. A versão 6 foi criada pelo próprio fluxo antes do lote de dez; a versão 5 foi apenas o valor inicial do contador e não foi materializada.
3. **O contador é inicializado ou reconciliado com MAX(version)?** A migration inicializa/reconcilia linhas existentes com `MAX(version)+1` e `GREATEST` em conflito. A criação usa `MAX(version)+1` somente no INSERT da linha do contador; em conflito, incrementa a linha existente. A interação causa o salto inicial identificado e fica como pendência.
4. **Alteração simultânea de organizationId e structureId escapa?** Não na prova adicional. Um UPDATE direto alterando os dois campos foi rejeitado por `cannot change organization`; a função também valida o destino. A evidência está em `postgres-extra-org-structure-and-final-state.txt`.
5. **A publicação usa conexões independentes?** As transações são independentes no nível do `db.transaction` e foram iniciadas em paralelo pelo pool PostgreSQL. Porém, o harness não captura `pg_backend_pid()` nem usa uma barreira explícita; a quantidade exata de conexões físicas não pode ser comprovada neste pacote.
6. **A transação rejeitada deixa alterações residuais?** Não foi observado estado parcial: a consulta final encontrou exatamente uma ACTIVE e nenhum estado inválido. O conteúdo das linhas das DRAFTs concorrentes não foi comparado por checksum; essa prova específica permanece pendente.
7. **O retry repete a transação inteira?** Sim. `createCostStructure` chama `createCostStructureOnce`, que abre a transação, valida o item, lê MAX, reserva o contador e insere a estrutura. Em `40001` ou `40P01`, a transação inteira é repetida, no máximo três vezes. O contador e a estrutura ficam na mesma transação e são revertidos juntos; não há efeitos externos entre elas.

## Pendências

- Eliminar ou justificar formalmente o salto inicial causado por `MAX(version)+1` combinado com o primeiro `ON CONFLICT DO UPDATE`.
- Instrumentar `pg_backend_pid()` e uma barreira explícita para provar o número de conexões físicas independentes na publicação concorrente.
- Adicionar checksum/comparação de linhas para provar diretamente que a transação de publicação rejeitada não alterou conteúdo de linhas.
- RLS continua pendente conforme as rodadas anteriores.

Este pacote é exclusivamente documental. Não constitui aprovação da implementação para integração ou produção.
