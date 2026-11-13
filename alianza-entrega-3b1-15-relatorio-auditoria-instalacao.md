# Alianza Costing — Auditoria de instalação e caminho de integração

## Escopo e proveniência

Auditoria somente leitura da branch publicada `costing-security-preflight-final-20261112` do repositório `joaovictorsotog-create/alianza-ai-platform`.

- HEAD auditado: `ecbd686b2c58c46ec7c114c07e3bf22fdfbab028`
- Base comum com `main`: `1ac2573092990c8af2793055f1924e28ff0a2c5f`
- `main` auditada: `aff3c6408d57c2c328fa7b4b2fca0f65ac10ec3d`
- Nenhum arquivo da aplicação foi alterado.
- Nenhum merge, rebase, cherry-pick, push, PR, deploy ou banco persistente/remoto foi utilizado nesta rodada.

## Conclusão executiva

O menor caminho seguro **não** é executar diretamente `drizzle-kit migrate` nem aplicar `scripts/apply-supabase-rls.mjs` em um banco vazio. O estado versionado de PostgreSQL está incompleto como cadeia Drizzle: `drizzle/pg/meta/_journal.json` possui somente as entradas `0000_eminent_mathemanic` e `0001_pink_pete_wisdom`, enquanto o diretório contém SQLs até `0036_costing_foundation.sql`, com numerações duplicadas e lacunas. Não há evidência versionada suficiente para afirmar que os SQLs `0002`–`0036` são uma sequência migrável pelo journal atual.

Além disso, o preflight atual aplica `drizzle/pg/rls_multitenant.sql`, que é global. Ele altera RLS, grants e funções de usuários, organizações, CRM, automações, pipelines, auditoria e outros módulos, não apenas Costing. Portanto, não é um mecanismo seguro para um teste isolado do Costing.

O backend Costing possui engine, snapshots, publicação e endpoints tRPC de cálculo/snapshot/publicação. Não foi localizada tela, rota de frontend ou hooks tRPC de Costing; também não existem routers CRUD para grupos, itens, preços, estruturas ou configurações Gama. Assim, o teste funcional integrado do frontend não está disponível na branch auditada.

## Classificação das etapas

| Etapa | Estado | Evidência / impedimento |
|---|---|---|
| Inventário de migrations | COMPROVADA | 38 SQLs PostgreSQL, de `0000` a `0036`, com duplicidades e lacunas documentadas na matriz |
| Relação SQL ↔ journal/meta | COMPROVADA | journal/meta PostgreSQL registram somente `0000` e `0001` |
| Bootstrap vazio reproduzível | BLOQUEADA | nesta sessão os binários `initdb`/`pg_ctl` não estão disponíveis; independentemente disso, a cadeia journal/SQL é inconsistente e depende de objetos Supabase/auth |
| Dependências do Costing | COMPROVADA | `0036` depende de `organizations`, e das tabelas de Costing em cadeia; mapa anexo |
| RLS exclusivo do Costing | BLOQUEADA | `rls_multitenant.sql` é global; aplica segurança a múltiplos módulos |
| Preflight seguro para Costing isolado | PENDENTE | requer um artefato SQL/runner específico para Costing e uma estratégia de baseline aprovada |
| Divergência Git | COMPROVADA | branch tem 40 commits exclusivos; `main` tem 4; não há arquivos sobrepostos no diff contra a base comum |
| Autenticação real | PENDENTE | wiring Supabase + sessão estático; não foi executado ambiente autorizado |
| Identidade/organização real | PENDENTE | contratos e helpers existem; falta teste funcional com autenticação e banco autorizado |
| Leitura/gravação tenant-scoped | PENDENTE | backend e RLS foram testados em harness descartável anterior; fluxo frontend não existe |
| Cadastro/edição de grupos, itens e preços | BLOQUEADA | não há UI nem endpoints CRUD Costing correspondentes |
| Estruturas e versões via backend | COMPROVADA | schema, `publishStructure` e constraints existem; fluxo frontend inexistente |
| Cálculo e Gama via backend | COMPROVADA | engine, routers e testes artificiais existem; integração frontend pendente |
| Publicação/snapshots imutáveis | COMPROVADA | persistência, trigger e testes existem; integração frontend pendente |
| Isolamento entre duas organizações | COMPROVADA | harness PostgreSQL descartável da Entrega 3B.1.14; não é E2E frontend |
| Comunicação frontend → backend → PostgreSQL | BLOQUEADA | não há superfície frontend Costing e não há baseline de instalação PostgreSQL comprovada |

## RLS: risco de escopo

O script `scripts/apply-supabase-rls.mjs` valida destino e falha fechado para production, mas seu payload é `rls_multitenant.sql` completo. Esse SQL:

- cria/hardeniza helpers `private.*`;
- altera `users` e `organizations`;
- percorre dezenas de tabelas gerais e aplica `ENABLE/FORCE ROW LEVEL SECURITY`, grants e políticas;
- configura políticas de convites, auditoria, Agents, prompts, CRM e pipelines;
- só dentro de um bloco posterior configura as sete tabelas Costing.

Aplicá-lo para testar somente Costing modifica inadvertidamente a segurança de módulos existentes. O caminho seguro é separar a validação do Costing do payload global, usando banco descartável já carregado com um baseline explicitamente identificado, ou criar posteriormente um script Costing-only revisado. Essa separação não foi implementada nesta rodada.

## Caminho mínimo seguro

1. Congelar e aprovar um baseline PostgreSQL real, identificado por SHA e por sequência de migrations; não inventar entradas no journal.
2. Reconciliar `drizzle/pg/meta/_journal.json` e os SQLs históricos em uma rodada própria de migrations, com decisão explícita sobre duplicidades `0007`, `0021`, `0027` e `0032` e lacuna `0016`.
3. Validar o baseline em PostgreSQL descartável; só depois aplicar `0036_costing_foundation.sql` e verificar as dependências.
4. Criar/revisar uma aplicação Costing-only para o banco descartável, sem executar o RLS global; comparar políticas e grants esperados com o baseline.
5. Implementar a superfície frontend e os endpoints CRUD faltantes para grupos, itens, preços, estruturas e Gama.
6. Executar testes funcionais com autenticação real em ambiente autorizado, usando duas organizações e dados artificiais; separar isso dos testes de contrato e do harness PostgreSQL.
7. Somente após evidência dos passos anteriores planejar integração da branch com `main`; nesta rodada não se recomenda merge automático porque o caminho funcional ainda está incompleto.

## Parecer

O Costing está tecnicamente testável no domínio e no backend, mas não está pronto para um teste funcional integrado de frontend em banco vazio. O risco principal é tratar uma coleção histórica parcialmente journalizada como migration chain e aplicar o RLS global como se fosse Costing-only. O menor caminho seguro é primeiro resolver proveniência/instalação e escopo RLS; depois completar a superfície frontend/CRUD; por fim executar E2E real em ambiente autorizado.
