# Regras funcionais — Cadastro Central e formação do custo

**Projeto:** Alianza — Sistema de Custos  
**Repositório:** Boost Cost Management  
**Status:** decisões funcionais consolidadas em 09/11/2026  
**Escopo deste documento:** registrar regras confirmadas em conversa. Não representa implementação, decisão de stack ou autorização para migrations/deploy.

## 1. Princípio do Cadastro Central

1. Existe um Cadastro Central único de itens.
2. Cada item é cadastrado uma vez, possui identidade própria e pode ser pesquisado e reutilizado em várias estruturas.
3. A estrutura de um produto não cria cópias dos itens: ela referencia itens já existentes no Cadastro Central.
4. Um item pode ser componente de outro item e também possuir sua própria estrutura. Portanto, a composição pode ter vários níveis.
5. Não existe uma separação funcional obrigatória entre item comprado e fabricado para determinar como ele é cadastrado ou reutilizado.
6. Categorias (por exemplo, Usinagem, Pintura, Corte Laser) classificam os itens; a categoria, isoladamente, não determina se o custo entra ou não na composição.

## 2. Tipos de item e origem do custo unitário

A origem do custo é determinada pelo tipo e pela existência de estrutura:

### 2.1 Tipo Simples

- Não possui estrutura de composição.
- O custo unitário é informado manualmente no cadastro.
- A janela/campo de preço permanece habilitada para edição.
- O valor manual é a origem do custo unitário do item.

### 2.2 Tipo Composto

- Possui estrutura de composição.
- O custo unitário é calculado automaticamente a partir dos componentes da estrutura.
- A janela/campo de preço não permite edição manual; deve ficar bloqueada/inativa para edição.
- O custo unitário calculado é apresentado automaticamente no cadastro do item.
- O custo manual não pode sobrescrever o custo calculado da estrutura.

**Regra de consistência:** um item Tipo Composto precisa ter uma estrutura válida para que seu custo seja calculado. Um item sem estrutura utiliza a regra de Tipo Simples. A interface e a validação devem impedir combinações contraditórias entre tipo e estrutura.

## 3. Formação do custo de um item composto

Para uma estrutura cuja quantidade-base representa uma unidade do item composto:

**Custo unitário do composto = soma do (quantidade utilizada de cada componente × custo unitário vigente desse componente), respeitando a unidade única cadastrada para cada item. Não há unidades alternativas nem conversão automática.**

Exemplo confirmado:

| Componente | Quantidade na estrutura | Custo total |
|---|---:|---:|
| Eixo | 1 un. | R$ 10,00 |
| Chapa de aço | 3 kg | R$ 30,00 |
| Parafuso M6 | 4 un. | R$ 4,00 |
| **Custo unitário do mecanismo** | **1 mecanismo** | **R$ 44,00** |

O sistema soma os custos da estrutura e preenche automaticamente o custo unitário do Mecanismo de Torniquete com **R$ 44,00**.

Se a estrutura representar mais de uma unidade produzida, será necessário dividir o custo total da estrutura pela quantidade-base produzida para chegar ao custo unitário. A definição detalhada desse campo de quantidade-base ainda precisa ser fechada.

## 4. Estruturas multinível e recálculo em cascata

Exemplo de hierarquia:

- Mini Torniquete
  - Base de Mecanismo (item composto)
    - Chapas
    - Tubos
    - Eixo sextavado
    - Fixadores
  - Outros componentes

Regras:

1. Um item composto pode ser utilizado como componente de outro item composto.
2. O custo do item-pai utiliza o custo unitário calculado do item-filho.
3. Quando o custo de um item simples muda, todos os compostos que dependem dele devem ser recalculados, direta ou indiretamente.
4. O recálculo deve propagar-se até os produtos finais afetados.
5. Um mesmo item reutilizado em várias estruturas mantém um único cadastro e uma única origem de preço.
6. O sistema deve impedir referências circulares (um item não pode depender de si mesmo, direta ou indiretamente). Essa proteção deve ser técnica e não criar etapas desnecessárias no fluxo normal do usuário.

## 5. O que compõe o custo

- Entram no custo os materiais, componentes, fixadores e serviços terceirizados que participam diretamente da composição do item.
- Operações ou serviços como usinagem, pintura e corte laser podem ser itens/custos próprios e entrar na estrutura quando utilizados.
- A categoria não exclui automaticamente um item do custo. Exemplo: um eixo sextavado classificado na categoria Usinagem pode ter preço próprio e compor o custo.
- Mão de obra direta (MOD) e gastos gerais de fabricação (GGF) não entram no cálculo definido para este sistema.

## 6. Regras específicas já esclarecidas

- Para chapas precificadas por kg, o custo considera o peso utilizado multiplicado pelo preço por kg.
- A conversão interna de dimensão para peso de peças de chapa já incorpora o desperdício informado pelo usuário. Não adicionar o mesmo desperdício novamente.
- Exemplo de peso: se seis peças totalizam 2,15 kg, o peso informado é total; o peso unitário é 2,15 ÷ 6. O custo total do material é calculado sobre 2,15 kg.
- Regras de aproveitamento de barras comerciais para tubos foram observadas na planilha de referência, mas ainda não foram confirmadas como regra universal do sistema.

