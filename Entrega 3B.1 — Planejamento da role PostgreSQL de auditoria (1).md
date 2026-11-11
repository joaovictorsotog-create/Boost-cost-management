# Entrega 3B.1.7 — Fechamento da auditoria da role PostgreSQL

**Projeto:** Alianza — Sistema de Custos  
**Ambiente:** Supabase PostgreSQL de produção  
**Role proposta:** `alianza_audit_ro`  
**Estado:** revisão documental final; nenhum comando deste documento foi executado.

## 1. Parecer executivo

O conector Supabase/MCP atual não permite selecionar uma role por argumento nem fornecer uma connection string alternativa. A auditoria 3B só deve ser executada através de uma conexão PostgreSQL independente, autenticada como `alianza_audit_ro`, com `NOBYPASSRLS` e sem privilégios de escrita.

A propriedade `default_transaction_read_only = on` deve ser configurada como defesa adicional, mas não é um controle suficiente: uma role com privilégios de escrita poderia tentar alterar o estado da sessão. A validade da role depende primeiro dos atributos, memberships, ownerships e grants efetivos.

Não reutilizar `postgres`, `supabase_admin`, `service_role`, `app_runtime` ou `supabase_read_only_user`.

## 2. Princípios de desenho

- `LOGIN`, para permitir uma conexão independente.
- `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOREPLICATION`, `NOBYPASSRLS`.
- `NOINHERIT`, como proteção adicional contra memberships futuras.
- Sem ownership de schemas, tabelas, sequences ou funções.
- Sem membership em roles administrativas ou de leitura ampla.
- Sem `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER`, `CREATE` ou `EXECUTE` concedidos pela auditoria.
- Sem leitura indiscriminada de dados operacionais quando os catálogos forem suficientes.
- Uma única conexão simultânea e timeout curto.

## 3. Plano SQL comentado — não executar sem autorização

O conteúdo executável está em `alianza-entrega-3b1-role-auditoria.sql`. As etapas administrativas são separadas para revisão.

### Etapa A — pré-condições administrativas

Antes de criar a role, o administrador deve confirmar:

1. O nome `alianza_audit_ro` não existe.
2. A base alvo é a produção correta.
3. O administrador conhece o procedimento seguro para definir a senha sem a colocar no script, no Git ou na conversa.
4. Não há processo de migração, deploy ou manutenção concorrente que possa confundir a auditoria.
5. A política de retenção e rotação de credenciais foi aprovada.

### Etapa B — criação da role

Criar a role com os atributos mínimos e `NOINHERIT`. A senha deve ser definida pelo administrador através de mecanismo seguro, nunca no arquivo SQL.

A role não deve ser proprietária de nenhum objeto e não deve receber memberships.

### Etapa C — parâmetros de sessão

Configurar:

- `default_transaction_read_only = on`;
- `statement_timeout = '60s'`;
- `lock_timeout = '5s'`;
- `idle_in_transaction_session_timeout = '60s'`;
- `search_path = pg_catalog`.

Esses parâmetros são barreiras operacionais. Não substituem a ausência de privilégios de escrita.

### Etapa D — conectividade e leitura mínima

Conceder apenas `CONNECT` à base e `USAGE` aos schemas estritamente necessários para resolver nomes. `private` é condicional: só deve receber `USAGE` se existir e se a auditoria precisar consultar objetos nomeados desse schema. `auth`, `storage`, `realtime`, `extensions`, `vault` e demais schemas não recebem grants de leitura para esta auditoria.

Conceder `SELECT` explícito somente ao histórico de migrations:

- `supabase_migrations.schema_migrations`.

Não conceder `SELECT` global em `public`, `auth`, `storage`, `realtime`, `vault` ou outros schemas. Não conceder roles agregadoras como `pg_read_all_data`.

Se a implementação de uma consulta de metadados demonstrar que um privilégio adicional é necessário, a consulta deve ser identificada, testada fora de produção e submetida para aprovação separada.

### Etapa E — validação e aprovação

A conexão independente só será aprovada se todas as validações da secção 6 passarem. Se qualquer privilégio de escrita, ownership, membership privilegiada ou `BYPASSRLS` aparecer, a role não poderá ser usada.

## 4. Matriz de privilégios

