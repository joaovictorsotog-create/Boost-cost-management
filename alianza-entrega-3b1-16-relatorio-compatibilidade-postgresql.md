# Alianza — Auditoria de compatibilidade PostgreSQL por módulo

**Entrega:** 3b1-16  
**Data da execução:** 2026-11-13  
**Repositório auditado:** `joaovictorsotog-create/alianza-ai-platform`  
**Branch auditada:** `costing-security-preflight-final-20261112`  
**HEAD auditado:** `ecbd686b2c58c46ec7c114c07e3bf22fdfbab028`  
**Pai direto:** `16fde337f707734fbca13ac311f1ebe2d01a2472`  
**Base comum com `origin/main`:** `1ac2573092990c8af2793055f1924e28ff0a2c5f`  
**HEAD remoto de `main` observado:** `0bdd0306b5630f34c3daef6e03f5f47ec8925332`

## 1. Escopo e método

A auditoria foi estática e local, usando exclusivamente o checkout da branch indicada, dados artificiais implícitos nos testes existentes e comandos de leitura/validação. Não foram acessados Supabase, produção, staging persistente ou banco remoto; nenhuma migration foi executada. Foram inspecionados: proveniência Git contra `main`, routers registrados, serviços e módulos DB, schemas Drizzle MySQL/PostgreSQL, migrations, SQL cru, funções/triggers, RLS, autenticação/tenant e integração do Costing com o frontend.

Foram executados localmente `pnpm check` e quatro arquivos de teste: conversão do schema, engine Costing, snapshots e router Costing. O resultado foi **47 testes aprovados**, sem erro de TypeScript. As saídas completas estão nos arquivos de evidência desta entrega.

## 2. Conclusão executiva

A branch é tecnicamente coerente para o escopo Costing e já usa PostgreSQL no runtime principal (`drizzle-orm/postgres-js`, `SUPABASE_DATABASE_URL`) e nas tabelas específicas do Costing. O Costing está registrado no `appRouter`, possui RBAC `costing.read`, engine de aritmética racional, snapshots autoritativos e testes unitários/contratuais.

Contudo, a aplicação completa **não pode ser classificada como PostgreSQL plenamente compatível ou funcionalmente homologada** apenas com esta branch. Há dois motivos independentes:

1. A plataforma ainda carrega um legado MySQL/TiDB: `drizzle/schema.mysql.ts`, 17 migrations em `drizzle/`, `mysql2`, testes/scripts de staging e ETL TiDB.
2. A cobertura PostgreSQL consolidada é paralela e incompleta no histórico: 38 arquivos SQL em `drizzle/pg`, incluindo migrations duplicadas/alternativas numeradas (`0021_budgets.sql` e `0021_production_schema_consolidation.sql`; `0027_budget_revoked.sql` e `0027_catalog_product_description.sql`; `0032_catalog_tenant_category_isolation.sql` e `0032_restore_scheduler_columns.sql`), além de um journal PostgreSQL que não demonstra sozinho uma instalação integral e linear de toda a plataforma.

Portanto, o parecer é **“compatível por camadas, não homologado como plataforma PostgreSQL completa”**. O Costing pode avançar para validação integrada somente após um baseline PostgreSQL autoritativo e uma sequência de migrations reconciliada, executada em cluster descartável.

## 3. Proveniência e isolamento da mudança

A comparação remota mostrou 46 commits exclusivos da branch auditada contra a base comum e 8 commits exclusivos de `main`. Os caminhos alterados pela branch Costing são majoritariamente do módulo e da segurança compartilhada: `server/domain/costing/*`, `server/db/costing.ts`, `server/routers/costing.ts`, `drizzle/pg/0036_costing_foundation.sql`, `drizzle/pg/schema.costing.ts`, `drizzle/pg/rls_multitenant.sql`, `scripts/apply-supabase-rls.mjs`, `server/db.ts`, `server/routers.ts`, RBAC, contexto de workspace e testes contratuais.

Não houve interseção de caminhos entre o diff da branch Costing e o diff de `main` em relação à base comum. Isso reduz o risco de atribuir ao Costing mudanças recentes de CRM/Inbox/AI de `main`, mas não elimina a dívida de compatibilidade existente na própria plataforma.

## 4. Achados principais de compatibilidade

### 4.1 Runtime e ORM

O runtime server usa `drizzle-orm/postgres-js` e `postgres`, com conexão principal por `SUPABASE_DATABASE_URL`. O módulo `appRuntimeDb` usa role `app_runtime`, `prepare: false`, TLS obrigatório e contexto transacional de RLS. Isso é compatível com PostgreSQL/Supabase.

O repositório ainda mantém `drizzle/schema.mysql.ts` e dependências `mysql2`. Scripts de inventário, staging, seed e ETL continuam MySQL/TiDB-specific. Isso não é um defeito do Costing isoladamente, mas impede declarar conversão global concluída.

