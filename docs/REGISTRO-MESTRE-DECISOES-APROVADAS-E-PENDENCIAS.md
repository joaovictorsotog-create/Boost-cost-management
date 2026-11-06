# Registro mestre de decisões — Alianza Sistema de Custos

**Projeto:** Alianza — Sistema de Custos  
**Repositório:** Boost Cost Management  
**Branch de documentação:** `docs/regras-custeio-cadastro-central`  
**Atualizado:** 06/11/2026  
**Finalidade:** separar decisões aprovadas de assuntos pendentes e evitar reabrir definições já fechadas.

## Como interpretar este documento

- **APROVADO:** confirmado explicitamente pelo usuário nas conversas do projeto disponíveis para esta consolidação.
- **JÁ DEFINIDO — RECUPERAR DETALHE:** o usuário informou que a regra já foi decidida em outra conversa, mas o detalhe não está presente no material recuperável nesta sessão. Não redefinir nem inventar.
- **PENDENTE:** ainda exige decisão.
- Este documento registra regras funcionais. Não significa que estejam implementadas.

## 1. Decisões aprovadas nesta sequência

### 1.1 Cadastro Central e custos

1. Itens são cadastrados no Cadastro Central e reutilizados nas estruturas por referência ao mesmo registro.
2. **Tipo Simples:** não possui estrutura de composição; seu custo unitário é informado manualmente e a janela/campo de preço permanece editável.
3. **Tipo Composto:** possui estrutura; seu custo unitário é calculado automaticamente a partir dos componentes e o campo/janela de preço não permite edição manual.
4. O custo unitário calculado de um composto é a soma dos custos totais dos componentes utilizados na quantidade-base da estrutura.
5. Ao incluir um item em uma estrutura, o sistema consulta seu cadastro central. A quantidade informada multiplica o custo unitário cadastrado e gera o custo total do componente.
6. Na estrutura, o custo unitário do componente pode aparecer apenas para informação; ele vem do Cadastro Central e não é editado naquela estrutura. O custo total também deve ser exibido.
7. A unidade de medida é única por item. **Não haverá unidades alternativas nem conversão automática entre unidades.** Devem ser usadas somente as unidades já definidas nas conversas anteriores; não inventar ou ampliar a lista.

### 1.2 Categorias e Configurações

1. Todas as configurações administrativas ficam centralizadas no menu Configurações, acessado pela engrenagem já discutida.
2. Categorias podem ser criadas e editadas nesse menu.
3. Uma categoria só pode ser excluída quando não houver nenhum item vinculado.
4. Para excluir uma categoria vinculada, primeiro é necessário alterar a categoria dos itens relacionados. O sistema deve verificar novamente a inexistência de vínculos antes de permitir a exclusão.

### 1.3 Confirmação global antes de consolidar alterações

1. A regra é **global**, não restrita ao Cadastro Central.
2. Toda operação de criação, alteração ou exclusão deve ser analisada e notificada ao usuário antes de ser consolidada.
3. A notificação deve apresentar o que será feito e os impactos identificáveis. Em seguida, o usuário confirma ou cancela.
4. Nenhuma alteração deve ser efetivada antes da confirmação explícita.
5. Se o usuário cancelar, os dados permanecem como estavam.
6. A regra deve ser garantida também no backend, não apenas pela interface.

### 1.4 Exclusão de itens e impacto em dependências

1. Antes de excluir um item, o sistema identifica quantos produtos o utilizam e apresenta os impactos.
2. A notificação deve alertar que a exclusão pode alterar os custos dos produtos que utilizam aquele item.
3. A operação exige confirmação explícita antes de ser consolidada.
4. O impacto e as dependências devem ser apresentados de forma compreensível, evitando referências quebradas e custos inconsistentes.

### 1.5 Recálculo automático em cascata

1. Após o usuário confirmar uma alteração de custo, o sistema atualiza automaticamente todos os produtos dependentes.
2. Não será necessária aprovação individual de cada produto afetado.
3. O sistema deve recalcular todos os níveis da cadeia de estruturas, até os produtos finais dependentes.
4. A mesma lógica vale para alterações de estruturas: mostrar os impactos antes, solicitar uma única confirmação e, depois dela, recalcular automaticamente toda a cadeia dependente.
5. O usuário não precisa abrir e salvar manualmente cada produto dependente.

### 1.6 Estruturas multinível e prevenção de ciclos

1. Um item composto pode ser utilizado como componente de outro item composto.
2. A composição multinível é permitida.
3. O sistema deve bloquear ciclos de composição, inclusive ciclos indiretos (ex.: A usa B, B usa C, C tenta usar A).
4. A validação deve ocorrer antes da confirmação/consolidação e explicar o ciclo identificado.
5. A proteção deve existir no backend, não apenas na interface.