| Âmbito | Privilégio proposto | Finalidade | Observação |
|---|---|---|---|
| Base `postgres` | `CONNECT` | Abrir a conexão independente | Não concede leitura de tabelas |
| Schemas `public`, `supabase_migrations` | `USAGE` | Resolver referências e consultar catálogos | Não concede acesso a dados por si só |
| Schema `private` | `USAGE` apenas condicional | Somente se existir e houver necessidade comprovada de resolver objetos nomeados | Não conceder por padrão |
| `supabase_migrations.schema_migrations` | `SELECT` | Confirmar histórico físico de migrations | Única tabela de dados com leitura inicialmente prevista |
| Catálogos PostgreSQL | Acesso padrão de catálogo | Tabelas, colunas, tipos, constraints, índices, RLS, policies, funções e triggers | Validar no ambiente; não adicionar `pg_read_all_data` |
| Schemas operacionais | Nenhum `SELECT` geral | Evitar exposição de dados | Relações físicas devem ser obtidas dos catálogos |
| Funções | Nenhum `EXECUTE` concedido pela auditoria | Impedir execução acidental | Inventariar funções `SECURITY DEFINER` executáveis por `PUBLIC` |
| Roles administrativas | Nenhuma membership | Evitar escalada | Validar em `pg_auth_members` |

O acesso a `pg_roles` e `pg_auth_members` pode ser limitado pelo PostgreSQL conforme a versão e os privilégios do observador. Se os catálogos não permitirem visibilidade suficiente, isso deve ser reportado como limitação — não contornado com privilégios administrativos.

## 5. Consultas de validação

As consultas completas estão no arquivo SQL. A validação deve ser executada através da nova connection string, e não pelo conector MCP administrativo.

### Versão e compatibilidade PostgreSQL

Antes das demais consultas, executar `SHOW server_version`, `SHOW server_version_num` e consultar `current_setting('server_version_num')`. O resultado deve ser registado como evidência da produção, sem presumir a versão a partir do Supabase.

O plano usa `pg_has_role(current_user, role_oid, 'SET')`, assinatura documentada que aceita um identificador de role e o privilégio `SET`, e `pg_auth_members.roleid/member` para o grafo de memberships. Se a versão ou o proxy rejeitar essa assinatura, a validação deve parar e a consulta ser adaptada para a assinatura compatível observada; não se deve substituir por uma simulação de ACL. A consulta recursiva identifica memberships existentes, mas não prova herança de privilégios por si só.

### Identidade

Confirmar que `current_user` e `session_user` são `alianza_audit_ro`. Se `session_user` for `postgres`, a conexão não é independente.

### Atributos

Confirmar `rolsuper`, `rolcreatedb`, `rolcreaterole`, `rolreplication`, `rolbypassrls` falsos, além de `rolinherit` falso e `rolcanlogin` verdadeiro.

### Memberships

Separar explicitamente:

- memberships existentes: arestas em `pg_auth_members`;
- privilégios herdáveis: memberships cujo role tem `rolinherit = true`, além de grants a roles do grafo;
- possibilidade de assumir roles: resultado de `pg_has_role(..., 'SET')`, independentemente de `rolinherit`.

Uma role `NOINHERIT` não recebe automaticamente privilégios de uma membership, mas ainda pode ter `SET ROLE` se a membership permitir. Em PostgreSQL que exponha `inherit_option`, `set_option` e `admin_option` em `pg_auth_members`, essas colunas devem ser lidas diretamente. Em versões sem essas colunas, a validação correspondente é indeterminada e deve parar; `rolinherit` não é substituto das opções da membership.

### Ownership

Pesquisar databases, schemas, tabelas, partições, views, materialized views, sequences, funções, procedures, types, domains, enums, extensões e demais objetos relevantes cujo proprietário seja `alianza_audit_ro`. O resultado deve ser vazio.

### Escrita efetiva

Usar `has_database_privilege`, `has_schema_privilege`, `has_table_privilege`, `has_any_column_privilege`, `has_column_privilege`, `has_sequence_privilege` e `has_function_privilege` para verificar que não há escrita nos objetos relevantes. A matriz deve testar `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER`, `USAGE`, `SELECT`, `CREATE` e `EXECUTE` quando aplicável, tanto ao nível de relação como ao nível de cada coluna.

`TEMPORARY` no database deve ser tratado separadamente: ele permite criar objetos temporários, não altera objetos persistentes, mas permite consumo de recursos e execução de SQL na sessão. A aprovação estrita exige `can_create_temp = false`; se `TEMPORARY` vier de `PUBLIC` e não for revogado, a conexão só pode ser aprovada condicionalmente, com proibição operacional de `CREATE TEMP TABLE`, documentação do risco e confirmação de que nenhum teste o utilizará. O plano não propõe revogar privilégios de `PUBLIC` automaticamente.

