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

A quantidade-base de saída da estrutura está aprovada: campo obrigatório para item composto, com padrão 1 quando a estrutura representa uma unidade; para ficha em lote, informar a quantidade de unidades acabadas representadas. O motor calcula o custo total dos componentes para essa saída e divide pela quantidade-base para obter o custo unitário. A precisão interna para divisões não terminantes continua pendente; não inventar escala ou arredondamento intermediário.

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
- [x] Adicionar a fundação isolada `server/domain/costing/engine.ts` e seus testes, sem alterar módulos atuais.
- [ ] Criar contratos tRPC, validações Zod e permissões `costing.*`.
- [x] Implementar motor puro inicial com aritmética decimal exata, estruturas multinível, linhas repetidas e rejeição de ciclos/itens inativos/estruturas contraditórias.
- [x] Adicionar testes unitários para os invariantes principais; execução dos testes e do TypeScript check ainda pendente.
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
6. Precisão interna monetária para divisões não terminantes.
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

**Estado atualizado em 10/11/2026:** auditoria estática inicial concluída e fundação do motor puro de domínio iniciada na branch `feature/alianza-costing-foundation-20261110`. Foram adicionados `server/domain/costing/engine.ts` e `server/domain/costing/engine.test.ts`; os testes foram escritos, mas ainda não foram executados e nenhum check de TypeScript foi confirmado. Não há router, UI, persistência ou integração com banco. A branch de trabalho não autoriza alteração de banco ou produção.


---

## 13. Auditoria da planilha de referência — 10/11/2026

**Arquivo analisado:** `TABELA DE PREÇO - Atualizada (Inox 201).xlsx`  
**Método:** leitura das fórmulas e dos valores armazenados no arquivo, sem editar nem recalcular/salvar a planilha.

### 13.1 Estrutura encontrada

- 145 abas, incluindo menu, tabela consolidada de preços, custos variáveis e fichas técnicas individuais de produtos/conjuntos.
- 11.171 células com fórmulas.
- As fichas técnicas apresentam linhas de componentes com quantidade, unidade, peso/comprimento por peça, custos por grupo e totais.
- A aba `CUSTOS VARIÁVEIS` centraliza referências de matérias-primas e serviços: chapas/tubos por kg ou metro, vidros, pintura, usinados, fixadores, eletrônica e outros itens.
- Existem fichas com cálculo de aproveitamento de barras comerciais por lote. Exemplo observado em `MINI TORNIQUETE - INOX`: quantidade de conjuntos configurada em 10, comprimento real calculado, comprimento comercial arredondado para múltiplos de 6 m e custo rateado por conjunto.
- Há também custos agrupados por chaparia, tubos, usinagem, corte laser, pintura, manufatura, embalagem e itens de montagem. A planilha distingue subtotal de grupos e total da ficha.

### 13.2 Evidências que não devem ser confundidas com regras aprovadas

1. **Quantidade-base/lote:** a regra funcional do Alianza já está definida: o custo total da estrutura é dividido pela quantidade-base de unidades acabadas; quando omitida, a base é 1. A ficha do Mini Torniquete - Inox confirma o uso de lote de 10 conjuntos. O campo operacional e sua persistência ainda precisam ser ligados à UI/dados.
2. **Aproveitamento comercial:** há arredondamento de barras para múltiplos de 6 m em fórmulas específicas. Não generalizar para todos os tubos, materiais ou produtos sem regra operacional confirmada.
3. **Custos por grupo:** a planilha agrega categorias de custo antes de formar totais. No Cadastro Central, materiais e serviços deverão continuar sendo itens identificáveis/reutilizáveis; os agrupamentos podem ser uma visão de relatório, não uma nova origem de custo duplicada.
4. **Manufatura:** a observação da planilha indica que certos itens comprados podem receber processo de fabricação. Isso não autoriza criar um adicional genérico de manufatura: só deve entrar quando existir item/serviço/custo explicitamente cadastrado e aprovado.
5. **Fatores comerciais:** a aba consolidada de preços calcula colunas de preço sem desconto, desconto de 10% e cliente final +45%, além de referências Alpha/Beta e fatores associados a canais. Isso pertence à formação de preço comercial e permanece fora do motor de custo industrial aprovado.
6. **Gama:** valores e fórmulas aparecem em fichas de inox, mas a regra aprovada do Alianza continua sendo aplicação manual, opcional e contextual; não copiar o fator automaticamente.
7. **Arredondamento:** as fórmulas da planilha usam funções como `ROUNDUP` e arredondamentos para compra/aproveitamento. Não substituir a regra de apresentação já aprovada no Alianza por esses arredondamentos comerciais/operacionais.

### 13.3 Qualidade e integridade da fonte

A leitura dos valores de erro já armazenados no arquivo encontrou **277 células com valores de erro em cache**. Destas, 234 estão na aba `TABELA DE PREÇO - PRODUTOS`; outras aparecem em fichas técnicas e na aba de custos variáveis. Um exemplo rastreável é `CUSTOS VARIÁVEIS!I65`, cuja fórmula referencia uma pasta de trabalho externa (`[1]COFRE!$K$10`) e cujo valor armazenado é `#ERROR!`; fórmulas da tabela consolidada que dependem desse valor também exibem erro.

Esses valores podem refletir links externos indisponíveis, fórmulas não recalculadas ou erros reais de origem. A inspeção estática não permite determinar qual hipótese se aplica a cada célula. Portanto:
- a planilha não deve ser importada diretamente como fonte confiável de custos vigentes;
- uma futura importação deve usar staging, validação por linha/campo, prévia e aprovação;
- erros de fórmula, referências externas, unidades inconsistentes e valores ausentes devem ser sinalizados, nunca convertidos silenciosamente em zero;
- os dados importados devem ser tratados como proposta de cadastro, não como regra de cálculo executável.

