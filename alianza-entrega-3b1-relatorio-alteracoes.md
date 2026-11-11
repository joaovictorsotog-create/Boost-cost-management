# Entrega 3B.1.5 — Relatório de alterações e compatibilidade

**Projeto:** Alianza — Sistema de Custos  
**Role proposta:** `alianza_audit_ro`  
**Escopo:** revisão exclusivamente documental e estática; nenhum comando foi enviado ao Supabase.

## 1. Alterações em relação à 3B.1.3

1. O `search_path` proposto foi restringido para `pg_catalog`; referências a `information_schema` e `supabase_migrations` permanecem qualificadas.
2. Foi adicionado inventário de Large Objects usando `pg_largeobject_metadata`, ACLs, `PUBLIC`, grants diretos, memberships e privilégios efetivos de `SELECT`/`UPDATE`.
3. Foi adicionado inventário de FDWs, foreign servers, event triggers, publications, subscriptions e linguagens, sem executar handlers, publishers, subscribers ou validadores.
4. A análise foi ampliada de `SECURITY DEFINER` para todas as funções executáveis, incluindo `SECURITY INVOKER`, funções de extensões e linguagens `internal`, `c` e externas.
5. Foi adicionado inventário de dependências via `pg_depend`, com a limitação explícita de que chamadas dinâmicas podem não aparecer.
6. A decisão final incorpora Large Objects, funções executáveis não verificáveis e ownership das categorias externas.
7. A decisão final mantém `INDETERMINADA` quando uma função executável não tiver revisão individual baseada em evidências.
8. A cobertura de ownership foi ampliada para Large Objects, FDWs, foreign servers, event triggers, publications, subscriptions e linguagens.
9. O plano passou a distinguir ACLs efetivos de objetos existentes e default ACLs aplicáveis apenas a objetos futuros.
10. Foi corrigida a numeração das etapas novas do SQL para evitar etapas duplicadas.
11. Foram criadas a matriz de controlos/evidências e este relatório.

## 2. Compatibilidade por versão PostgreSQL

A versão real de produção não foi consultada nesta revisão. A primeira execução autorizada deve registrar `server_version` e `server_version_num`; a tabela abaixo é uma matriz de pré-verificação, não uma confirmação do ambiente.

| Recurso | Expectativa estática | Condição de execução |
|---|---|---|
| `pg_has_role(..., 'SET'/'USAGE')` | Disponível em versões modernas e anteriores, mas a assinatura deve ser comprovada | Falha ou assinatura incompatível: `INDETERMINADA` |
| `pg_auth_members.roleid/member/admin_option` | Estrutura histórica | Catálogo/coluna não visível: `INDETERMINADA` |
| `inherit_option` e `set_option` em `pg_auth_members` | Recursos associados a versões recentes, esperados a partir do PostgreSQL 16 | Ausência não pode ser substituída por `rolinherit`; `INDETERMINADA` |
| `pg_proc.prokind` | Necessário pelo SQL para separar funções, procedures e aggregates; requer PostgreSQL moderno | Se ausente, o SQL deve parar e o resultado é `INDETERMINADA` |
| `pg_largeobject_metadata` | Catálogo de Large Objects em PostgreSQL moderno | Catálogo ausente/invisível: `INDETERMINADA` |
| `has_large_object_privilege` | Deve ser confirmada na versão real | Função ausente ou assinatura incompatível: `INDETERMINADA` |
| `pg_foreign_data_wrapper` e `pg_foreign_server` | Recursos FDW | Catálogo ou ACL não verificável: `INDETERMINADA` |
| `pg_event_trigger` | Recurso de event triggers | Catálogo/campos incompatíveis: `INDETERMINADA` |
| `pg_publication` e `pg_subscription` | Recursos de logical replication introduzidos em versões modernas | Em versões sem estes catálogos, a cobertura deve ser marcada como não disponível e a aprovação fica `INDETERMINADA` até decisão explícita |
| `pg_language` e ACLs de linguagens | Catálogo estrutural | Owner/ACL/linguagem não visível: `INDETERMINADA` |
| `pg_default_acl` | Catálogo de defaults futuros | Ausência de visibilidade: `INDETERMINADA`; não representa ACL retroativo |
| `aclexplode`/`acldefault` | Funções de inspeção de ACL | Falha ou tipo de objeto não suportado: `INDETERMINADA` |

O SQL não presume PostgreSQL 16 ou superior. A versão real deve ser registada antes de interpretar qualquer resultado.

## 3. Limitações conhecidas

- O SQL não foi executado e, portanto, não há evidência sobre a versão, catálogos ou privilégios reais de produção.
- A role comum pode não visualizar todos os memberships, owners, ACLs ou definições de funções.
- `pg_depend` não revela necessariamente chamadas dinâmicas ou efeitos externos.
- `default_transaction_read_only` não impede automaticamente efeitos externos de funções.
- Event triggers, publications e subscriptions não possuem exatamente o mesmo modelo de ACL das relações; owner e propriedades são verificados, e lacunas impedem aprovação.
- Large Objects podem estar sujeitos a visibilidade ou funções de privilégio específicas da versão.
- Inventários transportados com truncamento, timeout ou limite externo não podem fundamentar `APROVADA`.
- Não há leitura de dados operacionais além do histórico explicitamente autorizado de migrations.

## 4. Consultas que determinam cada estado

### `REPROVADA`

A etapa 13 emite `REPROVADA` quando encontra identidade/atributos inválidos, membership ou `SET ROLE` não autorizado, `CREATE`, escrita relacional, `SELECT` fora do escopo, privilégios em sequences, leitura/escrita em Large Objects, ownership, risco comprovado de `SECURITY DEFINER` ou `transaction_read_only` desligado.

### `INDETERMINADA`

A etapa 13 emite `INDETERMINADA` quando faltam opções de membership, visibilidade catalogal, `SELECT` do histórico, revisão individual de qualquer função executável, definição/linguagem verificável, catálogos de Large Objects/objetos externos ou integridade do inventário.

Além disso, qualquer erro de execução, timeout, incompatibilidade de versão ou truncamento do cliente deve ser tratado como `INDETERMINADA`, mesmo que a consulta consolidada não seja alcançada.

### `APROVACAO_CONDICIONAL_TEMPORARY`

Só pode ocorrer depois de todos os controlos anteriores serem comprovados e quando o único risco remanescente for `TEMPORARY`, formalmente documentado e aceite.

### `APROVADA`

Só pode ocorrer quando todos os controlos obrigatórios forem comprovados, cada função executável relevante tiver revisão baseada em evidências, não houver Large Object privilegiado, não houver ownership ou lacunas de visibilidade e `TEMPORARY` não for efetivo.

## 5. Integridade da entrega

Todos os comandos administrativos continuam comentados. Não foram executados `CREATE ROLE`, `ALTER ROLE`, `GRANT`, `REVOKE`, DDL, DML, migrations, execução de funções ou conexão de produção.
