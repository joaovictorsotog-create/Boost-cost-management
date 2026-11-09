# Registro mestre de decisões — Alianza Sistema de Custos

**Projeto:** Alianza — Sistema de Custos  
**Repositório:** Boost Cost Management  
**Branch de documentação:** `docs/regras-custeio-cadastro-central`  
**Atualizado:** 09/11/2026  
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
<badge>APROVADO — DETALHES RECUPERADOS</badge>

1. Login individual por usuário.
2. Autenticação de dois fatores (2FA) integrada.
3. Row Level Security (RLS) aplicada no banco de dados.
4. Três níveis de acesso aprovados: **Administrador, Editor e Visualizador**.
5. A pesquisa global deve respeitar as permissões de cada usuário; não pode contornar acessos restritos.
6. Registrar quem realizou cada alteração.

Não importar para este projeto regras de administração de usuários/cargos discutidas no CRM Alianza. A conversa “Corrigir usuários e permissões” refere-se ao CRM e não é fonte para ampliar os papéis do Sistema de Custos.

### 2.2 Arquivamento de logs de atividades
<badge>APROVADO — DETALHES RECUPERADOS</badge>

1. Os registros do Log de Atividades permanecem no ambiente principal durante o primeiro ano.
2. Após um ano, são transferidos para o Arquivamento.
3. Os registros arquivados permanecem consultáveis.
4. A exclusão definitiva não é automática: o administrador decide explicitamente se e quando excluir.
5. Esse prazo se aplica ao **Log de Atividades**, não autoriza apagar automaticamente histórico de custos, estruturas antigas ou memórias de cálculo.


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

## 5. Cobertura da auditoria do export enviado em 09/11/2026

1. O ZIP enviado contém 36 conversas no total.
2. Foram localizadas e lidas as 17 conversas correspondentes aos links compartilhados pelo usuário (sequência “Pesquisa sobre criação no Manus” e ramificações “Avaliar capacidade da VPS”).
3. Também foram inspecionadas conversas adicionais do export para separar assuntos de outros sistemas. Conversas do CRM, como “Corrigir usuários e permissões” e “Problema no Kanban”, não foram usadas como fonte de requisitos do Sistema de Custos.
4. “Desenvolver Tabela Automatizada” contém requisitos de uma aplicação de planilha/custos, mas o vínculo com o escopo atual ainda precisa ser confirmado; por isso não foi incorporada como decisão do Alianza.
5. A auditoria das 17 conversas vinculadas está registrada em `docs/AUDITORIA-CONVERSAS-PROJETO-2026-11-09.md`.

**Limite importante:** o usuário havia mencionado 27 conversas no projeto, mas o export contém 36 conversas gerais e os 17 links fornecidos identificam 17 conversas da sequência atual. Não se deve declarar que as 27 conversas do projeto foram todas auditadas sem identificar e conferir as 10 conversas restantes. A cobertura atual é completa para as 17 conversas vinculadas e parcial para o universo de 27 conversas mencionado pelo usuário.


## 6. Decisões recuperadas na auditoria de 09/11/2026

As regras abaixo foram recuperadas de confirmações explícitas nas conversas vinculadas. A trilha por conversa está no documento de auditoria.

### 6.1 Unidades, identificação e famílias

1. Unidades aprovadas: **metro, quilograma (kg), metro quadrado (m²) e unidade**.
2. Cada item possui uma única unidade de medida; não criar conversões ou unidades alternativas.
3. O identificador interno é numérico e sua definição/organização será feita manualmente pelo administrador. Ele serve para busca e organização.
4. Cada item pertence a **uma única família específica e obrigatória**, usada como classificação principal e para localização/pesquisa; não admite múltiplas famílias no mesmo item.
5. Famílias/classificações são cadastráveis e editáveis. A família não determina a unidade de medida.
6. O usuário pode localizar itens por ID, descrição ou família.

### 6.2 Precisão e arredondamento de custo

1. Regra de arredondamento de apresentação aprovada por item, individualmente: olhando a casa decimal seguinte, valores de 0 a 5 arredondam para baixo; valores acima de 5 arredondam para cima.
2. Exemplos aprovados: R$ 1,543 → R$ 1,54; R$ 1,546 → R$ 1,55.
3. Não arredondar apenas o total final se a decisão aprovada é arredondar cada item individualmente.
4. A precisão interna de armazenamento/cálculo além dessa regra de apresentação ainda precisa ser especificada tecnicamente.