### 13.4 Consequências para a implementação

- O motor puro implementado na branch de desenvolvimento recebe quantidades e custos unitários já normalizados, calcula estruturas multinível com decimal exato, contabiliza linhas repetidas e rejeita ciclos, itens inativos e estruturas contraditórias.
- O motor suporta quantidade-base de saída para estruturas por lote, com divisão decimal exata quando o resultado é finito; não arredonda divisões periódicas sem política de precisão aprovada.
- A ficha do Mini Torniquete - Inox informa lote de 10 conjuntos. Para um tubo: consumo real de 11 m no lote, compra comercial de 12 m (múltiplos de 6 m), preço de R$ 44,47395/m, custo comprado de R$ 533,68740 e rateio de R$ 53,36874 por conjunto. O fator Gama 1,2 aparece separadamente em AH7 e não deve ser aplicado automaticamente pelo Alianza.
- A suíte cobre o exemplo aprovado de R$ 44,00, o rateio de 12 m comprados por 10 conjuntos e a soma dos grupos de custo da ficha Mini Torniquete - Inox.
- O motor não calcula por conta própria o arredondamento de barras comerciais; a quantidade da linha deve chegar com o aproveitamento já incorporado, evitando aplicar perda duas vezes. A regra de compra em múltiplos de 6 m permanece específica da ficha e não foi generalizada.
- Permanecem fora do motor preço de venda, desconto, Alpha/Beta e Gama automático.
- A execução local isolada de validação passou em 12 asserções de runtime e no TypeScript check isolado do motor com o compilador global TypeScript 5.8.3. O repositório fixa TypeScript 5.9.3; portanto, o check completo do projeto com as dependências da versão fixada, a suíte Vitest e o CI ainda precisam ser executados.
- A escala interna monetária ainda não foi fixada: o motor usa aritmética decimal exata por strings/inteiros, sem escolher uma escala fixa de banco. A política de apresentação aprovada é aplicada separadamente.

**Conclusão da auditoria:** a planilha é útil para extrair candidatos a itens, unidades, composições e práticas industriais, mas não é uma especificação limpa nem uma base confiável para migração automática. Antes de qualquer carga, será necessário mapear fichas e referências, resolver erros e validar a semântica de lote, aproveitamento e serviços com o responsável pelo processo.

### 13.5 Confronto numérico com a ficha Mini Torniquete - Inox

A ficha registra `T8 = 10` conjuntos. Na seção de tubos, a primeira referência calcula:
- consumo real `V11 = 11 m` (10 conjuntos × 1,1 m);
- compra comercial `W11 = 12 m` por arredondamento para múltiplos de 6 m;
- preço `Z11 = R$ 44,47395/m`;
- custo comprado `AA11 = R$ 533,68740`;
- rateio `AB11 = R$ 53,36874/conjunto`.

A implementação representa esse cálculo com quantidade-base 10 e quantidade da linha de 12 m já ajustada pelo aproveitamento: `12 × 44,47395 ÷ 10 = 53,36874`. O motor não decide que toda barra deve ser comprada em múltiplos de 6 m; apenas calcula corretamente quando a quantidade efetiva da linha já contém o ajuste operacional validado.

A ficha também apresenta os grupos de custo em `I10:I18`: chapa carbono, chapa inox, tubos, usinagem, corte laser, manufatura, embalagem e itens de montagem. O grupo de tubos tem subtotal bruto `AB15 = R$ 666,10674`, mas `I12 = AB15 × AH7`. A célula `AH7` está identificada na própria planilha como **Gama** e contém 1,2; por isso o valor apresentado em `I12` é R$ 799,328088. O total em `I19` (R$ 1.733,89638) inclui esse fator.

A regra vigente do Alianza não aplica Gama automaticamente: trata-se de correção manual, opcional e contextual. Portanto, o teste-base do motor utiliza o subtotal de tubos antes de Gama e valida R$ 1.600,6750321 (apresentação conforme a regra do Alianza: R$ 1.600,67). Se um Administrador decidir aplicar Gama àquele custo, o valor ajustado deve ser informado explicitamente; o motor não deve multiplicar todos os tubos nem todos os itens de inox por 1,2. A soma dos grupos com o valor de tubos já ajustado pela planilha resulta em R$ 1.733,8963801, diferença de R$ 0,0000001 do cache de `I19`, sem impacto na apresentação.

O teste da ficha usa os valores por grupo como componentes simples de referência e valida o total decimal do motor antes de Gama. Ele não pretende reproduzir todas as fórmulas internas da planilha nem aprovar automaticamente os custos armazenados nela.


### 13.6 Aplicação da referência funcional do Omie

A referência ao Omie recuperada nos registros do projeto é **conceitual e funcional**. O material preservado não contém uma especificação de API do Omie, contrato de integração, endpoints, payloads ou uma auditoria técnica do produto. Portanto, não afirmar compatibilidade ou copiar comportamento não documentado.

Os conceitos explicitamente registrados e sua aplicação no Alianza são:

| Conceito observado como referência Omie | Aplicação no Alianza | Limite |
|---|---|---|
| Cadastro central de produtos/itens | Cadastro Central único, com ID próprio, família, unidade, tipo, status e origem de custo | Não duplicar o mesmo item em cada produto |
| Busca de itens já cadastrados ao compor um produto | Seletor/pesquisa de itens existentes no Cadastro Central ao montar uma estrutura | A estrutura referencia o item; não cria outro cadastro |
| Reutilização do mesmo item em diferentes estruturas | Uma identidade de item pode ser componente de vários produtos e subconjuntos | Alteração do custo simples propaga recálculo para todos os compostos dependentes |
| Estrutura de produto em múltiplos níveis | Composição recursiva de produto, subconjunto e componentes | Ciclos são proibidos; componentes repetidos em posições distintas são contabilizados por ocorrência |
| Quantidade de cada componente na composição | Linha de estrutura registra item e quantidade consumida, respeitando a unidade única do item | Sem conversão automática entre unidades |

