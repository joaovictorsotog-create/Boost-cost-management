# Plano de integração — Alianza Sistema de Custos na plataforma Alianza

**Status:** auditoria inicial concluída; plano de integração proposto.  
**Fonte de análise:** snapshot ZIP `alianza-ai-platform-main`, enviado em 10/11/2026; SHA do arquivo ZIP: `d4ed3f388c5ef3d902b57de4108a504d4c202c80`.  
**Escopo desta etapa:** análise estática e planejamento. Nenhuma alteração foi feita no código do produto, banco remoto, ambiente, infraestrutura ou produção.  
**Decisão de produto:** integrar o Sistema de Custos como módulo da plataforma Alianza, mantendo fronteiras funcionais e de dados.

## 1. Conclusão executiva

A integração na plataforma existente é tecnicamente plausível e preferível a criar uma segunda aplicação, mas **a implementação de domínio ainda não deve começar diretamente no banco remoto**. O snapshot contém uma migração MySQL/TiDB → Supabase/PostgreSQL em andamento e o documento `docs/phase-1e3o-gate-closure.md` classifica o PostgreSQL de homologação, a aplicação efetiva de RLS, o journal de migrations e o rollback como bloqueados ou não aplicados.

A recomendação é:
- reutilizar a aplicação React/Vite + TypeScript, Express + tRPC, Zod, Drizzle e PostgreSQL/Supabase quando os gates forem liberados;
- criar um módulo de domínio independente chamado Sistema de Custos;
- manter as tabelas, serviços, permissões e testes de custeio separados dos módulos atuais;
- aproveitar identidade, organização/tenant, infraestrutura de auditoria, notificações, armazenamento e processamento somente depois de validar os contratos existentes;
- não reutilizar o catálogo comercial atual como Cadastro Central de custos.

## 2. Stack encontrada no snapshot

| Camada | Evidência no repositório | Leitura |
|---|---|---|
| Runtime | `.nvmrc` = Node 22.23.2; `package.json` exige Node >=22 <23 | Node 22 |
| Frontend | React 19, Vite 7, TypeScript 5.9, Tailwind CSS 4 | Manter |
| API | Express 4, tRPC 11, Zod 4 | Manter |
| Persistência | Drizzle ORM 0.45, postgres-js e mysql2 | Compatibilidade/transição |
| Banco | Supabase PostgreSQL em `server/db.ts`; MySQL/TiDB legado em documentação/configuração | PostgreSQL existe no código, mas gate remoto não está liberado |
| Identidade | Supabase JWT validado por JWKS em `server/lib/supabaseIdentity.ts`; fallback Manus documentado como transição | Reutilizar após confirmar política de retirada do legado |
| Isolamento | Organização/membership, RBAC por tenant e role `app_runtime` com contexto transacional | Reaproveitar padrão, não copiar sem teste |
| Filas | BullMQ/ioredis, com ativação operacional condicionada | Usar somente para tarefas que justifiquem execução assíncrona |
| Storage | Fachada de storage e compatibilidade Manus/Forge; R2 é destino documentado | Reutilizar adaptador apenas após validação de independência |
| Qualidade | Vitest, Playwright, TypeScript checks e testes contratuais | Ampliar para o novo módulo |
| Deploy | Docker e GitHub Actions; docs ainda registram dependências Manus/Forge e destino futuro | Não presumir migração operacional concluída |

## 3. Descoberta importante: existe um catálogo comercial

O código atual já possui:
- rota frontend `/catalog`;
- router tRPC `catalog`;
- tabelas `catalog_categories` e `catalog_products`;
- categorias comerciais, código de produto, nome, descrição, imagem e `basePrice`;
- regras de preço comercial e permissões `catalog.read` / `catalog.manage`.

Arquivos inspecionados:
- `client/src/App.tsx`;
- `server/routers/catalog.ts`;
- `server/db/catalog.ts`;
- `drizzle/pg/schema.catalog.ts`.

