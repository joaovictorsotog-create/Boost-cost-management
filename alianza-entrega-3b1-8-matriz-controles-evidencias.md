# Entrega 3B.1.8 — Matriz de controles e evidências

| Controle | Implementação 3B.1.8 | Evidência/teste | Falha resultante |
|---|---|---|---|
| SHA-256 efetivo | Bytes UTF-8, origem, snapshot, hash calculado externamente e hash apresentado reconciliados; divergência invalida | `sha_divergente` retornou `has_stale_function_review = t` | `INDETERMINADA` |
| Identidade individual | schema, nome, argumentos, tipo, owner, linguagem, segurança e extensão | `revisao_valida_f_p_a` com inventário real | ausência/alteração: `INDETERMINADA` |
| `f`/`p` | `pg_get_functiondef` | funções e procedure locais revisadas | sem revisão: `INDETERMINADA` |
| `a` | metadados canônicos de `pg_aggregate` | `aggregate_sem_revisao` e aggregate válido | sem revisão: `INDETERMINADA` |
| `w` | entrada `pg_proc` e representação canônica apropriada | população `p.prokind IN ('f','p','a','w')`; zero `w` no PG16 local | se existir sem evidência: `INDETERMINADA` |
| Read-only transacional | `transaction_read_only` e `default_transaction_read_only` | fixture local com role configurada | desligado: `REPROVADA` |
| Large Objects | ACL de `pg_largeobject_metadata` compatível com PG16 | execução real da CTE | privilégio indevido: `REPROVADA` |
| Ownership/SECURITY DEFINER | estados anteriores preservados e integrados ao CASE | execução real da Etapa 13 | risco crítico: `REPROVADA` |
| TEMPORARY | entrada externa completa e associada à role/auditoria | aceitação incompleta e válida | sem/incompleta: `INDETERMINADA`; válida: condicional se demais passarem |
| Catálogos, FDW, memberships, PUBLIC, ACLs | CTEs de controle preservadas no SQL completo | consulta real PostgreSQL 16 | indisponibilidade: `INDETERMINADA` |

A consulta final não considera uma linha CSV suficiente: a linha precisa reconciliar a população atual, a identidade completa, a evidência de bytes e o snapshot da sessão.