#### Como combinar Omie e a planilha sem misturar seus papéis

- **Omie orienta a organização funcional:** como cadastrar, localizar, reutilizar e estruturar itens.
- **A planilha orienta a investigação industrial:** quais materiais, serviços, quantidades, unidades, lotes e agrupamentos aparecem nas fichas reais.
- **As regras aprovadas do Alianza governam o cálculo:** custo do composto é a soma das quantidades das linhas multiplicadas pelos custos unitários vigentes, dividida pela quantidade-base de unidades acabadas quando a estrutura representar um lote.
- **O motor próprio executa a regra:** não deve reproduzir automaticamente algoritmos, arredondamentos, fiscalidade ou políticas de estoque de Omie ou da planilha.

#### Consequências para UX e modelo de dados

1. O fluxo de composição deve começar pela pesquisa do Cadastro Central; permitir cadastrar um item novo sem sair do contexto só se isso respeitar o fluxo de permissões e aprovação já aprovado.
2. A linha da estrutura deve apontar para a identidade persistente do item, guardar a quantidade consumida e preservar a unidade do item. A descrição exibida é uma projeção do cadastro, não uma cópia que se torne uma segunda identidade.
3. A tela do produto deve apresentar sua estrutura por níveis, com expansão de subconjuntos e consulta do custo consolidado, sem somar novamente os componentes internos de um subconjunto já incluído no custo do pai.
4. O mesmo componente deve poder ser selecionado em estruturas diferentes. Alterar seu custo unitário deve localizar e recalcular todos os pais dependentes, sem exigir edição manual de cada produto.
5. Estrutura e custo precisam de fotografia/versionamento histórico para que mudanças futuras no cadastro não reescrevam a composição usada em um cálculo anterior.
6. O fluxo deve deixar clara a diferença entre item simples (custo manual) e item composto (custo calculado), regra específica do Alianza que prevalece sobre qualquer analogia com Omie.

#### O que não importar da referência

Não incluir por analogia:
- emissão fiscal, SPED, NCM ou outras classificações fiscais;
- estoque, compras, ordens de produção ou planejamento de materiais;
- preço de venda, tabelas comerciais, margens e descontos;
- MOD, GGF, perdas ou regras de custeio não aprovadas;
- comportamento específico de telas ou APIs do Omie que não tenha sido verificado em fonte técnica.

**Conclusão:** Omie e planilha são referências complementares, não concorrentes. Omie ajuda a desenhar a experiência de cadastro e composição reutilizável; a planilha ajuda a confrontar essa estrutura com a realidade de fabricação; as decisões funcionais do Alianza definem o comportamento final.


### 13.7 Auditoria da documentação técnica pública do Omie — 10/11/2026

**Fontes consultadas:** documentação oficial da API Omie (api.omie.com.br/docs) e artigo oficial de ajuda sobre cadastro de produto via API (ajuda.omie.com.br). A pesquisa foi feita em páginas públicas; não houve autenticação, chamada real de API, acesso a uma conta Omie nem validação prática de payloads.

Fontes primárias:
- Referência geral da API: https://api.omie.com.br/docs/apis
- Cadastro de Produtos: https://api.omie.com.br/docs/apis/geral/produtos
- Estrutura de produtos (ProdutosEstrutura / malha): https://api.omie.com.br/docs/apis/geral/malha
- KIT de produtos: https://api.omie.com.br/docs/apis/geral/produtoskit
- Famílias de Produtos: https://api.omie.com.br/docs/apis/geral/familias
- Ajuda — Cadastrando um Produto via API: https://ajuda.omie.com.br/pt-BR/articles/6596014-cadastrando-um-produto-via-api

#### 13.7.1 Descoberta principal: estrutura de produto e KIT são recursos separados

A referência oficial lista serviços distintos:
- geral/produtos: cadastro, consulta, listagem, alteração e situação do produto;
- geral/familias: cadastro e pesquisa de famílias;
- geral/malha: estrutura de produtos, com inclusão, alteração, exclusão, consulta e listagem;
- geral/produtoskit: manutenção dos componentes de KIT.

Isso confirma tecnicamente que não devemos modelar a composição industrial do Alianza como se fosse apenas um KIT comercial. A API de estrutura de produto é a referência mais próxima para estudar a UX e a semântica de composição multinível; o serviço de KIT é uma funcionalidade distinta. Essa separação é conceitual: não implica que o modelo de dados do Alianza deva copiar o Omie.

#### 13.7.2 Campos técnicos relevantes da estrutura de produto

A API geral/malha documenta, entre outros:
- identificação do produto-pai por ID interno ou código de integração;
- identificação do produto-filho por ID interno ou código de integração;
- identificador próprio da linha da estrutura;
- quantidade do componente (quantProdMalha);
- observação por componente (obsProdMalha);
- percentual de perda por componente (percPerdaProdMalha);
- identificação de família, tipo e unidade do produto nas consultas;
- observações relevantes de produção;
- dados de inclusão/alteração e usuário associado à linha;
- operações separadas para incluir, alterar, excluir, consultar e listar estruturas;
- listagem paginada, com campos de página e limite de registros.

A consulta de estrutura também retorna um objeto custoProducao com vGGF e vMOD. A existência desses campos na API é apenas evidência do escopo funcional do Omie; não altera a decisão expressa do projeto de deixar MOD e GGF fora do Alianza.