A validação não deve tentar uma escrita real nem usar transações de teste que escrevam.

### RLS e policies

Consultar `pg_class.relrowsecurity`, `pg_class.relforcerowsecurity` e `pg_policies`. A presença de `NOBYPASSRLS` deve ser comprovada no catálogo da role.

### Schema `private`

Confirmar primeiro se `private` existe. Se existir, verificar se a Entrega 3B precisa consultar objetos desse schema. `USAGE` não deve ser concedido por padrão apenas porque o schema existe: ele só é necessário para resolver objetos nomeados nesse schema; consultas de catálogo podem ser feitas sem leitura de dados do schema. Se `private` não existir, remover esse schema do conjunto de validação sem tratar a ausência como falha.

### Metadados

Consultar somente catálogos para verificar todos os schemas não sistémicos relevantes — incluindo `public`, `private`, `auth`, `storage`, `realtime`, `extensions`, `vault`, `supabase_migrations` e demais schemas de aplicação — e os seus objetos: tabelas, foreign tables, colunas, tipos, domains, enums, PKs, FKs, constraints, índices, sequences, views, materialized views, funções, procedures, aggregates, triggers, extensões e ownerships. `pg_get_functiondef` só é aplicado a funções e procedures suportadas; aggregates são inventariados separadamente. Com `search_path = pg_catalog`, todas as referências externas no SQL são qualificadas explicitamente.

Os inventários de segurança não devem usar limites arbitrários. Se uma ferramenta cliente impuser um limite de transporte, deve obter também a contagem total, marcar o resultado como truncado e reprovar qualquer conclusão de ausência baseada no resultado incompleto.

### Migrations

Consultar `supabase_migrations.schema_migrations` com `SELECT` e confirmar que o histórico é legível.

### Read-only transacional

Abrir uma sessão independente, confirmar `SHOW default_transaction_read_only`, iniciar `BEGIN`, confirmar o estado, executar apenas `SELECT`, fazer `ROLLBACK` e verificar que o estado da base não foi alterado. Não usar uma tentativa de escrita como teste.

### Compatibilidade com role comum

As consultas de identidade, `SHOW`, `current_setting`, `has_*_privilege`, `pg_has_role`, `pg_auth_members`, `pg_class`, `pg_namespace`, `pg_type`, `pg_extension`, `pg_proc`, `pg_policy` e `pg_policies` devem ser executadas através da role independente. Elas não devem depender de superuser, `BYPASSRLS`, `pg_read_all_data` ou leitura geral das tabelas operacionais.

Ainda assim, PostgreSQL pode limitar a visibilidade de `pg_roles`, `pg_auth_members`, ACLs de objetos de terceiros e corpos de funções. `pg_get_functiondef` também deve ser tratado como informação potencialmente indisponível para uma role comum. Se qualquer consulta falhar por falta de visibilidade, a conclusão correspondente é **indeterminada**, e a auditoria não pode declarar aprovação plena. Não se deve elevar a role para fazer a consulta funcionar.

O teste de compatibilidade deve registar a versão `server_version_num`, o resultado de `pg_has_role(..., 'SET')` e a consulta recursiva de `pg_auth_members`. Uma falha de assinatura ou de permissão deve interromper a validação, não ser mascarada por uma consulta equivalente que não meça a mesma propriedade.

## 6. Camadas de privilégios a validar

A aprovação não deve analisar apenas grants concedidos diretamente a `alianza_audit_ro`. Para cada database, schema, tabela, view, materialized view, sequence e função relevante, a validação deve separar:

1. privilégios diretamente concedidos à role;
2. privilégios herdados de memberships diretas;
3. privilégios herdados de memberships indiretas, percorrendo recursivamente `pg_auth_members`;
4. privilégios concedidos a `PUBLIC`;
5. privilégios decorrentes de ownership;
6. privilégios implícitos do superuser ou de `BYPASSRLS` — que devem ser falsos;
7. privilégios de criação no database ou schema;
8. privilégios de assumir outra role (`SET ROLE`), inclusive por `admin_option` ou memberships transitivas.

As funções `has_*_privilege` devem ser combinadas com a leitura dos ACLs (`datacl`, `nspacl`, `relacl`, `proacl`, `relacl` de sequences) e com o grafo de memberships. Um resultado efetivo `true` não prova, sozinho, que o privilégio veio de uma concessão direta.

## 7. Ownership, SET ROLE e sequences

A role deve ser validada contra todos os objetos relevantes, não apenas tabelas:

