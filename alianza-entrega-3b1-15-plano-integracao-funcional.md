# Alianza Costing — Plano mínimo para teste funcional integrado

## Pré-condições obrigatórias

| Pré-condição | Estado | Ação necessária |
|---|---|---|
| Baseline PostgreSQL identificável | BLOQUEADA | reconciliar journal, SQLs e histórico de aplicação |
| Banco PostgreSQL descartável reproduzível | PENDENTE | executar sequência aprovada com `initdb`/`pg_ctl` disponíveis |
| RLS Costing-only | PENDENTE | separar payload Costing do SQL global ou provar baseline seguro |
| Roles e identidade Supabase | PENDENTE | fornecer ambiente autorizado de teste; sem produção |
| CRUD Costing backend | BLOQUEADA | implementar/revisar endpoints para cadastro e edição |
| Tela frontend Costing | BLOQUEADA | criar rota/componentes/hooks tRPC |

## Sequência proposta

### Fase 1 — Instalação

1. Selecionar o baseline oficial que corresponde ao schema Alianza.
2. Reconciliar os SQLs não journalizados sem fabricar histórico.
3. Subir PostgreSQL descartável.
4. Aplicar somente a sequência aprovada e verificar o schema.
5. Aplicar `0036_costing_foundation.sql` e verificar FKs, índices, constraints e trigger.
6. Aplicar políticas Costing-only em banco descartável. O SQL global só deve ser aplicado em um ambiente quando sua mudança nos demais módulos for intencional e aprovada.

### Fase 2 — Backend

7. Criar fixtures artificiais para duas organizações, dois usuários/membros, grupos, itens simples e compostos, preços manuais e estruturas DRAFT.
8. Exercitar CRUD tenant-scoped para grupos, itens, preços, estruturas e Gama.
9. Publicar uma estrutura DRAFT e verificar transição ACTIVE/SUPERSEDED.
10. Criar snapshot autoritativo via `createSnapshot` e confirmar leitura histórica.
11. Tentar UPDATE/DELETE do snapshot e confirmar rejeição por trigger/privilégio.
12. Comparar cálculo exato, Gama, quantidade de saída e arredondamento final usando valores artificiais.

### Fase 3 — Frontend e autenticação

13. Adicionar uma superfície Costing que use o contexto de workspace existente.
14. Fazer login real em projeto de teste Supabase, nunca com dados de produção.
15. Confirmar `auth.uid()` → usuário local → membership → `organizationId` selecionado.
16. Exercitar chamadas reais do frontend para backend e PostgreSQL, sem chamar contratos/harness de E2E.

### Fase 4 — Isolamento E2E

17. Criar duas organizações e dois usuários de teste.
18. Fazer usuário A criar/editar apenas registros de A.
19. Confirmar que A não lê nem grava registros de B.
20. Repetir para B.
21. Confirmar que a alteração de workspace invalida caches e não reutiliza dados da sessão anterior.
22. Registrar request, resposta, organização, usuário, resultado esperado e resultado real.

## Critérios de aceite

- autenticação real confirmada;
- organização derivada de membership real;
- operações CRUD tenant-scoped confirmadas;
- cálculo e Gama confirmados com dados artificiais;
- publicação e snapshot imutável confirmados;
- duas organizações isoladas em frontend, backend e banco;
- nenhum teste chamado de E2E sem atravessar frontend, backend e PostgreSQL;
- nenhum SQL aplicado em produção ou banco persistente sem autorização explícita;
- hashes e sequência de instalação registrados no Boost.

## Resultado esperado nesta branch

Com o conteúdo atual, as fases de domínio/backend e parte do RLS já têm evidências anteriores. O teste funcional integrado permanece **BLOQUEADO** pela ausência da superfície frontend/CRUD e **PENDENTE** pela reconciliação das migrations e do RLS global. O próximo passo seguro é uma rodada de engenharia/documentação específica para esses gaps, não um merge ou execução em produção.
