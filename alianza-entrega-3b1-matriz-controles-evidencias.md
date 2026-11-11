# Entrega 3B.1.5 — Matriz de controlos e evidências

**Projeto:** Alianza — Sistema de Custos  
**Role:** `alianza_audit_ro`  
**Estado:** revisão documental; nenhuma consulta foi executada.

## Matriz consolidada

| Controlo | Evidência no SQL | Resultado que reprova | Resultado que torna `INDETERMINADA` |
|---|---|---|---|
| Identidade | Etapas 4 e 13: `current_user`, `session_user` | Identidade diferente de `alianza_audit_ro` | Falha ou visibilidade insuficiente de `pg_roles` |
| Atributos | Etapas 5 e 13: `rolsuper`, `rolcreatedb`, `rolcreaterole`, `rolreplication`, `rolbypassrls`, `rolinherit` | Qualquer atributo perigoso ativo | Role não visível ou consulta falha |
| Memberships | Etapas 6, 8A e 13: `pg_auth_members`, grafo recursivo e opções | Membership direta/indireta não autorizada, inclusive sem `SET ROLE` | `pg_auth_members` incompleto, colunas de opções ausentes ou consulta falha |
| `SET ROLE` | Etapas 6, 8A e 13: `pg_has_role(..., 'SET')` para todas as roles | Possibilidade de assumir qualquer role não autorizada, inclusive `pg_*` | Assinatura incompatível, role não visível ou catálogo incompleto |
| `search_path` | Etapa 2 comentada: `search_path = pg_catalog`; referências externas qualificadas | Configuração aprovada diferente ou schema externo não qualificado | Não foi possível confirmar a configuração efetiva |
| Database e schemas | Etapa 7 e `schema_state`: `CREATE`, `TEMPORARY`, `USAGE` | `CREATE` no database/schema; `TEMPORARY` não documentado | Schema não visível ou privilege check indisponível |
| Privilégios por relação | Etapa 10 e `relation_state`: tabelas, partições, views, materialized views e foreign tables | Escrita ou `SELECT` fora do escopo autorizado | Relações não visíveis ou inventário truncado |
| Privilégios por coluna | Consulta `has_column_privilege` e `has_any_column_privilege` | `SELECT`, `INSERT`, `UPDATE` ou `REFERENCES` não autorizado por coluna | Falha de função, coluna não visível ou relação incompleta |
| Sequences | Etapa 7 e `sequence_state`: `USAGE`, `SELECT`, `UPDATE` | Qualquer privilégio operacional, especialmente `UPDATE` | Sequences não visíveis ou catálogo incompleto |
| Large Objects | Etapa 9B e `large_object_state`: OID, owner, ACL, PUBLIC, memberships e `has_large_object_privilege` | Leitura ou alteração não autorizada | Catálogo/função ausente, invisível ou incompatível |
| Funções executáveis | Etapa 9A e `executable_function_state` | Função com efeito perigoso comprovado | Função executável sem revisão individual baseada em evidências; linguagem/implementação não verificável |
| `SECURITY DEFINER` | `security_definer_state`, `pg_depend`, owner tree e inventário de definição | Owner/membership privilegiada com caminho de risco comprovado | Owner, ACL, `search_path`, dependências ou definição sem visibilidade/revisão |
| Extensões e linguagens | Etapas 9A e 9C: extensão de origem, linguagem, validator, owner e ACL | Owner/privilégio perigoso confirmado | Linguagem externa, C/internal ou extensão sem implementação/revisão suficiente |
| FDW e foreign servers | Etapa 9C: `pg_foreign_data_wrapper`, `pg_foreign_server` | Ownership ou ACL perigoso | Catálogo/ACL não disponível |
| Event triggers | Etapa 9C: owner, evento, enabled, handler | Ownership indevido ou handler perigoso comprovado | Owner/handler não verificável |
| Publications/subscriptions | Etapa 9C: owner e propriedades, sem conninfo | Ownership ou privilégio indevido | Catálogo ausente, campos incompatíveis ou owner não verificável |
| Ownership geral | `ownership_state` e inventários | `alianza_audit_ro` é owner de qualquer objeto relevante | Categoria não inventariada ou owner não visível |
| Default ACLs | Etapa 8: `pg_default_acl`, owner/schema/tipo/grantee/privilégio | Exposição futura não autorizada quando coberta pela política | `pg_default_acl` não visível ou resultado incompleto |
| Migrations | Etapa 11 e `has_migration_select` | `SELECT` em outras tabelas de `supabase_migrations` | Histórico não legível ou sessão diferente da role auditada |
| RLS | Etapa 10: `relrowsecurity`, `relforcerowsecurity`, policies | `BYPASSRLS` ou privilégio não autorizado | Policy/catálogo não visível |
| Read-only transacional | Etapa 12 e `transaction_read_only_ok` | `transaction_read_only` desligado | Falha de `SHOW`, `BEGIN`/`ROLLBACK` ou estado não observável |
| Integridade do inventário | Contagens, ausência de limites arbitrários e regras do plano | Conclusão baseada em inventário truncado | Timeout, falha de statement, transporte truncado ou visibilidade parcial |

## Estados finais

- **`REPROVADA`**: existe uma condição de segurança comprovadamente violada.
- **`INDETERMINADA`**: um controlo obrigatório não foi comprovado, há incompatibilidade de versão, falha de consulta ou visibilidade insuficiente.
- **`APROVACAO_CONDICIONAL_TEMPORARY`**: todos os controlos foram comprovados, mas `TEMPORARY` permanece efetivo e o risco foi formalmente aceite.
- **`APROVADA`**: todos os controlos obrigatórios foram comprovados, sem `TEMPORARY` efetivo e sem lacunas relevantes.

A ausência de evidência nunca é tratada como evidência de ausência.

## Registo obrigatório de revisão individual de funções

Para cada função executável, o registo externo deve conter:

1. assinatura;
2. owner;
3. linguagem;
4. `SECURITY DEFINER` ou `SECURITY INVOKER`;
5. `EXECUTE` efetivo e proveniência;
6. definição/implementação disponível;
7. extensão de origem;
8. dependências e limitações de `pg_depend`;
9. efeitos possíveis e chamadas indiretas;
10. resultado da revisão;
11. justificativa baseada em evidências;
12. responsável e data da revisão.

O SQL não executa funções e não transforma uma classificação manual sem evidências em aprovação.
