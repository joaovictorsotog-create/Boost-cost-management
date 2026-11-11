-- ENTREGA 3B.1.8 — Plano SQL da role PostgreSQL de auditoria
--
-- NÃO EXECUTAR SEM AUTORIZAÇÃO ADMINISTRATIVA EXPLÍCITA.
-- Este arquivo é um plano revisável. Não contém senha nem connection string.
-- Nenhum comando deste arquivo foi enviado ao Supabase.

-- ============================================================================
-- ETAPA 0 — Pré-condições (somente revisão)
-- ============================================================================
-- Confirmar manualmente:
--   * projeto e base de produção corretos;
--   * role ainda inexistente;
--   * procedimento seguro para definir a senha;
--   * ausência de operação concorrente que possa confundir a auditoria.
--
-- SELECT rolname
-- FROM pg_catalog.pg_roles
-- WHERE rolname = 'alianza_audit_ro'
-- LIMIT 1;

-- ============================================================================
-- ETAPA 1 — Criar a role
-- ============================================================================
-- A senha deve ser definida fora deste arquivo, no mecanismo seguro aprovado.
-- NOINHERIT reduz risco de memberships futuras; ainda assim memberships devem
-- ser proibidas e validadas.
--
-- CREATE ROLE alianza_audit_ro
--   LOGIN
--   NOSUPERUSER
--   NOCREATEDB
--   NOCREATEROLE
--   NOREPLICATION
--   NOBYPASSRLS
--   NOINHERIT
--   CONNECTION LIMIT 1;
--
-- Não incluir PASSWORD neste arquivo.

-- ============================================================================
-- ETAPA 2 — Proteções de sessão
-- ============================================================================
-- São proteções adicionais; não substituem ACLs sem escrita.
--
-- ALTER ROLE alianza_audit_ro SET default_transaction_read_only = 'on';
-- ALTER ROLE alianza_audit_ro SET statement_timeout = '60s';
-- ALTER ROLE alianza_audit_ro SET lock_timeout = '5s';
-- ALTER ROLE alianza_audit_ro SET idle_in_transaction_session_timeout = '60s';
-- ALTER ROLE alianza_audit_ro SET search_path = pg_catalog;

-- ============================================================================
-- ETAPA 3 — Acesso mínimo
-- ============================================================================
-- O nome real da base deve ser confirmado antes da execução.
-- Em Supabase, substituir <database_name> somente no ambiente administrativo.
--
-- GRANT CONNECT ON DATABASE <database_name> TO alianza_audit_ro;
-- GRANT USAGE ON SCHEMA public TO alianza_audit_ro;
-- GRANT USAGE ON SCHEMA supabase_migrations TO alianza_audit_ro;
-- GRANT SELECT ON TABLE supabase_migrations.schema_migrations TO alianza_audit_ro;
-- Condicional, somente se private existir e a auditoria precisar resolver
-- objetos nomeados nesse schema:
-- GRANT USAGE ON SCHEMA private TO alianza_audit_ro;
--
-- Não conceder:
--   * pg_read_all_data;
--   * SELECT ON ALL TABLES IN SCHEMA public;
--   * INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES ou TRIGGER;
--   * CREATE em schemas;
--   * EXECUTE em funções.

-- ============================================================================
-- ETAPA 4 — Validação de identidade
-- Executar através da nova connection string, não pelo conector MCP admin.
-- ============================================================================
SHOW server_version;
SHOW server_version_num;

SELECT current_setting('server_version_num') AS server_version_num,
       current_setting('server_version') AS server_version
LIMIT 1;

SELECT table_schema,
       table_name,
       column_name,
       data_type
FROM information_schema.columns
WHERE table_schema = 'pg_catalog'
  AND table_name = 'pg_auth_members'
  AND column_name IN ('admin_option', 'inherit_option', 'set_option')
ORDER BY column_name;

-- admin_option existe em versões antigas; inherit_option e set_option são
-- dependentes da versão. A ausência de qualquer coluna esperada impede uma
-- conclusão plena sobre a opção correspondente.

SELECT current_user AS current_user,
       session_user AS session_user,
       current_database() AS database_name
LIMIT 1;

-- Resultado obrigatório:
-- current_user  = alianza_audit_ro
-- session_user  = alianza_audit_ro

-- ============================================================================
-- ETAPA 5 — Validação dos atributos da role
-- ============================================================================
SELECT rolname,
       rolcanlogin,
       rolsuper,
       rolcreatedb,
       rolcreaterole,
       rolreplication,
       rolbypassrls,
       rolinherit,
       rolconnlimit
FROM pg_catalog.pg_roles
WHERE rolname = current_user
LIMIT 1;

-- Resultado obrigatório:
-- rolcanlogin = true
-- rolsuper = false
-- rolcreatedb = false
-- rolcreaterole = false
-- rolreplication = false
-- rolbypassrls = false
-- rolinherit = false

-- Compatibilidade: pg_has_role(text, oid, text) e pg_auth_members.roleid/member
-- são usados mais abaixo. Se a versão/proxy rejeitar a assinatura 'SET', parar
-- e adaptar a consulta à assinatura disponível; nunca simular SET por ACL.
-- PostgreSQL 16+ expõe inherit_option, set_option e admin_option em
-- pg_auth_members. A consulta abaixo usa to_jsonb para não referenciar
-- colunas ausentes em versões anteriores; a presença das chaves é validada e,
-- se faltar alguma, a conclusão sobre a opção correspondente é INDETERMINADA.

-- ============================================================================
-- ETAPA 6 — Memberships e ownership
-- ============================================================================
SELECT member.rolname AS member_role,
       parent.rolname AS parent_role,
       am.admin_option,
       to_jsonb(am)->>'inherit_option' AS membership_inherit_option,
       to_jsonb(am)->>'set_option' AS membership_set_option,
       to_jsonb(am) ? 'inherit_option' AS supports_inherit_option,
       to_jsonb(am) ? 'set_option' AS supports_set_option,
       pg_catalog.pg_has_role(current_user, parent.oid, 'USAGE') AS has_role_usage,
       pg_catalog.pg_has_role(current_user, parent.oid, 'SET') AS can_set_parent
FROM pg_catalog.pg_auth_members am
JOIN pg_catalog.pg_roles parent ON parent.oid = am.roleid
JOIN pg_catalog.pg_roles member ON member.oid = am.member
WHERE member.rolname = current_user;

-- Esta consulta cobre membership direta. A consulta recursiva da ETAPA 8A
-- cobre memberships indiretas. As opções da membership são distintas de
-- rolinherit da role e de SET efetivo. Se supports_* for false, interromper a
-- validação dessa propriedade e marcar o resultado como indeterminado.

-- Resultado obrigatório: zero linhas para memberships não aprovadas.

SELECT n.nspname AS schema_name,
       c.relname AS object_name,
       c.relkind AS object_kind
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
JOIN pg_catalog.pg_roles r ON r.oid = c.relowner
WHERE r.rolname = current_user
ORDER BY n.nspname, c.relname;

-- Resultado obrigatório: zero linhas.

-- ============================================================================
-- ETAPA 7 — Privilégios efetivos de database e schemas
-- ============================================================================
SELECT current_user AS role_name,
       has_database_privilege(current_user, current_database(), 'CONNECT') AS can_connect,
       has_database_privilege(current_user, current_database(), 'CREATE') AS can_create_in_database,
       has_database_privilege(current_user, current_database(), 'TEMPORARY') AS can_create_temp
LIMIT 1;

-- TEMPORARY não é escrita persistente, mas permite criar objetos temporários e
-- consumir recursos da sessão. Critério estrito: can_create_temp = false.
-- Se o resultado for true por PUBLIC, não revogar PUBLIC automaticamente; a
-- conexão só pode ser aprovada condicionalmente, sem executar CREATE TEMP e com
-- o risco registado. Nunca tratar TEMPORARY como equivalente a read-only.

SELECT n.nspname AS schema_name,
       has_schema_privilege(current_user, n.oid, 'USAGE') AS can_usage,
       has_schema_privilege(current_user, n.oid, 'CREATE') AS can_create
FROM pg_catalog.pg_namespace n
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
ORDER BY n.nspname;

-- Resultado obrigatório: can_create = false para todos os schemas.

-- ============================================================================
-- ETAPA 7A — Existência e necessidade do schema private
-- ============================================================================
SELECT n.nspname AS schema_name,
       has_schema_privilege(current_user, n.oid, 'USAGE') AS can_usage,
       has_schema_privilege(current_user, n.oid, 'CREATE') AS can_create
FROM pg_catalog.pg_namespace n
WHERE n.nspname = 'private'
LIMIT 1;

-- Se não houver linha, private não existe e não é necessário conceder USAGE.
-- Se existir, USAGE só é necessário se a auditoria consultar objetos nomeados
-- de private; consultas de catálogo não justificam SELECT em tabelas private.

-- Inventário completo de schemas não sistémicos relevantes. Não concede acesso
-- nem lê dados operacionais.
SELECT n.oid::regnamespace::text AS schema_name,
       pg_get_userbyid(n.nspowner) AS owner_name,
       has_schema_privilege(current_user, n.oid, 'USAGE') AS can_usage,
       has_schema_privilege(current_user, n.oid, 'CREATE') AS can_create
FROM pg_catalog.pg_namespace n
WHERE n.nspname NOT LIKE 'pg_%'
  AND n.nspname <> 'information_schema'
ORDER BY n.nspname;

-- ============================================================================
-- ETAPA 8 — Privilégios efetivos nas tabelas alvo
-- ============================================================================
-- Esta consulta é estrutural e não lê linhas operacionais.
SELECT n.nspname AS schema_name,
       c.relname AS table_name,
       has_table_privilege(current_user, c.oid, 'SELECT') AS can_select,
       has_table_privilege(current_user, c.oid, 'INSERT') AS can_insert,
       has_table_privilege(current_user, c.oid, 'UPDATE') AS can_update,
       has_table_privilege(current_user, c.oid, 'DELETE') AS can_delete,
       has_table_privilege(current_user, c.oid, 'TRUNCATE') AS can_truncate,
       has_table_privilege(current_user, c.oid, 'REFERENCES') AS can_references,
       has_table_privilege(current_user, c.oid, 'TRIGGER') AS can_trigger
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p', 'v', 'm', 'f')
  AND n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