**Decisão técnica recomendada:** não transformar `catalog_products` em Cadastro Central de custos. O modelo atual é um catálogo comercial com preço-base e imagens; não representa item simples/composto, unidade industrial, estrutura multinível, custo derivado, snapshots e cascata de custeio. A integração deve criar um domínio próprio, com nome interno explícito (por exemplo, `costing`) e navegação própria. Integrações futuras entre produto comercial e item de custo exigiriam relação explícita, nunca identidade presumida.

## 4. Infraestrutura e bloqueadores encontrados

### 4.1 PostgreSQL e migrations

- `server/db.ts` cria conexão PostgreSQL via `SUPABASE_DATABASE_URL`.
- `server/lib/appRuntimeDb.ts` abre contexto transacional com role `app_runtime`, define claims locais e expõe a transação pelo contexto assíncrono.
- `server/_core/trpc.ts` envolve procedures protegidas em `withRequestRuntimeDb`.
- `scripts/apply-supabase-rls.mjs` aplica `drizzle/pg/rls_multitenant.sql`.
- `docs/phase-1e3o-gate-closure.md` declara que a identidade inequívoca do PostgreSQL de homologação ainda não foi confirmada, RLS está preparado mas não aplicado, migrations/journal precisam reconciliação e rollback real ainda não foi testado.

**Bloqueio:** não executar migrations, provisionamento, alteração de RLS ou teste que escreva em banco até identificar formalmente ambiente não produtivo, confirmar backup/restore e liberar o gate correspondente.

### 4.2 RLS e tenancy

A plataforma usa `organizations`, `organization_members`, permissões por tenant e funções privadas como `private.has_organization_access`. O SQL-base de RLS lista tabelas explicitamente. Novas tabelas de custeio não estarão protegidas só por terem `organizationId`: será necessário adicionar policies, grants para `app_runtime`, índices e testes de isolamento.

Toda tabela operacional do módulo deverá ser tenant-scoped, com `organizationId` e chaves/constraints que impeçam referências cruzadas entre organizações. A autorização de negócio continuará obrigatória no backend; RLS será uma segunda barreira, não substituto do RBAC.

### 4.3 Autenticação e papéis

A plataforma atual possui papéis e permissões de CRM/plataforma. O Sistema de Custos já tem decisões funcionais próprias: Administrador, Editor e Visualizador. Não presumir equivalência entre `platform_admin`, `admin/supervisor/agent` e esses três papéis.

Criar permissões específicas do módulo (prefixo sugerido `costing.*`) e uma matriz explícita de mapeamento entre associação/role da plataforma e perfil funcional do módulo. A regra final precisa preservar:
- Administrador: operações de impacto e administração do módulo;
- Editor: criação de itens e propostas limitadas de alteração, conforme regras aprovadas;
- Visualizador: leitura autorizada, sem mutações.

A integração não pode ampliar privilégios no CRM nem importar automaticamente permissões de outros módulos.

## 5. Arquitetura de integração recomendada

**Monólito modular**, sem microserviço próprio no primeiro ciclo:

```text
client/src/
  pages/costing/
  components/costing/
  features/costing/

server/
  routers/costing/
  services/costing/
  db/costing/
  domain/costing/
  tests/costing/

drizzle/pg/
  migrations específicas do módulo
  policies RLS específicas do módulo
```

Os caminhos são proposta de organização, não arquivos já criados.

Fronteiras:
1. **Domínio:** Cadastro Central, famílias, itens simples/compostos, estruturas, custo, snapshots, histórico.
2. **Aplicação:** casos de uso, permissões, prévias/confirmar, solicitações, importação, recálculo e exportação.
3. **Persistência:** repositórios Drizzle, transações e constraints PostgreSQL.
4. **Apresentação:** páginas React e contratos tRPC; interface nunca calcula ou autoriza por conta própria.
5. **Integrações compartilhadas:** identidade/tenant, auditoria, notificação, storage e filas por adaptadores.