- schemas;
- tabelas particionadas e não particionadas;
- views e materialized views;
- sequences;
- funções e procedures;
- tipos, enums e extensões quando visíveis;
- objetos do schema `supabase_migrations`.

O inventário deve confirmar que `relowner`, `proowner`, `typowner`, `nspowner` e proprietários equivalentes nunca apontam para `alianza_audit_ro`. Também deve verificar `pg_has_role(current_user, role_oid, 'SET')` para todas as roles não sistémicas visíveis. Qualquer resultado positivo para uma role administrativa ou com escrita reprova a conexão.

Sequences exigem verificação separada: `USAGE`, `SELECT` e `UPDATE` são privilégios distintos e `UPDATE` pode permitir avançar valores. A role de auditoria não deve ter nenhum desses privilégios sobre sequences operacionais. O plano não concede acesso a sequences.

## 8. Catálogos PostgreSQL e limites de visibilidade

Uma role PostgreSQL comum normalmente consegue consultar partes de `pg_catalog` necessárias ao funcionamento do SQL, mas a visibilidade não é uniforme:

- `pg_class`, `pg_namespace`, `pg_attribute`, `pg_constraint`, `pg_index`, `pg_indexes`, `pg_proc`, `pg_trigger` e `pg_policy` podem ser consultados estruturalmente, mas alguns campos ou objetos podem ser filtrados conforme privilégios;
- `information_schema.tables`, `columns`, `table_constraints`, `routines` e `table_privileges` aplicam filtros de visibilidade baseados nos privilégios do utilizador;
- `pg_roles` pode ocultar ou limitar informação sensível e não deve ser tratado como prova completa de todas as ACLs;
- `pg_auth_members` pode não mostrar todas as relações de membership a uma role comum;
- ACLs, ownerships e privilégios de objetos pertencentes a outros proprietários podem ter visibilidade limitada;
- `pg_policies` permite inspeção estrutural das policies visíveis, mas não prova o comportamento de uma policy;
- `pg_default_acl` mostra defaults visíveis, mas não substitui a verificação dos ACLs efetivos dos objetos existentes;
- `pg_default_acl` deve ser consultado por proprietário, schema, tipo de objeto, destinatário e privilégios; ausência de visibilidade torna o resultado indeterminado;
- `supabase_migrations.schema_migrations` é uma tabela de dados, não um catálogo, e precisa de `SELECT` explícito.
- `pg_largeobject_metadata`, `pg_foreign_data_wrapper`, `pg_foreign_server`, `pg_event_trigger`, `pg_publication`, `pg_subscription` e `pg_language` devem ser confirmados na versão real; ausência, alteração de colunas, ACL não visível ou função de privilégio indisponível impede aprovação plena.

Se uma consulta necessária retornar visibilidade incompleta, o resultado deve ser classificado como **indeterminado**. Não se deve adicionar `pg_read_all_data`, `BYPASSRLS`, superuser ou privilégios administrativos apenas para eliminar essa limitação.

O schema `private` é opcional para a auditoria: a sua existência deve ser confirmada no catálogo e o seu uso justificado por objetos concretos. `USAGE` em `private` não deve ser concedido apenas por conveniência. O acesso ao histórico continua restrito a `supabase_migrations.schema_migrations`, sem leitura global do schema.

O inventário de segurança deve abranger foreign tables e todos os schemas não sistémicos, sem conceder `SELECT` amplo. A ausência de privilégio deve ser distinguida de ausência de visibilidade catalogal.

O `search_path` aprovado contém exclusivamente `pg_catalog`. Por isso, referências a `information_schema` e `supabase_migrations` aparecem qualificadas no SQL; nenhum schema externo é adicionado ao caminho de resolução.

O SQL não limita arbitrariamente os inventários de segurança. Os `LIMIT 1` restantes são apenas para resultados escalares de identidade/configuração e não sustentam conclusões de ausência.

## 9. Histórico de migrations sem acesso amplo

A leitura do histórico deve ser concedida apenas ao objeto:

`supabase_migrations.schema_migrations`

O plano não concede `SELECT` em todas as tabelas do schema `supabase_migrations`. O `USAGE` do schema permite resolução de nomes, mas não concede leitura das tabelas. A validação deve confirmar tanto o `SELECT` permitido na tabela de histórico como a ausência de `SELECT` efetivo nas demais tabelas do schema.

## 10. Funções executáveis e risco de bypass