## 7. Princípios de atualização e integridade

- Alterações no preço de um item simples devem refletir nos custos de todos os itens compostos dependentes.
- O recálculo não deve depender de o usuário abrir e salvar manualmente cada estrutura.
- O mecanismo precisa preservar a consistência entre o custo dos componentes e o custo calculado dos compostos.
- Histórico de custos deve preservar os valores anteriores e permitir visualizar evolução; detalhes de armazenamento técnico e precisão interna ainda precisam ser especificados.
- A retenção de um ano e arquivamento se aplicam ao Log de Atividades, não à exclusão automática do histórico de custos.

## 8. Exemplo de comportamento da interface

| Tipo do item | Origem do custo unitário | Campo/janela de preço |
|---|---|---|
| Simples | Valor informado manualmente | Editável |
| Composto | Soma calculada da estrutura | Bloqueado para edição manual; valor calculado visível |

A interface deve deixar evidente quando o custo é manual e quando é calculado, sem permitir que o usuário confunda ou sobrescreva as duas origens.

## 9. Pontos ainda não decididos

Não assumir decisões para os pontos abaixo sem confirmação:

1. Quantidade-base da estrutura (sempre uma unidade ou lote de produção configurável).
2. Regras universais de aproveitamento de barras/tubos e arredondamento de compras.
3. Precisão interna de armazenamento e cálculo além do arredondamento de apresentação por item já aprovado.
4. Como tratar versões de estruturas e custos históricos em alterações futuras.
5. Se haverá preço por fornecedor, múltiplas tabelas ou apenas um preço vigente por item.
6. Comportamento para itens sem preço ou com estrutura incompleta.
7. Regra de exclusão de item que ainda esteja vinculado a estruturas: foi aprovado mostrar impacto e exigir confirmação, mas não foi fechado se a exclusão pode prosseguir com vínculos ou se exige remoção prévia.
8. Frequência, retenção e teste de restauração dos backups.

## 10. Limites deste registro

- Este documento registra entendimento funcional, não especifica tabelas, endpoints, jobs ou tecnologia.
- Não autoriza alterar VPS, CRM, infraestrutura, banco remoto, migrations ou realizar deploy.
- A planilha de preços é referência para exemplos e entendimento, não deve impor sozinha a lógica do sistema.
- A referência ao Omie é inspiração para cadastro e reutilização de itens/estruturas, não para copiar regras fiscais ou funcionalidades não solicitadas.
- Em caso de conflito com a Ordem Mestra ou com a especificação funcional original, registrar a divergência e resolver antes de implementar; não substituir silenciosamente documentos oficiais.


## 11. Unidades, IDs e famílias — decisões recuperadas

- Unidades aprovadas: **metro, quilograma (kg), metro quadrado (m²) e unidade**.
- Cada item utiliza uma única unidade. Não há unidades alternativas nem conversão automática.
- O ID interno é numérico e sua organização será definida manualmente pelo administrador; serve para busca e organização.
- Cada item deve pertencer a **uma única família específica e obrigatória**, utilizada como classificação principal e critério de localização/pesquisa. Não atribuir múltiplas famílias ao mesmo item.
- Famílias/classificações são cadastráveis e editáveis. A família não determina a unidade de medida.
- Busca de itens pode utilizar ID, descrição ou família.
- Uma categoria/família só pode ser excluída se não houver itens vinculados; se houver, os itens devem ser reclassificados primeiro.

## 12. Regras complementares de custo industrial

1. Matérias-primas são cadastradas com custo pela unidade correspondente: chapa por kg, tubo por metro, etc.
2. O custo da linha é quantidade utilizada × custo unitário cadastrado.
3. Os custos/pesos fornecidos já incorporam o desperdício calculado pelo usuário; não adicionar uma segunda margem de desperdício.
4. O sistema apura custo industrial. Não adiciona impostos separadamente nem realiza formação de preço de venda.
5. Gama é fator de correção associado ao inox e pode ser aplicado manualmente quando necessário. Não é automático nem obrigatório. O valor 1,20 da planilha é referência, não constante global.
6. Pintura é um serviço/item com custo unitário próprio, ativável no produto ou subconjunto. Quando ativada, entra na composição e propaga seu custo aos produtos-pai.
7. Usinagem externa pode ser cadastrada como item/serviço com custo unitário.
8. A categoria “corte a laser” não adiciona por si só um custo automático. O custo do material utilizado é calculado pelo peso e custo da matéria-prima informado.
9. Não aplicar Alpha/Beta ou multiplicadores de preço comercial ao motor de custo sem decisão específica.

## 13. Arredondamento aprovado

A regra de apresentação é aplicada **individualmente por item**, não somente sobre a soma final:

- Terceira casa decimal de 0 a 5: arredondar para baixo.
- Terceira casa decimal acima de 5: arredondar para cima.
- Exemplos aprovados: R$ 1,543 → R$ 1,54; R$ 1,546 → R$ 1,55.

A precisão interna usada para armazenar e calcular valores antes da apresentação ainda precisa ser definida tecnicamente.

## 14. Estruturas, famílias e prevenção de dupla contagem

