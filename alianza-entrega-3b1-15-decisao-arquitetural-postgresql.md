# ADR — PostgreSQL como banco oficial do Alianza

- **Status:** Aprovada como decisão arquitetural
- **Escopo:** Plataforma Alianza e módulo Alianza Costing
- **Data:** 2026-11-13
- **Natureza:** Decisão documental; não representa implementação concluída

## Decisão

PostgreSQL será o banco oficial de toda a plataforma Alianza. O Alianza Costing é uma complementação integrada da plataforma, não um sistema independente.

O Costing compartilhará o mesmo projeto Supabase utilizado pelo Alianza, a mesma infraestrutura de autenticação e identidade e o mesmo modelo de isolamento multi-organização. Não será criado um segundo projeto Supabase nem um banco independente para o Costing.

As tabelas do Costing permanecerão específicas do módulo, mas serão integradas ao schema PostgreSQL oficial por meio de dependências, constraints, roles, grants e policies compatíveis com a plataforma.

## Consequências obrigatórias

1. **Banco único oficial:** todos os módulos existentes e o Costing devem convergir para PostgreSQL.
2. **Supabase compartilhado:** o Costing usará o mesmo projeto Supabase da plataforma, incluindo o mesmo pooler e o mesmo ambiente de autenticação autorizado.
3. **Identidade compartilhada:** Supabase Auth, `public.users`, memberships e resolução de `organizationId` formarão uma cadeia de identidade comum.
4. **Isolamento multi-organização:** as sete tabelas Costing terão isolamento tenant-scoped coerente com a plataforma, para `authenticated` e `app_runtime` conforme contrato aprovado.
5. **Sem banco independente:** nenhum schema paralelo, projeto Supabase separado ou conexão dedicada de outro banco será criado para Costing.
6. **Compatibilidade global:** budgets, catalog, CRM, automações, storage, auditoria e demais módulos existentes precisarão ser compatíveis com o baseline PostgreSQL oficial.
7. **Baseline autoritativo:** a instalação nova dependerá de um baseline PostgreSQL completo, versionado, reproduzível e identificado por SHA.
8. **Histórico não presumido:** as migrations históricas com journal incompleto, duplicidades e lacunas não podem ser aplicadas como se fossem uma cadeia confiável sem reconciliação formal.
9. **Teste descartável obrigatório:** antes de qualquer ambiente persistente, o baseline e as migrations incrementais deverão ser executados em PostgreSQL descartável, com catálogo, policies, grants, funções e triggers verificados.
10. **RLS com escopo explícito:** a segurança Costing deve ser validada separadamente do payload RLS global, ainda que posteriormente seja integrada ao runner oficial.

## Decisões de segurança associadas

- Todas as funções `SECURITY DEFINER` deverão usar `search_path = ''`, com referências schema-qualified.
- `app_runtime` não poderá possuir `BYPASSRLS`, superuser ou privilégios implícitos que permitam contornar tenant isolation.
- O preflight de conexão deverá continuar fail-closed e validar projeto, hostname e ambiente antes de abrir conexão.
- Nenhum teste desta decisão usa dados de produção, banco persistente ou credenciais operacionais.

## O que esta decisão não significa

Esta ADR não implementa PostgreSQL, não cria baseline, não reconcilia o journal, não renumera migrations, não aplica DDL/DML, não altera o RLS global e não comprova que o bootstrap já funciona.

A decisão apenas fixa a arquitetura-alvo. A implementação permanece condicionada a:

- reconciliação do histórico PostgreSQL;
- produção e revisão do baseline autoritativo;
- prova em cluster descartável;
- separação e validação do RLS Costing;
- verificação de compatibilidade de todos os módulos Alianza.

## Critérios para considerar a decisão implementada

A decisão somente poderá ser considerada implementada quando houver evidência documental de:

1. baseline PostgreSQL completo e reproduzível;
2. instalação bem-sucedida em banco vazio descartável;
3. migrations incrementais journalizadas e reconciliadas;
4. autenticação/identidade compartilhada funcionando;
5. isolamento entre duas organizações em `authenticated` e `app_runtime`;
6. compatibilidade dos módulos existentes;
7. ausência de dependência não definida, incluindo `rls_auto_enable()`;
8. hashes dos artefatos e logs de execução preservados.