A role não deve receber `EXECUTE`. Contudo, funções podem ter privilégios herdados de `PUBLIC`, e funções `SECURITY DEFINER` podem ser sensíveis. Por isso, a auditoria deve:

1. distinguir `proacl` direto, `PUBLIC` e memberships ao avaliar `EXECUTE`;
2. inventariar funções `SECURITY DEFINER` nos schemas relevantes;
3. recolher owner, memberships e privilégios efetivos do owner, ownerships relevantes, `proconfig`/`search_path`, linguagem, `prokind`, volatilidade e definição visível sem invocar a função;
4. verificar `has_function_privilege` para `EXECUTE`, sem invocar a função;
5. verificar se `current_user` possui `SET` sobre roles usadas para executar funções;
6. considerar risco confirmado quando houver combinação de `SECURITY DEFINER`, `EXECUTE` efetivo para a role/PUBLIC e owner ou membership privilegiada;
7. exigir revisão explícita para cada função `SECURITY DEFINER` executável, considerando linguagem, owner, memberships, `search_path`, dependências em `pg_depend`, chamadas indiretas e definição visível;
8. classificar como risco indeterminado quando a revisão individual não estiver comprovada ou quando corpo, owner, memberships, `search_path`, dependências ou ACL não puderem ser vistos;
9. não usar expressões regulares sobre o corpo como prova suficiente de segurança; a decisão depende da revisão manual da definição, dependências e possíveis chamadas indiretas;
10. tratar eventual revogação de `EXECUTE FROM PUBLIC` como mudança administrativa separada, nunca como parte automática deste plano.

### Registo formal e reconciliação da revisão individual

A revisão individual será mantida fora da base de dados, em registo versionado e assinado, porque esta entrega não autoriza DDL ou DML. Cada linha representa uma única função/procedure e contém schema, nome, argumentos de identidade, tipo de objeto, linguagem, owner, modo de segurança, extensão, `definition_sha256`, `definition_md5`, status, responsável, data, referência da evidência, conclusão técnica e justificativa do risco.

Na execução read-only, o cliente injeta esse registo como uma CTE `VALUES` tipada. A reconciliação compara cada linha com o inventário da sessão por identidade completa e verifica `review_status = 'APPROVED'`, responsável, data, evidência, conclusão, justificativa e `definition_md5`. O cliente calcula o SHA-256 sobre os bytes UTF-8 da definição visível; a divergência de SHA-256 ou MD5, owner, assinatura, linguagem, modo de segurança ou extensão invalida a revisão. Entradas duplicadas, ausentes, stale ou não reconciliadas deixam o resultado como `INDETERMINADA`.

Não são aceites declarações genéricas, uma única linha “todas as funções” ou revisão sem evidência individual. A reconciliação é feita contra a identidade obtida na mesma sessão auditada, impedindo que uma revisão de outra base, versão ou owner seja reutilizada.

### Privilégios efectivos dos proprietários

Para cada `SECURITY DEFINER` executável, o plano também avalia os privilégios efectivos do owner — incluindo os herdados pelas memberships — sobre:

- `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES` e `TRIGGER` nas relações;
- `INSERT`, `UPDATE` e `REFERENCES` por coluna;
- `USAGE`, `SELECT` e `UPDATE` em sequences;
- `UPDATE` e `SELECT` em Large Objects;
- `CREATE` na base de dados e em schemas não sistémicos;
- ownership de FDWs, foreign servers e event triggers.

Um caminho executável com owner que possua esses privilégios, ou com ownership externo relevante, é risco confirmado e resulta em `REPROVADA`. Se a consulta do privilégio efectivo, owner, membership, ACL ou catálogo falhar, resulta em `INDETERMINADA`; a análise não se limita a `SUPERUSER`, `CREATEROLE` e `BYPASSRLS`.

Não propor revogações globais nesta entrega: um `REVOKE EXECUTE ON ALL FUNCTIONS ... FROM PUBLIC` poderia quebrar a aplicação e alterar o modelo de segurança de produção.

### Funções SECURITY INVOKER e extensões

A auditoria deve inventariar todas as funções executáveis pela role ou por `PUBLIC`, não apenas `SECURITY DEFINER`. Para cada função deve registar assinatura, owner, linguagem, modo de segurança, `EXECUTE` efetivo, definição/implementação visível, extensão de origem, dependências, efeitos possíveis e chamadas indiretas. Linguagens `internal`, `c` e procedurais externas exigem revisão específica; `default_transaction_read_only` não prova ausência de efeitos externos. Sem revisão individual baseada em evidências, o estado é `INDETERMINADA`.