- Um mesmo componente pode aparecer diretamente no produto e dentro de um subconjunto; cada ocorrência deve ser contabilizada conforme sua posição e quantidade na árvore.
- O sistema não deve bloquear componentes repetidos só por serem iguais.
- Quando um subconjunto composto é inserido no produto-pai, o resumo por família do pai considera a família principal do subconjunto e seu custo consolidado. Não deve somar novamente as famílias internas já incorporadas no custo do subconjunto.
- O resumo de custos por família apresenta quantidades e custos acumulados sem dupla contagem.
- Duplicar um produto cria uma cópia independente, permitindo adaptar descrição e estrutura para variantes como aço carbono e inox.

## 15. Itens inativos e custos zerados

- Itens inativos ficam em aba própria.
- Item inativo não aparece na árvore de composição e não participa do custeamento.
- Inativar/remover componente reduz o custo; substituir componente recalcula o custo correspondente.
- R$ 0,00 pode ser salvo/exibido, mas não é considerado primeiro valor válido para a evolução histórica. O sistema deve sinalizar/notificar o item para revisão.
- Itens inativos ficam ocultos por padrão na pesquisa global, mas podem ser encontrados com filtro específico.

## 16. Revisão semestral, histórico e alertas

1. A revisão de custos dos materiais deve ser estimulada a cada seis meses.
2. Se não houver revisão nem alteração durante o ciclo de seis meses, emitir lembrete.
3. Quando o usuário alterar o custo e salvar, reiniciar a contagem do ciclo.
4. O sistema só reconhece uma alteração depois que o cadastro for salvo.
5. Não calcular média entre preço antigo e novo; utilizar o custo vigente real informado.
6. O primeiro custo válido (maior que zero) é a base de comparação; os registros seguintes mostram aumentos e quedas.
7. A evolução pode ser apresentada em gráfico, alternando entre valores em reais e percentuais.
8. Limites de variação podem ser configurados no ambiente do produto.
9. Alterações da estrutura vigente não apagam o histórico anterior. Apenas a estrutura atual e seus custos derivados são atualizados.
10. Relatórios são gerados sob demanda; PDF pode ser solicitado manualmente.

## 17. Importação e atualização em lote

- Disponibilizar planilha Excel padronizada para download, preenchimento e reenvio.
- A prévia deve mostrar apenas os dados/linhas que sofreram alteração.
- Erros devem ser destacados por linha/campo.
- Linhas válidas podem ser aprovadas mesmo quando outras linhas da mesma planilha apresentam erros.
- Aplicar a mesma proteção de prévia e aprovação tanto na importação quanto na atualização em lote.
- Nenhuma linha será gravada antes da aprovação do usuário.

## 18. Interface, pesquisa e operação

- Painel Geral é a tela inicial.
- Sidebar recolhível, com opção de permanecer fixa.
- Sino com contador de notificações e painel flutuante expansível.
- Pesquisa global compacta por ID/descrição, apresentando ID, descrição, família, tipo e custo vigente.
- Ao abrir um cadastro pela pesquisa global, preservar o contexto de navegação anterior no retorno.
- Pesquisa global respeita permissões e oculta inativos por padrão, oferecendo filtro para localizá-los.
- Atalhos aprovados: Esc fecha modal; Enter confirma pesquisa; Ctrl+K abre pesquisa global; Alt+← retorna à tela anterior.
- Se o usuário tentar sair com alterações não salvas, perguntar se deseja sair. Se confirmar, descartar sem gravar e sem criar histórico.
- Desktop recebe experiência completa; notebook/tablet adaptam os componentes; celular prioriza consultas, notificações, histórico e relatórios. Edição complexa de estruturas tem prioridade no desktop.
- Tabelas extensas devem carregar progressivamente; gráficos, históricos e relatórios sob demanda; recálculos não devem bloquear a navegação.

## 19. Log de atividades, acesso e continuidade

1. Log de Atividades deve mostrar quem fez e o que fez.
2. Registros permanecem no ambiente principal durante o primeiro ano; após um ano vão para o Arquivamento.
3. O administrador decide explicitamente se e quando excluir registros arquivados; não há exclusão automática.
4. Essa retenção não autoriza apagar automaticamente histórico de custos, estruturas antigas ou memórias de cálculo.
5. Login individual, 2FA integrado e RLS no banco de dados.
6. Níveis de acesso aprovados: Administrador, Editor e Visualizador.
7. Backup automático periódico aprovado; frequência, retenção e teste de restauração ainda não especificados.
8. Operações interrompidas não podem ser apresentadas como concluídas; evitar duplicidade em tentativas repetidas e preservar integridade.
9. Painel discreto de Informações do Sistema mostra estado real do banco, autenticação, serviços internos e horário da última verificação.

## 20. Limites de escopo e arquitetura técnica

- O sistema é de apuração de custo industrial; não deve incorporar CRM, estoque, fiscal, clientes, condições comerciais ou formação de preço de venda.
- O projeto é separado do CRM, com Supabase separado.
- O usuário informou domínio planejado `sistema.trique-brasil.io` e VPS KVM2 existente (2 vCPU, 8 GB RAM, 100 GB disco); isso não significa que o sistema esteja implantado.
- Frontend deve ser tratado como não confiável; validações críticas no backend; segredos, tokens, credenciais e arquivos `.env` nunca podem ser expostos.
- A stack do CRM não deve ser copiada para este projeto. A stack específica do Sistema de Custos ainda não foi aprovada nas conversas auditadas.
- A Ordem Mestra e a especificação técnica de segurança são documentos de precedência e devem ser cruzados antes de implementação.