#### 13.7.3 Campos de perda: não aplicar duas vezes

A API Omie admite percPerdaProdMalha na linha da estrutura. O Alianza, porém, já possui a decisão de que perdas/aproveitamento incorporados no consumo informado não devem ser aplicados novamente pelo motor.

Consequência:
- não criar multiplicador automático de perda no motor atual;
- não importar o campo de perda do Omie como regra ativa sem uma decisão funcional específica;
- na importação futura, identificar se a quantidade já contém consumo bruto/perda ou se a perda está separada, e bloquear/sinalizar ambiguidades;
- não converter silenciosamente um percentual de perda em quantidade adicional.

O exemplo de barras comerciais da planilha continua sendo um ajuste operacional específico: o motor recebe a quantidade de compra/consumo já validada e não inventa arredondamento para múltiplos comerciais.

#### 13.7.4 Identidade, famílias e situação dos itens

A documentação de produtos distingue:
- codigo_produto: identificador interno gerado pelo Omie e recomendado para localizar o produto via API;
- codigo: código visível/SKU, que pode ser alterado pelo usuário;
- codigo_produto_integracao: identificador fornecido pelo sistema integrador, usado para evitar duplicidade e relacionar os cadastros.

A API também possui cadastro próprio de famílias e operações para ativar/inativar produto e família.

Aplicação ao Alianza:
- manter o ID numérico funcional próprio aprovado pelo projeto como chave do Cadastro Central;
- não usar descrição ou código visual editável como chave de relacionamento;
- manter chaves internas estáveis para linhas de composição e referências entre itens;
- preservar a regra Alianza de IDs reservados após inativação/exclusão lógica;
- manter famílias controladas pelo Administrador, conforme decisão já aprovada.

Não copiar literalmente os nomes ou os formatos dos identificadores Omie; aproveitar o princípio de separar identificador estável, código de exibição e identificador de integração.

#### 13.7.5 KIT: diferenças relevantes

O serviço geral/produtoskit mantém componentes de um produto cujo tipo deve ser KIT. A operação documenta ações de incluir/alterar/excluir componente, ID do produto componente, quantidade e valor unitário do componente, além de possível local de estoque.

Isso não corresponde integralmente ao motor de custeio industrial do Alianza. Em especial:
- o Alianza não deve exigir que um item composto seja classificado como KIT;
- não importar local de estoque, valor comercial do componente ou regras de estoque;
- o custo do componente deve vir do cadastro de custo do Alianza, e não de um valor unitário comercial informado na linha;
- a composição do Alianza precisa suportar níveis recursivos, custo derivado e recálculo em cascata conforme as regras próprias.

#### 13.7.6 Contrato de API e integração: observações técnicas

A documentação pública apresenta endpoints POST por serviço, operação identificada no campo call, parâmetros em param e exemplos de requisição/resposta em JSON. O cadastro de produtos documenta operações de inclusão/consulta/alteração/listagem e recomenda persistir o identificador retornado pelo Omie e utilizar código de integração para evitar duplicidade.

A referência geral lista centenas de operações e disponibiliza especificação OpenAPI. Isso pode apoiar uma integração futura, mas nenhuma integração com Omie foi aprovada nesta etapa. Não armazenar App Key/App Secret no frontend; qualquer integração futura exigirá serviço backend, gestão de segredos, permissões, tratamento de erros, idempotência, limites operacionais e política de sincronização próprios.

A documentação consultada não é prova de:
- comportamento transacional entre múltiplas operações;
- validação de ciclos de composição;
- cálculo automático de custo recursivo ou cascata de custos;
- compatibilidade exata entre estrutura, KIT e ordens de produção;
- semântica de arredondamento, precisão ou conversão de unidades;
- histórico imutável ou versionamento de composição.

Esses comportamentos não devem ser presumidos a partir da existência dos endpoints/campos.

#### 13.7.7 Matriz de aproveitamento para o Alianza

| Recurso documentado no Omie | Decisão para o Alianza |
|---|---|
| Cadastro central de produtos | Aproveitar o padrão de cadastro único, mantendo modelo próprio de custos |
| ID interno distinto do código visível | Aproveitar o princípio; manter ID numérico próprio já aprovado |
| Cadastro de famílias | Aproveitar a separação conceitual; seguir as regras de famílias já aprovadas |
| Estrutura de produto (malha) | Referência principal de UX/semântica para composição industrial |
| Linha com componente e quantidade | Compatível com a estrutura aprovada do Alianza |
| Observações por componente e produção | Avaliar como informação descritiva, sem efeito automático no cálculo |
| Percentual de perda | Não importar como cálculo ativo; perdas já incorporadas não podem ser duplicadas |
| Campos GGF e MOD | Explicitamente fora do escopo Alianza |
| KIT de produto | Não confundir com composição industrial; não importar estoque/valor comercial |
| Ativação/inativação | Conceito compatível, mas prevalecem exclusão lógica, reserva de ID e reativação do Alianza |
| Paginação e filtros de API | Referência técnica para futuras integrações/importações; não regra de UX obrigatória |
| OpenAPI e exemplos JSON | Material de apoio para eventual integração futura, ainda não autorizada |

**Conclusão atualizada:** agora existe documentação técnica pública oficial suficiente para confirmar a separação entre cadastro, famílias, estrutura de produto e KIT no Omie e para identificar campos concretos de composição. A estrutura geral/malha é a referência técnica mais pertinente para o desenho do Cadastro Central e da composição multinível. Ainda assim, o Alianza mantém seu próprio modelo, cálculo, governança, histórico, permissões e exclusões de escopo. Nenhum contrato de integração com Omie foi implementado ou testado.