ORDER BY n.nspname, c.relname;

-- Resultado obrigatório:
--   * escrita falsa em todos os objetos;
--   * SELECT permitido somente onde previamente aprovado;
--   * SELECT em supabase_migrations.schema_migrations permitido.

-- Privilégios por coluna. Esta consulta é necessária porque ACLs de coluna
-- podem conceder SELECT, INSERT, UPDATE ou REFERENCES sem aparecer como um
-- privilégio de tabela. Não executar nenhuma alteração.
SELECT n.nspname AS schema_name,
       c.relname AS relation_name,
       c.relkind AS relation_kind,
       a.attname AS column_name,
       has_column_privilege(current_user, c.oid, a.attname, 'SELECT') AS can_select_column,
       has_column_privilege(current_user, c.oid, a.attname, 'INSERT') AS can_insert_column,
       has_column_privilege(current_user, c.oid, a.attname, 'UPDATE') AS can_update_column,
       has_column_privilege(current_user, c.oid, a.attname, 'REFERENCES') AS can_references_column
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid
WHERE c.relkind IN ('r', 'p', 'f', 'v', 'm')
  AND a.attnum > 0
  AND NOT a.attisdropped
  AND n.nspname NOT LIKE 'pg_%'
  AND n.nspname <> 'information_schema'
ORDER BY n.nspname, c.relname, a.attnum;

-- ============================================================================
-- ETAPA 8A — ACLs diretas, PUBLIC e memberships transitivas
-- ============================================================================
-- Expande o grafo de memberships apenas para inspeção. Não executa SET ROLE.
WITH RECURSIVE role_tree AS (
  SELECT r.oid AS granted_role_oid,
         r.rolname AS granted_role,
         0 AS depth,
         ARRAY[r.oid] AS path
  FROM pg_catalog.pg_roles r
  WHERE r.rolname = current_user
  UNION ALL
  SELECT parent.oid,
         parent.rolname,
         rt.depth + 1,
         rt.path || parent.oid
  FROM pg_catalog.pg_auth_members am
  JOIN role_tree rt ON rt.granted_role_oid = am.member
  JOIN pg_catalog.pg_roles parent ON parent.oid = am.roleid
  WHERE NOT parent.oid = ANY(rt.path)
)
SELECT granted_role,
       depth,
       (depth = 0) AS direct_identity,
       (depth > 0) AS indirect_membership
FROM role_tree
ORDER BY depth, granted_role;

-- ACLs de database, distinguindo PUBLIC (grantee = 0), identidade direta e
-- roles herdadas. has_*_privilege abaixo confirma o efeito final.
WITH RECURSIVE role_tree AS (
  SELECT oid AS role_oid FROM pg_catalog.pg_roles WHERE rolname = current_user
  UNION
  SELECT am.roleid
  FROM pg_catalog.pg_auth_members am
  JOIN role_tree rt ON rt.role_oid = am.member
)
SELECT d.datname,
       x.grantee,
       CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END AS grantee_name,
       x.privilege_type,
       x.is_grantable
FROM pg_catalog.pg_database d
CROSS JOIN LATERAL aclexplode(COALESCE(d.datacl, acldefault('d', d.datdba))) x
LEFT JOIN pg_catalog.pg_roles r ON r.oid = x.grantee
WHERE d.datname = current_database()
  AND (x.grantee = 0 OR x.grantee IN (SELECT role_oid FROM role_tree))
ORDER BY grantee_name, x.privilege_type;

-- ACLs de schemas relevantes, incluindo PUBLIC e memberships.
WITH RECURSIVE role_tree AS (
  SELECT oid AS role_oid FROM pg_catalog.pg_roles WHERE rolname = current_user
  UNION
  SELECT am.roleid
  FROM pg_catalog.pg_auth_members am
  JOIN role_tree rt ON rt.role_oid = am.member
)
SELECT n.nspname AS schema_name,
       x.grantee,
       CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END AS grantee_name,
       x.privilege_type,
       x.is_grantable
FROM pg_catalog.pg_namespace n
CROSS JOIN LATERAL aclexplode(COALESCE(n.nspacl, acldefault('n', n.nspowner))) x
LEFT JOIN pg_catalog.pg_roles r ON r.oid = x.grantee
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
  AND (x.grantee = 0 OR x.grantee IN (SELECT role_oid FROM role_tree))
ORDER BY n.nspname, grantee_name, x.privilege_type;

-- ACLs de tabelas/partições/foreign tables/views/materialized views. A consulta lista apenas ACLs que
-- podem afetar a identidade ou PUBLIC; o efeito final deve ser confirmado por
-- has_table_privilege na ETAPA 8.
WITH RECURSIVE role_tree AS (
  SELECT oid AS role_oid FROM pg_catalog.pg_roles WHERE rolname = current_user
  UNION
  SELECT am.roleid
  FROM pg_catalog.pg_auth_members am
  JOIN role_tree rt ON rt.role_oid = am.member
)
SELECT n.nspname AS schema_name,
       c.relname AS object_name,
       c.relkind AS object_kind,
       x.grantee,
       CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END AS grantee_name,
       x.privilege_type,
       x.is_grantable
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('r', c.relowner))) x
LEFT JOIN pg_catalog.pg_roles r ON r.oid = x.grantee
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
  AND c.relkind IN ('r', 'p', 'f', 'v', 'm')
  AND (x.grantee = 0 OR x.grantee IN (SELECT role_oid FROM role_tree))
ORDER BY n.nspname, c.relname, grantee_name, x.privilege_type;

-- Qualquer SET ROLE para uma role não sistémica deve ser analisado; role
-- administrativa ou com escrita reprova a conexão.
SELECT r.rolname AS target_role,
       r.rolsuper,
       r.rolcreatedb,
       r.rolcreaterole,
       r.rolbypassrls,
       pg_catalog.pg_has_role(current_user, r.oid, 'SET') AS can_set_role
FROM pg_catalog.pg_roles r
WHERE r.rolname <> current_user
ORDER BY r.rolname;

-- ============================================================================
-- ETAPA 8B — Ownership completo de objetos relevantes
-- ============================================================================
SELECT 'database' AS object_kind,
       datname AS schema_name,
       datname AS object_name,
       pg_get_userbyid(datdba) AS owner_name
FROM pg_catalog.pg_database
WHERE datname = current_database()
UNION ALL
SELECT 'schema', nspname, nspname, pg_get_userbyid(nspowner)
FROM pg_catalog.pg_namespace
WHERE nspname NOT LIKE 'pg_%'
  AND nspname <> 'information_schema'
UNION ALL
SELECT CASE c.relkind
         WHEN 'S' THEN 'sequence'
         WHEN 'v' THEN 'view'
         WHEN 'm' THEN 'materialized_view'
         WHEN 'r' THEN 'table'
         WHEN 'p' THEN 'partitioned_table'
         ELSE c.relkind::text
       END,
       n.nspname,
       c.relname,
       pg_get_userbyid(c.relowner)
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
  AND c.relkind IN ('r', 'p', 'f', 'S', 'v', 'm')
UNION ALL
SELECT 'function_or_procedure',
       n.nspname,
       p.oid::regprocedure::text,
       pg_get_userbyid(p.proowner)
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
ORDER BY object_kind, schema_name, object_name;

-- Resultado obrigatório: nenhuma linha com owner_name = 'alianza_audit_ro'.

-- Ownership de types, domains e enums. Cada enum aparece como type e as suas
-- labels são metadados associados, não objetos com owner separado.
SELECT 'type' AS object_kind,
       n.nspname AS schema_name,
       t.typname AS object_name,
       CASE WHEN t.typtype = 'e' THEN 'enum'
            WHEN t.typtype = 'd' THEN 'domain'
            WHEN t.typtype = 'c' THEN 'composite'
            ELSE t.typtype::text
       END AS type_kind,
       pg_get_userbyid(t.typowner) AS owner_name
FROM pg_catalog.pg_type t
JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
  AND t.typtype IN ('b', 'c', 'd', 'e')
ORDER BY n.nspname, t.typname;

-- Ownership de extensões instaladas nos schemas relevantes.
SELECT e.extname AS extension_name,
       e.extnamespace::regnamespace::text AS extension_schema,
       pg_get_userbyid(e.extowner) AS owner_name
FROM pg_catalog.pg_extension e
ORDER BY e.extname;

-- Ownership de categorias adicionais que podem permitir alterações estruturais
-- ou controlar resolução/execução: tablespaces, collations e text search.
SELECT 'tablespace' AS object_kind,
       NULL::text AS schema_name,
       spcname AS object_name,
       pg_get_userbyid(spcowner) AS owner_name
FROM pg_catalog.pg_tablespace
UNION ALL
SELECT 'collation', n.nspname, c.collname, pg_get_userbyid(c.collowner)
FROM pg_catalog.pg_collation c
JOIN pg_catalog.pg_namespace n ON n.oid = c.collnamespace
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
UNION ALL
SELECT 'text_search_configuration', n.nspname, c.cfgname,
       pg_get_userbyid(c.cfgowner)
FROM pg_catalog.pg_ts_config c
JOIN pg_catalog.pg_namespace n ON n.oid = c.cfgnamespace
UNION ALL
SELECT 'text_search_dictionary', n.nspname, d.dictname,
       pg_get_userbyid(d.dictowner)
FROM pg_catalog.pg_ts_dict d
JOIN pg_catalog.pg_namespace n ON n.oid = d.dictnamespace
UNION ALL
SELECT 'text_search_parser', n.nspname, p.prsname,
       pg_get_userbyid(p.prsowner)
FROM pg_catalog.pg_ts_parser p
JOIN pg_catalog.pg_namespace n ON n.oid = p.prsnamespace
UNION ALL
SELECT 'text_search_template', n.nspname, t.tmplname,
       pg_get_userbyid(t.tmplowner)
FROM pg_catalog.pg_ts_template t
JOIN pg_catalog.pg_namespace n ON n.oid = t.tmplnamespace
ORDER BY object_kind, schema_name, object_name;