## 21. Identificação única dos itens — decisão aprovada em 09/11/2026

- Todo item deve possuir um ID numérico obrigatório e exclusivo.
- Não pode haver dois itens diferentes com o mesmo ID.
- A numeração é organizada e definida manualmente pelo administrador; o sistema deve validar a unicidade antes de salvar.
- O ID é um critério de pesquisa e localização do item.
- Alterações de ID seguem a confirmação global e devem ser registradas na auditoria.


## 22. Descrição não exclusiva dos itens — decisão aprovada em 09/11/2026

- A descrição/nome do item não precisa ser exclusiva.
- Podem existir itens diferentes com a mesma descrição, desde que cada registro possua seu próprio ID numérico obrigatório e exclusivo.
- O ID é a identidade única do cadastro; a descrição é informação de identificação e pesquisa, não uma chave única.
- A pesquisa deve permitir distinguir resultados com descrições iguais exibindo, no mínimo, ID e família, além dos demais dados relevantes já definidos.
- Esta regra não altera a obrigatoriedade de família única, unidade única ou validação de ID duplicado.

## 23. Descrição complementar — decisão aprovada em 09/11/2026

- O Cadastro Central terá um campo **Descrição complementar**, opcional.
- O campo registra características técnicas e detalhes que ajudem a diferenciar itens com descrições principais iguais ou semelhantes.
- A descrição complementar é informativa e pesquisável; pode ser utilizada nos resultados e filtros de pesquisa.
- Ela não substitui nem altera a descrição principal e não precisa ser preenchida para salvar o cadastro.
- O campo não interfere na família, unidade de medida, estrutura, origem do custo ou cálculo.

## 24. Listagem do Cadastro Central — decisão aprovada em 09/11/2026

- A listagem do Cadastro Central apresenta itens Simples e Compostos em uma única relação.
- A separação por tipo e situação será feita por filtros, não por abas fixas independentes.
- Itens inativos permanecem ocultos por padrão, conforme regra já aprovada, e podem ser localizados por filtro específico.
- A listagem deve priorizar identificação e consulta rápida; detalhes completos ficam na tela do cadastro.

## 25. Colunas da listagem do Cadastro Central — decisão aprovada em 09/11/2026

A listagem principal deve apresentar as seguintes colunas:

- ID numérico;
- Descrição principal;
- Família;
- Unidade de medida;
- Tipo (Simples ou Composto);
- Custo unitário vigente;
- Situação (Ativo ou Inativo, quando o filtro de inativos estiver habilitado).

A **Descrição complementar** não será exibida como coluna na listagem principal, para manter a tabela objetiva. Ela continuará disponível na tela do cadastro e será considerada na pesquisa.

## 26. Organização da tela de cadastro — decisão aprovada em 09/11/2026

O formulário de cadastro do Cadastro Central será apresentado em uma única tela, com quatro blocos organizados verticalmente:

1. **Identificação:** ID, descrição principal, descrição complementar e família.
2. **Características:** unidade de medida e tipo do item.
3. **Custeio:** custo unitário e origem do custo (manual ou calculado), respeitando as regras de itens Simples e Compostos.
4. **Controle:** situação do item e informações de atualização.

Não serão usadas abas separadas para esses quatro blocos. A decisão trata da organização visual; não altera regras de validação, permissões, confirmação ou cálculo já aprovadas.


## 27. Sugestão sequencial de ID com escolha manual — decisão aprovada em 09/11/2026

- O sistema deve sugerir automaticamente o menor número inteiro positivo ainda não utilizado como próximo ID.
- A sugestão não é obrigatória: o administrador pode aceitá-la ou informar manualmente qualquer outro ID numérico disponível.
- Antes de salvar, o sistema valida a unicidade do ID escolhido; IDs já utilizados não podem ser atribuídos novamente.
- Após cada cadastro, a sugestão seguinte é recalculada considerando todos os IDs já utilizados. Exemplo: se o ID 10 já existe e os IDs 5 a 9 estão livres, a sugestão será 5; depois que 5 a 9 forem ocupados, a sugestão passa a 11.
- IDs de itens inativados permanecem reservados e não podem ser reutilizados.
- A regra é uma conveniência de preenchimento e organização; não altera o caráter obrigatório e exclusivo do ID nem retira do administrador a possibilidade de escolher outro número livre.


## 28. Descrição principal do item — decisão aprovada em 09/11/2026

- A descrição principal é obrigatória para salvar o cadastro.
- O campo aceita letras, números e caracteres especiais; não será imposto um padrão rígido de nomenclatura.
- Descrições repetidas são permitidas. A identidade exclusiva do item continua sendo seu ID numérico.
- A descrição principal permanece disponível para pesquisa, em conjunto com os demais critérios já definidos.