### Large Objects

`pg_largeobject_metadata` e `has_large_object_privilege` devem ser verificados quando disponíveis. O inventário regista OID, owner, ACL, `PUBLIC`, grants diretos, memberships e privilégios efetivos de leitura (`SELECT`) e alteração (`UPDATE`). Qualquer privilégio não autorizado reprova. Catálogo ou função ausente, invisível ou incompatível produz `INDETERMINADA`.

### Categorias adicionais de ownership

Além dos objetos relacionais, a auditoria verifica `pg_foreign_data_wrapper`, `pg_foreign_server`, `pg_event_trigger`, `pg_publication`, `pg_subscription`, `pg_language`, Large Objects e extensões. Para cada categoria são consultados owner e ACL quando o catálogo fornece ACL; event triggers, publications e subscriptions são tratados como owner-only quando não têm ACL equivalente. A ausência do catálogo numa versão compatível, falha de leitura ou campos não verificáveis impede declarar cobertura completa.

## 11. Critérios objetivos de aprovação e reprovação

### Aprovar somente se todos forem verdadeiros

- `current_user = 'alianza_audit_ro'`;
- `session_user = 'alianza_audit_ro'`;
- `rolcanlogin = true`;
- `rolsuper`, `rolcreatedb`, `rolcreaterole`, `rolreplication`, `rolbypassrls` e `rolinherit` são `false`;
- não existem memberships diretas ou indiretas em roles administrativas, de aplicação ou de leitura ampla;
- não existem privilégios herdáveis indesejados por memberships;
- não existe `SET ROLE` permitido para outra role, incluindo roles predefinidas `pg_*`;
- não existe ownership de qualquer objeto relevante;
- não há `SET ROLE` permitido para outra role não sistémica;
- não há `CREATE` no database ou schemas relevantes;
- `TEMPORARY` está ausente; se vier de `PUBLIC`, a aprovação só pode ser condicional e deve registar expressamente que não é uma garantia de read-only absoluto;
- não há `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES` ou `TRIGGER` efetivos em tabelas/views alvo, nem `INSERT`, `UPDATE`, `REFERENCES` ou `SELECT` indevidos por coluna;
- não há `USAGE`, `SELECT` ou `UPDATE` efetivos em sequences operacionais;
- `SELECT` em `supabase_migrations.schema_migrations` funciona;
- as demais tabelas de `supabase_migrations` não têm `SELECT` efetivo, salvo aprovação explícita;
- os catálogos necessários estão acessíveis ou as limitações estão documentadas como não impeditivas;
- `pg_default_acl` foi consultado com owner, schema, tipo de objeto, destinatário e privilégios; visibilidade incompleta impede aprovação plena;
- os inventários de schemas, objetos, ACLs, sequences, functions, ownerships e memberships não estão truncados;
- `default_transaction_read_only = on` e `transaction_read_only = on` são observados;
- cada função `SECURITY DEFINER` executável pela role ou por `PUBLIC` tem revisão explícita comprovada; revisão ausente ou indeterminada impede aprovação plena;
- nenhuma consulta exigiu escrita, DDL, DML, migration ou alteração de sessão administrativa.

A consulta consolidada só pode emitir um dos quatro estados seguintes:

- `REPROVADA`: membership não autorizada, privilégio efetivo não autorizado, ownership, risco de `SECURITY DEFINER`, `CREATE`, `SELECT` indevido, sequence privilegiada ou `transaction_read_only` desligado;
- `INDETERMINADA`: falha de consulta, visibilidade insuficiente, inventário incompleto, incompatibilidade de versão/opções de `pg_auth_members`, histórico inacessível ou classificação de função não concluída;
- `APROVACAO_CONDICIONAL_TEMPORARY`: todos os demais controles foram comprovados, mas `TEMPORARY` permanece efetivo e o risco foi expressamente aceite;
- `APROVADA`: todos os controles foram comprovados e não existe `TEMPORARY` efetivo.

Se qualquer statement de validação falhar, exceder timeout, retornar visibilidade insuficiente ou for truncado pelo cliente, não existe resultado consolidado seguro: o estado obrigatório é `INDETERMINADA`, com a consulta pendente identificada para revisão manual.

O campo da consulta de database chama-se `can_create_in_database`. A consulta final inclui memberships diretas e indiretas, o campo separado `has_effective_inherited_membership`, `CREATE` em todos os schemas não sistémicos, `SELECT` em todas as tabelas/views/materialized views/foreign tables, sequences, ownership, `SECURITY DEFINER`, catálogos e `transaction_read_only`.

