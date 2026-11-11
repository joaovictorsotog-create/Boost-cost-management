# Entrega 3B.1.8 — Matriz de cenários executados

Todos os cenários abaixo devem executar a consulta SQL real da Etapa 13 em uma instância PostgreSQL local descartável. O resultado observado é capturado pelo teste automatizado.

| # | Cenário | Resultado esperado |
|---:|---|---|
| 1 | Todos os controles aprovados, sem TEMPORARY | `APROVADA` |
| 2 | SHA-256 apresentado diferente do calculado | `INDETERMINADA` |
| 3 | Definição/revisão stale após mudança de snapshot | `INDETERMINADA` |
| 4 | Função com revisão individual válida | sem bloqueio de revisão |
| 5 | Procedure com revisão individual válida | sem bloqueio de revisão |
| 6 | Aggregate com representação canônica e revisão válida | sem bloqueio de revisão |
| 7 | Aggregate executável sem revisão | `INDETERMINADA` |
| 8 | Categoria executável sem evidência verificável | `INDETERMINADA` |
| 9 | Metadado de identidade/owner/language alterado | `INDETERMINADA` |
| 10 | TEMPORARY ausente | `APROVADA` quando os demais controles passam |
| 11 | TEMPORARY com aceitação incompleta | `INDETERMINADA` |
| 12 | TEMPORARY com aceitação válida e rastreável | `APROVACAO_CONDICIONAL_TEMPORARY` |
| 13 | `transaction_read_only` desligado | `REPROVADA` |
| 14 | risco crítico de privilégio/ownership | `REPROVADA` |
| 15 | catálogo ou inventário não verificável | `INDETERMINADA` |

A suíte também registra a versão PostgreSQL, os bytes usados no cálculo externo, o snapshot de sessão e os hashes dos arquivos publicados. Nenhum cenário usa Supabase, mocks de catálogos ou uma cópia Python da decisão.