## 29. Cadastro de família por seleção controlada — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- O campo Família no cadastro do item será uma lista de seleção alimentada pelas famílias previamente cadastradas em Configurações.
- O usuário não poderá digitar livremente ou criar uma família diretamente durante o cadastro do item.
- O cadastro e a edição das famílias serão realizados na área de Configurações, por usuário com permissão administrativa.
- A família continua obrigatória e única por item.
- A seleção deve referenciar o registro da família existente, evitando variações de grafia e classificações duplicadas por digitação.
- A regra de exclusão permanece: uma família vinculada a itens não pode ser excluída até que os itens sejam reclassificados.


## 30. Contagem automática de itens vinculados à família — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário nesta conversa.**

- A quantidade de itens vinculados será calculada automaticamente pelo sistema com base nos vínculos existentes entre itens do Cadastro Central e cada família.
- O contador aumenta quando um item é associado à família e diminui quando o item é reclassificado para outra família ou deixa de estar vinculado, conforme operação permitida.
- A quantidade é somente informativa e não pode ser preenchida ou editada manualmente.
- A contagem deve refletir os vínculos efetivos, sem exigir manutenção manual pelo usuário.


## 31. Nome obrigatório e único da família — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário nesta conversa.**

- Toda família deve possuir um nome preenchido; não é permitido salvar família sem nome.
- O nome da família deve ser único no cadastro de Configurações.
- O sistema deve impedir classificações duplicadas decorrentes de variações de escrita, incluindo os exemplos “Chapas”, “CHAPAS” e “Chapa”.
- A validação de unicidade deve ocorrer antes de salvar, inclusive no backend.
- A regra de comparação/normalização que identificará variações equivalentes de escrita deverá ser definida tecnicamente, sem enfraquecer o resultado funcional aprovado: não permitir famílias duplicadas por variação de grafia.


## 32. Inativação de famílias sem itens vinculados — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário nesta conversa.**

- Uma família sem itens vinculados poderá ser inativada em Configurações, em vez de ser excluída definitivamente.
- A inativação deve ser impedida enquanto houver qualquer item vinculado à família; primeiro será necessário reclassificar os itens.
- Famílias inativas não devem aparecer como opção na seleção de família durante o cadastro ou edição de itens.
- A família inativada permanece registrada, preservando sua existência no sistema. A reativação foi aprovada e está detalhada na seção 33.


## 33. Reativação de famílias inativas — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário nesta conversa.**

- O administrador poderá reativar uma família anteriormente inativada.
- Ao reativar, a família volta a ter situação ativa e fica novamente disponível na lista de seleção do campo Família no Cadastro Central.
- A reativação não cria uma nova família nem altera sua identidade ou histórico; recupera o registro já existente.
- A validação de unicidade do nome também deve ser aplicada na reativação. Se houver conflito com outra família, a reativação deverá ser bloqueada até que o conflito seja resolvido, preservando a regra de nome único.
- A reativação não associa automaticamente itens à família; os vínculos continuam dependendo de uma operação explícita de classificação no Cadastro Central.

## 34. Área isolada de famílias arquivadas em Configurações — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário nesta conversa.**

- O gerenciamento de famílias ficará dentro do ambiente **Configurações**.
- As famílias ativas serão apresentadas na área normal de gerenciamento de famílias.
- As famílias inativas ficarão em uma área separada, identificada por um ícone com o texto **Arquivados**.
- A área **Arquivados** exibirá somente famílias inativas e permitirá ao administrador consultá-las e reativá-las.
- Famílias arquivadas não serão oferecidas na seleção do Cadastro Central.
- Após a reativação, a família retornará à listagem normal de famílias ativas, respeitando a validação de unicidade já aprovada.
- Esta decisão define a organização funcional da interface em Configurações; não autoriza implementação ou alteração técnica.

## 35. Data de inativação na área Arquivados — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário nesta conversa.**

- A listagem **Configurações → Famílias → Arquivados** deve exibir também a data em que cada família foi inativada.
- A data exibida corresponde à inativação mais recente do registro. Se a família for reativada e posteriormente inativada novamente, a data deverá ser atualizada para a nova inativação.
- A informação é de consulta e rastreabilidade; não altera as regras de reativação, seleção ou vínculo de itens.

## 36. Colunas da listagem de famílias ativas — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário nesta conversa.**

A listagem normal de famílias ativas em **Configurações → Famílias** deve apresentar:

- **Nome da família**;
- **Quantidade de itens vinculados**, calculada automaticamente e somente para consulta;
- **Data de criação**;
- **Última atualização**;
- **Situação**.

A listagem também disponibilizará as ações **Editar** e **Inativar**, respeitando as regras já aprovadas: somente famílias sem itens vinculados podem ser inativadas. Famílias inativas permanecem na área separada **Arquivados**, com data da inativação mais recente e opção de reativação para o administrador.

## 37. Edição de família — preservação do registro e dos vínculos — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário nesta conversa.**

- A ação **Editar** permitirá alterar o nome da família.
- A alteração será feita no registro já existente; não criará uma nova família nem substituirá sua identidade.
- Todos os itens já vinculados permanecerão associados ao mesmo registro após a alteração do nome. A quantidade de itens vinculados não será alterada pela simples edição do nome.
- O novo nome deverá continuar obrigatório e respeitar a regra de unicidade já aprovada, inclusive contra variações de grafia equivalentes. Havendo conflito, a alteração será bloqueada até a correção.
- A edição seguirá o fluxo geral de prévia, confirmação explícita e auditoria antes da gravação.