### 6.3 Custos, matérias-primas e fatores

1. Matéria-prima é cadastrada com custo por sua unidade: chapa por kg e tubo por metro, por exemplo.
2. O custo utilizado na estrutura é quantidade × custo unitário cadastrado.
3. O desperdício já está incorporado nos custos/pesos preparados pelo usuário; não aplicar uma segunda margem automática de desperdício.
4. O sistema apura custo industrial a partir dos valores cadastrados e das estruturas. Não deve acrescentar impostos por conta própria nem formar preço de venda.
5. O fator Gama é uma correção associada a produtos em aço inox, mas **não é obrigatório nem automático**: sua aplicação será manual quando o usuário considerar necessária. O valor 1,20 aparece como referência na planilha analisada, não como regra fixa global.
6. Usinagem externa pode ser cadastrada como item/serviço com custo unitário.
7. Pintura é um item/serviço com custo próprio e pode ser ativada ou não no produto/subconjunto. Quando ativada, seu valor compõe o custo e propaga para os itens-pai.
8. A classificação “corte a laser” não gera, por si só, um adicional automático. O custo do material utilizado já é calculado a partir do peso/custo da matéria-prima conforme os dados fornecidos.
9. Não incluir Alpha/Beta ou outros multiplicadores de preço comercial no motor de custo sem decisão específica; o escopo aprovado exclui formação de preço de venda.

### 6.4 Estruturas, famílias e prevenção de dupla contagem

1. Um item composto pode ser usado dentro de outro composto, em vários níveis.
2. Um mesmo componente pode aparecer diretamente no produto e também dentro de um subconjunto; isso não deve gerar bloqueio por duplicidade. Cada ocorrência é contabilizada conforme sua quantidade na respectiva posição da árvore.
3. Quando um subconjunto composto entra na estrutura de um produto-pai, o resumo por família do produto-pai considera a família principal do subconjunto e seu custo total; não deve reabrir e somar novamente as famílias internas do subconjunto.
4. A estrutura deve exibir quantidade, unidade, custo unitário informativo e custo total por linha.
5. O resumo de custo por família mostra quantidades e custos acumulados das famílias diretas consideradas na estrutura, sem dupla contagem dos componentes internos já incorporados em subconjuntos.
6. Duplicar produto cria uma cópia independente, permitindo adaptar descrição e estrutura para variantes (ex.: aço carbono e inox).

### 6.5 Itens inativos e valores zerados

1. Item inativo fica em uma aba própria de inativos.
2. Item inativo não aparece na árvore de composição nem participa do custeamento.
3. Inativar/remover componente reduz o custo calculado; substituir componente recalcula o custo correspondente.
4. Itens podem ser salvos com R$ 0,00, mas zero não é tratado como primeiro valor/base de histórico. O sistema deve sinalizar/notificar a situação para revisão.
5. Itens inativos ficam ocultos por padrão na pesquisa global, com filtro específico para localizá-los.

### 6.6 Atualização, histórico e alertas

1. Revisão de custos de materiais idealmente semestral.
2. Se não houver revisão nem alteração no ciclo de seis meses, o sistema deve emitir lembrete.
3. Quando o usuário altera o custo e salva o cadastro, o ciclo de seis meses reinicia. A alteração só é reconhecida após salvar.
4. Não calcular média entre custo antigo e novo: o sistema utiliza o custo vigente real informado.
5. O primeiro custo válido (maior que zero) é a base de comparação da evolução; registros seguintes mostram aumentos e quedas.
6. A evolução pode ser visualizada em gráfico e em valores monetários ou percentuais, com alternância entre R$ e %.
7. Limites de variação/alerta podem ser configurados no ambiente do produto.
8. Histórico de custos permanece intacto quando a estrutura vigente é alterada; apenas a composição atual e seus custos derivados são recalculados.
9. Relatórios são solicitados manualmente; pode haver geração de PDF sob demanda.

### 6.7 Importação e atualização em lote

1. A atualização em lote usa planilha Excel padronizada disponibilizada para download.
2. O usuário preenche/edita a planilha e envia novamente.
3. O sistema apresenta prévia somente das linhas/dados alterados.
4. Erros são destacados por linha/campo. Linhas válidas podem ser aprovadas mesmo que outras apresentem erros.
5. A mesma proteção de prévia e aprovação vale para importação e atualização em lote.
6. Nenhuma linha é consolidada antes da aprovação do usuário.