### 4.2 SQL e features PostgreSQL

Há uso legítimo de PostgreSQL em módulos já convertidos: `ON CONFLICT`, `jsonb`, `pg_advisory_xact_lock`, `FOR UPDATE SKIP LOCKED`, funções PL/pgSQL, `SECURITY DEFINER`, `set_config` e RLS. Essas features exigem que os módulos correspondentes permaneçam em PostgreSQL e não podem ser reencaminhadas ao driver MySQL.

Os artefatos legados contêm sintaxe MySQL explícita: backticks, `AUTO_INCREMENT`, `enum(...)`, `json`, `bigint unsigned`, `MODIFY COLUMN`, `ON UPDATE`, `SELECT DATABASE()`, placeholders `?` e imports `mysql2/promise`. Esses arquivos não são migrations PostgreSQL executáveis sem conversão/reconciliação.

### 4.3 Dados, tipos e semântica

O schema PostgreSQL principal é uma adaptação do schema MySQL e mantém muitos campos temporais como `bigint` em milissegundos; módulos mais recentes usam `timestamp with timezone`. A coexistência é possível, mas exige contrato de unidade e timezone por entidade.

Decimais de budgets/catalog permanecem declarados com `mode: "number"`, enquanto o Costing usa strings e aritmética racional com `BigInt`. Para uma plataforma financeira coerente, os contratos de entrada, persistência e serialização devem ser documentados por módulo; não se deve presumir que todas as quantias PostgreSQL estejam livres de arredondamento binário.

### 4.4 Transactions, locks e jobs

CRM, Inbox, Automations, AI, Budgets, Catalog, Tenancy e Costing usam transações Drizzle. Inbox e materialization usam locks PostgreSQL, incluindo advisory locks e `SKIP LOCKED`. Isso é uma dependência de runtime real e deve ser preservado no baseline PostgreSQL; uma migração parcial para outro dialeto quebraria semântica de concorrência.

### 4.5 RLS, identidade e tenancy

O modelo compartilhado depende de `organizationId`, `authenticated`, `app_runtime`, helpers privados e funções com `search_path` controlado. O Costing possui sete tabelas próprias cobertas por policies de leitura autenticada/runtime e escrita runtime conforme o SQL da branch. O runtime deve continuar obtendo a identidade pelo contexto Supabase e executando com role PostgreSQL preparada; não é seguro validar compatibilidade apenas pelo ORM sem validar policies, grants, funções e triggers no mesmo cluster.

## 5. Costing: integração encontrada

O Costing está exposto no `appRouter` como `costing`, tem router dedicado, DB service dedicado e schema PostgreSQL dedicado. O frontend, porém, mostra apenas a permissão `costing.read` no `WorkspaceContext`; não foi encontrada página, rota ou hook `trpc.costing` dedicado em `client/src`. Assim, a superfície backend existe, mas a integração frontend funcional completa não está evidenciada nesta branch.

A chamada de cálculo no router é protegida por tenancy/RBAC, mas o caminho de persistência autoritativo está no serviço server-side. Os snapshots registram versão do engine, gamma e linhas calculadas; a migration cria trigger de imutabilidade para `cost_calculations`.

## 6. Riscos e bloqueios

- Não existe evidência nesta execução de um bootstrap PostgreSQL vazio que instale todos os módulos e migrations em ordem única.
- O histórico `drizzle/pg` contém numerações duplicadas e arquivos de consolidação/alternativos; um executor ingênuo por nome pode aplicar sequência incorreta ou duplicada.
- A aplicação ainda contém dependências MySQL/TiDB legítimas para legado, staging e ETL; isso deve ser explicitamente isolado ou convertido antes de declarar PostgreSQL único.
- Não há evidência de tela frontend Costing completa; o backend não equivale a fluxo funcional usuário→UI→router→DB.
- Nenhum teste desta etapa usou banco descartável; portanto RLS, grants, FK, triggers e tipos SQL permanecem sem prova de instalação nesta rodada.

## 7. Parecer

**Status:** `PARCIALMENTE COMPATÍVEL — NÃO HOMOLOGADO`.

A branch é adequada para auditoria remota do Costing e para testes unitários do domínio. Não é suficiente para afirmar que toda a plataforma Alianza pode operar exclusivamente em PostgreSQL sem um baseline consolidado, reconciliação das migrations, inventário de objetos e prova integrada em PostgreSQL descartável.

**Próximo gate obrigatório:** produzir baseline PostgreSQL autoritativo ou sequência reconciliada, instalar em cluster descartável vazio, executar testes de schema/RLS/tenant por módulo e somente depois executar teste funcional de ponta a ponta do Costing.