-- Resultado obrigatório: nenhum type, domain, enum ou extensão relevante
-- pertencente a alianza_audit_ro. A ausência de visibilidade deve ser marcada
-- como indeterminada, não interpretada como ausência física.

-- ============================================================================
-- ETAPA 8C — ACLs e privilégios de sequences
-- ============================================================================
WITH RECURSIVE role_tree AS (
  SELECT oid AS role_oid FROM pg_catalog.pg_roles WHERE rolname = current_user
  UNION
  SELECT am.roleid
  FROM pg_catalog.pg_auth_members am
  JOIN role_tree rt ON rt.role_oid = am.member
)
SELECT n.nspname AS schema_name,
       c.relname AS sequence_name,
       has_sequence_privilege(current_user, c.oid, 'USAGE') AS can_usage,
       has_sequence_privilege(current_user, c.oid, 'SELECT') AS can_select,
       has_sequence_privilege(current_user, c.oid, 'UPDATE') AS can_update,
       x.grantee,
       CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END AS grantee_name,
       x.privilege_type,
       x.is_grantable
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('s', c.relowner))) x
LEFT JOIN pg_catalog.pg_roles r ON r.oid = x.grantee
WHERE c.relkind = 'S'
  AND n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
  AND (x.grantee = 0 OR x.grantee IN (SELECT role_oid FROM role_tree))
ORDER BY n.nspname, c.relname, grantee_name, x.privilege_type;

-- Resultado obrigatório para sequences operacionais: can_update = false e
-- nenhuma concessão inesperada via PUBLIC ou membership.

-- ============================================================================
-- ETAPA 8D — supabase_migrations sem acesso amplo ao schema
-- ============================================================================
SELECT c.relname AS table_name,
       has_table_privilege(current_user, c.oid, 'SELECT') AS can_select,
       has_table_privilege(current_user, c.oid, 'INSERT') AS can_insert,
       has_table_privilege(current_user, c.oid, 'UPDATE') AS can_update,
       has_table_privilege(current_user, c.oid, 'DELETE') AS can_delete
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'supabase_migrations'
  AND c.relkind IN ('r', 'p', 'v', 'm')
ORDER BY c.relname;

-- Esperado: SELECT true somente em schema_migrations; escrita false em todas.

-- ============================================================================
-- ETAPA 8E — visibilidade dos catálogos PostgreSQL
-- ============================================================================
-- Uma role comum pode consultar catálogos necessários ao planner, mas
-- information_schema, pg_roles e pg_auth_members podem filtrar a visibilidade.
-- Estas consultas medem a visibilidade real; não assumem que ausência de linhas
-- significa ausência física do objeto.
SELECT c.oid::regclass::text AS catalog_relation,
       has_table_privilege(current_user, c.oid, 'SELECT') AS catalog_select
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'pg_catalog'
  AND c.relname IN ('pg_class', 'pg_namespace', 'pg_attribute', 'pg_constraint',
                    'pg_index', 'pg_proc', 'pg_trigger', 'pg_auth_members',
                    'pg_roles', 'pg_policy', 'pg_default_acl')
ORDER BY c.relname;

SELECT current_user AS role_name,
       (SELECT count(*) FROM pg_catalog.pg_roles) AS visible_role_rows,
       (SELECT count(*) FROM pg_catalog.pg_auth_members) AS visible_membership_rows,
       (SELECT count(*) FROM information_schema.tables
        WHERE table_schema NOT LIKE 'pg_%' AND table_schema <> 'information_schema')
       AS visible_information_schema_tables
LIMIT 1;

-- ============================================================================
-- ETAPA 8F — Default privileges reais
-- ============================================================================
-- defaclobjtype: r=tables, S=sequences, f=functions, T=types, n=schemas.
-- grantee = 0 representa PUBLIC. Ausência de linhas pode significar ausência
-- de defaults ou visibilidade limitada; não concluir além da evidência.
SELECT d.defaclrole::regrole::text AS owner_role,
       d.defaclnamespace::regnamespace::text AS schema_name,
       d.defaclobjtype AS object_type,
       x.grantee,
       CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END AS grantee_name,
       x.privilege_type,
       x.is_grantable
FROM pg_catalog.pg_default_acl d
CROSS JOIN LATERAL aclexplode(d.defaclacl) x
LEFT JOIN pg_catalog.pg_roles r ON r.oid = x.grantee
ORDER BY owner_role, schema_name, object_type, grantee_name, x.privilege_type;

-- ==========================================================================
-- ETAPA 9 — Inventário de funções potencialmente sensíveis
-- Não executar funções; apenas consultar catálogo e privilégios.
-- ============================================================================
SELECT n.nspname AS schema_name,
       p.oid::regprocedure::text AS function_signature,
       p.prosecdef AS security_definer,
       pg_get_userbyid(p.proowner) AS owner_name,
       owner.rolsuper AS owner_superuser,
       owner.rolcreaterole AS owner_createrole,
       owner.rolbypassrls AS owner_bypassrls,
       p.prokind,
       p.provolatile,
       lang.lanname AS language_name,
       p.proconfig AS function_config,
       has_function_privilege(current_user, p.oid, 'EXECUTE') AS can_execute,
       pg_get_functiondef(p.oid) AS visible_definition
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
LEFT JOIN pg_catalog.pg_roles owner ON owner.oid = p.proowner
JOIN pg_catalog.pg_language lang ON lang.oid = p.prolang
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
  AND p.prokind IN ('f', 'p')
ORDER BY n.nspname, function_signature
;

-- Aggregates não são funções/procedures para pg_get_functiondef. Inventariar
-- separadamente, sem tentar obter uma definição de função.
SELECT n.nspname AS schema_name,
       p.oid::regprocedure::text AS aggregate_signature,
       pg_get_userbyid(p.proowner) AS owner_name,
       lang.lanname AS language_name,
       has_function_privilege(current_user, p.oid, 'EXECUTE') AS can_execute
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
JOIN pg_catalog.pg_language lang ON lang.oid = p.prolang
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
  AND p.prokind = 'a'
ORDER BY n.nspname, aggregate_signature;

-- Proveniência do EXECUTE: direto, PUBLIC ou membership transitiva. A ACL não
-- prova efeitos da função; a definição visível deve ser revisada sem invocação.
WITH RECURSIVE role_tree AS (
  SELECT oid AS role_oid FROM pg_catalog.pg_roles WHERE rolname = current_user
  UNION
  SELECT am.roleid
  FROM pg_catalog.pg_auth_members am
  JOIN role_tree rt ON rt.role_oid = am.member
)
SELECT n.nspname AS schema_name,
       p.oid::regprocedure::text AS function_signature,
       p.prosecdef AS security_definer,
       pg_get_userbyid(p.proowner) AS owner_name,
       p.proconfig AS function_config,
       lang.lanname AS language_name,
       p.prokind,
       x.grantee,
       CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END AS grantee_name,
       x.privilege_type,
       x.is_grantable
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
JOIN pg_catalog.pg_language lang ON lang.oid = p.prolang
CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) x
LEFT JOIN pg_catalog.pg_roles r ON r.oid = x.grantee
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
  AND p.prokind IN ('f', 'p')
  AND x.privilege_type = 'EXECUTE'
  AND (x.grantee = 0 OR x.grantee IN (SELECT role_oid FROM role_tree))
ORDER BY n.nspname, function_signature, grantee_name;

-- Memberships dos proprietários de funções SECURITY DEFINER. A ausência de
-- visibilidade de pg_auth_members torna a classificação indeterminada.
SELECT fn.nspname AS function_schema,
       p.oid::regprocedure::text AS function_signature,
       owner.rolname AS owner_role,
       parent.rolname AS owner_parent_role,
       am.admin_option,
       to_jsonb(am)->>'inherit_option' AS owner_inherit_option,
       to_jsonb(am)->>'set_option' AS owner_set_option,
       owner.rolsuper AS owner_superuser,
       owner.rolcreaterole AS owner_createrole,
       owner.rolbypassrls AS owner_bypassrls
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace fn ON fn.oid = p.pronamespace
JOIN pg_catalog.pg_roles owner ON owner.oid = p.proowner
JOIN pg_catalog.pg_auth_members am ON am.member = owner.oid
JOIN pg_catalog.pg_roles parent ON parent.oid = am.roleid
WHERE p.prosecdef
  AND fn.nspname NOT LIKE 'pg_%'
  AND fn.nspname <> 'information_schema'
ORDER BY fn.nspname, function_signature, parent.rolname;

-- Fecho transitivo das memberships dos owners SECURITY DEFINER. Distingue a
-- role owner inicial de roles ancestrais e não executa nenhuma delas.
WITH RECURSIVE owner_tree AS (
  SELECT p.proowner AS role_oid,
         p.oid AS function_oid,
         0 AS depth,
         ARRAY[p.proowner] AS path
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace fn ON fn.oid = p.pronamespace
  WHERE p.prosecdef
    AND p.prokind IN ('f', 'p')
    AND fn.nspname NOT LIKE 'pg_%'
    AND fn.nspname <> 'information_schema'
  UNION ALL
  SELECT am.roleid,
         ot.function_oid,
         ot.depth + 1,
         ot.path || am.roleid
  FROM pg_catalog.pg_auth_members am
  JOIN owner_tree ot ON ot.role_oid = am.member
  WHERE NOT am.roleid = ANY(ot.path)
)
SELECT p.oid::regprocedure::text AS function_signature,
       member_role.rolname AS owner_or_ancestor_role,
       ot.depth,
       member_role.rolsuper,
       member_role.rolcreaterole,
       member_role.rolbypassrls,
       pg_catalog.pg_has_role(current_user, member_role.oid, 'SET') AS auditor_can_set_role
FROM owner_tree ot
JOIN pg_catalog.pg_proc p ON p.oid = ot.function_oid
JOIN pg_catalog.pg_roles member_role ON member_role.oid = ot.role_oid
ORDER BY function_signature, ot.depth, owner_or_ancestor_role;