### 6.8 Interface, navegação e notificações

1. Painel Geral é a tela inicial.
2. Sidebar pode ser recolhida, mantendo ícones, e o usuário pode escolher se permanece fixa.
3. Sino de notificações exibe contador e abre painel flutuante; o usuário pode expandir uma notificação para ver detalhes.
4. Cadastro do item apresenta ID, descrição, família, unidade e custo; a busca/listagem permite filtrar Simples e Composto.
5. A estrutura permite pesquisa por ID, descrição ou família e seleção de grupos da família desejada.
6. A pesquisa global apresenta ID, descrição, família, tipo e custo vigente; selecionar um resultado abre seu cadastro.
7. A pesquisa global respeita permissões e preserva o contexto de navegação anterior ao retornar.
8. Atalhos aprovados: Esc fecha modal; Enter confirma pesquisa; Ctrl+K abre pesquisa global; Alt+← retorna à tela anterior.
9. Alterações não salvas geram aviso antes de sair. Se o usuário confirmar a saída, as alterações são descartadas e não geram gravação nem histórico.
10. Responsividade: desktop com experiência completa; notebook/tablet adaptados; celular prioriza consultas, notificações, histórico e relatórios. Edição complexa de estruturas tem prioridade no desktop.
11. Desempenho: tabelas extensas carregam progressivamente; gráficos, históricos e relatórios sob demanda; recálculos não devem bloquear a navegação.

### 6.9 Segurança, continuidade e saúde do sistema

1. Login individual, 2FA integrado e RLS no banco de dados.
2. Níveis de acesso: Administrador, Editor e Visualizador.
3. Backup automático periódico aprovado.
4. Operações interrompidas não podem ser apresentadas como concluídas; o sistema deve evitar duplicidade em tentativas repetidas e preservar integridade.
5. Painel discreto de Informações do Sistema deve mostrar status real do banco, autenticação, serviços internos e horário da última verificação.
6. A frequência de backup e os procedimentos/cadência de teste de restauração não foram especificados nas mensagens auditadas; não inventar.



### 6.10 Diretrizes técnicas já informadas

1. O Sistema de Custos será uma aplicação separada do CRM.
2. O banco definido para o projeto é Supabase separado do banco/ambiente do CRM.
3. Estimativa inicial informada: 1 a 10 usuários simultâneos.
4. Domínio planejado informado: `sistema.trique-brasil.io`.
5. VPS existente informada para dimensionamento: Hostinger KVM2, 2 vCPU, 8 GB de RAM e 100 GB de disco. Isso não significa que o sistema esteja implantado nessa VPS.
6. O usuário exigiu diretrizes rigorosas para execução no Manus: frontend não confiável, validações críticas no backend, proteção de segredos e arquivos `.env`, sem exposição de chaves, tokens, senhas ou credenciais.
7. A stack específica do Sistema de Custos **não foi aprovada** nas conversas auditadas. Não copiar automaticamente a stack do CRM.
8. A Ordem Mestra e a especificação técnica de segurança são fontes de precedência e devem ser consultadas antes de qualquer implementação.



## 7. Complemento de cobertura e decisões — export conferido em 09/11/2026

- O identificador `conversation_template_id = g-p-6ae9c560f4908191aa722657220d9362` confirma **19 conversas** do ZIP como pertencentes a este projeto. Duas conversas antes não incluídas nos 17 links foram revisadas: “Desenvolver Tabela Automatizada” (`6ae9c59e-b148-83e9-9e66-83bd911c5aca`) e “Pesquisa sobre criação no Manus (1)” (`6aea176d-65cc-83e9-ab2d-a8d456162f14`).
- O ZIP tem 36 conversas no total; 17 não pertencem ao identificador deste projeto. Das 27 conversas mencionadas pelo usuário, 19 aparecem no ZIP e **8 ainda precisam ser localizadas**. Auditoria integral das 27 ainda não concluída.
- “Desenvolver Tabela Automatizada” pertence ao mesmo projeto Alianza, mas o usuário esclareceu que é uma aplicação separada do CRM. O nome escolhido para a aplicação é **Alianza — Sistema de Custos**.
- O usuário definiu a finalidade principal como cálculo do custo industrial por produto a partir dos custos de materiais/componentes alimentados pelo usuário; não acrescentar impostos nem formar preço de venda automaticamente. O usuário também declarou não desejar integração com a aplicação CRM.
- A aba `CUSTOS VARIÁVEIS` deve ser entendida como biblioteca central organizada em categorias configuráveis de componentes/recursos, cujos itens são selecionados na árvore do produto (matéria-prima, pintura, eletrônica e outros).
- Placa/Fonte foi aprovada como item de montagem na posição H18 da ficha referida (e I18 para a variante INOX, a conferir na planilha), contabilizada uma única vez.
- Atualização automática global foi escolhida: alteração salva de custo central recalcula produtos e subconjuntos dependentes. O ajuste manual deve ocorrer no custo vigente de itens cadastrados; não permite sobrescrever manualmente custo calculado de item composto.
- **Conflito a preservar:** uma conversa menciona canais comerciais configuráveis por produto, mas também delimita o aplicativo como cálculo de custo industrial, sem formação de preço de venda. Não incluir canais/margens/markup sem nova confirmação explícita.
- Detalhamento por conversa e contexto está em `docs/AUDITORIA-CONVERSAS-PROJETO-2026-11-09.md`.