### 13.8 Auditoria do fluxo de produção do Omie e decisão de escopo do módulo — 10/11/2026

**Fontes oficiais adicionais consultadas:**
- Ordem de Produção — API: https://api.omie.com.br/docs/apis/produtos/op
- Cadastrando uma Ordem de Produção: https://ajuda.omie.com.br/pt-BR/articles/1432016-cadastrando-uma-ordem-de-producao
- Visualizando e Imprimindo a OP e o Mapa de Custo: https://ajuda.omie.com.br/pt-BR/articles/9864358-visualizando-e-imprimindo-a-ordem-de-producao-e-o-mapa-de-custo
- FAQ — Compras, Estoque e Produção: https://ajuda.omie.com.br/pt-BR/articles/6867689-perguntas-frequentes-compras-estoque-e-producao
- Perguntas Frequentes sobre Compras, Estoque e Produção (inclui reordenação e ajustes na OP): https://ajuda.omie.com.br/pt-BR/articles/6867689-perguntas-frequentes-compras-estoque-e-producao

A consulta foi documental, sem conta Omie, sem chamadas reais à API e sem integração executada.

#### 13.8.1 O Omie separa ficha técnica de execução da fabricação

A documentação oficial descreve dois objetos e ciclos diferentes:

1. **Estrutura do produto / ficha técnica:** definição reutilizável dos itens e quantidades necessários para fabricar um produto acabado ou em processo.
2. **Ordem de Produção (OP):** instância de uma fabricação, com produto, quantidade a produzir, previsão, datas, componentes necessários, observações e conclusão.

Ao criar uma OP, o Omie preenche seus componentes a partir da estrutura cadastrada. O operador pode incluir, remover, reordenar ou alterar quantidades na OP sem modificar a estrutura mestre. Ao concluir, informa a quantidade efetivamente produzida; o processo também pode tratar produtos ruins, movimentar estoque e consumir componentes. A API expõe inclusão, alteração, consulta, listagem, conclusão, exclusão, reversão e upsert de OP.

**Leitura para o Alianza:** o Cadastro Central e a estrutura de composição são dados mestres de custeio. OP, apontamento e conclusão são controle de execução produtiva. Não são a mesma funcionalidade e não devem ser misturados no módulo de custos.

#### 13.8.2 Mapa de Custo do Omie e componentes de custo

O Mapa de Custo apresentado pelo Omie separa:
- MP (matéria-prima): quantidade do item na OP multiplicada pelo CMC unitário;
- MOD (mão de obra direta): valor configurado na estrutura do produto;
- GGF (gastos gerais de fabricação): valor configurado na estrutura do produto.

O FAQ oficial confirma que MOD e GGF são informados na aba Custo da Produção e que a estrutura do produto está disponível para tipos específicos de produto em processo/acabado. Isso descreve o modelo do Omie, não uma obrigação para o Alianza.

**Decisão Alianza:** manter fora do escopo MOD, GGF e CMC baseado em estoque. O Alianza calcula o custo industrial conforme as regras já aprovadas, usando itens e serviços cadastrados com custos próprios e composição multinível. Não criar campos vazios de MOD/GGF para imitar o Omie.

#### 13.8.3 Confronto com a planilha industrial

A planilha de referência contém fichas técnicas e quantidades de lote, mas não constitui um sistema de apontamento de produção. O exemplo Mini Torniquete - Inox mostra:
- lote de 10 conjuntos;
- na linha específica do tubo Ø3", consumo de 11 m para 10 conjuntos e compra comercial de 12 m;
- nessa linha, preço de R$ 44,47395/m, custo de compra de R$ 533,68740 e rateio de R$ 53,36874 por conjunto;
- o grupo completo de tubos soma quatro bitolas e tem subtotal AB15 de R$ 666,10674 antes do fator Gama;
- quantidade-base da estrutura, portanto, não pode ser presumida como sempre 1.

A conferência das fórmulas também revelou um ponto importante para a validação: a planilha aplica o fator Gama 1,2 tanto ao grupo de chapas inox (AB22 = R$ 213,0577515, resultando em I11 = R$ 255,6693018) quanto ao grupo de tubos (AB15 = R$ 666,10674, resultando em I12 = R$ 799,328088). O total I19 = R$ 1.733,89638 inclui esse fator nos dois grupos. Removendo o efeito de Gama desses dois grupos, sem alterar os demais grupos, o total-base calculado é R$ 1.558,0634817, exibido como R$ 1.558,06 pela regra de apresentação aprovada. A comparação anterior que tratava apenas o grupo de tubos como afetado por Gama estava incompleta e não deve ser usada como fixture de referência.

Isso exige que a estrutura de custeio represente uma quantidade-base de saída e que o motor divida o custo total do lote por essa base. Não exige criar OP, saldo de estoque, reserva de materiais, lote/validade, apontamento de produção ou quantidade rejeitada.

A planilha também contém grupos de materiais e serviços (chapas, tubos, usinagem, corte laser, pintura, manufatura, embalagem e montagem). A decisão vigente é cadastrar materiais e serviços como itens identificáveis, reutilizáveis e com unidade/custo próprios. Grupos de relatório não devem gerar custos duplicados nem virar multiplicadores genéricos. Pintura e usinagem podem ser itens/serviços com custo próprio; corte laser não cria custo automático. Perdas e aproveitamento já incorporados à quantidade informada não podem ser aplicados uma segunda vez.

#### 13.8.4 Matriz final de escopo