### Reprovar imediatamente se qualquer um ocorrer

- `current_user` ou `session_user` for uma identidade administrativa;
- `rolbypassrls = true`;
- qualquer privilégio de escrita efetivo;
- qualquer ownership relevante;
- membership ou `SET ROLE` para role privilegiada;
- qualquer membership direta ou indireta não autorizada, mesmo sem `SET ROLE`;
- privilégio herdável indesejado, mesmo sem uso atual;
- `SELECT` indiscriminado concedido a schemas operacionais;
- `UPDATE` em sequences;
- `TEMPORARY` não documentado ou tratado como se fosse equivalente a read-only;
- privilégios de leitura ou alteração em Large Objects;
- função executável sem registo de revisão individual e evidências suficientes;
- ownership ou ACL não verificado em FDW, foreign server, event trigger, publication, subscription, language ou Large Object;
- inventário de segurança truncado, sem contagem total ou sem indicação de incompletude;
- acesso ao histórico apenas por uma sessão administrativa diferente da role validada;
- versão PostgreSQL ou assinatura de `pg_has_role` não confirmada;
- visibilidade insuficiente para uma conclusão que seja apresentada como confirmada;
- falha ao verificar ownership, `SELECT` efetivo, sequences, `SECURITY DEFINER`, `CREATE` por schema ou `transaction_read_only`;
- necessidade de executar função, escrever dados ou contornar RLS para obter evidência.

## 12. Gestão da credencial

### Criação

O administrador deve definir a senha diretamente no painel seguro ou em um gestor de secrets. A senha não deve aparecer em:

- arquivos SQL;
- repositório;
- histórico de shell;
- tickets;
- mensagens;
- logs;
- variáveis impressas no terminal.

### Armazenamento

Guardar a connection string como secret nomeado, por exemplo `ALIANZA_AUDIT_RO_DATABASE_URL`, usando o mecanismo de secrets aprovado pelo projeto Manus. O valor não deve ser lido de volta para a conversa nem impresso.

### Rotação

1. Criar uma nova senha através do mecanismo seguro.
2. Atualizar o secret.
3. Validar `current_user`, `session_user` e os privilégios.
4. Invalidar a senha anterior conforme a política do Supabase.
5. Registar somente o evento de rotação, nunca o valor.

### Revogação

A revogação deve ocorrer nesta ordem, com aprovação administrativa:

1. remover o secret da automação/ambiente que o utiliza;
2. revogar `CONNECT` da base;
3. revogar os `USAGE` e `SELECT` concedidos especificamente;
4. confirmar que não existem memberships nem ownerships;
5. desativar o login com `ALTER ROLE ... NOLOGIN` ou remover a role com `DROP ROLE` apenas se estiver sem dependências.

Nenhuma destas ações foi executada.

## 13. Riscos e limitações

- `default_transaction_read_only` é uma configuração de sessão, não substitui ACLs.
- `NOINHERIT` não elimina privilégios concedidos diretamente nem privilégios via `PUBLIC`.
- Visibilidade de `pg_roles`, memberships e alguns catálogos pode ser limitada para uma role não administrativa.
- `information_schema` pode ocultar objetos conforme os privilégios; os catálogos devem ser usados para inventário estrutural.
- Sem `SELECT` nas tabelas operacionais, a auditoria poderá confirmar estrutura, mas não validar conteúdo de linhas.
- A ausência de `BYPASSRLS` pode fazer com que consultas a tabelas com RLS retornem zero linhas; isso é comportamento desejado para a identidade de auditoria e não deve ser contornado.
- O conector MCP continuará inadequado para esta auditoria mesmo depois de a role existir, salvo se passar a suportar explicitamente a nova connection string.
- Large Objects podem não ser visíveis a uma role comum; `pg_largeobject_metadata` e `has_large_object_privilege` devem ser testados pela versão real, sem substituir a falha por uma suposição de ausência.
- FDW, foreign servers, event triggers, publications, subscriptions e linguagens têm catálogos e modelos de ACL diferentes; ownership ou ACL não comprovado em qualquer categoria resulta em `INDETERMINADA`.
- Default ACLs são privilégios para objetos futuros e não concessões retroativas: devem ser analisados separadamente dos ACLs efetivos dos objetos já existentes.
- Funções `SECURITY INVOKER`, `SECURITY DEFINER`, de extensões, `internal`, `c` ou linguagens externas são inventariadas sem execução; comportamento não verificável permanece `INDETERMINADA`.