## 8. Método de continuidade adotado em 09/11/2026

Por decisão do usuário, o projeto **não ficará bloqueado pela recuperação das oito conversas ainda ausentes do ZIP**. A partir desta data, o trabalho seguirá de forma incremental com base no material consolidado no GitHub.

- O GitHub passa a ser a fonte central de continuidade documental.
- Cada módulo será analisado com as regras já aprovadas; lacunas serão perguntadas quando se tornarem relevantes.
- Novas decisões serão registradas com origem, contexto, impacto e commit.
- Conversas ausentes poderão ser incorporadas posteriormente, sem exigir auditoria integral antes de avançar.
- Hipóteses técnicas não são aprovações funcionais.
- Conflitos serão isolados e resolvidos sem apagar silenciosamente decisões anteriores.
- Não há autorização implícita para implementação, merge, deploy, migration ou mudança de infraestrutura.

O procedimento completo está em `docs/PROTOCOLO-DE-CONTINUIDADE-E-DECISOES-INCREMENTAIS.md`.

**Correção de status:** unidades (metro, kg, m² e unidade), controle de acesso (login individual, 2FA, RLS e Administrador/Editor/Visualizador), regra de arquivamento do Log de Atividades (um ano no ambiente principal e depois arquivo, sem exclusão automática) e demais decisões descritas nas seções 6.x deste documento já foram recuperadas. Menções anteriores nas seções 3 e 5 que as tratavam como pendências devem ser lidas como registros históricos superados por esta consolidação posterior.


## 9. Decisão incremental — família obrigatória por item (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- Cada item deve ter uma família específica e única.
- A família é obrigatória e integra a classificação principal do item; não é apenas uma etiqueta opcional.
- A classificação por família é necessária para localizar/pesquisar os itens de forma organizada.
- Mantêm-se as regras anteriores: famílias são configuráveis, não determinam unidade de medida e só podem ser excluídas quando não houver itens vinculados.

## 10. Decisão incremental — ID numérico único e obrigatório (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- Todo item terá ID numérico obrigatório e exclusivo.
- O administrador organiza e define a numeração manualmente.
- O sistema deve impedir a gravação de IDs duplicados.
- O ID será utilizado como critério de pesquisa.
- Alterações de ID seguem a confirmação global e o registro de auditoria.


## 11. Decisão incremental — descrição não exclusiva (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- Descrições iguais são permitidas para itens diferentes.
- Cada item continua identificado por seu ID numérico obrigatório e exclusivo.
- A descrição é utilizada para identificação e pesquisa, mas não funciona como chave única.
- Resultados de pesquisa com descrições iguais devem ser distinguíveis pelo ID e pela família, além dos demais dados pertinentes.

## 12. Decisão incremental — descrição complementar opcional (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- Incluir no Cadastro Central o campo opcional **Descrição complementar**.
- Utilizá-lo para registrar características técnicas e diferenciar itens com descrições principais iguais ou semelhantes.
- Permitir pesquisa e filtros por esse campo.
- Não substituir nem alterar a descrição principal; o preenchimento não é obrigatório.
- O campo é informativo e não interfere em família, unidade, estrutura, origem do custo ou cálculo.