| Capacidade | Decisão final para o módulo Sistema de Custos |
|---|---|
| Cadastro Central único de materiais, serviços, subconjuntos e produtos | INCLUIR |
| Famílias, unidade única por item, ID estável e status | INCLUIR |
| Item simples com custo manual e item composto com custo derivado | INCLUIR |
| Estruturas multinível, componentes reutilizáveis e quantidades por linha | INCLUIR |
| Quantidade-base de saída/lote da estrutura, default 1 | INCLUIR |
| Cálculo recursivo e recálculo em cascata de dependentes | INCLUIR |
| Histórico, versionamento e fotografia imutável de estrutura/custo | INCLUIR |
| Observação descritiva por linha de composição | INCLUIR como dado informativo, sem efeito matemático |
| Custo de materiais e serviços como itens simples cadastrados | INCLUIR |
| Ajuste manual Gama, opcional e contextual | INCLUIR conforme regra existente; nunca automático |
| Prévia/confirmar, permissões, auditoria, aprovações e importação validada | INCLUIR conforme decisões funcionais existentes |
| Visão/relatório de composição e memória de cálculo por componente | INCLUIR; saída consultiva/exportável, sem se tornar novo motor |
| Ordem de Produção, etapas/Kanban e programação de fábrica | EXCLUIR do módulo atual |
| Apontamento de início/fim, quantidade produzida e refugos | EXCLUIR do módulo atual |
| Reserva/baixa/entrada de estoque, locais de estoque e inventário | EXCLUIR |
| Lotes físicos, validade e rastreabilidade de matéria-prima | EXCLUIR |
| Compras, fornecedores, pedido de compra e recebimento | EXCLUIR |
| CMC médio de estoque e recálculo contábil retroativo | EXCLUIR |
| MOD e GGF | EXCLUIR, decisão já aprovada |
| Preço de venda, margem, desconto, tabelas comerciais e fiscalidade | EXCLUIR |
| Percentual automático de perda, fator de aproveitamento ou arredondamento comercial genérico | EXCLUIR; a quantidade da linha deve refletir a regra operacional aprovada, sem dupla aplicação |
| Integração/sincronização com Omie | NÃO IMPLEMENTAR nesta fase; pesquisa não equivale a autorização de integração |

#### 13.8.5 Decisão final de produto e fronteira do módulo

O módulo a finalizar é um **Sistema de Cadastro e Custeio Industrial por Estrutura**, e não um módulo de PCP/MRP, estoque ou execução de produção.

Seu fluxo principal fica definido assim:

1. Administrador mantém famílias, unidades e regras de cadastro.
2. Usuário autorizado pesquisa ou cadastra uma única vez materiais, serviços, subconjuntos e produtos no Cadastro Central.
3. Item simples recebe custo manual controlado; item composto recebe uma estrutura com referências a itens já cadastrados.
4. A estrutura informa quantidades consumidas e quantidade-base de unidades acabadas do lote (1 por padrão).
5. O motor calcula recursivamente o custo do lote e o custo unitário, sem ponto flutuante binário, sem dupla aplicação de perdas e sem fatores comerciais.
6. O sistema guarda a versão da estrutura, memória do cálculo, custo vigente e histórico; mudanças em componentes propagam recálculo de forma consistente aos compostos dependentes.
7. O usuário consulta composição e impacto, exporta relatórios e acompanha alterações/aprovações conforme permissões.
8. A execução física da fabricação permanece fora do módulo. Se futuramente for necessária, será um módulo de Produção separado, que poderá consumir uma versão aprovada da estrutura de custos, sem alterar retroativamente o cadastro mestre.

#### 13.8.6 Pendências que não devem reabrir o escopo funcional

A pesquisa não identificou motivo para adicionar OP, estoque, MOD, GGF, compras ou fiscalidade ao Sistema de Custos. As pendências remanescentes são de fechamento técnico e validação, não de ampliação de produto:
- definir e documentar a política de precisão interna para divisões periódicas, persistência decimal e apresentação; a regra de apresentação aprovada permanece a existente;
- verificar que o motor suporta e testa quantidade-base de lote, recálculo em cascata, ciclos, itens inativos, exclusão lógica e snapshots;
- executar reconciliação integral da ficha Mini Torniquete - Inox, incluindo todos os grupos e a regra de Gama aplicada a chapas inox e tubos; a conferência parcial acima não substitui a validação completa de cada linha;
- executar a suíte do projeto com as versões de dependências fixadas e testes de integração quando o gate de ambiente não produtivo estiver liberado;
- concluir modelagem, permissões, RLS, auditoria e transações antes de qualquer persistência;
- não executar migrations, deploy ou alteração de produção sem os gates já registrados neste plano.

**Decisão recomendada para encerramento funcional:** congelar o escopo do módulo nos itens marcados INCLUIR nesta matriz e não acrescentar funcionalidades de execução da produção. A partir deste ponto, mudanças de escopo exigem justificativa operacional e aprovação explícita; o trabalho restante é completar a implementação, validar o cálculo e fechar os gates técnicos.


### 13.9 Consolidação final do escopo funcional — decisão de encerramento

A análise complementar do fluxo de produção do Omie e a conferência direta das fórmulas da planilha não justificam ampliar o módulo. Fica congelado o escopo funcional definido na matriz 13.8.4. Esta seção resolve expressamente a pendência anterior de quantidade-base: ela está aprovada conforme a regra abaixo; não permanece como decisão em aberto.

