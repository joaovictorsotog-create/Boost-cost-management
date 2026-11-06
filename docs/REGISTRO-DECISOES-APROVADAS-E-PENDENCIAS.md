# Registro de decisões — aprovadas, pendentes e a recuperar

**Projeto:** Alianza — Sistema de Custos  
**Data de consolidação:** 06/11/2026  
**Status:** consolidação parcial baseada no contexto compartilhado disponível nesta conversa e nos documentos acessíveis do repositório.

> **Limite de auditoria:** este registro não afirma que todas as conversas antigas do projeto foram pesquisadas. Não tenho acesso a uma busca integral e enumerável de todos os chats do projeto. As decisões abaixo foram extraídas do contexto disponível nesta conversa e confrontadas com o documento funcional já existente na branch. Itens que o usuário informou já terem sido definidos em outros chats, mas cujos detalhes não estão visíveis, ficam marcados como “recuperar definição anterior”, sem inventar conteúdo.

## 1. Decisões aprovadas nesta sequência de conversa

### 1.1 Tipos de item e custo
- **Tipo Simples:** custo unitário informado manualmente; janela/campo de preço editável.
- **Tipo Composto:** custo unitário calculado automaticamente a partir da estrutura; janela/campo de preço não editável manualmente.
- O custo calculado do composto é a soma dos custos totais dos componentes consumidos na estrutura.
- O custo unitário de cada componente pode ser exibido para informação, mas é obtido do cadastro central e não editado dentro da estrutura.
- O custo total de cada componente é calculado pela quantidade utilizada multiplicada pelo custo unitário cadastrado.
- O Cadastro Central é a fonte única dos registros e custos dos itens reutilizados nas estruturas.

### 1.2 Unidades de medida
- Não haverá unidades alternativas por item.
- Não haverá conversão automática entre unidades alternativas.
- Devem ser usadas somente as unidades de medida já discutidas e aprovadas anteriormente no projeto.
- **Pendente de recuperação documental:** a lista exata das unidades já aprovadas não está presente no contexto acessível. Não criar nem presumir uma lista nova.

### 1.3 Categorias e Configurações
- O usuário poderá criar categorias novas.
- A criação e a edição de categorias ficarão no menu **Configurações** (ícone de engrenagem), pois configurações administrativas devem ser centralizadas nesse menu.
- Categorias existentes poderão ser editadas.
- Uma categoria só poderá ser excluída quando não houver nenhum item vinculado.
- Para excluir uma categoria em uso, primeiro será necessário alterar a categoria dos itens vinculados; depois o sistema verificará novamente a ausência de vínculos e permitirá excluir.

### 1.4 Confirmação prévia global
- A regra é **global**, aplicável a todos os módulos, não apenas ao Cadastro Central.
- Toda operação de criação, alteração ou exclusão deve ser analisada e apresentada ao usuário antes de ser consolidada.
- A notificação deve explicar o que será feito e os impactos identificáveis.
- A operação só será efetivada após confirmação explícita do usuário.
- Se o usuário cancelar, os dados devem permanecer como estavam.
- A proteção deve existir no backend e na camada de persistência, não somente na interface.

### 1.5 Impacto de exclusão de item
- Antes da exclusão de um item utilizado em estruturas, o sistema deve informar quantos produtos utilizam aquele item.
- Deve apresentar os produtos afetados e alertar que a exclusão provocará alterações nos custos desses produtos.
- Deve solicitar confirmação antes de executar.
- **Ponto a detalhar:** a conversa aprovou a notificação de impacto e confirmação, mas não fechou todos os detalhes do tratamento das referências após a exclusão. Não implementar remoção silenciosa de componentes nem deixar referências quebradas.

### 1.6 Recálculo automático em cascata
- Quando o usuário alterar o custo de um item e confirmar, o sistema atualizará automaticamente todos os produtos dependentes.
- Não será necessária confirmação individual para cada produto afetado; uma única confirmação da operação original autoriza os recálculos decorrentes.
- O recálculo deve propagar-se por todos os níveis de estruturas compostas, até os produtos finais dependentes.
- O mesmo princípio se aplica à alteração de uma estrutura: apresentar previamente os impactos e, após uma única confirmação, recalcular toda a cadeia dependente.