## 13. Decisão incremental — listagem unificada do Cadastro Central (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- Exibir itens Simples e Compostos juntos em uma única listagem.
- Usar filtros para distinguir tipo e situação, em vez de abas fixas separadas.
- Manter inativos ocultos por padrão e acessíveis por filtro específico, conforme decisão anterior.
- Priorizar uma listagem objetiva para localização rápida; informações completas serão vistas no cadastro do item.

## 14. Decisão incremental — colunas da listagem do Cadastro Central (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- Colunas: ID, descrição principal, família, unidade, tipo, custo unitário vigente e situação.
- A descrição complementar não aparece como coluna na listagem principal.
- A descrição complementar permanece visível no cadastro e pesquisável.
- A escolha busca manter a listagem objetiva sem perder a capacidade de localizar itens por detalhes técnicos.

## 15. Decisão incremental — organização da tela de cadastro (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

O formulário será uma única tela com quatro blocos verticais: Identificação; Características; Custeio; Controle. Não haverá abas separadas para esses blocos. A decisão é de apresentação e não modifica as regras funcionais já aprovadas.


## 16. Decisão incremental — sugestão sequencial de ID com escolha manual (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- O sistema sugere o menor número inteiro positivo ainda não utilizado.
- O administrador pode aceitar a sugestão ou informar qualquer outro ID numérico disponível; a sugestão não é obrigatória.
- A unicidade é validada antes de salvar, impedindo IDs duplicados.
- A cada cadastro, a sugestão é recalculada considerando todos os IDs já utilizados. Exemplo: com o ID 10 ocupado e os IDs 5 a 9 livres, o sistema sugere 5; depois que 5 a 9 forem ocupados, sugere 11.
- IDs de itens inativados continuam reservados e não podem ser reutilizados.
- Essa regra complementa a decisão anterior de ID numérico obrigatório e exclusivo, sem alterar a autonomia do administrador para escolher outro número livre.


## 17. Decisão incremental — descrição principal obrigatória e sem padrão rígido (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- A descrição principal é obrigatória.
- Aceita letras, números e caracteres especiais, sem padrão rígido de nomenclatura.
- Descrições iguais são permitidas para itens diferentes.
- O ID numérico exclusivo permanece como identificador único do cadastro.

## 18. Decisão incremental — seleção controlada de família (09/11/2026)

**Status: APROVADO pelo usuário.**

- No cadastro do item, Família será selecionada em uma lista alimentada pelas famílias cadastradas em Configurações.
- Não haverá digitação livre nem criação de família diretamente no formulário do item.
- Cadastro e edição de famílias ocorrerão em Configurações, sob permissão administrativa.
- A família permanece obrigatória e única por item.
- A seleção referencia uma família já cadastrada, evitando duplicidade e inconsistência de nomenclatura.
- Famílias vinculadas a itens não poderão ser excluídas até que os itens sejam reclassificados.


## 19. Decisão incremental — contagem automática de itens vinculados à família (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- A quantidade de itens vinculados a cada família será calculada automaticamente a partir dos vínculos existentes no Cadastro Central.
- A contagem aumenta ou diminui conforme os itens são associados ou reclassificados entre famílias.
- O número é informativo e somente leitura; não haverá preenchimento ou ajuste manual.
- A contagem deve representar os vínculos efetivos e permanecer consistente com o Cadastro Central.


## 20. Decisão incremental — nome obrigatório e único da família (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- O nome da família é obrigatório.
- Não podem existir famílias duplicadas no cadastro.
- A validação deve impedir variações de escrita que representem a mesma classificação, inclusive os exemplos “Chapas”, “CHAPAS” e “Chapa”.
- A unicidade deve ser validada antes de salvar e também garantida no backend.
- A regra técnica exata de normalização/comparação ainda deverá ser especificada; isso não altera o resultado funcional aprovado de impedir duplicidades por grafia.


## 21. Decisão incremental — inativação de famílias sem itens vinculados (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- Famílias sem itens vinculados poderão ser inativadas, em vez de excluídas definitivamente.
- Não será permitida a inativação enquanto houver itens vinculados; os itens deverão ser reclassificados primeiro.
- Famílias inativas não serão oferecidas na seleção de família do Cadastro Central.
- O registro da família será preservado. A reativação foi aprovada e está detalhada na decisão incremental 22.