## 38. Confirmação da inativação de família — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário nesta conversa.**

- Ao acionar **Inativar** em uma família, o sistema deve apresentar uma confirmação antes de executar a operação.
- A confirmação deve identificar a família pelo nome e informar a quantidade atual de itens vinculados.
- Se a família possuir qualquer item vinculado, a inativação será bloqueada; a interface deverá informar que os itens precisam ser reclassificados antes de tentar novamente.
- Se não houver itens vinculados, o administrador poderá confirmar ou cancelar a inativação.
- Nenhuma alteração será realizada antes da confirmação explícita. A operação confirmada deverá ser registrada na auditoria e a família passará para a área **Arquivados**, preservando o registro.

## 39. Confirmação da reativação de família — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Ao solicitar a reativação de uma família arquivada, o sistema deve apresentar uma confirmação antes de executar a operação.
- A confirmação deve exibir o nome da família e a data de sua última inativação.
- Deve informar que, após a reativação, a família voltará a aparecer como opção na seleção de família do Cadastro Central.
- A reativação não restabelece nem cria vínculos automaticamente: itens não serão associados à família por efeito da reativação.
- O administrador poderá confirmar ou cancelar. Nenhuma alteração ocorrerá antes da confirmação explícita.
- A reativação preserva a identidade e o histórico do registro original, respeitando a validação de unicidade do nome já aprovada.

## 40. Conflito de nome na reativação de família — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Antes de reativar uma família arquivada, o sistema deve validar se o nome pretendido conflita com o nome de outra família ativa, aplicando a regra de unicidade já aprovada, inclusive para diferenças de capitalização ou grafia equivalente.
- Se houver conflito, bloquear a reativação e informar claramente que o nome está em uso por outra família ativa.
- A mensagem deve identificar o nome conflitante e, quando possível, a família ativa que o utiliza, para orientar a resolução.
- O administrador deverá resolver o conflito — por exemplo, renomeando a família arquivada ou a família ativa, respeitando as permissões e a validação de unicidade — e então tentar novamente.
- Não renomear famílias automaticamente, não sobrescrever registros e não criar vínculos como efeito da tentativa de reativação.
- A reativação só poderá prosseguir após nova validação bem-sucedida e confirmação explícita do administrador.

## 41. Permissões para manutenção de famílias — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Somente usuários com papel **Administrador** podem criar, editar, inativar e reativar famílias.
- Usuários com papel **Editor** ou **Visualizador** podem consultar as famílias, mas não podem executar essas operações de manutenção.
- A restrição deve ser aplicada também no backend, não apenas ocultando ou desabilitando controles na interface.
- Tentativas não autorizadas devem ser recusadas sem alterar dados e devem respeitar as regras gerais de auditoria e segurança do sistema.


## 42. Pesquisa na gestão de famílias — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- A listagem normal de **Configurações → Famílias** deve permitir pesquisar pelo nome da família.
- A pesquisa deve aceitar correspondência parcial, permitindo localizar uma família ao informar apenas parte de seu nome.
- A pesquisa não deve diferenciar letras maiúsculas de minúsculas.
- A listagem normal e sua pesquisa consideram somente famílias ativas.
- Famílias inativas continuam consultáveis exclusivamente na área **Arquivados**, sem aparecer nos resultados da listagem normal.
- A pesquisa é somente um recurso de localização; não altera famílias, vínculos, permissões ou regras de unicidade.


## 43. Ordenação das listagens de famílias — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- A listagem normal de famílias ativas será apresentada em ordem alfabética crescente (A–Z), pelo nome da família.
- A listagem da área **Arquivados** será ordenada pela data de inativação mais recente primeiro (ordem decrescente).
- A ordenação é apenas de apresentação e não altera registros, identificadores, vínculos, datas ou histórico.
- A pesquisa já aprovada continuará funcionando sobre a listagem correspondente, respeitando a separação entre famílias ativas e arquivadas.


## 44. Atualização em tempo real em todo o sistema — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- A atualização em tempo real é uma regra geral do Alianza — Sistema de Custos e não se limita ao Cadastro Central, à gestão de famílias ou a uma tela específica.
- Toda alteração de dados concluída com sucesso deve ser refletida automaticamente nas telas, listagens, consultas e sessões de usuários que exibam ou dependam dos dados afetados, sem exigir atualização manual da página.
- A atualização deve respeitar os papéis, permissões e filtros de cada usuário. A sincronização em tempo real não concede acesso adicional nem contorna controles de autorização.
- O backend e os dados efetivamente persistidos são a fonte de verdade. A interface só deve apresentar uma alteração como concluída depois da confirmação de sucesso da operação; falhas não podem gerar aparência de gravação bem-sucedida.
- Alterações relacionadas e recálculos em cascata devem preservar a consistência transacional já aprovada: os usuários não devem receber um estado parcial como se fosse o resultado final de uma operação que ainda não foi concluída.
- A sincronização deve evitar apresentar dados desatualizados após uma alteração confirmada e tratar conflitos de edições concorrentes sem sobrescrever silenciosamente alterações de outro usuário.
- A regra abrange todos os módulos e operações de criação, edição, inativação, reativação, exclusão autorizada, vínculos e recálculos do projeto, conforme as permissões e regras específicas de cada módulo.
- A tecnologia, o mecanismo de comunicação, a estratégia de reconexão e os objetivos mensuráveis de latência ainda serão definidos na especificação técnica. Esta decisão aprova o comportamento funcional em tempo real, não uma tecnologia específica nem uma promessa de latência numérica.


