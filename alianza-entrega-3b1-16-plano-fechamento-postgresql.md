# Plano de fechamento da compatibilidade PostgreSQL

## Objetivo

Transformar o estado atual, que é compatível por camadas e não homologado, em uma plataforma verificável em PostgreSQL com Costing integrado ao Alianza.

## Etapa 1 — Baseline autoritativo

1. Escolher um único conjunto de migrations PostgreSQL oficial.
2. Reconciliar arquivos numerados duplicados e migrations de consolidação.
3. Gerar journal/manifesto coerente com a ordem real de instalação.
4. Inventariar tabelas, colunas, tipos, FK, índices, funções, triggers, policies, grants e roles.
5. Marcar explicitamente objetos fora do escopo do baseline.

**Aceite:** cluster PostgreSQL vazio recebe o baseline uma única vez, sem erro, e o inventário esperado coincide com `pg_catalog`/`information_schema`.

## Etapa 2 — Isolamento do legado MySQL/TiDB

1. Classificar `drizzle/schema.mysql.ts`, migrations MySQL, scripts `mysql2` e ETL como legado/ferramentas de migração.
2. Proibir que o runtime web escolha `DATABASE_URL` MySQL quando o perfil oficial for PostgreSQL.
3. Preservar ETL somente como ferramenta explicitamente separada, com testes artificiais e destino controlado.
4. Documentar unidades temporais, precisão decimal e conversões JSON/enum.

**Aceite:** busca automatizada distingue “legado/ETL” de runtime oficial; nenhum caminho de produção depende de driver MySQL.

## Etapa 3 — RLS e identidade

1. Criar fixtures artificiais para duas organizações e dois usuários.
2. Testar roles `authenticated` e `app_runtime` com sessão/contexto corretos.
3. Testar SELECT, INSERT, UPDATE e DELETE no próprio tenant e cross-tenant.
4. Testar `rolbypassrls`, grants públicos/anon, `search_path` de funções SECURITY DEFINER e imutabilidade de snapshots.
5. Registrar SQLSTATE e origem de cada rejeição; não aceitar constraint/privilégio como prova de RLS.

**Aceite:** matriz RLS passa em banco descartável, com evidência reproduzível e sem dados reais.

## Etapa 4 — Compatibilidade funcional por módulo

Executar um smoke test por cada módulo registrado no appRouter: Auth/Workspace, CRM, Inbox, AI/Knowledge, Automations, Webhooks, Budgets, Catalog, Sellers, Operations/Audit, Platform Admin e Costing. Cada smoke test deve atravessar router, serviço DB e PostgreSQL, com tenant A/B.

**Aceite:** cada módulo tem teste de leitura, escrita e isolamento conforme sua capacidade; módulos somente leitura devem declarar isso.

## Etapa 5 — Costing ponta a ponta

1. Confirmar ou implementar tela/hook frontend Costing.
2. Criar grupo, item, estrutura, linhas e configuração Gamma com dados artificiais.
3. Calcular no servidor, ignorando qualquer total enviado pelo cliente.
4. Persistir snapshot e verificar que UPDATE/DELETE são bloqueados.
5. Reabrir histórico, comparar SHA/JSON do snapshot e verificar isolamento entre organizações.
6. Testar números decimais com três casas, quantidades fracionárias, Gamma ativo/inativo e estruturas aninhadas.

**Aceite:** fluxo UI→router→serviço→PostgreSQL→histórico passa sem arredondamento indevido e sem cross-tenant.

## Proibições durante o fechamento

Não usar planilhas de preços, dados de produção ou banco persistente para os testes; não aplicar migrations diretamente em produção; não declarar compatibilidade global a partir de testes unitários; não ocultar migrations históricas divergentes por renomeação sem preservar o histórico documental.