## 22. Decisão incremental — reativação de famílias inativas (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- O administrador poderá reativar uma família que tenha sido inativada anteriormente.
- A família reativada volta a aparecer como opção no campo Família do Cadastro Central.
- A operação recupera o registro existente; não cria uma nova família nem altera sua identidade ou histórico.
- A unicidade do nome também será validada na reativação. Havendo conflito com outra família, a operação fica bloqueada até a resolução do conflito.
- Reativar uma família não vincula itens automaticamente; a classificação dos itens continua sendo explícita.

## 23. Área isolada de famílias arquivadas em Configurações (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- O gerenciamento de famílias ficará em **Configurações**.
- Famílias ativas permanecem na área normal de gerenciamento.
- Famílias inativas aparecem em uma área isolada, identificada por um ícone e pelo texto **Arquivados**.
- A área **Arquivados** lista somente famílias inativas e permite ao administrador consultar e reativar os registros.
- Famílias arquivadas não aparecem na seleção do Cadastro Central.
- Ao reativar, a família retorna à listagem normal de famílias ativas, preservando o registro e respeitando a unicidade do nome.
- A decisão especifica a organização funcional da interface; não representa autorização para implementar ou alterar banco/infraestrutura.

## 24. Data de inativação na área Arquivados (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- A listagem **Configurações → Famílias → Arquivados** também exibirá a data em que cada família foi inativada.
- Deve ser mostrada a data da inativação mais recente. Caso a família seja reativada e inativada novamente, a data será atualizada.
- A informação é destinada à consulta e rastreabilidade e não altera as demais regras funcionais de famílias.

## 25. Listagem de famílias ativas — colunas e ações (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

A listagem normal em **Configurações → Famílias** exibirá:

- Nome da família;
- Quantidade de itens vinculados, calculada automaticamente e somente para consulta;
- Data de criação;
- Última atualização;
- Situação.

A listagem disponibilizará as ações **Editar** e **Inativar**, respeitando a regra aprovada de que uma família com itens vinculados não pode ser inativada. Famílias inativas permanecem na área separada **Arquivados**, com data da inativação mais recente e opção de reativação pelo administrador.

## 26. Edição de família — alteração do nome sem romper vínculos (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- A ação **Editar** permite alterar o nome da família existente.
- A operação atualiza o registro original, sem criar outra família ou trocar sua identidade.
- Os itens vinculados permanecem associados à mesma família; a contagem de vínculos não muda pela edição do nome.
- O novo nome é obrigatório e deve passar pela validação de unicidade já aprovada, inclusive para variações de grafia equivalentes. Conflitos impedem a gravação até serem resolvidos.
- A edição obedece à prévia, confirmação explícita e registro de auditoria previstos nas regras gerais.

## 27. Confirmação antes de inativar família (09/11/2026)

**Status: APROVADO pelo usuário nesta conversa.**

- Ao selecionar **Inativar**, apresentar confirmação com o nome da família e a quantidade atual de itens vinculados.
- Se houver qualquer vínculo, bloquear a inativação e informar que os itens precisam ser reclassificados antes de nova tentativa.
- Se a família estiver sem vínculos, permitir ao administrador confirmar ou cancelar.
- Não alterar o registro antes da confirmação explícita. Após confirmação, registrar a operação na auditoria e mover a família para a área **Arquivados**, sem excluir o registro.

## 28. Confirmação antes de reativar família (09/11/2026)

**Status: APROVADO pelo usuário.**

- Ao solicitar a reativação de uma família arquivada, apresentar confirmação com o nome da família e a data da última inativação.
- Informar que a família voltará a aparecer na seleção do Cadastro Central.
- Esclarecer que a reativação não cria nem restaura vínculos automaticamente.
- Permitir confirmar ou cancelar; não alterar nada antes da confirmação explícita.
- Preservar a identidade e o histórico do registro original e aplicar a validação de unicidade do nome já aprovada.

## 29. Conflito de nome ao reativar família (09/11/2026)

**Status: APROVADO pelo usuário.**

- Validar a unicidade do nome antes de reativar, considerando também diferenças de capitalização e grafias equivalentes conforme a regra aprovada.
- Se outra família ativa já utilizar nome conflitante, bloquear a reativação e informar o nome em conflito e, quando possível, qual família ativa o utiliza.
- O administrador deverá resolver o conflito e tentar novamente. Nenhuma renomeação automática, sobrescrita ou criação de vínculo será permitida.
- Após a resolução, exigir nova validação bem-sucedida e confirmação explícita para reativar.

## 30. Permissões de manutenção de famílias (09/11/2026)

