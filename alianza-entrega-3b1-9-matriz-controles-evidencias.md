# Entrega 3B.1.9 — Matriz de controles e evidências

| Controle | Implementação | Evidência SQL/teste |
|---|---|---|
| Definição atual | Inventário produz `canonical_definition` na mesma sessão | `03_canonical_alterada` falha |
| Bytes atuais | Comparação nativa com `encode(convert_to(...,'UTF8'),'hex')` | `04_bytes_diferentes` falha |
| Hash registrado | SHA-256 esperado e calculado devem coincidir | `05_hash_registrado_adulterado` falha |
| Hash calculado | Hash externo é aceito apenas para bytes canônicos atuais reconciliados | `06_hash_calculado_adulterado` falha |
| Algoritmo/encoding | `hash_algorithm='SHA-256'`, `definition_encoding='UTF-8'` | casos 15 e 18 |
| Snapshot | role e registro devem usar o snapshot da sessão | `07_snapshot_divergente` e `27_temp_snapshot` |
| Identidade | schema, nome, argumentos, tipo, owner, linguagem, segurança e extensão | casos 08, 09, 19 e 20 |
| Duplicidade | agrupamento por identidade/audit/role/snapshot | `10_review_duplicada` |
| Registro órfão | todo registro deve corresponder a objeto atual | `11_registro_inexistente` |
| Campos obrigatórios | auditor, data, evidência, conclusão, risco e campos técnicos | `12_registro_incompleto` |
| Status | somente `APPROVED` íntegro é válido | `13_status_reprovado` |
| Aggregate | representação com campos de `pg_aggregate` | casos 21 e 22 |
| Window function | representação de metadados disponível, sem código inventado | caso 23; ausência de `w` local é observada |
| TEMPORARY | audit_id, role, snapshot, responsável, data, evidência, justificativa, escopo e validade | casos 24–30 |
| Precedência | risco estrutural não é compensado por TEMPORARY | suíte legada de 15 casos + 30 novos |

A saída local continua `INDETERMINADA` quando o fixture não reproduz integralmente os catálogos/propriedades do ambiente produtivo. Nenhuma limitação técnica é convertida em aprovação.