-- Se houver função SECURITY DEFINER executável por PUBLIC ou pela role,
-- classificar assim:
--   1) risco confirmado: EXECUTE efetivo + owner privilegiado + definição
--      visível com INSERT/UPDATE/DELETE/TRUNCATE/DDL, alteração de role/ACL,
--      acesso a secrets ou bypass explícito;
--   2) risco elevado: search_path configurável ou incluindo schema controlável,
--      owner privilegiado ou definição não disponível;
--   3) risco não confirmado: sem EXECUTE efetivo para a role/PUBLIC ou função
--      SECURITY INVOKER sem outro caminho de escalada.
-- Risco confirmado ou elevado impede aprovação plena. Não revogar EXECUTE de
-- PUBLIC automaticamente; qualquer correção é mudança separada.

-- ============================================================================
-- ETAPA 9A — Inventário de todas as funções executáveis
-- ============================================================================
-- SECURITY INVOKER não é sinónimo de inofensiva: linguagem, owner, corpo,
-- dependências e chamadas indiretas continuam a exigir revisão. Funções C,
-- internal e linguagens procedurais externas não são executadas.
SELECT n.nspname AS schema_name,
       p.oid::regprocedure::text AS function_signature,
       CASE WHEN p.prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END
         AS security_mode,
       pg_get_userbyid(p.proowner) AS owner_name,
       lang.lanname AS language_name,
       lang.laninline,
       lang.lanvalidator::regproc::text AS validator,
       p.prokind,
       p.provolatile,
       p.prosrc,
       p.probin,
       p.proconfig,
       has_function_privilege(current_user, p.oid, 'EXECUTE') AS can_execute,
       ext.extname AS extension_name,
       CASE WHEN p.prokind IN ('f', 'p') THEN pg_get_functiondef(p.oid) END
         AS visible_definition
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
JOIN pg_catalog.pg_language lang ON lang.oid = p.prolang
LEFT JOIN pg_catalog.pg_depend dep
  ON dep.classid = 'pg_proc'::regclass
 AND dep.objid = p.oid
 AND dep.refclassid = 'pg_extension'::regclass
 AND dep.deptype = 'e'
LEFT JOIN pg_catalog.pg_extension ext ON ext.oid = dep.refobjid
WHERE n.nspname NOT LIKE 'pg_%'
  AND n.nspname <> 'information_schema'
ORDER BY n.nspname, function_signature;

-- Dependências de funções executáveis. pg_depend não prova todas as chamadas
-- dinâmicas; a ausência de dependências não é evidência de ausência de efeitos.
SELECT p.oid::regprocedure::text AS function_signature,
       p.prosecdef,
       dep.deptype,
       dep.refclassid::regclass::text AS referenced_class,
       dep.refobjid::text AS referenced_object_id
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
JOIN pg_catalog.pg_depend dep
  ON dep.classid = 'pg_proc'::regclass
 AND dep.objid = p.oid
WHERE n.nspname NOT LIKE 'pg_%'
  AND n.nspname <> 'information_schema'
  AND has_function_privilege(current_user, p.oid, 'EXECUTE')
ORDER BY function_signature, referenced_class, referenced_object_id;

-- Toda função executável requer revisão documental individual. Uma revisão
-- manual sem evidências de definição, linguagem, owner e dependências não
-- muda o resultado para APROVADA.

-- ============================================================================
-- ETAPA 9D — Registro externo e reconciliação das revisões individuais
-- ============================================================================
-- O registro é uma entrada externa, sem tabela persistente e sem pgcrypto.
-- O cliente deve obter a representação da MESMA sessão/inventário, conservar
-- os bytes UTF-8 sem normalização e calcular definition_sha256_calculated
-- independentemente. A consulta reconcilia esse cálculo com o hash apresentado;
-- sha256_verified não é usado como prova isolada.
--
-- Contrato: os campos definition_bytes_hex, definition_encoding, snapshot_id,
-- definition_source e definition_sha256_calculated devem ser transportados junto
-- com o hash apresentado. Divergência, ausência de bytes/evidência, mudança de
-- identidade/metadados ou snapshot diferente torna a revisão inválida.
WITH review_registry AS (
  SELECT * FROM (VALUES
    (NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text,
     NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::boolean,
     NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text,
     NULL::text, NULL::text, NULL::text, NULL::text, NULL::text)
  ) AS v(audit_id, role_name, snapshot_id, schema_name, object_name,
         identity_arguments, object_type, language_name, owner_name,
         security_mode, extension_name, definition_normalized, definition_source,
         definition_encoding, definition_bytes_hex, definition_sha256,
         definition_sha256_calculated, review_status, reviewer, reviewed_at,
         evidence_ref, technical_conclusion, risk_justification)
  WHERE schema_name IS NOT NULL
), function_inventory AS (
  SELECT n.nspname AS schema_name, p.proname AS object_name,
         pg_get_function_identity_arguments(p.oid) AS identity_arguments,
         CASE p.prokind WHEN 'f' THEN 'function' WHEN 'p' THEN 'procedure'
              WHEN 'a' THEN 'aggregate' WHEN 'w' THEN 'window_function' END AS object_type,
         lang.lanname AS language_name, owner.rolname AS owner_name,
         CASE WHEN p.prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END AS security_mode,
         ext.extname AS extension_name,
         CASE WHEN p.prokind IN ('f','p') THEN pg_get_functiondef(p.oid)
              WHEN p.prokind = 'a' THEN format('pg_aggregate:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s',
                p.oid::regprocedure, p.proowner, p.prolang, p.prosecdef,
                p.provolatile, p.proparallel, p.proleakproof, p.prosrc,
                p.proargtypes::text, a.aggkind, a.aggnumdirectargs,
                a.aggtransfn::text, a.aggfinalfn::text, a.aggcombinefn::text,
                a.aggserialfn::text, a.aggdeserialfn::text, a.aggmtransfn::text,
                a.aggminvtransfn::text)
              WHEN p.prokind = 'w' THEN format('pg_window:%s:%s:%s:%s:%s:%s:%s:%s:%s',
                p.oid::regprocedure, p.proowner, p.prolang, p.prosecdef,
                p.provolatile, p.proparallel, p.proleakproof, p.prosrc,
                p.proargtypes::text)
         END AS canonical_definition,
         has_function_privilege(current_user, p.oid, 'EXECUTE') AS can_execute
  FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
  JOIN pg_catalog.pg_language lang ON lang.oid=p.prolang
  LEFT JOIN pg_catalog.pg_roles owner ON owner.oid=p.proowner
  LEFT JOIN pg_catalog.pg_aggregate a ON a.aggfnoid=p.oid
  LEFT JOIN pg_catalog.pg_depend dep ON dep.classid='pg_proc'::regclass AND dep.objid=p.oid
    AND dep.refclassid='pg_extension'::regclass AND dep.deptype='e'
  LEFT JOIN pg_catalog.pg_extension ext ON ext.oid=dep.refobjid
  WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
    AND p.prokind IN ('f','p','a','w')
), review_reconciliation AS (
  SELECT count(*) FILTER (WHERE fi.can_execute) AS executable_object_count,
    count(*) FILTER (WHERE rr.schema_name IS NOT NULL) AS registry_entry_count,
    COALESCE(bool_and(
      rr.review_status='APPROVED' AND rr.audit_id IS NOT NULL
      AND rr.role_name=current_user AND rr.snapshot_id=current_setting('alianza.audit_snapshot_id',true)
      AND rr.definition_source=CASE WHEN fi.object_type IN ('function','procedure') THEN 'pg_get_functiondef'
                                    WHEN fi.object_type='aggregate' THEN 'pg_catalog.pg_aggregate'
                                    ELSE 'pg_catalog.pg_proc' END
      AND rr.definition_encoding='UTF-8' AND rr.definition_normalized IS FALSE
      AND rr.definition_bytes_hex IS NOT NULL AND rr.definition_bytes_hex ~ '^[0-9A-Fa-f]+$'
      AND length(rr.definition_sha256)=64 AND rr.definition_sha256 ~ '^[0-9A-Fa-f]{64}$'
      AND rr.definition_sha256 = rr.definition_sha256_calculated
      AND rr.schema_name=fi.schema_name AND rr.object_name=fi.object_name
      AND rr.identity_arguments=fi.identity_arguments AND rr.object_type=fi.object_type
      AND rr.language_name=fi.language_name AND rr.owner_name=fi.owner_name
      AND rr.security_mode=fi.security_mode AND coalesce(rr.extension_name,'')=coalesce(fi.extension_name,'')
      AND rr.reviewer IS NOT NULL AND rr.reviewed_at IS NOT NULL AND rr.evidence_ref IS NOT NULL
      AND rr.technical_conclusion IS NOT NULL AND rr.risk_justification IS NOT NULL
    ) FILTER (WHERE fi.can_execute), true) AS all_reviews_valid,
    COALESCE(bool_or(fi.can_execute AND rr.schema_name IS NULL),false) AS has_missing_review,
    COALESCE(bool_or(fi.can_execute AND rr.schema_name IS NOT NULL AND NOT (
      rr.review_status='APPROVED' AND rr.audit_id IS NOT NULL
      AND rr.role_name=current_user AND rr.snapshot_id=current_setting('alianza.audit_snapshot_id',true)
      AND rr.definition_sha256=rr.definition_sha256_calculated
      AND rr.schema_name=fi.schema_name AND rr.object_name=fi.object_name
      AND rr.identity_arguments=fi.identity_arguments AND rr.object_type=fi.object_type
      AND rr.language_name=fi.language_name AND rr.owner_name=fi.owner_name
      AND rr.security_mode=fi.security_mode AND coalesce(rr.extension_name,'')=coalesce(fi.extension_name,'')
    )),false) AS has_stale_or_invalid_review,
    COALESCE(bool_or(fi.can_execute AND (fi.object_type='aggregate' OR fi.object_type='window_function')
                     AND rr.schema_name IS NULL),false) AS has_unreviewed_special_executable
  FROM function_inventory fi LEFT JOIN review_registry rr
    ON rr.schema_name=fi.schema_name AND rr.object_name=fi.object_name
   AND rr.identity_arguments=fi.identity_arguments AND rr.object_type=fi.object_type
)
SELECT * FROM review_reconciliation;