**Status: APROVADO pelo usuário.**

- Apenas o papel **Administrador** pode criar, editar, inativar ou reativar famílias.
- Os papéis **Editor** e **Visualizador** podem consultar, sem permissão para essas operações.
- A autorização deve ser imposta no backend, e não somente pela interface. Tentativas não autorizadas não podem alterar dados.


## 31. Pesquisa de famílias por nome (09/11/2026)

**Status: APROVADO pelo usuário.**

- A listagem normal de famílias em Configurações permite pesquisar pelo nome.
- A busca aceita correspondência parcial e não diferencia maiúsculas de minúsculas.
- A listagem normal pesquisa somente famílias ativas.
- Famílias inativas são consultadas na área isolada **Arquivados**, não nos resultados da listagem normal.
- A pesquisa não altera registros, vínculos, permissões ou a regra de unicidade dos nomes.


## 32. Ordenação das listagens de famílias (09/11/2026)

**Status: APROVADO pelo usuário.**

- Famílias ativas na listagem normal: ordem alfabética crescente (A–Z), pelo nome.
- Famílias inativas em **Arquivados**: data de inativação mais recente primeiro (ordem decrescente).
- A ordenação é somente de apresentação; não altera registros, IDs, vínculos ou histórico.
- A pesquisa permanece restrita à listagem correspondente: ativas na área normal e inativas em Arquivados.


## 33. Atualização em tempo real em todo o projeto (09/11/2026)

**Status: APROVADO pelo usuário.**

- Atualizações em tempo real são uma regra global do Alianza — Sistema de Custos, aplicável a todos os módulos e não apenas às telas de famílias.
- Após uma alteração ser persistida com sucesso, telas, listagens, consultas e sessões de usuários que dependam dos dados afetados devem refletir automaticamente o novo estado, sem atualização manual da página.
- A sincronização respeita permissões e filtros de cada usuário e não concede acesso adicional.
- O backend/dado persistido é a fonte de verdade; a interface não pode indicar sucesso antes da confirmação da operação.
- Operações relacionadas e recálculos em cascata devem manter consistência transacional, sem expor estados parciais como definitivos.
- Edições concorrentes devem ser tratadas sem sobrescrita silenciosa de alterações de outro usuário.
- A decisão aprova o comportamento funcional em tempo real. Tecnologia, reconexão e metas mensuráveis de latência permanecem como definições técnicas pendentes.


## 34. Atualização em tempo real de filtros, pesquisas e ordenações (09/11/2026)

**Status: APROVADO pelo usuário.**

- Filtros, pesquisas e ordenações devem refletir automaticamente alterações confirmadas nos dados que afetam seus resultados, em todos os módulos.
- As telas abertas devem recalcular os resultados quando atributos relevantes mudarem, preservando os critérios escolhidos pelo usuário.
- Registros que deixarem de atender aos critérios ativos saem dos resultados; registros que passarem a atendê-los entram conforme a ordenação vigente.
- Permissões, escopo e regras de visibilidade continuam prevalecendo; a sincronização não pode expor registros indevidos.
- Esta decisão complementa a regra global de atualização em tempo real e não escolhe tecnologia nem meta numérica de latência.


## 35. Alteração da família de um item já cadastrado (09/11/2026)

**Status: APROVADO pelo usuário.**

- Ao alterar a família de um item existente, a nova classificação deve aparecer imediatamente no Cadastro Central e nas demais telas, pesquisas, consultas e filtros afetados.
- A mudança é exclusivamente classificatória: não altera custo unitário, unidade de medida, tipo ou estrutura de composição.
- O histórico do item deve preservar a família anterior e a nova, o responsável e a data/hora da alteração.
- Aplicam-se permissões, validações, prévia, confirmação explícita e auditoria já aprovadas.


## 36. Exclusão definitiva de famílias (09/11/2026)

**Status: APROVADO pelo usuário.**

- Família que já tenha sido utilizada em vínculos ou registros históricos não pode ser excluída definitivamente, mesmo sem itens vinculados atualmente.
- Famílias utilizadas devem ser preservadas para integridade referencial e rastreabilidade; quando aplicável, usar inativação e arquivamento.
- Exclusão definitiva só pode ser permitida se a família nunca tiver sido utilizada e não possuir vínculos atuais ou históricos.
- A exclusão permitida exige prévia, confirmação explícita do Administrador e registro de auditoria.
- A verificação considera histórico de uso, não apenas a contagem atual de itens; a implementação técnica dessa verificação permanece para a especificação de dados.