### 1.7 Atomicidade e consistência

1. Operações que alterem estruturas e provoquem recálculos em cadeia devem ser transacionais.
2. Se qualquer etapa falhar, toda a operação deve ser revertida.
3. Não pode haver atualização parcial de produtos dependentes.
4. Os valores anteriores devem permanecer preservados e o usuário deve receber uma notificação sobre a falha.

### 1.8 Histórico de custos e arquivamento

1. O histórico de custos deve ser preservado; não se deve permitir apagar registros históricos pela interface.
2. Já existe uma regra aprovada de arquivamento periódico para evitar que o histórico operacional fique excessivamente extenso.
3. Arquivar não significa excluir: os registros arquivados devem continuar disponíveis para consulta.
4. **Não redefinir a periodicidade, os critérios ou o mecanismo de arquivamento nesta etapa.** Esses detalhes já foram discutidos em outra conversa e precisam ser recuperados da fonte original antes de serem documentados novamente.

### 1.9 Auditoria global

1. Deve existir rastreabilidade global das operações.
2. Registrar quem realizou a operação e quando, além do módulo, tipo de operação, registro afetado, valores anteriores/novos quando aplicável e resultado.
3. Registrar também operações automáticas, como recálculos, identificando-as como ações do sistema e relacionando-as à operação que as originou.
4. Histórico de custos e auditoria global são registros complementares, com finalidades distintas.

## 2. Decisões anteriores já existentes — não reabrir

### 2.1 Controle de acesso e usuários
**Status: JÁ DEFINIDO — RECUPERAR DETALHE.**

O usuário confirmou que o projeto já definiu um controle padrão de usuários/permissões em outra conversa do projeto. Não propor um novo modelo, não inventar perfis, papéis ou permissões. Recuperar a decisão original e transcrevê-la aqui quando a fonte estiver disponível.

### 2.2 Arquivamento periódico
**Status: JÁ DEFINIDO — RECUPERAR DETALHE.**

O usuário confirmou que a regra de arquivamento periódico já havia sido definida. Não perguntar novamente se deve arquivar e não inventar periodicidade, idade dos registros, retenção ou política de consulta. Recuperar a regra original.

### 2.3 Outras decisões existentes no projeto
Há conversas anteriores sobre unidades de medida, menu Configurações/engrenagem, histórico, estrutura de custos e outros módulos. Quando a decisão original não estiver reproduzida neste documento, tratá-la como informação a recuperar, não como autorização para propor uma alternativa nova.

## 3. Pendências reais identificadas nesta consolidação

Os itens abaixo não foram decididos nesta sequência e não devem ser preenchidos por suposição:

1. Recuperar e documentar a lista exata de unidades de medida já aprovada.
2. Recuperar a definição exata do controle padrão de usuários e permissões.
3. Recuperar a periodicidade e os critérios exatos do arquivamento periódico.
4. Definir detalhes operacionais ainda não cobertos para exclusão de item em uso, garantindo a atualização das estruturas e a integridade das referências.
5. Consolidar as demais decisões dos chats do projeto que ainda não foram transcritas neste registro.

## 4. Procedimento obrigatório para continuidade do projeto

Antes de fazer uma nova pergunta ou propor uma regra:

1. Consultar este registro e os documentos oficiais disponíveis.
2. Verificar as conversas e decisões anteriores acessíveis no projeto.
3. Classificar o assunto como aprovado, já definido a recuperar ou realmente pendente.
4. Não pedir ao usuário que repita uma decisão já aprovada.
5. Não transformar uma sugestão do assistente em decisão aprovada sem confirmação explícita do usuário.
6. Quando uma nova decisão for aprovada, atualizar este documento na branch de documentação e registrar um commit.
7. Não fazer merge na branch principal nem implementar código, alterar banco ou infraestrutura sem autorização específica.

## 5. Limitação de cobertura desta revisão

Esta consolidação foi feita a partir das conversas do projeto que estavam efetivamente disponíveis no contexto desta sessão e do documento funcional encontrado na branch de documentação. Não é correto afirmar que todos os chats históricos do projeto foram varridos integralmente: a interface/conexão disponível não expôs automaticamente o conteúdo completo de todas as conversas.

Por isso, este documento distingue expressamente decisões confirmadas nesta sequência de decisões anteriores cujo detalhe precisa ser recuperado. A auditoria completa dos demais chats ainda é uma tarefa pendente, não algo que deva ser declarado concluído.