-- ETAPA 9B — Large Objects
-- ============================================================================
-- Executar somente se pg_largeobject_metadata e suas ACLs forem visíveis
-- existirem na versão identificada. Se algum catálogo/função não estiver
-- disponível ou não for visível, o resultado é INDETERMINADA.
WITH RECURSIVE role_tree AS (
  SELECT oid AS role_oid FROM pg_catalog.pg_roles WHERE rolname = current_user
  UNION
  SELECT am.roleid
  FROM pg_catalog.pg_auth_members am
  JOIN role_tree rt ON rt.role_oid = am.member
)
SELECT m.oid AS large_object_oid,
       pg_get_userbyid(m.lomowner) AS owner_name,
       m.lomacl AS object_acl,
       x.grantee,
       CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END AS grantee_name,
       x.privilege_type,
       x.is_grantable,
       (x.grantee = 0 OR x.grantee = (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = current_user))
         AS direct_or_public,
       (x.grantee IN (SELECT role_oid FROM role_tree)) AS via_membership,
       EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(m.lomacl, pg_catalog.acldefault('L', m.lomowner))) x WHERE x.privilege_type = 'SELECT' AND (x.grantee = 0 OR x.grantee = current_user::regrole OR pg_catalog.pg_has_role(current_user, x.grantee, 'USAGE'))) AS can_read,
       EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(m.lomacl, pg_catalog.acldefault('L', m.lomowner))) x WHERE x.privilege_type = 'UPDATE' AND (x.grantee = 0 OR x.grantee = current_user::regrole OR pg_catalog.pg_has_role(current_user, x.grantee, 'USAGE'))) AS can_write
FROM pg_catalog.pg_largeobject_metadata m
CROSS JOIN LATERAL aclexplode(COALESCE(m.lomacl, acldefault('L', m.lomowner))) x
LEFT JOIN pg_catalog.pg_roles r ON r.oid = x.grantee
WHERE x.grantee = 0
   OR x.grantee IN (SELECT role_oid FROM role_tree)
ORDER BY m.oid, grantee_name, x.privilege_type;

-- Privilégios efetivos agregados. Qualquer leitura ou alteração de Large Object
-- fora de uma autorização explícita reprova; falha de execução é indeterminada.
SELECT count(*) AS visible_large_object_count,
       COALESCE(bool_or(EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(m.lomacl, pg_catalog.acldefault('L', m.lomowner))) x WHERE x.privilege_type = 'SELECT' AND (x.grantee = 0 OR x.grantee = current_user::regrole OR pg_catalog.pg_has_role(current_user, x.grantee, 'USAGE')))), false)
         AS has_large_object_read,
       COALESCE(bool_or(EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(m.lomacl, pg_catalog.acldefault('L', m.lomowner))) x WHERE x.privilege_type = 'UPDATE' AND (x.grantee = 0 OR x.grantee = current_user::regrole OR pg_catalog.pg_has_role(current_user, x.grantee, 'USAGE')))), false)
         AS has_large_object_write
FROM pg_catalog.pg_largeobject_metadata m;

-- ============================================================================
-- ETAPA 9C — Ownership e ACLs de objetos externos/operacionais
-- ============================================================================
-- Estas consultas não executam handlers, validadores, publishers, subscribers
-- nem linguagens. Não selecionar conninfo de subscriptions.

SELECT f.oid::regclass::text AS fdw_oid,
       f.fdwname,
       pg_get_userbyid(f.fdwowner) AS owner_name,
       f.fdwacl AS object_acl,
       x.grantee,
       CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END AS grantee_name,
       x.privilege_type,
       x.is_grantable
FROM pg_catalog.pg_foreign_data_wrapper f
CROSS JOIN LATERAL aclexplode(COALESCE(f.fdwacl, acldefault('F', f.fdwowner))) x
LEFT JOIN pg_catalog.pg_roles r ON r.oid = x.grantee
ORDER BY f.fdwname, grantee_name, x.privilege_type;

SELECT s.oid::regclass::text AS server_oid,
       s.srvname,
       pg_get_userbyid(s.srvowner) AS owner_name,
       s.srvacl AS object_acl,
       x.grantee,
       CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END AS grantee_name,
       x.privilege_type,
       x.is_grantable
FROM pg_catalog.pg_foreign_server s
CROSS JOIN LATERAL aclexplode(COALESCE(s.srvacl, acldefault('S', s.srvowner))) x
LEFT JOIN pg_catalog.pg_roles r ON r.oid = x.grantee
ORDER BY s.srvname, grantee_name, x.privilege_type;

SELECT e.oid AS event_trigger_oid,
       e.evtname,
       pg_get_userbyid(e.evtowner) AS owner_name,
       e.evtevent,
       e.evtenabled,
       e.evtfoid::regprocedure::text AS handler_signature
FROM pg_catalog.pg_event_trigger e
ORDER BY e.evtname;

SELECT p.oid AS publication_oid,
       p.pubname,
       pg_get_userbyid(p.pubowner) AS owner_name,
       p.puballtables,
       p.pubinsert,
       p.pubupdate,
       p.pubdelete,
       p.pubtruncate
FROM pg_catalog.pg_publication p
ORDER BY p.pubname;

SELECT s.oid AS subscription_oid,
       s.subname,
       pg_get_userbyid(s.subowner) AS owner_name,
       s.subenabled,
       s.subslotname,
       s.subpublications
FROM pg_catalog.pg_subscription s
ORDER BY s.subname;

SELECT l.oid AS language_oid,
       l.lanname,
       pg_get_userbyid(l.lanowner) AS owner_name,
       l.lanpltrusted,
       l.lanacl AS object_acl,
       x.grantee,
       CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END AS grantee_name,
       x.privilege_type,
       x.is_grantable
FROM pg_catalog.pg_language l
CROSS JOIN LATERAL aclexplode(COALESCE(l.lanacl, acldefault('l', l.lanowner))) x
LEFT JOIN pg_catalog.pg_roles r ON r.oid = x.grantee
ORDER BY l.lanname, grantee_name, x.privilege_type;

-- ==========================================================================
-- ETAPA 10 — Metadados estruturais sem leitura de dados
-- ============================================================================
SELECT table_schema,
       table_name,
       table_type
FROM information_schema.tables
WHERE table_schema NOT LIKE 'pg_%' AND table_schema <> 'information_schema'
ORDER BY table_schema, table_name;

SELECT table_schema,
       table_name,
       column_name,
       data_type,
       udt_name,
       is_nullable,
       column_default
FROM information_schema.columns
WHERE table_schema NOT LIKE 'pg_%' AND table_schema <> 'information_schema'
ORDER BY table_schema, table_name, ordinal_position;

SELECT tc.table_schema,
       tc.table_name,
       tc.constraint_name,
       tc.constraint_type
FROM information_schema.table_constraints tc
WHERE tc.table_schema NOT LIKE 'pg_%'
  AND tc.table_schema <> 'information_schema'
ORDER BY tc.table_schema, tc.table_name, tc.constraint_name;

SELECT schemaname,
       tablename,
       indexname,
       indexdef
FROM pg_catalog.pg_indexes
WHERE schemaname NOT LIKE 'pg_%' AND schemaname <> 'information_schema'
ORDER BY schemaname, tablename, indexname;

SELECT n.nspname AS schema_name,
       c.relname AS table_name,
       c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS force_rls
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p')
  AND n.nspname NOT LIKE 'pg_%'
  AND n.nspname <> 'information_schema'
ORDER BY n.nspname, c.relname;

SELECT schemaname,
       tablename,
       policyname,
       roles,
       cmd,
       qual,
       with_check
FROM pg_catalog.pg_policies
WHERE schemaname NOT LIKE 'pg_%' AND schemaname <> 'information_schema'
ORDER BY schemaname, tablename, policyname;

-- ============================================================================
-- ETAPA 11 — Histórico físico de migrations
-- ============================================================================
SELECT version,
       name
FROM supabase_migrations.schema_migrations
ORDER BY version;

-- ============================================================================
-- ETAPA 12 — Verificação de transação read-only
-- Não realizar INSERT/UPDATE/DELETE como teste.
-- ============================================================================
SHOW default_transaction_read_only;
SHOW statement_timeout;
SHOW idle_in_transaction_session_timeout;

BEGIN;
SELECT current_setting('transaction_read_only') AS transaction_read_only
LIMIT 1;
ROLLBACK;

-- Resultado obrigatório: transaction_read_only = on.
-- Resultado obrigatório adicional: default_transaction_read_only = on.
-- A configuração padrão não substitui ACLs, RLS ou a verificação do estado
-- transaccional; ambas as flags são necessárias para aprovação.