## 45. Atualização em tempo real de filtros, pesquisas e ordenações — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Filtros, resultados de pesquisa e ordenações devem refletir automaticamente alterações confirmadas nos dados que afetam seus resultados, em todas as telas e módulos do sistema.
- Quando um registro mudar de nome, classificação, situação ou outro atributo utilizado na pesquisa, filtro ou ordenação, as visualizações abertas devem ser atualizadas para refletir o estado persistido.
- A atualização deve preservar os critérios de pesquisa, filtros e ordenação que o usuário já selecionou, recalculando os resultados conforme esses critérios; não deve limpar ou substituir as escolhas do usuário sem necessidade.
- Se um registro deixar de atender aos critérios ativos, deve deixar de aparecer nos resultados; se passar a atendê-los, deve aparecer conforme a ordenação vigente.
- As regras de visibilidade, permissões, escopo e separação entre registros ativos e arquivados continuam prevalecendo. A atualização em tempo real não deve revelar registros que o usuário não pode consultar.
- Esta regra complementa a atualização global em tempo real e não define tecnologia específica nem meta numérica de latência.


## 46. Alteração da família de um item já cadastrado — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Quando um Administrador alterar a família de um item existente, a nova classificação deverá ser refletida imediatamente no Cadastro Central e nas demais telas, consultas, pesquisas e filtros que exibam ou utilizem esse item, conforme a regra global de atualização em tempo real.
- A alteração de família é exclusivamente classificatória: não modifica o custo unitário, a unidade de medida, o tipo do item nem sua estrutura de composição.
- O histórico de alterações do item deve ser preservado e registrar a mudança de família, permitindo identificar a classificação anterior e a nova, o responsável e a data/hora da operação.
- A operação deve respeitar as permissões, validações, prévia, confirmação explícita e auditoria já aprovadas para alterações cadastrais.


## 47. Exclusão definitiva de famílias — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Uma família que já tenha sido utilizada em qualquer vínculo ou registro histórico não poderá ser excluída definitivamente, mesmo que atualmente não possua itens vinculados.
- Famílias já utilizadas devem ser preservadas para manter a integridade referencial, a rastreabilidade e o histórico. Quando aplicável, sua gestão deverá ocorrer por inativação e arquivamento, conforme as regras aprovadas.
- A exclusão definitiva poderá ser permitida somente quando a família nunca tiver sido utilizada e não possuir vínculos atuais ou históricos.
- Antes da exclusão permitida, o sistema deverá apresentar prévia com a identificação da família e confirmação explícita do Administrador; a operação deverá ser registrada na auditoria.
- A verificação de uso deve considerar o histórico, e não apenas a quantidade atual de itens vinculados. A forma técnica de identificar e comprovar esse uso será definida na especificação de dados.


## 48. Prévia de impacto ao editar o nome de uma família — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Antes de confirmar a edição do nome de uma família, o sistema deve apresentar uma prévia que identifique claramente o nome atual e o novo nome proposto.
- A prévia deve informar a quantidade de itens atualmente vinculados à família e destacar que a alteração do nome será refletida em todos esses itens e nas telas, pesquisas, filtros e consultas correspondentes.
- A prévia deve deixar explícito que a mudança é apenas nominal/classificatória e não altera os itens vinculados, seus custos, unidades ou estruturas de composição.
- O Administrador deve poder confirmar ou cancelar. Nenhuma alteração será efetivada antes da confirmação explícita.
- Após a confirmação e persistência bem-sucedida, a atualização deve ser propagada em tempo real, preservando o histórico e registrando a operação na auditoria.


## 49. Relação detalhada de itens afetados na prévia de alteração de família — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- A prévia de edição de uma família deve permitir consultar a relação dos itens atualmente vinculados que serão afetados pela mudança de nome.
- A relação deve identificar cada item, no mínimo, por seu código/ID e descrição principal, e apresentar a quantidade total de itens afetados.
- A relação deve permitir ao Administrador avaliar o impacto concreto da ação antes de confirmar ou cancelar a alteração.
- A consulta dos itens afetados é somente informativa: não permite alterar, remover ou reclassificar os itens dentro da prévia.
- A listagem deve respeitar permissões e regras de visibilidade do Cadastro Central. Se a relação for extensa, deverá ser apresentada de forma consultável e paginada ou equivalente, sem omitir silenciosamente itens do total informado.
- A prévia deve refletir os vínculos existentes no momento da confirmação; se os vínculos mudarem enquanto a prévia estiver aberta, o sistema deve atualizar a relação ou exigir nova validação da prévia antes de permitir confirmar, evitando confirmar com impacto desatualizado.


