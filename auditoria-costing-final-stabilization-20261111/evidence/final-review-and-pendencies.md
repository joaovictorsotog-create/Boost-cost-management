# Revisão final independente e pendências

## Escopo revisto

Foi feita uma segunda revisão somente leitura após a execução dos testes, comparando a branch final contra `e110f98b8298d7732e3424e4b84da09df9bad9ca`.

Foram revistos:

- contador e rollback;
- migration incremental e idempotência;
- triggers de estruturas e linhas;
- ordem de locks e publicação;
- corrida de edição de linha versus publicação;
- snapshots e leitura transacional;
- isolamento por `organizationId`;
- motor de cálculo e Gama;
- router e permissões;
- escopo do diff e ausência de alterações em produção.

Não foram encontrados defeitos críticos na implementação alterada. O RLS continua uma pendência de segurança explicitamente mantida pelo requisito da rodada e não foi alterado.

## Snapshots e integridade do cálculo

O serviço de snapshot:

- executa o cálculo no servidor;
- usa `REPEATABLE READ` para leitura e persistência numa transação;
- filtra itens, estruturas, linhas e configurações pela organização;
- exige item-alvo pertencente à organização;
- exige estrutura ACTIVE quando uma estrutura é solicitada;
- seleciona a estrutura ACTIVE para cada item composto;
- persiste o grafo completo, resultado exato, Gama e versão do motor;
- mantém o snapshot imutável no PostgreSQL;
- ordena o histórico por `calculatedAt` e `id` descendentemente.

Os testes de snapshot e motor direcionados passaram: 34 testes combinados entre engine e snapshots.

## Motor e Gama

As regras existentes não foram alteradas. Os testes existentes cobrem cálculos simples, composições, conversões, frações exatas, arredondamento aprovado, Gama, grupos selecionados, snapshots e publicação planejada. O harness PostgreSQL confirmou custo exato `50.6` e ajuste Gama `0.6` com fixtures artificiais.

## Autorização

O router continua a exigir:

- `costing.read` para estruturas, snapshots e cálculo;
- `workspace.manage` para criação, edição, remoção e publicação;
- validação por tenant via `requireTenantPermission` antes de chamar o serviço.

Os testes de router passaram: 18/18. Foram preservados testes de tenant inválido, permissões insuficientes, item estrangeiro e snapshot não ACTIVE.

## Pendências e riscos

### RLS não implementado

A migration final não instala RLS, policies, grants ou `FORCE ROW LEVEL SECURITY`. A autorização de aplicação está coberta, mas o PostgreSQL não tem a segunda barreira de isolamento para acesso SQL direto. O plano RLS permanece apenas documental e deve ser tratado antes de produção.

### Registro operacional da migration

A migration `0038` é idempotente e foi executada duas vezes no PostgreSQL descartável. A árvore local mantém migrations Costing em `drizzle/pg`, mas o journal PostgreSQL existente não lista `0036`/`0037`; o pipeline operacional precisa confirmar como esses ficheiros são aplicados e registrar `0038` de acordo com a convenção real antes de release.

### Concorrência de publicação

O harness principal usa chamadas concorrentes pelo pool da aplicação e verifica resultados individuais e estado final. A prova com duas sessões/PIDs independentes concentra-se na corrida de linha contra publicação e executa as transições de publicação diretamente em SQL. Ainda não existe uma prova com duas sessões independentes chamando simultaneamente a função TypeScript `publishCostStructure` em processos separados; a invariável do banco foi testada, mas essa instrumentação de camada de serviço fica como melhoria de cobertura.

### Deadlock

Os fluxos de publicação e edição de linhas usam locks de estruturas em ordem determinística e o trigger valida depois de obter os locks. O cenário real testado não produziu deadlock. Uma prova adicional de dois movimentos simultâneos de linhas entre estruturas DRAFT, com timeout controlado, seria recomendável antes de uma declaração operacional definitiva sobre ausência de deadlocks.

## Conclusão

A rodada corrigiu o salto de versões, o rollback pós-reserva e a corrida entre linha e publicação, mantendo as regras de cálculo e as permissões existentes. A entrega não é aprovação para integração ou produção enquanto RLS e o mecanismo operacional de aplicação das migrations permanecerem pendentes.