-- ============================================================================
-- ETAPA 13 — Validação final objetiva (3B.1.8)
-- ============================================================================
-- Esta consulta só pode emitir APROVADA quando todos os checks obrigatórios
-- abaixo foram observados. Falha de execução, timeout, visibilidade incompleta
-- ou inventário truncado deve ser tratado pelo cliente como INDETERMINADA;
-- não deve ser convertido em ausência de risco.
WITH RECURSIVE
review_registry AS (
  SELECT *
  FROM (VALUES
    (NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text,
     NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::boolean,
     NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text,
     NULL::text, NULL::text, NULL::text, NULL::text, NULL::text)
  ) AS v(audit_id, role_name, snapshot_id, schema_name, object_name,
         identity_arguments, object_type, language_name, owner_name, security_mode,
         extension_name, definition_normalized, definition_source, definition_encoding,
         definition_bytes_hex, definition_sha256, definition_sha256_calculated,
         review_status, reviewer, reviewed_at, evidence_ref, technical_conclusion,
         risk_justification)
  WHERE schema_name IS NOT NULL
),
review_inventory_final AS (
  SELECT n.nspname AS schema_name, p.proname AS object_name,
    pg_get_function_identity_arguments(p.oid) AS identity_arguments,
    CASE p.prokind WHEN 'f' THEN 'function' WHEN 'p' THEN 'procedure'
      WHEN 'a' THEN 'aggregate' WHEN 'w' THEN 'window_function' END AS object_type,
    lang.lanname AS language_name, owner.rolname AS owner_name,
    CASE WHEN p.prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END AS security_mode,
    ext.extname AS extension_name, has_function_privilege(current_user,p.oid,'EXECUTE') AS can_execute,
    CASE WHEN p.prokind IN ('f','p') THEN 'pg_get_functiondef'
         WHEN p.prokind='a' THEN 'pg_catalog.pg_aggregate' ELSE 'pg_catalog.pg_proc' END AS definition_source
  FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
  JOIN pg_catalog.pg_language lang ON lang.oid=p.prolang
  LEFT JOIN pg_catalog.pg_roles owner ON owner.oid=p.proowner
  LEFT JOIN pg_catalog.pg_depend dep ON dep.classid='pg_proc'::regclass AND dep.objid=p.oid
    AND dep.refclassid='pg_extension'::regclass AND dep.deptype='e'
  LEFT JOIN pg_catalog.pg_extension ext ON ext.oid=dep.refobjid
  WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
    AND p.prokind IN ('f','p','a','w')
), review_state AS (
  SELECT COALESCE(bool_and(
    rr.review_status='APPROVED' AND rr.audit_id IS NOT NULL AND rr.role_name=current_user
    AND rr.snapshot_id=current_setting('alianza.audit_snapshot_id',true)
    AND rr.definition_source=fi.definition_source AND rr.definition_encoding='UTF-8'
    AND rr.definition_normalized IS FALSE AND rr.definition_bytes_hex IS NOT NULL
    AND rr.definition_sha256=rr.definition_sha256_calculated
    AND rr.schema_name=fi.schema_name AND rr.object_name=fi.object_name
    AND rr.identity_arguments=fi.identity_arguments AND rr.object_type=fi.object_type
    AND rr.language_name=fi.language_name AND rr.owner_name=fi.owner_name
    AND rr.security_mode=fi.security_mode AND coalesce(rr.extension_name,'')=coalesce(fi.extension_name,'')
    AND rr.reviewer IS NOT NULL AND rr.reviewed_at IS NOT NULL AND rr.evidence_ref IS NOT NULL
    AND rr.technical_conclusion IS NOT NULL AND rr.risk_justification IS NOT NULL
  ) FILTER (WHERE fi.can_execute),true) AS all_function_reviews_valid,
  COALESCE(bool_or(fi.can_execute AND rr.schema_name IS NULL),false) AS has_missing_function_review,
  COALESCE(bool_or(fi.can_execute AND rr.schema_name IS NOT NULL AND NOT (
    rr.review_status='APPROVED' AND rr.definition_sha256=rr.definition_sha256_calculated
    AND rr.schema_name=fi.schema_name AND rr.object_name=fi.object_name
    AND rr.identity_arguments=fi.identity_arguments AND rr.object_type=fi.object_type
    AND rr.language_name=fi.language_name AND rr.owner_name=fi.owner_name
    AND rr.security_mode=fi.security_mode AND coalesce(rr.extension_name,'')=coalesce(fi.extension_name,'')
  )),false) AS has_stale_function_review,
  count(*) FILTER (WHERE fi.can_execute) AS executable_function_count,
  count(*) FILTER (WHERE rr.schema_name IS NOT NULL) AS registry_entry_count,
  COALESCE(bool_or(fi.can_execute AND fi.object_type IN ('aggregate','window_function')
                   AND rr.schema_name IS NULL),false) AS has_nonverifiable_executable_function
  FROM review_inventory_final fi LEFT JOIN review_registry rr
    ON rr.schema_name=fi.schema_name AND rr.object_name=fi.object_name
   AND rr.identity_arguments=fi.identity_arguments AND rr.object_type=fi.object_type
),
temporary_acceptance AS (
  SELECT
    (ta.audit_id IS NOT NULL AND ta.role_name=current_user AND ta.responsible IS NOT NULL
     AND ta.accepted_at IS NOT NULL AND ta.evidence_ref IS NOT NULL
     AND ta.justification IS NOT NULL AND ta.risk_scope IS NOT NULL
     AND ta.acceptance_valid IS TRUE) AS temporary_acceptance_valid,
    ta.responsible AS temporary_acceptance_responsible, ta.accepted_at AS temporary_acceptance_date,
    ta.evidence_ref AS temporary_acceptance_evidence, ta.justification AS temporary_acceptance_justification
  FROM (VALUES
    (NULL::text, NULL::text, NULL::text, NULL::timestamptz, NULL::text, NULL::text, NULL::text, NULL::boolean)
  ) AS ta(audit_id, role_name, responsible, accepted_at, evidence_ref, justification, risk_scope, acceptance_valid)
),
role_tree AS (
  SELECT r.oid AS role_oid,
         r.rolname,
         0 AS depth,
         ARRAY[r.oid] AS path
  FROM pg_catalog.pg_roles r
  WHERE r.rolname = current_user
  UNION ALL
  SELECT parent.oid,
         parent.rolname,
         rt.depth + 1,
         rt.path || parent.oid
  FROM pg_catalog.pg_auth_members am
  JOIN role_tree rt ON rt.role_oid = am.member
  JOIN pg_catalog.pg_roles parent ON parent.oid = am.roleid
  WHERE NOT parent.oid = ANY(rt.path)
),
membership_state AS (
  SELECT
    EXISTS (
      SELECT 1
      FROM pg_catalog.pg_auth_members am
      JOIN pg_catalog.pg_roles member ON member.oid = am.member
      WHERE member.rolname = current_user
    ) AS has_direct_membership,
    EXISTS (SELECT 1 FROM role_tree WHERE depth > 0) AS has_indirect_membership,
    EXISTS (
      SELECT 1
      FROM role_tree rt
      WHERE rt.depth > 0
        AND pg_catalog.pg_has_role(current_user, rt.role_oid, 'USAGE')
    ) AS has_effective_inherited_membership,
    EXISTS (
      SELECT 1
      FROM pg_catalog.pg_roles r
      WHERE r.rolname <> current_user
        AND pg_catalog.pg_has_role(current_user, r.oid, 'SET')
    ) AS can_set_other_role,
    (
      SELECT count(*) = 3
      FROM information_schema.columns
      WHERE table_schema = 'pg_catalog'
        AND table_name = 'pg_auth_members'
        AND column_name IN ('admin_option', 'inherit_option', 'set_option')
    ) AS membership_options_visible
),
schema_state AS (
  SELECT
    count(*) AS visible_schema_count,
    COALESCE(bool_or(has_schema_privilege(current_user, n.oid, 'CREATE')), false)
      AS has_schema_create
  FROM pg_catalog.pg_namespace n
  WHERE n.nspname NOT LIKE 'pg_%'
    AND n.nspname <> 'information_schema'
),
relation_state AS (
  SELECT
    count(*) AS visible_relation_count,
    COALESCE(bool_or(
      has_table_privilege(current_user, c.oid, 'INSERT')
      OR has_table_privilege(current_user, c.oid, 'UPDATE')
      OR has_table_privilege(current_user, c.oid, 'DELETE')
      OR has_table_privilege(current_user, c.oid, 'TRUNCATE')
      OR has_table_privilege(current_user, c.oid, 'REFERENCES')
      OR has_table_privilege(current_user, c.oid, 'TRIGGER')
      OR has_any_column_privilege(current_user, c.oid, 'INSERT')
      OR has_any_column_privilege(current_user, c.oid, 'UPDATE')
      OR has_any_column_privilege(current_user, c.oid, 'REFERENCES')
    ), false) AS has_relation_write,
    COALESCE(bool_or(
      (has_table_privilege(current_user, c.oid, 'SELECT')
       OR has_any_column_privilege(current_user, c.oid, 'SELECT'))
      AND NOT (n.nspname = 'supabase_migrations'
               AND c.relname = 'schema_migrations')
    ), false) AS has_unauthorized_select,
    COALESCE(bool_or(
      n.nspname = 'supabase_migrations'
      AND c.relname = 'schema_migrations'
      AND (has_table_privilege(current_user, c.oid, 'SELECT')
           OR has_any_column_privilege(current_user, c.oid, 'SELECT'))
    ), false) AS has_migration_select
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind IN ('r', 'p', 'f', 'v', 'm')
    AND n.nspname NOT LIKE 'pg_%'
    AND n.nspname <> 'information_schema'
),
sequence_state AS (
  SELECT
    count(*) AS visible_sequence_count,
    COALESCE(bool_or(
      has_sequence_privilege(current_user, c.oid, 'USAGE')
      OR has_sequence_privilege(current_user, c.oid, 'SELECT')
      OR has_sequence_privilege(current_user, c.oid, 'UPDATE')
    ), false) AS has_sequence_privilege
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind = 'S'
    AND n.nspname NOT LIKE 'pg_%'
    AND n.nspname <> 'information_schema'
),
large_object_state AS (
  SELECT
    count(*) AS visible_large_object_count,
    COALESCE(bool_or(EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(m.lomacl, pg_catalog.acldefault('L', m.lomowner))) x WHERE x.privilege_type = 'SELECT' AND (x.grantee = 0 OR x.grantee = current_user::regrole OR pg_catalog.pg_has_role(current_user, x.grantee, 'USAGE')))), false)
      AS has_large_object_read,
    COALESCE(bool_or(EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(m.lomacl, pg_catalog.acldefault('L', m.lomowner))) x WHERE x.privilege_type = 'UPDATE' AND (x.grantee = 0 OR x.grantee = current_user::regrole OR pg_catalog.pg_has_role(current_user, x.grantee, 'USAGE')))), false)
      AS has_large_object_write
  FROM pg_catalog.pg_largeobject_metadata m
),
owner_role_tree AS (
  SELECT p.oid AS function_oid,
         p.proowner AS role_oid,
         ARRAY[p.proowner] AS path
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE p.prosecdef
    AND p.prokind IN ('f', 'p')
    AND n.nspname NOT LIKE 'pg_%'
    AND n.nspname <> 'information_schema'
  UNION ALL
  SELECT ort.function_oid,
         am.roleid,
         ort.path || am.roleid
  FROM pg_catalog.pg_auth_members am
  JOIN owner_role_tree ort ON ort.role_oid = am.member
  WHERE NOT am.roleid = ANY(ort.path)
),
ownership_state AS (
  SELECT
    EXISTS (SELECT 1 FROM pg_catalog.pg_database d
            JOIN pg_catalog.pg_roles r ON r.oid = d.datdba
            WHERE d.datname = current_database() AND r.rolname = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_namespace n
               WHERE n.nspname NOT LIKE 'pg_%'
                 AND n.nspname <> 'information_schema'
                 AND pg_get_userbyid(n.nspowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_class c
               JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
               WHERE n.nspname NOT LIKE 'pg_%'
                 AND n.nspname <> 'information_schema'
                 AND pg_get_userbyid(c.relowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
               JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname NOT LIKE 'pg_%'
                 AND n.nspname <> 'information_schema'
                 AND pg_get_userbyid(p.proowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_type t
               JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
               WHERE n.nspname NOT LIKE 'pg_%'
                 AND n.nspname <> 'information_schema'
                 AND pg_get_userbyid(t.typowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_extension e
               WHERE pg_get_userbyid(e.extowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_largeobject_metadata m
               WHERE pg_get_userbyid(m.lomowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_foreign_data_wrapper f
               WHERE pg_get_userbyid(f.fdwowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_foreign_server s
               WHERE pg_get_userbyid(s.srvowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_event_trigger e
               WHERE pg_get_userbyid(e.evtowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_publication p
               WHERE pg_get_userbyid(p.pubowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_subscription s
               WHERE pg_get_userbyid(s.subowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_language l
               WHERE pg_get_userbyid(l.lanowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_tablespace t
               WHERE pg_get_userbyid(t.spcowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_collation c
               WHERE pg_get_userbyid(c.collowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_ts_config c
               WHERE pg_get_userbyid(c.cfgowner) = current_user)
    OR EXISTS (SELECT 1 FROM pg_catalog.pg_ts_dict d
               WHERE pg_get_userbyid(d.dictowner) = current_user)
    AS has_relevant_ownership
),
owner_effective_privilege_state AS (
  SELECT p.oid AS function_oid,
    (
      has_database_privilege(owner.oid, current_database(), 'CREATE')
      OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_namespace n2
        WHERE n2.nspname NOT LIKE 'pg_%'
          AND n2.nspname <> 'information_schema'
          AND has_schema_privilege(owner.oid, n2.oid, 'CREATE')
      )
      OR EXISTS (
        SELECT 1
        FROM pg_catalog.pg_class c2
        JOIN pg_catalog.pg_namespace n2 ON n2.oid = c2.relnamespace
        WHERE c2.relkind IN ('r', 'p', 'f', 'v', 'm')
          AND n2.nspname NOT LIKE 'pg_%'
          AND n2.nspname <> 'information_schema'
          AND (
            has_table_privilege(owner.oid, c2.oid, 'INSERT')
            OR has_table_privilege(owner.oid, c2.oid, 'UPDATE')
            OR has_table_privilege(owner.oid, c2.oid, 'DELETE')
            OR has_table_privilege(owner.oid, c2.oid, 'TRUNCATE')
            OR has_table_privilege(owner.oid, c2.oid, 'REFERENCES')
            OR has_table_privilege(owner.oid, c2.oid, 'TRIGGER')
            OR has_any_column_privilege(owner.oid, c2.oid, 'INSERT')
            OR has_any_column_privilege(owner.oid, c2.oid, 'UPDATE')
            OR has_any_column_privilege(owner.oid, c2.oid, 'REFERENCES')
          )
      )
      OR EXISTS (
        SELECT 1
        FROM pg_catalog.pg_class s2
        JOIN pg_catalog.pg_namespace n2 ON n2.oid = s2.relnamespace
        WHERE s2.relkind = 'S'
          AND n2.nspname NOT LIKE 'pg_%'
          AND n2.nspname <> 'information_schema'
          AND (
            has_sequence_privilege(owner.oid, s2.oid, 'USAGE')
            OR has_sequence_privilege(owner.oid, s2.oid, 'SELECT')
            OR has_sequence_privilege(owner.oid, s2.oid, 'UPDATE')
          )
      )
      OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_largeobject_metadata lo
        WHERE EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(lo.lomacl, pg_catalog.acldefault('L', lo.lomowner))) x WHERE x.privilege_type = 'UPDATE' AND (x.grantee = 0 OR x.grantee = owner.oid OR pg_catalog.pg_has_role(owner.oid, x.grantee, 'USAGE')))
      )
    ) AS has_owner_effective_write_risk,
    EXISTS (
      SELECT 1 FROM pg_catalog.pg_largeobject_metadata lo
      WHERE EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(lo.lomacl, pg_catalog.acldefault('L', lo.lomowner))) x WHERE x.privilege_type = 'SELECT' AND (x.grantee = 0 OR x.grantee = owner.oid OR pg_catalog.pg_has_role(owner.oid, x.grantee, 'USAGE')))
    ) AS has_owner_large_object_read,
    EXISTS (
      SELECT 1 FROM pg_catalog.pg_foreign_data_wrapper f2
      WHERE pg_get_userbyid(f2.fdwowner) = owner.rolname
    )
    OR EXISTS (
      SELECT 1 FROM pg_catalog.pg_foreign_server s2
      WHERE pg_get_userbyid(s2.srvowner) = owner.rolname
    )
    OR EXISTS (
      SELECT 1 FROM pg_catalog.pg_event_trigger e2
      WHERE pg_get_userbyid(e2.evtowner) = owner.rolname
    )
    OR EXISTS (
      SELECT 1 FROM pg_catalog.pg_publication p2
      WHERE pg_get_userbyid(p2.pubowner) = owner.rolname
    )
    OR EXISTS (
      SELECT 1 FROM pg_catalog.pg_subscription s2
      WHERE pg_get_userbyid(s2.subowner) = owner.rolname
    )
    OR EXISTS (
      SELECT 1 FROM pg_catalog.pg_language l2
      WHERE pg_get_userbyid(l2.lanowner) = owner.rolname
    )
    OR EXISTS (
      SELECT 1 FROM pg_catalog.pg_extension x2
      WHERE pg_get_userbyid(x2.extowner) = owner.rolname
    ) AS has_owner_external_ownership
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_roles owner ON owner.oid = p.proowner
  WHERE p.prosecdef AND p.prokind IN ('f', 'p')
),
security_definer_state AS (
  SELECT
    COALESCE(bool_or(
      p.prosecdef
      AND has_function_privilege(current_user, p.oid, 'EXECUTE')
      AND (
        owner.rolsuper
        OR owner.rolcreaterole
        OR owner.rolbypassrls
        OR EXISTS (
          SELECT 1
          FROM owner_role_tree ort
          JOIN pg_catalog.pg_roles ancestor ON ancestor.oid = ort.role_oid
          WHERE ort.function_oid = p.oid
            AND (ancestor.rolsuper OR ancestor.rolcreaterole
                 OR ancestor.rolbypassrls
                 OR has_database_privilege(ancestor.oid, current_database(), 'CREATE'))
        )
        OR COALESCE(oeps.has_owner_effective_write_risk, false)
        OR COALESCE(oeps.has_owner_external_ownership, false)
      )
    ), false) AS has_security_definer_risk,
    COALESCE(bool_or(
      p.prosecdef
      AND has_function_privilege(current_user, p.oid, 'EXECUTE')
    ), false) AS has_security_definer_review_required,
    count(*) FILTER (
      WHERE p.prosecdef
        AND has_function_privilege(current_user, p.oid, 'EXECUTE')
    ) AS security_definer_review_count,
    COALESCE(bool_or(
      p.prosecdef
      AND has_function_privilege(current_user, p.oid, 'EXECUTE')
      AND (
        owner.rolname IS NULL
        OR p.proconfig IS NULL
        OR NOT EXISTS (
          SELECT 1
          FROM unnest(p.proconfig) cfg
          WHERE cfg LIKE 'search_path=%'
        )
        OR pg_get_functiondef(p.oid) IS NULL
      )
    ), false) AS has_security_definer_metadata_indeterminate,
    COALESCE(bool_or(
      p.prosecdef
      AND has_function_privilege(current_user, p.oid, 'EXECUTE')
      AND (COALESCE(oeps.has_owner_effective_write_risk, false)
           OR COALESCE(oeps.has_owner_large_object_read, false)
           OR COALESCE(oeps.has_owner_external_ownership, false))
    ), false) AS has_owner_effective_privilege_risk
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  LEFT JOIN pg_catalog.pg_roles owner ON owner.oid = p.proowner
  LEFT JOIN owner_effective_privilege_state oeps ON oeps.function_oid = p.oid
  WHERE p.prokind IN ('f', 'p')
    AND n.nspname NOT LIKE 'pg_%'
    AND n.nspname <> 'information_schema'
),
security_definer_dependencies AS (
  SELECT p.oid AS function_oid,
         p.oid::regprocedure::text AS function_signature,
         dep.deptype,
         dep.classid::regclass::text AS dependency_class,
         dep.objid::text AS dependency_object_id,
         dep.refclassid::regclass::text AS referenced_class,
         dep.refobjid::text AS referenced_object_id
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_catalog.pg_depend dep
    ON dep.classid = 'pg_proc'::regclass
   AND dep.objid = p.oid
  WHERE p.prosecdef
    AND p.prokind IN ('f', 'p')
    AND n.nspname NOT LIKE 'pg_%'
    AND n.nspname <> 'information_schema'
),
executable_function_state AS (
  SELECT
    COALESCE(bool_or(has_function_privilege(current_user, p.oid, 'EXECUTE')), false)
      AS has_executable_function_review_required,
    count(*) FILTER (
      WHERE has_function_privilege(current_user, p.oid, 'EXECUTE')
    ) AS executable_function_review_count,
    COALESCE(bool_or(
      has_function_privilege(current_user, p.oid, 'EXECUTE')
      AND (
        owner.rolname IS NULL
        OR lang.lanname IN ('internal', 'c')
        OR (p.prokind IN ('f', 'p') AND pg_get_functiondef(p.oid) IS NULL)
      )
    ), false) AS has_nonverifiable_language_function
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_catalog.pg_language lang ON lang.oid = p.prolang
  LEFT JOIN pg_catalog.pg_roles owner ON owner.oid = p.proowner
  WHERE n.nspname NOT LIKE 'pg_%'
    AND n.nspname <> 'information_schema'
),
catalog_state AS (
  SELECT
    count(*) = 28 AS required_catalogs_visible,
    COALESCE(bool_and(has_table_privilege(current_user, c.oid, 'SELECT')),
             false) AS required_catalogs_selectable,
    COALESCE(bool_and(
      c.relname IN ('pg_auth_members', 'pg_roles')
      AND has_table_privilege(current_user, c.oid, 'SELECT')
    ) FILTER (WHERE c.relname IN ('pg_auth_members', 'pg_roles')), false)
      AS membership_catalog_selectable,
    COALESCE(bool_and(
      has_table_privilege(current_user, c.oid, 'SELECT')
    ) FILTER (WHERE c.relname IN ('pg_database', 'pg_namespace', 'pg_class',
                                  'pg_proc', 'pg_type', 'pg_extension',
                                  'pg_largeobject_metadata',
                                  'pg_foreign_data_wrapper', 'pg_foreign_server',
                                  'pg_event_trigger', 'pg_publication',
                                  'pg_subscription', 'pg_language',
                                  'pg_tablespace', 'pg_collation',
                                  'pg_ts_config', 'pg_ts_dict', 'pg_ts_parser',
                                  'pg_ts_template')), false)
      AS ownership_catalogs_selectable,
    COALESCE(bool_and(has_table_privilege(current_user, c.oid, 'SELECT'))
      FILTER (WHERE c.relname = 'pg_default_acl'), false)
      AS default_acl_catalog_selectable
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'pg_catalog'
    AND c.relname IN ('pg_class', 'pg_namespace', 'pg_attribute', 'pg_constraint',
                      'pg_index', 'pg_proc', 'pg_trigger', 'pg_auth_members',
                      'pg_roles', 'pg_policy', 'pg_default_acl', 'pg_database',
                      'pg_type', 'pg_extension', 'pg_depend', 'pg_language',
                      'pg_largeobject_metadata', 'pg_foreign_data_wrapper',
                      'pg_foreign_server', 'pg_event_trigger', 'pg_publication',
                      'pg_subscription', 'pg_tablespace', 'pg_collation',
                      'pg_ts_config', 'pg_ts_dict', 'pg_ts_parser',
                      'pg_ts_template')
),
default_acl_state AS (
  WITH RECURSIVE default_role_tree AS (
    SELECT oid AS role_oid
    FROM pg_catalog.pg_roles
    WHERE rolname = current_user
    UNION
    SELECT am.roleid
    FROM pg_catalog.pg_auth_members am
    JOIN default_role_tree rt ON rt.role_oid = am.member
  )
  SELECT
    COALESCE(bool_or(
      (x.grantee = 0 OR x.grantee IN (SELECT role_oid FROM default_role_tree))
      AND x.privilege_type IN (
        'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES',
        'TRIGGER', 'USAGE', 'CREATE', 'EXECUTE'
      )
    ), false) AS has_dangerous_default_acl,
    count(*) AS visible_default_acl_entries,
    has_table_privilege(current_user, 'pg_catalog.pg_default_acl', 'SELECT')
      AS default_acl_inventory_complete
  FROM pg_catalog.pg_default_acl d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) x
),
foreign_privilege_state AS (
  SELECT
    to_regprocedure('has_foreign_data_wrapper_privilege(name,name,text)')
      IS NOT NULL AS fdw_check_available,
    to_regprocedure('has_server_privilege(name,name,text)') IS NOT NULL
      AS server_check_available,
    COALESCE((SELECT bool_or(
      has_foreign_data_wrapper_privilege(current_user, f.fdwname, 'USAGE')
    ) FROM pg_catalog.pg_foreign_data_wrapper f), false)
      AS has_fdw_effective_privilege,
    COALESCE((SELECT bool_or(
      has_server_privilege(current_user, s.srvname, 'USAGE')
    ) FROM pg_catalog.pg_foreign_server s), false)
      AS has_server_effective_privilege,
    (SELECT count(*) FROM pg_catalog.pg_foreign_data_wrapper)
      AS visible_fdw_count,
    (SELECT count(*) FROM pg_catalog.pg_foreign_server)
      AS visible_server_count
),
final_flags AS (
  SELECT
    current_user = 'alianza_audit_ro'
      AND session_user = 'alianza_audit_ro' AS identity_ok,
    EXISTS (
      SELECT 1 FROM pg_catalog.pg_roles r
      WHERE r.rolname = current_user
        AND r.rolcanlogin AND NOT r.rolsuper AND NOT r.rolcreatedb
        AND NOT r.rolcreaterole AND NOT r.rolreplication
        AND NOT r.rolbypassrls AND NOT r.rolinherit
    ) AS attributes_ok,
    ms.*,
    ss.*,
    rs.*,
    frs.*,
    seqs.*,
    los.*,
    os.*,
    sd.*,
    ef.*,
    cs.*,
    fps.*,
    das.*,
    ta.*,
    (SELECT count(*) FROM security_definer_dependencies)
      AS security_definer_dependency_count,
    has_database_privilege(current_user, current_database(), 'CREATE')
      AS can_create_in_database,
    has_database_privilege(current_user, current_database(), 'TEMPORARY')
      AS can_create_temp,
    current_setting('transaction_read_only') = 'on' AS transaction_read_only_ok,
    current_setting('default_transaction_read_only') = 'on'
      AS default_transaction_read_only_ok
  FROM membership_state ms
  CROSS JOIN schema_state ss
  CROSS JOIN relation_state rs
  CROSS JOIN review_state frs
  CROSS JOIN sequence_state seqs
  CROSS JOIN large_object_state los
  CROSS JOIN ownership_state os
  CROSS JOIN security_definer_state sd
  CROSS JOIN executable_function_state ef
  CROSS JOIN catalog_state cs
  CROSS JOIN default_acl_state das
  CROSS JOIN foreign_privilege_state fps
  CROSS JOIN temporary_acceptance ta
)
SELECT CASE
         WHEN NOT identity_ok
           OR NOT attributes_ok
           OR has_direct_membership
           OR has_indirect_membership
           OR can_set_other_role
           OR can_create_in_database
           OR has_schema_create
           OR has_relation_write
           OR has_unauthorized_select
           OR has_sequence_privilege
           OR has_large_object_read
           OR has_large_object_write
           OR has_fdw_effective_privilege
           OR has_server_effective_privilege
           OR has_relevant_ownership
           OR has_security_definer_risk
           OR has_owner_effective_privilege_risk
           OR NOT transaction_read_only_ok
           OR NOT default_transaction_read_only_ok
         THEN 'REPROVADA'
         WHEN NOT membership_options_visible
           OR NOT membership_catalog_selectable
           OR NOT required_catalogs_visible
           OR NOT required_catalogs_selectable
           OR NOT ownership_catalogs_selectable
           OR NOT default_acl_catalog_selectable
           OR NOT default_acl_inventory_complete
           OR has_dangerous_default_acl
           OR NOT fdw_check_available
           OR NOT server_check_available
           OR visible_fdw_count IS NULL
           OR visible_server_count IS NULL
           OR visible_schema_count = 0
           OR visible_relation_count = 0
           OR has_missing_function_review
           OR has_stale_function_review
           OR NOT all_function_reviews_valid
           OR registry_entry_count <> executable_function_count
           OR has_security_definer_metadata_indeterminate
           OR has_nonverifiable_language_function
           OR has_nonverifiable_executable_function
           OR NOT has_migration_select
         THEN 'INDETERMINADA'
         WHEN can_create_temp AND NOT temporary_acceptance_valid
         THEN 'INDETERMINADA'
         WHEN can_create_temp
         THEN 'APROVACAO_CONDICIONAL_TEMPORARY'
         ELSE 'APROVADA'
       END AS final_status,
       current_setting('server_version_num') AS server_version_num,
       can_create_in_database,
       can_create_temp,
       identity_ok,
       attributes_ok,
       has_direct_membership,
       has_indirect_membership,
       has_effective_inherited_membership,
       can_set_other_role,
       membership_options_visible,
       has_schema_create,
       has_relation_write,
       has_unauthorized_select,
       has_migration_select,
       has_sequence_privilege,
       visible_large_object_count,
       has_large_object_read,
       has_large_object_write,
       fdw_check_available,
       server_check_available,
       has_fdw_effective_privilege,
       has_server_effective_privilege,
       visible_fdw_count,
       visible_server_count,
       has_relevant_ownership,
       has_security_definer_risk,
       has_security_definer_review_required,
       security_definer_review_count,
       has_security_definer_metadata_indeterminate,
       has_owner_effective_privilege_risk,
       security_definer_dependency_count,
       has_executable_function_review_required,
       executable_function_review_count,
       has_nonverifiable_language_function,
       has_nonverifiable_executable_function,
       all_function_reviews_valid,
       has_missing_function_review,
       has_stale_function_review,
       executable_function_count,
       registry_entry_count,
       transaction_read_only_ok,
       default_transaction_read_only_ok,
       has_dangerous_default_acl,
       visible_default_acl_entries,
       default_acl_inventory_complete,
       temporary_acceptance_valid,
       temporary_acceptance_responsible,
       temporary_acceptance_date,
       temporary_acceptance_evidence,
       temporary_acceptance_justification,
       required_catalogs_visible,
       required_catalogs_selectable,
       membership_catalog_selectable,
       ownership_catalogs_selectable,
       default_acl_catalog_selectable,
       visible_schema_count,
       visible_relation_count,
       visible_sequence_count
FROM final_flags;

-- ============================================================================
-- ETAPA 14 — Revogação futura (plano, não executar)
-- ============================================================================
-- REVOKE SELECT ON TABLE supabase_migrations.schema_migrations FROM alianza_audit_ro;
-- REVOKE USAGE ON SCHEMA public FROM alianza_audit_ro;
-- Condicional, somente se private existir:
-- REVOKE USAGE ON SCHEMA private FROM alianza_audit_ro;
-- REVOKE USAGE ON SCHEMA supabase_migrations FROM alianza_audit_ro;
-- REVOKE CONNECT ON DATABASE <database_name> FROM alianza_audit_ro;
-- ALTER ROLE alianza_audit_ro NOLOGIN;
-- DROP ROLE alianza_audit_ro;
--
-- Só remover a role depois de confirmar que não possui objetos nem dependências.