## 14. Checklist de aprovação administrativa

- [ ] Produção correta identificada.
- [ ] Nome `alianza_audit_ro` aprovado.
- [ ] Role criada com `LOGIN`, `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOREPLICATION`, `NOBYPASSRLS`, `NOINHERIT`.
- [ ] Nenhuma membership privilegiada.
- [ ] Nenhum ownership de objetos.
- [ ] Nenhum grant de escrita.
- [ ] Nenhum `pg_read_all_data`, `service_role` ou equivalente.
- [ ] Nenhum `EXECUTE` perigoso disponível por `PUBLIC`.
- [ ] `default_transaction_read_only` configurado.
- [ ] Timeouts configurados.
- [ ] Apenas `CONNECT`, `USAGE` e `SELECT` mínimo aprovados.
- [ ] Secret armazenado sem impressão.
- [ ] Conexão independente validada.
- [ ] `current_user = session_user = alianza_audit_ro`.
- [ ] Entrega 3B autorizada somente após todas as verificações.

## 15. Decisão solicitada

Este documento requer revisão e aprovação do administrador do Supabase. Até essa aprovação, não executar o SQL, não criar a role, não configurar secrets e não iniciar a Entrega 3B.

## 16. Artefactos da revisão 3B.1.7

Além deste plano e do SQL comentado, a revisão entrega:

1. uma matriz de controlos e evidências, com a consulta correspondente e os critérios de `REPROVADA`/`INDETERMINADA`;
2. um relatório de alterações em relação à 3B.1.3;
3. uma matriz de compatibilidade por versão PostgreSQL, sempre condicionada à confirmação de `server_version_num` na conexão real;
4. o modelo externo `alianza-entrega-3b1-7-registro-revisoes-funcoes.csv`, sem dados preenchidos, para reconciliação individual;
5. a matriz de cenários e o teste local da decisão consolidada;
6. o modelo vazio `alianza-entrega-3b1-7-aceitacao-temporary.csv`, que não pode ser preenchido automaticamente.

Esses artefactos são documentais. Nenhum resultado de produção é afirmado antes de uma execução autorizada através da conexão independente da role.

## 17. Correções obrigatórias da 3B.1.7

### SHA-256 e representação canónica

O SQL expõe a representação textual de revisão e um `definition_md5` auxiliar, mas não presume `pgcrypto` nem declara cálculo de SHA-256 dentro do PostgreSQL. O cliente deve obter a definição/canonical material da mesma sessão, preservar exactamente os bytes UTF-8 sem normalização e calcular SHA-256 externamente. O registo só é válido com `sha256_verified = true`, hash não vazio e evidência reproduzível; divergência invalida a revisão e produz `INDETERMINADA`.

### População completa de `pg_proc`

As CTEs de revisão incluem `prokind` `f`, `p`, `a` e `w`, respectivamente função, procedure, aggregate e window function. Objectos fora dessa população, ou categorias não interpretáveis na versão real, não podem ser omitidos: a consulta falhada ou a população não verificável impede aprovação.

### Read-only da sessão

São observados separadamente `transaction_read_only` e `default_transaction_read_only`. Ambos devem estar `on`. O segundo é uma configuração preventiva e não substitui ACLs, RLS, ausência de `BYPASSRLS`, `NOINHERIT` nem a validação dos privilégios efectivos.

### FDW e foreign servers

As funções nativas `has_foreign_data_wrapper_privilege` e `has_server_privilege` são verificadas por disponibilidade e usadas para avaliar `USAGE` efectivo, que inclui concessões directas, `PUBLIC` e memberships segundo o PostgreSQL. A ausência de qualquer função, falha da consulta ou visibilidade incompleta impede aprovação.

### Default ACLs e TEMPORARY

Default ACLs são inventariados por owner, schema, tipo, grantee e privilégio. Concessões perigosas a `PUBLIC`, à role auditada ou a roles relacionadas produzem `INDETERMINADA`; não são tratadas como ausência de risco.

`TEMPORARY` não gera aprovação condicional automaticamente. A aceitação deve ser injectada externamente com responsável, data, evidência e justificação válidos. Sem esse registo, o resultado é `INDETERMINADA`; somente com aceitação válida pode ser `APROVACAO_CONDICIONAL_TEMPORARY`.

### Ownership ampliado

Além de relações, funções, tipos, extensões, Large Objects e objectos externos, o inventário cobre tablespaces, collations e objectos de text search. Qualquer catálogo não verificável mantém o resultado `INDETERMINADA`.