**Contrato funcional da quantidade-base**
- Todo item composto possui quantidade-base de saída positiva.
- O padrão é 1 quando a ficha representa uma unidade acabada.
- Quando a ficha representa um lote, a quantidade-base informa quantas unidades acabadas aquele conjunto de componentes produz.
- Cada linha informa a quantidade total consumida para aquela quantidade-base de saída.
- O custo total da estrutura é a soma de quantidade da linha × custo unitário do componente, calculado recursivamente.
- O custo unitário do item composto é o custo total dividido pela quantidade-base.
- Quantidade-base zero, negativa ou ausente/inválida deve ser rejeitada; não assumir conversões de unidade.
- O motor não arredonda cada linha nem cada nível intermediário para exibição. O arredondamento de apresentação é aplicado ao resultado final segundo a regra já aprovada.
- Divisões cujo resultado decimal seja não terminante exigem política de precisão interna ainda pendente; até essa aprovação, o motor deve rejeitar explicitamente o caso, em vez de arredondar silenciosamente.

**Reconciliação da planilha — correção registrada**
A ficha Mini Torniquete - Inox aplica o fator Gama 1,2 em dois grupos identificáveis: chapas inox e tubos. O custo I19 da planilha, R$ 1.733,89638, contém Gama nos dois grupos. A base sem Gama desses grupos, mantendo os demais valores, é R$ 1.558,0634817. Qualquer fixture de teste que retire Gama apenas dos tubos está incorreto e deve ser corrigido. Esta conferência valida os valores desses grupos e a lógica da quantidade-base; não certifica ainda a reconciliação de todas as linhas e referências externas da pasta de trabalho.

**Decisão final do módulo**
O produto aprovado é um Sistema de Cadastro e Custeio Industrial por Estrutura, com Cadastro Central, famílias, materiais/serviços/subconjuntos/produtos reutilizáveis, itens simples e compostos, estruturas multinível, quantidade-base, cálculo recursivo, recálculo em cascata, histórico/versionamento, auditoria, aprovações, importação validada, relatórios e exportação.

Ficam fora do módulo: PCP/OP, apontamento e execução de fábrica, estoque, compras, fornecedores, MRP, MOD, GGF, CMC de estoque, perdas automáticas, preço de venda, margem, descontos, fiscalidade e sincronização com Omie.

A decisão funcional está encerrada. Permanecem tarefas de engenharia, qualidade e liberação: corrigir os fixtures de teste que estejam divergentes da planilha, aprovar a precisão interna para divisões não terminantes, completar UI/API/persistência/RLS/auditoria, executar testes e fechar os gates de ambiente. O encerramento funcional não é autorização para migration, deploy, merge ou alteração de produção.


### 13.10 Auditoria técnica inicial do motor de cálculo — 10/11/2026

**Base consultada:** branch `feature/alianza-costing-foundation-20261110`, arquivos `server/domain/costing/engine.ts`, `server/domain/costing/engine.test.ts` e `package.json`. Auditoria de leitura do código; nenhum arquivo de implementação foi alterado nesta etapa.

#### 13.10.1 Defeito identificado na divisão por quantidade-base

O motor atual calcula `divideExact(quantity × componentUnitCost, outputQuantity)` individualmente para cada linha e depois soma os resultados. Isso não corresponde exatamente ao contrato funcional fechado na seção 13.9, que determina somar primeiro o custo total de todas as linhas do lote e dividir uma única vez pela quantidade-base.

Consequência: uma estrutura pode ter linhas individuais com quocientes decimais não terminantes, mas total do lote divisível exatamente pela quantidade-base. O motor atual rejeita esse caso antes de avaliar o total consolidado. A correção deverá calcular o total do lote antes da divisão. A memória de cálculo por linha também precisa de semântica definida para contribuições que não tenham representação decimal finita.

#### 13.10.2 Divergência de R$ 0,0000001 no fixture Mini Torniquete - Inox

A fixture atual em `engine.test.ts` contém os seguintes grupos antes de Gama:

| Grupo | Valor (R$) |
|---|---:|
| Chapa carbono | 61,6601903 |
| Chapa inox | 213,0577515 |
| Tubos | 666,10674 |
| Usinagem | 109,805 |
| Corte laser | 0 |
| Manufatura | 30,4 |
| Embalagem | 150 |
| Itens de montagem | 327,0338 |
| **Soma aritmética dos grupos** | **1.558,0634818** |

O teste espera `1558.0634817`. Portanto, a fixture e a expectativa divergem em R$ 0,0000001. A leitura das fórmulas/valores armazenados confirma:
- `I17 = SUM(I10:I16)`, cache R$ 1.406,86258;
- `I18`, cache R$ 327,0338;
- `I19 = SUM(I17:I18)`, cache R$ 1.733,89638;
- `I11 = AB22 × AH7`, com `AB22 = 213,0577515` e `AH7 = 1,2`;
- `I12 = AB15 × AH7`, com `AB15 = 666,10674` e `AH7 = 1,2`.

Retirando Gama dos dois grupos a partir do total consolidado em cache, chega-se a R$ 1.558,0634817. Somando diretamente os valores em cache dos oito grupos-base informados na fixture, chega-se a R$ 1.558,0634818. A diferença de R$ 0,0000001 já aparece na reconciliação entre os caches de subtotal e os valores individuais; não deve ser escondida nem corrigida arbitrariamente. A ficha ainda requer reconciliação integral, incluindo fórmulas e referências de todos os grupos.

**Correção documental:** a frase anterior da seção 13.5 que menciona R$ 1.600,6750321 como base de teste está superada pela correção de escopo registrada na seção 13.8 e não deve orientar fixtures. A expectativa de R$ 1.558,0634817 também não deve ser tratada como reconciliada com a soma dos oito valores atualmente usados no teste até a diferença ser explicada.

#### 13.10.3 Validação executável ainda não comprovada nesta etapa