O motor de cálculo deve ser uma biblioteca de domínio pura, determinística e testável sem Express, tRPC ou React.

## 6. Modelo de dados: princípios antes de schema

Não gerar migrations ainda. O modelo deverá contemplar, no mínimo:
- famílias;
- itens do Cadastro Central;
- estrutura e linhas de composição;
- versão/fotografia imutável da estrutura;
- histórico de custo;
- operações de recálculo e correlação;
- solicitações e eventos de aprovação;
- sessões e linhas de importação;
- eventos de auditoria do módulo.

Requisitos de integridade:
- ID numérico funcional único por organização, com regra de reserva de IDs definida nos documentos de negócio;
- chaves estrangeiras compostas com `organizationId` quando necessário para impedir relações entre tenants;
- restrições de unicidade e índices por tenant;
- impedir ciclos de composição no serviço transacional;
- valores monetários em tipo decimal/numeric de precisão explícita; evitar ponto flutuante binário para o motor financeiro;
- preservar snapshots históricos mesmo após inativação/exclusão lógica;
- nunca apagar histórico de custo ou auditoria por cascata de FK.

A precisão interna e a quantidade-base de estrutura continuam pendentes no Registro Mestre/Checklist. Não fixar escala decimal, fórmula de lote ou regra de arredondamento adicional sem fechar essas pendências.

## 7. Transações, recálculo e eventos

As regras de negócio aprovadas exigem que mudanças de custo/estrutura e a cascata dependente não deixem custos parcialmente atualizados.

Primeira opção a validar: uma transação PostgreSQL que bloqueie/valide a versão dos registros afetados, aplique a alteração, calcule dependências em ordem bottom-up e grave custo vigente, histórico, snapshots necessários e auditoria antes do commit.

Se o volume tornar uma única transação impraticável, não publicar resultados parciais. Será necessário desenhar protocolo de versão/cálculo em preparação e troca atômica da versão vigente, com estados visíveis e recuperação. Essa alternativa exige decisão técnica e testes; não é autorização para relaxar atomicidade.

Notificações/realtime devem ser emitidas somente após commit, preferencialmente via outbox. Eventos são sinais para reconsultar API, não fonte da verdade.

## 8. Plano de execução por fases

### Fase 0 — fechamento de pré-requisitos (atual)
- [x] Receber snapshot e realizar inspeção estática inicial.
- [x] Identificar stack e dependências principais.
- [x] Identificar catálogo comercial existente e risco de colisão semântica.
- [x] Identificar gates PostgreSQL/RLS/migrations documentados como bloqueados.
- [ ] Confirmar o repositório GitHub real da plataforma atual e branch de trabalho autorizada.
- [ ] Identificar e aprovar ambiente local/development e homologação, sem tocar produção.
- [ ] Fechar gates de banco, RLS, migrations e rollback em ambiente não produtivo.
- [ ] Conferir o mapeamento de papéis e tenancy do módulo.

### Fase 1 — fundação isolada do módulo
- [ ] Adicionar esqueleto `costing` sem alterar módulos atuais.
- [ ] Criar contratos tRPC, validações Zod e permissões `costing.*`.
- [ ] Implementar domínio puro e testes unitários de custo/estrutura/ciclos.
- [ ] Criar migrations e policies somente após gate PostgreSQL aprovado.
- [ ] Testar isolamento entre duas organizações e negação por padrão.

### Fase 2 — Cadastro Central
- [ ] Famílias e unidades aprovadas.
- [ ] Cadastro de itens simples/compostos.
- [ ] IDs funcionais e reserva de IDs.
- [ ] Inativação, exclusão lógica e reativação conforme regras.
- [ ] Auditoria e prévia/confirmar.