## 50. Prévia de impacto para operações em massa — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Toda operação em massa que possa alterar múltiplos registros deve apresentar uma prévia antes da confirmação.
- A prévia deve informar a quantidade total de registros que serão afetados e permitir consultar a relação dos registros, identificando-os por seus códigos/IDs e descrições ou pelos campos identificadores próprios do módulo.
- A prévia deve descrever claramente a ação pretendida e seu impacto esperado, incluindo alterações de dados, situação, vínculos ou efeitos em módulos dependentes, quando aplicável.
- O usuário autorizado deve poder confirmar ou cancelar. Nenhuma alteração pode ser efetivada antes da confirmação explícita.
- A relação deve ser consultável mesmo quando extensa, por paginação ou recurso equivalente, sem divergência entre o total informado e os registros efetivamente apresentados.
- A prévia deve respeitar permissões e visibilidade. Alterações nos registros selecionados ou no conjunto afetado enquanto a prévia estiver aberta exigem atualização ou nova validação antes da confirmação.
- Após a confirmação, a operação deve ser executada com validação no backend e registrada na auditoria, com resultado identificável. Falhas parciais não podem ser apresentadas como sucesso integral; o tratamento de atomicidade ou retomada deverá ser especificado conforme cada operação.
- A regra aplica-se, entre outras, a importações, alterações em lote e inativações em massa, sem substituir validações específicas de cada módulo.

## 51. Exclusão de itens com prévia de impacto e tratamento automático dos vínculos — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Todo item do Cadastro Central poderá ser excluído, inclusive quando possuir vínculos atuais em estruturas de composição ou em outros registros/módulos. A existência de vínculos, por si só, não impede a exclusão.
- Antes da confirmação, o sistema deve verificar dependências e apresentar uma prévia resumida de impacto, informando a quantidade total de estruturas/registros afetados e os tipos de impacto relevantes. A prévia não deve abrir nem listar individualmente cada estrutura ou seus componentes, para evitar excesso de informação e poluição visual.
- A prévia deve explicar as consequências concretas, incluindo quais estruturas serão afetadas e que os custos dos produtos compostos dependentes serão recalculados após a exclusão.
- Somente o papel Administrador poderá autorizar e confirmar a exclusão. Após a confirmação explícita do Administrador, o sistema deverá remover automaticamente as referências atuais ao item excluído nas estruturas e registros dependentes, conforme as regras do módulo, e recalcular os custos de todos os compostos afetados, direta ou indiretamente, propagando o recálculo até os produtos finais.
- A exclusão e o tratamento dos vínculos devem ser executados com validação no backend, consistência transacional e registro completo na auditoria. A interface só poderá indicar conclusão após confirmação do backend; falhas não podem deixar vínculos quebrados nem ser apresentadas como sucesso integral.
- Se o conjunto de dependências mudar enquanto a prévia estiver aberta, o sistema deverá atualizar a prévia ou exigir nova validação e confirmação antes de executar.
- A exclusão deve deixar de permitir que o item seja selecionado em novas estruturas. A operação não deve apagar o registro de auditoria da exclusão.
- A exclusão não poderá apagar nem reescrever o passado: o sistema deverá preservar uma fotografia histórica imutável das composições e dos custos vigentes antes da exclusão, permitindo consultar como cada produto era composto e custeado naquele momento, mesmo após a remoção do item do Cadastro Central.
- A fotografia histórica deverá manter os dados necessários à rastreabilidade da composição e dos valores considerados no cálculo, sem depender da existência do cadastro ativo do item excluído.
- A exclusão de itens será lógica, não física: o registro original será preservado internamente para rastreabilidade, auditoria e referência histórica, mas ficará indisponível para uso operacional e não aparecerá nas consultas normais do Cadastro Central.
- Após a exclusão lógica, o item não poderá ser selecionado em novas estruturas; suas referências operacionais atuais serão tratadas conforme a regra de remoção automática aprovada, enquanto as fotografias históricas imutáveis continuarão consultáveis.
- A interface normal não deverá oferecer o item excluído como opção ativa. Eventual consulta administrativa de registros excluídos deverá ocorrer em ambiente separado e controlado, com permissões apropriadas.
- Detalhes técnicos de modelagem, retenção e consulta desse registro preservado permanecem pendentes de especificação antes da implementação.


## 52. Reativação de itens excluídos logicamente e autoridade para ações de impacto direto — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Somente usuários com papel **Administrador** poderão reativar itens excluídos logicamente.
- A reativação recuperará o registro original, preservando seu ID e os dados cadastrais/históricos; não criará um novo item.
- Após a reativação, o item voltará a aparecer no Cadastro Central ativo e poderá ser utilizado novamente, respeitadas as validações cadastrais vigentes.
- A reativação não restaurará automaticamente vínculos antigos em estruturas. Qualquer novo vínculo dependerá de ação explícita e das permissões aplicáveis.
- Como regra geral, decisões e operações que provoquem impacto direto nos dados, classificações, estruturas, custos, vínculos ou integridade histórica deverão ser de competência exclusiva do papel **Administrador**.
- Essa competência exclusiva inclui, no mínimo, exclusão e reativação de itens, além das operações de manutenção de famílias já restritas ao Administrador. A autorização deve ser validada no backend, com prévia de impacto quando aplicável e auditoria.
- A matriz completa de permissões deverá identificar, operação por operação, quais ações são de impacto direto e quais atividades rotineiras podem permanecer com o papel Editor. Não ampliar permissões por interpretação implícita.