O `package.json` declara Node `>=22 <23`, pnpm e Vitest. O runtime disponível nesta sessão é Node 22.16.0, mas o repositório não está clonado no ambiente local e pnpm/dependências não estão disponíveis. Por isso, não foi possível executar agora a suíte Vitest nem o TypeScript check fixado pelo projeto. A leitura dos arquivos no GitHub não é evidência de teste aprovado.

O estado dos testes permanece: escritos no branch, execução pendente de ambiente de desenvolvimento reproduzível. Não houve acesso a banco, migrations, DDL/DML, RLS, deploy ou produção.

#### 13.10.4 Próximas correções técnicas

1. Corrigir o algoritmo para agregar o custo de todas as linhas do lote antes de dividir pela quantidade-base.
2. Definir a representação/precisão da memória de cálculo por linha quando a contribuição por unidade for periódica.
3. Reconciliar a diferença de R$ 0,0000001 da fixture com as fórmulas/caches da planilha; não alterar a expectativa apenas para fazer o teste passar.
4. Executar Vitest e TypeScript check com versões/dependências fixadas no repositório.
5. Ampliar testes para divisões periódicas por linha com total consolidado exato, divisão periódica no total, lotes multinível e consistência da memória de cálculo.

A política de precisão interna continua pendente e deverá ser aprovada antes de persistir resultados arredondados ou escolher escala monetária fixa.

### 13.11 Correção do cálculo de lote — 10/11/2026

A implementação na branch `feature/alianza-costing-foundation-20261110` foi ajustada para seguir a regra de lote documentada na arquitetura: calcular o custo total de cada linha (`quantidade × custo unitário`), somar todas as linhas do lote e dividir o total uma única vez pela quantidade de unidades acabadas.

- Arquivo: `server/domain/costing/engine.ts`
- Commit: `2d097381f390b79e7074ebf7f4f81be96487596d`
- Testes: `server/domain/costing/engine.test.ts`
- Commit: `fb82e678e3c57f90bc4e389ef7c1011b895ae908`
- O detalhe por linha agora expõe `batchLineCost`, isto é, o custo total daquela linha no lote, sem tentar atribuir prematuramente uma parcela unitária que pode ser periódica.
- Foi incluído teste em que as parcelas individuais seriam 1/3 e 2/3, mas o lote totaliza 3 e produz custo unitário exato 1. Também permanece teste garantindo rejeição quando o resultado unitário final é periódico.
- A aritmética continua decimal exata com `BigInt`; nenhuma escala ou arredondamento interno novo foi introduzido.
- **Validação pendente:** os arquivos foram conferidos após a gravação no GitHub, mas a suíte Vitest ainda não foi executada. Não declarar os testes aprovados até executá-los.


### 13.12 Precisão de três casas, cálculo racional exato e Gama configurável — decisão aprovada (10/11/2026)

Esta seção atualiza e substitui as pendências de precisão descritas nas seções 13.10 e 13.11.

**Regra aprovada**
- Custos manuais, quantidades de linhas e quantidade-base aceitam no máximo três casas decimais.
- A aritmética intermediária preserva o valor exato, inclusive frações periódicas, em toda a composição multinível. Não arredondar linhas, grupos, subconjuntos ou itens intermediários.
- Somente o custo unitário final apresentado é arredondado para no máximo três casas.
- Convenção: quarta casa decimal de 0 a 5 mantém a terceira; de 6 a 9 incrementa. Empate exato em 5 fica para baixo. Exemplos: 1,2344 → 1,234; 1,2345 → 1,234; 1,2346 → 1,235.
- A apresentação pode omitir zeros finais: R$ 10; R$ 10,2; R$ 10,025.
- Valores racionais periódicos devem permanecer exatos internamente; não podem ser arredondados a cada nível para alimentar o próximo.

**Grupos e Gama**
- Os grupos serão criados manualmente na configuração dos custos; não existe lista fixa imposta pelo motor.
- Gama será uma configuração/aba própria de ativação, com percentual inicial de 1,2%.
- Gama não é grupo de custo nem fator automático global. A configuração deverá indicar explicitamente a quais grupos o percentual ativo se aplica.
- A camada de configuração/aplicação de Gama permanece separada do motor estrutural genérico, evitando embutir regra comercial ou multiplicador indiscriminado no cálculo recursivo.

**Implementação registrada**
- Motor: `server/domain/costing/engine.ts`, commit `1ee523b0afce444420c4a571ac2e517b80a31bce`.
- Testes: `server/domain/costing/engine.test.ts`, commit `064c93b66cecf07819c90001eb29530f2a2081ab`.
- O motor passou a usar frações exatas com `BigInt`, valida entradas de até três casas, preserva resultados periódicos entre níveis e formata o resultado final com três casas no máximo.
- Os testes escritos cobrem valores pequenos (0,025), recorrência 1/3, preservação exata em composição multinível, limites de entrada, arredondamento e a fixture de grupos ajustada à precisão aprovada.

**Reconciliação Mini Torniquete Inox**
A fixture passa a representar os grupos com no máximo três casas, conforme a regra nova: 61,660 + 213,058 + 666,107 + 109,805 + 0 + 30,4 + 150 + 327,034 = R$ 1.558,064. Esse total substitui a expectativa anterior de R$ 1.558,0634817 para o cenário de teste com entradas limitadas a três casas. Não se afirma que os caches antigos da planilha foram integralmente reconciliados; a diferença histórica de R$ 0,0000001 fica superada para a fixture sob a nova precisão de entrada, mas permanece registrada como diferença entre os valores originais da planilha.

**Validação**
Os arquivos foram gravados no branch de implementação e conferidos por leitura no GitHub. A suíte Vitest e o TypeScript check ainda não foram executados; portanto, não declarar testes aprovados. Nenhuma migration, alteração de banco, deploy, merge ou operação de produção foi realizada.