### Fase 3 — Estruturas e motor de cálculo
- [ ] Estrutura multinível e prevenção de ciclos.
- [ ] Cálculo determinístico e precisão aprovada.
- [ ] Recálculo em cascata com atomicidade.
- [ ] Histórico de custo e snapshots imutáveis.
- [ ] Testes de rollback, concorrência e carga.

### Fase 4 — fluxos complementares
- [ ] Central de Aprovações.
- [ ] Importação Excel com prévia e sucesso parcial conforme regras.
- [ ] Notificações e atualizações em tempo real.
- [ ] Relatórios, exportação e painel.
- [ ] Verificação de segurança, observabilidade e backup/restore.

### Fase 5 — homologação e liberação
- [ ] Testes de regressão de CRM, Inbox, catálogo comercial, campanhas e autenticação.
- [ ] Testes e2e do módulo de custos.
- [ ] Revisão independente de permissões/RLS e isolamento.
- [ ] Backup/restore e rollback comprovados.
- [ ] Aprovação explícita antes de merge, deploy ou mudança de produção.

## 9. Critérios de não regressão

A integração será rejeitada se:
- alterar comportamento de CRM, Inbox, Kanban, catálogo comercial, campanhas ou autenticação sem requisito explícito;
- compartilhar tabelas de domínio por conveniência e criar acoplamento de regras;
- permitir que API, importação ou UI contornem as permissões;
- gravar custos derivados parcialmente;
- perder histórico/snapshots;
- aceitar referência cruzada entre organizações;
- executar migration ou alteração remota sem gate e aprovação;
- considerar um teste contratual estático como prova de RLS ativo no banco real.

## 10. Decisões ainda não tomadas

1. Organização/tenant exato onde o Sistema de Custos será habilitado inicialmente.
2. Se o módulo será exclusivo de uma organização no primeiro ciclo ou multi-tenant desde o início. A arquitetura deve continuar tenant-scoped de qualquer forma.
3. Mapeamento formal entre Administrador/Editor/Visualizador e roles/permissões da plataforma.
4. Ambiente PostgreSQL não produtivo e conclusão dos gates da migração.
5. Fonte autoral definitiva do schema PostgreSQL e reconciliação do journal.
6. Precisão interna monetária e quantidade-base/lote.
7. Estratégia de cascata para estruturas muito grandes, caso uma transação única não atenda ao volume medido.
8. Realtime, filas e observabilidade que serão compartilhados versus específicos do módulo.

## 11. Evidências do snapshot inspecionado

- `package.json`, `.nvmrc`;
- `docs/architecture.md`;
- `docs/phase-1e3m-manus-to-definitive-stack.md`;
- `docs/phase-1e3n-migration-mapping-and-plan.md`;
- `docs/phase-1e3o-gate-closure.md`;
- `server/db.ts`;
- `server/lib/appRuntimeDb.ts`;
- `server/lib/supabaseIdentity.ts`;
- `server/_core/trpc.ts`;
- `drizzle/schema.pg.ts`, `drizzle/pg/rls_multitenant.sql`;
- `scripts/apply-supabase-rls.mjs`;
- `server/routers/catalog.ts`, `server/db/catalog.ts`, `drizzle/pg/schema.catalog.ts`;
- `client/src/App.tsx`.

**Conclusão:** integrar no mesmo produto, mas como módulo de domínio isolado. O próximo trabalho técnico é fechar o acesso ao repositório real da plataforma e liberar um ambiente não produtivo com PostgreSQL/RLS verificáveis. Até lá, continuar especificação e testes locais sem tocar banco ou produção.


---

## 12. Auditoria complementar do repositório vivo — 10/11/2026

**Repositório:** `joaovictorsotog-create/alianza-ai-platform`  
**Branch-base verificada:** `main`  
**Commit-base lido:** `1ac2573092990c8af2793055f1924e28ff0a2c5f`  
**Branch de trabalho criada:** `feature/alianza-costing-foundation-20261110`  
**Commit da auditoria complementar:** `ef695a33a40291ca6f06b08fd3b7f7cd3cf56a93` (documentação inicialmente criada na branch de código e transferida para este repositório de gestão).