## 37. Prévia de impacto ao editar o nome de uma família (09/11/2026)

**Status: APROVADO pelo usuário.**

- Antes da confirmação, apresentar nome atual, novo nome proposto e quantidade de itens vinculados.
- Destacar que o novo nome será refletido em todos os itens vinculados e nas telas, pesquisas, filtros e consultas correspondentes.
- Informar que a alteração é nominal/classificatória e não muda custos, unidades ou estruturas de composição dos itens.
- O Administrador pode confirmar ou cancelar; nada é alterado antes da confirmação explícita.
- Após persistência bem-sucedida, propagar em tempo real, preservar o histórico e registrar a auditoria.


## 38. Relação detalhada de itens afetados na prévia de alteração de família (09/11/2026)

**Status: APROVADO pelo usuário.**

- A prévia deve permitir consultar todos os itens atualmente vinculados à família que será renomeada.
- Identificar cada item, no mínimo, por código/ID e descrição principal, e informar o total de itens afetados.
- A relação serve para avaliar o impacto antes de confirmar ou cancelar; não permite editar, remover ou reclassificar itens dentro da prévia.
- Respeitar permissões e visibilidade. Relações extensas devem ser consultáveis por paginação ou recurso equivalente, sem omitir itens do total.
- Se os vínculos mudarem enquanto a prévia estiver aberta, atualizar a relação ou exigir nova validação antes da confirmação, para evitar decisão baseada em impacto desatualizado.


## 39. Prévia de impacto para operações em massa (09/11/2026)

**Status: APROVADO pelo usuário.**

- Toda operação em massa que possa alterar múltiplos registros exige prévia antes da confirmação.
- A prévia informa o total e permite consultar a relação dos registros por código/ID e descrição ou identificadores próprios do módulo.
- Deve explicar a ação e os impactos esperados, incluindo efeitos em dados, situações, vínculos e módulos dependentes quando aplicável.
- Usuário autorizado pode confirmar ou cancelar; nenhuma alteração ocorre antes da confirmação explícita.
- Relações extensas devem ser consultáveis por paginação ou equivalente, sem divergência entre total e registros.
- Respeitar permissões e visibilidade; se o conjunto afetado mudar com a prévia aberta, atualizar ou exigir nova validação.
- Executar com validação no backend e auditoria. Falhas parciais não podem ser exibidas como sucesso integral; atomicidade ou retomada será especificada por operação.
- Exemplos abrangidos: importações, alterações em lote e inativações em massa.

## 40. Exclusão de itens com prévia de impacto e tratamento automático dos vínculos (09/11/2026)

**Status: APROVADO pelo usuário.**

- Todo item poderá ser excluído, mesmo que possua vínculos atuais em estruturas de composição ou em outros registros/módulos. A existência de vínculos não bloqueia, por si só, a exclusão.
- Antes da confirmação, verificar dependências e apresentar aviso/prévia com quantidade e relação consultável dos registros afetados, identificados por código/ID e descrição ou identificadores próprios do módulo.
- Explicar os impactos, incluindo estruturas afetadas e recálculo dos custos dos produtos compostos dependentes.
- Após confirmação explícita de usuário autorizado, remover automaticamente as referências atuais ao item nas estruturas e registros dependentes e recalcular todos os compostos afetados, direta e indiretamente, até os produtos finais.
- Executar com validação no backend, consistência transacional e auditoria completa. Não deixar vínculos quebrados nem apresentar falha parcial como sucesso integral.
- Se as dependências mudarem enquanto a prévia estiver aberta, atualizar a prévia ou exigir nova validação e confirmação.
- O item excluído não poderá ser selecionado em novas estruturas. O registro de auditoria da exclusão deve permanecer.
- A exclusão não poderá apagar nem reescrever o passado: preservar fotografia histórica imutável das composições e dos custos vigentes antes da exclusão, para permitir consultar como cada produto era composto e custeado naquele momento, mesmo após a remoção do item do Cadastro Central.
- A fotografia deve manter dados suficientes para rastrear a composição e os valores usados no cálculo, sem depender da existência do cadastro ativo do item excluído.
- A modalidade técnica de exclusão e os detalhes de modelagem, retenção e consulta das fotografias históricas permanecem pendentes de especificação antes da implementação.