### 1.7 Estruturas multinível e ciclos
- Estruturas multinível são permitidas: um item composto pode utilizar outro item composto.
- O sistema deve bloquear composições circulares, diretas ou indiretas.
- Exemplo proibido: A utiliza B, B utiliza C e C tenta utilizar A.
- A validação deve ocorrer antes da consolidação e também no backend.

### 1.8 Atomicidade e falhas
- Operações que atualizem estruturas e custos dependentes devem ser transacionais.
- Se qualquer etapa do recálculo falhar, toda a operação deve ser revertida.
- Nenhum produto pode permanecer parcialmente atualizado.
- Os dados anteriores devem ser preservados e o usuário deve receber uma notificação do problema.

### 1.9 Auditoria global
- Adotar registro de auditoria global para operações do sistema.
- Registrar, quando aplicável: usuário responsável, data/hora, módulo de origem, tipo de operação, registro afetado, valores anteriores e novos, resultado e impactos/recálculos decorrentes.
- Operações automáticas devem ser identificadas como realizadas pelo sistema e vinculadas à operação que as originou.
- Auditoria global e histórico de custos são registros complementares, com finalidades distintas.

## 2. Definições anteriores que o usuário confirmou que já existem — recuperar sem redefinir

Os pontos abaixo foram explicitamente apontados pelo usuário como decisões já tomadas em outros chats do projeto. Os detalhes exatos não estão disponíveis no contexto atual e devem ser recuperados dos chats/documentos originais antes de qualquer especificação adicional.

1. **Controle padrão de usuários e permissões:** já foi conversado; não criar novos perfis ou regras por suposição. Recuperar a definição exata.
2. **Arquivamento periódico de históricos:** já existe uma regra de tempo em tempo para arquivar registros e evitar históricos operacionais excessivamente extensos. Recuperar periodicidade, critérios, retenção e acesso ao arquivo; não inventar esses parâmetros.
3. **Unidades de medida permitidas:** já foram discutidas. Recuperar a lista exata; não propor unidades alternativas nem conversões.
4. **Demais decisões globais e funcionais antigas:** precisam ser confrontadas com a Ordem Mestra, especificação funcional original e conversas anteriores antes de marcar o inventário como completo.

## 3. Pendências e pontos que ainda exigem especificação

- Lista exata das unidades de medida previamente aprovadas.
- Detalhes completos do controle padrão de usuários e permissões já discutido.
- Periodicidade e regras do arquivamento periódico já definido.
- Comportamento técnico após exclusão de item ainda referenciado em estruturas, incluindo como manter integridade e rastreabilidade.
- Conteúdo e campos completos da notificação prévia de cada tipo de operação.
- Escopo, retenção, consulta e proteção contra alteração dos registros de auditoria.
- Detalhes técnicos de transações, concorrência e recuperação de falhas.
- Regras de versionamento e consulta de custos históricos, sem contrariar a política de arquivamento já existente.

## 4. Regras de trabalho para evitar perda de decisões

- Antes de perguntar sobre uma regra, consultar primeiro os documentos e o contexto de decisões já disponíveis.
- Não reapresentar como pergunta uma decisão que já esteja aprovada.
- Distinguir claramente: **aprovado**, **pendente**, **a recuperar de conversa anterior** e **proposta ainda não aprovada**.
- Não transformar sugestões do assistente em decisões sem confirmação explícita do usuário.
- Atualizar este registro e os documentos funcionais pertinentes após novas aprovações.
- Não realizar implementação, alteração de banco, infraestrutura ou deploy apenas porque uma regra funcional foi aprovada; isso exige etapa e autorização próprias.

## 5. Limite e prioridade documental

Este arquivo é um índice de decisões e pendências, não substitui a Ordem Mestra nem a especificação funcional original. Se houver conflito, registrar a divergência e solicitar resolução; não sobrescrever silenciosamente a fonte oficial.

**Status geral:** consolidação parcial. Não declarar auditoria integral das conversas do projeto concluída até que os chats/documentos originais tenham sido efetivamente disponibilizados e conferidos.