Esta seção atualiza a auditoria baseada no ZIP com evidências consultadas diretamente no repositório GitHub privado. Quando houver diferença entre snapshot e repositório vivo, a leitura do repositório vivo prevalece para a implementação.

### 12.1 Stack confirmada no repositório vivo

- Node.js `>=22 <23`, pnpm.
- React 19, TypeScript 5.9, Vite 7, Tailwind CSS 4, Wouter e TanStack Query.
- Express 4, tRPC 11 e Zod 4.
- Drizzle ORM 0.45, `postgres-js` no runtime PostgreSQL e dependência MySQL ainda presente.
- Supabase Auth vinculado a usuário local; procedures protegidas exigem `supabaseAuthId`.
- Organizações/workspaces, membership e permissões resolvidas no backend.
- Vitest, Playwright e checks TypeScript.
- BullMQ/ioredis disponíveis de forma opt-in.

### 12.2 Identidade, tenant e conexão runtime

A leitura de `server/_core/trpc.ts`, `server/lib/appRuntimeDb.ts` e `server/db.ts` confirma o uso de contexto transacional por request. `withRequestRuntimeDb` configura `request.jwt.claim.sub` e `request.app_user_id` localmente à transação e disponibiliza o contexto por `AsyncLocalStorage`.

A autorização de tenant é feita por permissões específicas consultadas no backend, incluindo `requireTenantPermission(userId, organizationId, permission)`. O módulo Custos deverá declarar seu próprio namespace `costing.*`, sem herdar equivalência automática de papéis de CRM/plataforma.

### 12.3 Divergências e riscos adicionais a resolver

1. `drizzle/schema.pg.ts` declara ser gerado a partir de `drizzle/schema.mysql.ts`; sua autoria PostgreSQL precisa ser definida antes de ampliar o schema.
2. Há dois configs: `drizzle.config.ts` (MySQL) e `drizzle.pg.config.ts` (PostgreSQL). Scripts e CI devem usar explicitamente o alvo correto.
3. `organizations.id` é UUID no schema PostgreSQL, enquanto parte do schema do catálogo usa `organizationId varchar(64)`. Confirmar constraints físicas e padronizar novas referências com o tipo correto, sem copiar o padrão divergente.
4. `drizzle/pg/rls_multitenant.sql` percorre uma lista explícita de tabelas; adicionar tabela sem atualizar e testar policies/grants deixa lacuna de segurança.
5. A migration inicial do catálogo com policies `service_role` não comprova compatibilidade completa com `app_runtime`; revisar o conjunto de migrations do catálogo separadamente.
6. Novas operações protegidas devem usar o contexto de conexão/transação runtime; evitar conexão paralela que contorne claims e RLS.

### 12.4 Escopo e bloqueios reafirmados

A auditoria foi somente leitura. Não foram executados comandos de migration, DDL, DML, provisionamento, alteração de Auth/RLS, deploy ou publicação. Os gates já descritos neste plano permanecem obrigatórios: ambiente não produtivo inequivocamente identificado, journal reconciliado, RLS verificado no banco real, backup/restore e rollback testados antes de qualquer escrita integrada.

### 12.5 Organização do trabalho e fonte documental

Por decisão do projeto, **toda documentação de produto, arquitetura, auditoria, decisões e planos do Sistema de Custos deve residir no repositório `Boost-cost-management`**, na branch documental `docs/regras-custeio-cadastro-central`, salvo instrução expressa em contrário.

O repositório `alianza-ai-platform` será usado para código, testes e artefatos estritamente necessários à implementação. Não manter cópias divergentes de documentos de gestão nos dois repositórios.

**Estado:** auditoria estática do código vivo concluída em nível inicial; implementação funcional ainda não iniciada. A branch de trabalho existe, mas não autoriza alteração de banco ou produção.
