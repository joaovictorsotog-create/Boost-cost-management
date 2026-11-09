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


## 53. Permissões do Editor no Cadastro Central — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- O papel **Editor** poderá cadastrar novos itens no Cadastro Central e editar dados cadastrais permitidos de itens existentes.
- O Editor não poderá excluir logicamente nem reativar itens excluídos.
- O Editor não poderá executar alterações que modifiquem diretamente estruturas de composição ou provoquem recálculo/alteração dos custos de outros produtos.
- Operações que afetem diretamente estruturas, custos de produtos dependentes, vínculos ou integridade histórica permanecem exclusivas do **Administrador**.
- A autorização deverá ser validada no backend. A interface deverá ocultar ou desabilitar ações sem permissão, mas isso não substitui a validação de servidor.
- Os campos e operações específicos que o Editor poderá alterar sem impacto direto deverão ser discriminados na matriz completa de permissões antes da implementação. Em caso de dúvida sobre impacto, a operação não será liberada ao Editor por presunção.


## 54. Matriz de edição de campos do item por papel — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- O papel **Editor** poderá alterar somente a descrição principal e a descrição complementar do item, respeitadas as validações cadastrais e a auditoria.
- A alteração da **família** será exclusiva do **Administrador**, mesmo quando não modificar diretamente o custo. A mudança de família é uma alteração de classificação com impacto na organização e localização do item.
- Também serão exclusivas do Administrador as alterações de unidade, tipo do item, custo manual, estrutura de composição, exclusão e reativação, bem como qualquer outra operação que afete diretamente custeio, vínculos, estruturas ou histórico.
- O Editor não poderá contornar essas restrições por importação, edição em massa, API ou qualquer outro caminho; as permissões serão validadas no backend.
- A matriz completa deverá detalhar as demais ações e campos antes da implementação. Até lá, o Editor só poderá alterar os dois campos expressamente autorizados nesta decisão.


## 55. Solicitações de edição do Editor com aprovação do Administrador — decisão aprovada em 09/11/2026

**Status: APROVADO pelo usuário.**

- Toda alteração iniciada pelo papel **Editor** nos campos que lhe são permitidos — atualmente, descrição principal e descrição complementar — deverá gerar uma solicitação registrada diretamente no backend. A alteração não será aplicada ao cadastro oficial antes da aprovação explícita do Administrador.
- O backend deverá registrar, no mínimo, o item, o campo solicitado, o valor atual, o valor proposto, o Editor solicitante e a data/hora do envio. A solicitação deverá possuir estado rastreável, como pendente, aprovada ou rejeitada, e integrar a auditoria.
- O Administrador deverá visualizar as solicitações pendentes em uma área própria da interface, denominada **Central de Aprovações** ou equivalente, com acesso à comparação entre valor atual e valor proposto e às informações necessárias para decidir.
- O Administrador poderá aprovar ou rejeitar a solicitação. Rejeição não altera o cadastro oficial e deverá registrar responsável, data/hora e resultado. Aprovação deverá ser validada e efetivada pelo backend; a interface só informará sucesso após a persistência confirmada.
- Antes de aplicar uma aprovação, o backend deverá verificar se o registro e os valores de referência continuam compatíveis com aqueles apresentados ao Administrador. Se houver alteração concorrente ou mudança relevante, a solicitação deverá ser invalidada para aplicação automática e exigir atualização/revisão, evitando sobrescrita silenciosa ou aprovação de conteúdo desatualizado.
- O recálculo não será disparado apenas porque uma solicitação foi aprovada. Será obrigatório somente quando a alteração efetivamente modificar dados que participem do custeio ou afetem estruturas/vínculos de produtos compostos; nesse caso, recalcular todos os produtos dependentes, direta e indiretamente, em cascata, com consistência no backend.
- Alterações exclusivamente descritivas, como descrição principal ou complementar, atualizam o cadastro e a auditoria após aprovação, mas **não** provocam recálculo de custos.
- Esta aprovação não amplia as permissões de edição do Editor: até nova decisão expressa, ele continua podendo propor alterações somente na descrição principal e na descrição complementar. Família, unidade, tipo, custo manual, estrutura, exclusão, reativação e demais operações restritas continuam sob competência exclusiva do Administrador.
- A interface deverá apresentar ao Editor o estado da solicitação e o resultado da decisão, respeitando as permissões de acesso. Toda tentativa de contornar o fluxo por importação, edição em massa ou API deverá ser bloqueada pelo backend.


## 56. Organização visual e funcional da Central de Aprovações (09/11/2026)

**Status: APROVADO pelo usuário.**

- A **Central de Aprovações** será uma área própria e permanente no menu administrativo, separada do Cadastro Central e não escondida dentro de Configurações.
- O acesso deverá exibir um contador de solicitações pendentes, para que o Administrador identifique demandas que aguardam decisão.
- A tela principal terá cabeçalho próprio e resumo das quantidades de solicitações pendentes, aprovadas e rejeitadas.
- A consulta poderá ser filtrada por situação, com visualizações de **Pendentes**, **Aprovadas**, **Rejeitadas** e **Todas**.
- A listagem apresentará informações suficientes para identificar e avaliar cada solicitação: identificador da solicitação, item, tipo/campo da alteração, solicitante, data/hora, situação, comparação entre valor atual e valor proposto e indicação resumida do impacto previsto.
- A solicitação poderá ser aberta em uma visualização de detalhes para análise da identificação, dos valores comparados, do impacto e das ações disponíveis.
- Somente o Administrador poderá executar as ações **Aprovar** ou **Rejeitar**, respeitando as validações de backend e as regras de autorização já aprovadas. A decisão deverá ficar registrada no histórico.
- A Central manterá consulta ao histórico das decisões, incluindo solicitações aprovadas e rejeitadas.
- O Administrador deverá receber uma notificação quando uma nova solicitação chegar à Central de Aprovações.
- O Editor poderá acompanhar o estado e o resultado das próprias solicitações, sem receber permissão para aprová-las ou alterar diretamente o cadastro oficial.
- Antes de efetivar uma aprovação, o backend deverá revalidar os dados de referência. Se houver alteração concorrente ou impacto diferente do apresentado, a aprovação não poderá aplicar silenciosamente uma solicitação desatualizada; deverá exigir revisão/atualização.
- O impacto e a necessidade de recálculo serão avaliados conforme a natureza real da alteração. Mudanças exclusivamente descritivas não provocam recálculo; se uma alteração aprovada afetar efetivamente custeio, estruturas ou vínculos, os dependentes deverão ser recalculados em cascata.
- Exemplos de solicitações e valores exibidos em wireframes são meramente ilustrativos, não representam registros reais.
- Esta decisão aprova a organização visual e o comportamento funcional da Central. Não define tecnologia, modelo de dados, endpoints ou implementação, nem autoriza alterações de banco, infraestrutura ou deploy.


## 57. Estado de análise e prevenção de decisões simultâneas na Central de Aprovações (09/11/2026)

**Status: APROVADO pelo usuário.**

- Apenas abrir uma solicitação para consulta não altera seu estado: ela permanece **Pendente**.
- Quando um Administrador iniciar formalmente a análise, a solicitação passa para **Em análise**, com identificação do Administrador responsável.
- Enquanto estiver em análise por um Administrador, outros Administradores poderão consultar a solicitação, mas não poderão aprovar ou rejeitar aquela solicitação em paralelo.
- Se a análise for abandonada ou encerrada sem decisão, a solicitação deverá ser liberada e retornar ao estado **Pendente**, disponível para outro Administrador.
- Aprovação ou rejeição somente será efetivada após validação e persistência confirmadas pelo backend. A interface não poderá indicar decisão concluída antes dessa confirmação.
- O controle de concorrência e de titularidade da análise deverá ser imposto no backend, evitando decisões simultâneas, bloqueios indevidos e alterações silenciosas.
- A decisão aprova o comportamento funcional; prazo de expiração de uma análise abandonada, mecanismo de liberação automática e detalhes técnicos permanecem pendentes de especificação.


### Lembretes por inatividade durante a análise

- Após 30 minutos sem atividade na solicitação em análise, o sistema envia um lembrete ao Administrador responsável.
- Persistindo a ausência de atividade, novos lembretes são enviados em intervalos de 30 minutos, respeitando o limite máximo de **3 lembretes por solicitação**.
- Após o terceiro lembrete, o sistema interrompe novos envios e aguarda a manifestação do Administrador responsável. Não haverá repetição indefinida de notificações.
- Atingir o limite de lembretes não altera o estado **Em análise**, não transfere a titularidade e não aprova, rejeita ou libera a solicitação automaticamente.
- O controle de quantidade e agendamento dos lembretes deve ser individual por solicitação e protegido contra disparos duplicados ou ciclos de notificações.


## 58. Backend como autoridade exclusiva das regras de negócio (09/11/2026)

**Status: APROVADO pelo usuário.**

- O backend é a única autoridade para validar e executar regras de negócio do Alianza. O frontend nunca será considerado confiável nem fonte de verdade.
- Regras de autorização, permissões, validações, transições de estado, custeio, recálculos, vínculos, aprovações, exclusões, reativações, limites e agendamentos devem ser impostas no backend.
- Toda operação deve ser validada no backend mesmo quando a interface já tiver validado ou ocultado/bloqueado controles visuais.
- Chamadas diretas a APIs, manipulação de requisições, alterações no cliente, importações, operações em massa ou caminhos alternativos não podem contornar regras de negócio ou permissões.
- O frontend apresenta dados, coleta comandos e exibe resultados somente após confirmação de persistência/execução pelo backend; não pode declarar sucesso antecipadamente.
- Estados, contadores e controles que precisam sobreviver a atualização de página, encerramento de sessão ou reinício de serviço devem ser persistidos e controlados no backend.
- Esta regra é global e obrigatória para todos os módulos e fluxos do sistema.


## 59. Exclusividade de titularidade da análise e concorrência entre Administradores (09/11/2026)

**Status: APROVADO pelo usuário.**

- O primeiro Administrador cuja operação de início de análise for aceita pelo backend assume a solicitação e passa a ser seu responsável.
- O backend registra o Administrador responsável e o horário de início da titularidade.
- Enquanto a solicitação estiver **Em análise**, os demais Administradores podem consultar seus dados, mas não podem assumir a titularidade, aprovar ou rejeitar a solicitação.
- A interface deve informar que a solicitação está sob análise e identificar o Administrador responsável, respeitando as permissões de acesso.
- Não haverá tomada de controle forçada por outro Administrador.
- Se dois ou mais Administradores tentarem iniciar a análise simultaneamente, o backend deverá aceitar atomicamente apenas uma operação. As demais tentativas recebem o estado atualizado e a identificação do responsável, sem criar titularidades concorrentes.
- A exclusividade é regra de backend e não pode depender de bloqueio visual, estado local do navegador ou sincronização exclusivamente no frontend.
- Esta decisão consolida o comportamento funcional de exclusividade. Os mecanismos técnicos de concorrência, recuperação de falhas e liberação de análises abandonadas continuam sujeitos à especificação técnica, sem alterar as regras aprovadas.


## 60. Encerramento voluntário da análise sem decisão (09/11/2026)

**Status: APROVADO pelo usuário.**

- O Administrador responsável poderá encerrar formalmente sua análise sem aprovar ou rejeitar a solicitação, por meio da ação **Encerrar análise sem decisão**.
- A ação exigirá confirmação explícita antes de ser efetivada.
- Após confirmação e persistência pelo backend, a solicitação retornará ao estado **Pendente**, perderá a titularidade anterior e ficará disponível para outro Administrador.
- O encerramento voluntário deverá ser registrado na auditoria, identificando responsável, data/hora e solicitação.
- Fechar o navegador, sair do sistema ou permanecer inativo não equivale a encerramento voluntário: nesses casos a solicitação permanece **Em análise**, sob a titularidade atual.
- O limite de três lembretes por inatividade permanece válido e não provoca liberação automática.
- A transição de estado, liberação da titularidade e auditoria devem ocorrer de forma consistente no backend; a interface só informa sucesso após confirmação.


## 61. Nova assunção de solicitação após encerramento voluntário (09/11/2026)

**Status: APROVADO pelo usuário.**

- Após encerrar voluntariamente uma análise sem decisão, a solicitação retorna a **Pendente** e fica disponível para qualquer Administrador autorizado, inclusive para o mesmo Administrador que encerrou a análise anterior.
- Não haverá impedimento ou período de espera específico para que o mesmo Administrador assuma novamente a solicitação.
- Cada nova assunção inicia um novo ciclo de análise, com novo registro de responsável e data/hora de início, preservando integralmente os ciclos anteriores no histórico/auditoria.
- A nova assunção continua sujeita ao controle de titularidade exclusiva e à validação atômica do backend.


## 62. Perda inesperada de acesso durante análise (09/11/2026)

**Status: APROVADO pelo usuário.**

- Falha de conexão, encerramento inesperado da sessão, fechamento do navegador ou perda momentânea de acesso não encerram a análise nem liberam sua titularidade.
- A solicitação permanece **Em análise**, vinculada ao Administrador responsável, até que ele retome a análise ou execute formalmente **Encerrar análise sem decisão**.
- Ao autenticar-se novamente, o Administrador titular poderá retomar a análise, respeitadas as validações de autorização e estado feitas pelo backend.
- Outros Administradores podem consultar, mas não podem assumir, decidir ou tomar o controle enquanto a titularidade permanecer ativa.
- A titularidade e o estado são persistidos no backend; a sessão/frontend não é fonte de verdade.
- A regra não altera os lembretes já aprovados: após 30 minutos sem atividade, enviar lembrete ao responsável, repetindo a cada 30 minutos até o máximo de 3; depois, aguardar resposta sem liberar automaticamente a solicitação.


## 63. Transferência de titularidade após o terceiro lembrete (09/11/2026)

**Status: APROVADO pelo usuário.**

- A solicitação permanece **Em análise** e vinculada ao Administrador titular durante o ciclo de lembretes.
- Os lembretes são enviados ao titular: primeiro após 30 minutos de inatividade e os seguintes a cada 30 minutos, até o máximo de três.
- Após o envio efetivo do terceiro lembrete, a solicitação fica habilitada para que **outro Administrador** transfira a titularidade para si.
- A transferência não é automática. Exige ação explícita do Administrador que assumirá a solicitação e justificativa obrigatória.
- O backend valida atomicamente o estado da solicitação, a titularidade vigente, o envio do terceiro lembrete e a autorização do Administrador que solicita a transferência. Se as condições não forem mais verdadeiras ou outra operação concorrente tiver alterado o estado, a transferência é recusada.
- Após a transferência persistida, o novo Administrador passa a ser o único titular autorizado a analisar e decidir; o titular anterior perde a titularidade daquela análise.
- Registrar em auditoria/histórico o titular anterior, novo titular, justificativa, responsável pela transferência e data/hora. Preservar todos os ciclos e lembretes anteriores.
- A transferência não aprova nem rejeita a solicitação, não encerra seu fluxo e não apaga o histórico.
- A interface só confirma a transferência após sucesso da persistência no backend.


## 64. Notificação ao Administrador anterior após transferência de titularidade (09/11/2026)

**Status: APROVADO pelo usuário.**

- Após a persistência bem-sucedida de uma transferência de titularidade, o Administrador que perdeu a titularidade deve receber uma notificação.
- A notificação informa que a titularidade da solicitação foi transferida, identifica o novo Administrador responsável e apresenta a justificativa registrada para a transferência.
- A notificação deve referenciar a solicitação correspondente e não pode expor informações além das permitidas pelas regras de acesso.
- O envio/registro da notificação deve ser rastreável. A interface não pode informar que a transferência foi concluída antes da confirmação do backend.
- A notificação não restaura titularidade nem concede poder de decisão ao Administrador anterior.


## 65. Notificação ao novo titular após transferência (09/11/2026)

**Status: APROVADO pelo usuário.**

- Após a persistência bem-sucedida da transferência de titularidade, o novo Administrador responsável também deve receber uma notificação de que assumiu a solicitação.
- A notificação deve identificar a solicitação e oferecer acesso direto à análise e ao histórico anterior, respeitando as permissões aplicáveis.
- O novo titular deve conseguir consultar o contexto, as decisões e os registros anteriores necessários para dar continuidade à análise, sem apagar ou sobrescrever ciclos anteriores.
- O envio/registro da notificação deve ser rastreável. A interface só informa a transferência como concluída após persistência no backend.


## 66. Reinício do ciclo de lembretes após transferência (09/11/2026)

**Status: APROVADO pelo usuário.**

- Após uma transferência de titularidade ser persistida, inicia-se um novo ciclo de acompanhamento para o novo Administrador titular.
- A contagem de inatividade e de lembretes do titular anterior não é herdada pelo novo titular.
- O novo ciclo começa a partir do momento em que a transferência é efetivada no backend; o primeiro lembrete será devido após 30 minutos de inatividade do novo titular.
- Se permanecer inativo, os lembretes seguintes serão enviados a cada 30 minutos, até o máximo de três.
- Somente após o envio efetivo do terceiro lembrete desse novo ciclo, a solicitação ficará elegível para nova transferência por outro Administrador.
- Os ciclos e lembretes anteriores permanecem preservados no histórico/auditoria; reiniciar a contagem não apaga registros anteriores.
- O backend controla timestamps, contagem, elegibilidade e concorrência; notificações não podem ser duplicadas por reprocessamento.


## 67. Histórico integral de justificativas de transferência (09/11/2026)

**Status: APROVADO pelo usuário.**

- Ao assumir uma solicitação transferida, o novo Administrador deve ter acesso à justificativa da transferência imediatamente anterior e às justificativas de todas as transferências anteriores daquela solicitação.
- As justificativas integram o histórico permanente da solicitação, vinculadas a cada evento de transferência e aos respectivos titulares, responsáveis pela operação e datas/horários.
- O histórico deve permitir compreender a sequência de titularidades e os motivos informados, sem sobrescrita ou exclusão de justificativas anteriores.
- O acesso respeita as permissões administrativas aplicáveis; o novo titular recebe acesso ao histórico necessário para continuar a análise.


## 68. Histórico integral de atividades da análise na Central de Aprovações (09/11/2026)

**Status: APROVADO pelo usuário.**

- Cada solicitação da Central de Aprovações deve manter histórico cronológico, cumulativo e individual de suas atividades relevantes.
- Registrar, no mínimo: início formal da análise; retomada da análise após novo acesso; encerramento sem decisão; lembretes enviados, com ciclo, data/hora e resultado; transferências de titularidade e justificativas; aprovações e rejeições; consultas e demais ações relevantes realizadas durante a análise.
- Cada evento deve identificar a solicitação, o Administrador/ator responsável, data/hora, tipo de operação e resultado. Quando aplicável, registrar também o ciclo de titularidade e os dados necessários para compreender o contexto da ação.
- O histórico deve preservar a sequência dos acontecimentos, inclusive ciclos anteriores, sem sobrescrita ou exclusão pela interface.
- O backend é a fonte de verdade para geração, ordenação, integridade e autorização de acesso aos registros. O frontend não pode criar, alterar ou apagar eventos históricos por conta própria.
- O registro de consultas deve se limitar a consultas/ações relevantes para a rastreabilidade da análise; critérios exatos de relevância, granularidade, retenção e acesso permanecem pendentes de especificação técnica.
- A aprovação desta regra não define tecnologia, esquema de dados, endpoints, retenção legal ou implementação.


## 69. Linha do tempo única da solicitação na Central de Aprovações (09/11/2026)

**Status: APROVADO pelo usuário.**

- O histórico de cada solicitação deve ser apresentado em uma única linha do tempo cronológica, reunindo os eventos relevantes do ciclo de vida da solicitação.
- A linha do tempo deve integrar, conforme aplicável: início e retomada de análise, encerramento sem decisão, lembretes, transferências de titularidade e justificativas, consultas/ações relevantes, aprovação e rejeição.
- Cada evento deve apresentar as informações de identificação já aprovadas: ator responsável, data/hora, tipo de operação e resultado; incluir justificativa e ciclo de titularidade quando aplicável.
- A ordem deve refletir a sequência temporal real dos eventos, inclusive entre diferentes ciclos e titulares.
- A linha do tempo é uma forma unificada de consulta; não substitui nem altera os registros de auditoria mantidos pelo backend.
- Permissões de visualização continuam sendo aplicadas pelo backend. Critérios de filtros, paginação, agrupamento visual e detalhes de apresentação permanecem pendentes.


## 70. Filtros da linha do tempo da Central de Aprovações (09/11/2026)

**Status: APROVADO pelo usuário.**

- A linha do tempo única de cada solicitação deve permitir filtrar os eventos por **responsável** e por **tipo de evento**.
- Os filtros são recursos de consulta e não alteram, excluem, sobrescrevem ou modificam os registros históricos originais.
- A aplicação de filtros não deve comprometer a integridade nem a sequência cronológica dos eventos correspondentes ao resultado filtrado.
- Deve permanecer disponível a visão cronológica completa, sem filtros, reunindo todos os eventos aos quais o Administrador tenha permissão de acesso.
- O backend continua sendo a fonte de verdade e deve aplicar as permissões de acesso aos eventos e responsáveis; o frontend não pode ampliar a visibilidade por meio dos filtros.
- A aprovação define o comportamento funcional dos filtros, mas não define componentes visuais, paginação, tecnologia ou implementação técnica.


## 71. Seleção múltipla nos filtros da linha do tempo (09/11/2026)

**Status: APROVADO pelo usuário.**

- O filtro por responsável deve permitir selecionar múltiplos responsáveis simultaneamente.
- O filtro por tipo de evento deve permitir selecionar múltiplos tipos simultaneamente.
- Os dois filtros podem ser combinados na mesma consulta.
- Deve ser possível remover seleções individualmente e limpar todos os filtros para retornar à visão cronológica completa.
- A seleção múltipla altera somente os critérios de consulta; não modifica, exclui ou sobrescreve eventos históricos.
- A ordem cronológica dos eventos retornados deve ser preservada e as permissões continuam sendo aplicadas pelo backend.


## 72. Aplicação explícita dos filtros da linha do tempo (09/11/2026)

**Status: APROVADO pelo usuário.**

- A seleção ou remoção de responsáveis e tipos de evento não deve atualizar imediatamente os resultados da linha do tempo.
- O Administrador define os critérios desejados e aciona explicitamente o botão **Aplicar filtros** para executar a consulta.
- Após a aplicação, a linha do tempo apresenta os eventos correspondentes aos critérios selecionados, preservando a ordem cronológica e as permissões aplicáveis.
- Deve existir ação para limpar os filtros e retornar à visão cronológica completa.
- A escolha e edição dos critérios antes de aplicar não alteram os registros históricos nem a consulta atualmente exibida.


## 73. Preservação dos resultados durante edição dos filtros (09/11/2026)

**Status: APROVADO pelo usuário.**

- A interface deve distinguir os critérios atualmente aplicados dos critérios que o Administrador está editando.
- Enquanto o Administrador altera seleções de responsáveis ou tipos de evento, a linha do tempo continua exibindo os resultados da última consulta aplicada.
- Somente após acionar **Aplicar filtros** os novos critérios passam a ser aplicados e os resultados são atualizados.
- Se o Administrador cancelar ou descartar a edição, os critérios anteriormente aplicados e seus resultados permanecem vigentes, sem alteração.
- A edição temporária dos critérios não modifica os registros históricos nem a consulta aplicada.
- O backend continua validando permissões e executando a consulta; o estado visual de edição não é fonte de verdade para autorização ou integridade.


## 74. Aviso ao sair com filtros ainda não aplicados (09/11/2026)

**Status: APROVADO pelo usuário.**

- Se houver critérios de filtro alterados em edição, ainda não aplicados, e o Administrador tentar sair da tela, o sistema deve exibir uma notificação de confirmação antes de abandonar a tela.
- A notificação deve oferecer duas ações claras:
  - **Descartar alterações e sair:** descarta somente os critérios temporários em edição, preservando os filtros anteriormente aplicados e os resultados correspondentes.
  - **Permanecer na tela:** fecha a notificação e mantém a tela e os critérios temporários em edição.
- Nenhuma alteração de filtro deve ser descartada sem a escolha explícita do Administrador.
- Se não houver alterações temporárias pendentes, a navegação não deve ser bloqueada por esse aviso.
- O aviso protege apenas o estado de edição dos filtros; não modifica registros históricos nem a consulta anteriormente aplicada.

## Navegação global e proteção de filtros não aplicados — decisão aprovada em 09/11/2026

- O Alianza terá, no cabeçalho padrão global, botões visíveis **Voltar** e **Avançar**, seguindo convenções comuns de navegação de sites e sistemas.
- Os botões estarão disponíveis de forma consistente nas telas do sistema, respeitando os limites e o histórico de navegação existente.
- A navegação também deverá oferecer comandos de teclado compatíveis. O atalho **Esc** deverá executar a ação de voltar dentro do Alianza quando aplicável, sem presumir que seja um comando universal do navegador e sem interferir indevidamente em ações contextuais, como fechar modais.
- A navegação por botão, teclado ou controles do navegador deverá respeitar a proteção contra perda de alterações: se houver filtros não aplicados ou outra edição protegida, solicitar confirmação antes de abandonar a tela.
- Se o usuário optar por permanecer, manter integralmente a edição em andamento. Se optar por descartar e sair, preservar os últimos filtros aplicados e seus resultados.
- A cobertura deverá considerar navegação interna, voltar/avançar do navegador e atualização/recarregamento; para fechamento de aba/janela, utilizar o mecanismo nativo de aviso do navegador quando disponível, sem prometer modal personalizado.
- Regras de negócio, validação de estado e proteção contra perda de dados devem ser garantidas pelo backend quando envolverem persistência; o frontend não será autoridade.
- Detalhes de posicionamento responsivo, comportamento quando não houver histórico e compatibilidade de atalhos permanecem sujeitos à especificação técnica e aos critérios de aceite.

### Estado dos botões de navegação sem histórico disponível — decisão aprovada em 09/11/2026

- Quando não houver uma tela anterior disponível, o botão **Voltar** ficará desabilitado.
- Quando não houver uma tela posterior disponível, o botão **Avançar** ficará desabilitado.
- Botões desabilitados não executam navegação artificial nem alteram o histórico.
- O estado dos botões deve refletir o histórico real de navegação e atualizar quando esse histórico mudar.

### Preservação do contexto na navegação Voltar/Avançar — decisão aprovada em 09/11/2026

- Ao navegar por **Voltar** ou **Avançar**, o sistema deve preservar e restaurar o contexto da tela correspondente, incluindo posição de rolagem e filtros aplicados.
- A restauração deve apresentar o usuário no contexto em que estava antes de sair daquela tela, respeitando permissões e a validade atual dos dados.
- Critérios de filtro temporariamente alterados, mas ainda não aplicados, continuam sujeitos à confirmação de saída já aprovada; não devem ser confundidos com filtros aplicados.
- Se dados tiverem mudado enquanto a tela estava fora de foco, atualizar os resultados conforme as regras de atualização em tempo real, preservando os critérios de consulta quando ainda válidos.
- Detalhes técnicos de armazenamento/restauração do estado e comportamento diante de dados removidos ou permissões alteradas permanecem pendentes.

### Atualização do contexto ao retornar à tela — decisão aprovada em 09/11/2026

- Ao retornar a uma tela por **Voltar** ou **Avançar**, o sistema deve revalidar os dados e as permissões do usuário; não pode apresentar como atuais dados que tenham ficado desatualizados enquanto a tela estava fora de foco.
- Se um registro tiver sido excluído ou se o usuário tiver perdido permissão de acesso enquanto estava fora da tela, a tela deve ser atualizada conforme o estado confirmado pelo backend e informar claramente o que mudou, sem expor dados que já não sejam autorizados.
- A restauração de filtros e do contexto de navegação não prevalece sobre exclusões, alterações de dados ou mudanças de permissão posteriores; critérios ainda válidos podem ser preservados, mas os resultados devem refletir a situação atual.
- O backend é a autoridade para validar existência, estado e permissões; a interface apenas apresenta o resultado confirmado.

### Comunicação das alterações ao retornar à tela — decisão aprovada em 09/11/2026

- Ao retornar a uma tela, o sistema deve comunicar alterações relevantes encontradas desde a última visualização por meio de avisos objetivos e não intrusivos.
- Registro excluído: informar que o registro foi excluído e removê-lo dos resultados atuais.
- Permissão revogada: informar que o acesso ao registro foi alterado e impedir sua visualização; a mensagem não pode revelar dados do registro ou qualquer informação protegida.
- Dados modificados: atualizar as informações e indicar que houve atualização desde a última visita.
- Quando houver várias alterações, apresentar um único resumo consolidado, evitando notificações consecutivas e repetitivas.
- Quando não houver alterações relevantes, retornar normalmente, sem exibir aviso.
- O conteúdo das mensagens deve respeitar as permissões vigentes e não pode expor dados que o usuário deixou de estar autorizado a consultar.

### Conteúdo do resumo consolidado de alterações — decisão aprovada em 09/11/2026

- Quando houver alterações de categorias diferentes desde a última visualização, o resumo consolidado deve apresentar a quantidade de ocorrências por categoria, separadamente.
- Exemplos de categorias: registros excluídos, registros atualizados e alterações de permissão.
- O resumo deve permitir compreender o volume e a natureza das mudanças sem exigir que o usuário abra cada aviso individualmente.
- A apresentação por quantidade não autoriza revelar nomes, identificadores ou outros dados de registros cujo acesso tenha sido revogado; as regras de autorização e confidencialidade continuam prevalecendo.

### Sino de notificações e alertas sonoros — decisão aprovada em 09/11/2026

- O resumo consolidado de alterações ficará acessível pelo sino de notificações, como ponto permanente de consulta, não dependendo de uma mensagem temporária na tela.
- O sino deve apresentar um indicador visual enquanto houver notificações não lidas.
- Ao acionar o sino, o usuário poderá consultar o resumo consolidado por categoria.
- O indicador visual deve permanecer até que as notificações correspondentes sejam marcadas como lidas.
- O sistema oferecerá opções de alerta sonoro, incluindo ativar ou desativar o som.
- Alertas sonoros devem respeitar as preferências do usuário e não podem se repetir indefinidamente nem produzir excesso de notificações.
- O sino, o resumo e os alertas sonoros devem respeitar as permissões vigentes e não revelar dados protegidos.
- Detalhes de configuração, seleção de sons, volume, regras de disparo, agrupamento, frequência e sincronização entre dispositivos permanecem pendentes.

### Preferências individuais de alertas sonoros — decisão aprovada em 09/11/2026

- As preferências de alerta sonoro serão individuais por usuário, não uma configuração global imposta a toda a empresa.
- Cada usuário poderá ativar ou desativar o som, escolher entre diferentes opções de sons, ajustar o volume e testar o som antes de salvar suas preferências.
- As preferências salvas devem ser aplicadas aos alertas daquele usuário, respeitando as regras gerais de notificações e os limites contra repetição excessiva.
- Detalhes de persistência, disponibilidade de sons, compatibilidade dos dispositivos e comportamento quando o navegador/sistema bloquear áudio permanecem pendentes.


## Configurações individuais de notificações — localização aprovada em 09/11/2026

- Disponibilizar uma área própria em **Configurações → Notificações**.
- Centralizar nessa área as preferências individuais de alertas sonoros já aprovadas: ativar/desativar, escolher som, ajustar volume e testar antes de salvar.
- Manter as preferências individualizadas por usuário, sem impor a configuração de uma pessoa aos demais usuários ou à empresa.
- Integrar essa configuração ao sino de notificações, que permanece como ponto de acesso aos avisos e indicador de notificações não lidas.
- Desativar o som não desativa nem oculta notificações visuais.
- Persistência, catálogo de sons, compatibilidade e tratamento de bloqueios de áudio permanecem pendentes de especificação técnica.


## Sino de notificações no cabeçalho global — decisão aprovada em 09/11/2026

- O sino de notificações deve permanecer visível no cabeçalho global padrão do Alianza, independentemente do módulo ou tela em que o usuário esteja.
- O sino mantém acesso ao resumo consolidado e ao indicador de notificações não lidas em toda a navegação autenticada, respeitando permissões e confidencialidade.
- A presença global do sino não altera as preferências individuais de alertas sonoros nem implica que o som esteja sempre ativado.

### Abertura do painel do sino de notificações — decisão aprovada (09/11/2026)

- Ao acionar o sino no cabeçalho global, abrir o painel de notificações imediatamente abaixo do sino, alinhado ao canto superior direito da interface.
- O painel deve funcionar como elemento flutuante/suspenso, mantendo o usuário na tela e no módulo atuais, sem navegação para outra página.
- O painel deve permitir consultar o resumo e as notificações respeitando as permissões e regras de confidencialidade já aprovadas.
- Esta decisão define o comportamento funcional e a posição do painel; dimensões, responsividade, interação de fechamento e detalhes visuais permanecem pendentes.

### Fechamento do painel do sino de notificações — decisão aprovada (09/11/2026)

- O painel deve fechar ao clicar novamente no sino que o abriu.
- O painel deve fechar ao clicar fora de sua área.
- Enquanto o painel estiver aberto, a tecla **Esc** deve fechá-lo, sem navegar para outra tela.
- O fechamento do painel não marca notificações como lidas nem altera seu conteúdo ou estado; a leitura deve seguir ação própria já definida.
- Os três comportamentos são formas equivalentes de dispensar o painel e não devem provocar perda de contexto da tela atual.
- Detalhes de acessibilidade, foco de teclado e compatibilidade permanecem sujeitos à especificação técnica.

### Largura e adaptação do painel de notificações — decisão aprovada (09/11/2026)

- A largura do painel de notificações será adaptável ao espaço disponível, em vez de depender de uma largura fixa para todos os dispositivos.
- O painel deve respeitar os limites da área visível da tela, sem ultrapassar as bordas ou ficar parcialmente inacessível.
- Em telas maiores, manter apresentação compacta e alinhada ao sino no canto superior direito; em telas menores, adaptar a largura para preservar leitura e interação.
- A adaptação não deve retirar o usuário da tela ou do módulo atual nem alterar as regras de abertura e fechamento já aprovadas.
- Valores exatos de largura, margens, pontos de quebra e comportamento em dispositivos específicos permanecem pendentes de especificação visual/técnica.

### Conteúdo inicial do painel de notificações — decisão aprovada (09/11/2026)

- Ao abrir, o painel deve apresentar uma relação de notificações recentes.
- Cada notificação deve exibir, no mínimo, data, horário, categoria e indicação visual de leitura/não leitura.
- O painel deve oferecer acesso ao histórico completo de notificações, sem obrigar o usuário a sair do módulo/tela atual para consultar as notificações recentes.
- A indicação de leitura deve refletir o estado real da notificação; abrir ou fechar o painel, por si só, não altera esse estado.
- A consulta e o histórico devem respeitar permissões e confidencialidade.
- Quantidade de notificações recentes, ordenação, paginação, categorias definitivas e ação para marcar como lida permanecem pendentes de detalhamento.

### Quantidade de notificações recentes no painel — decisão aprovada (09/11/2026)

- O painel do sino deve exibir inicialmente as **10 notificações mais recentes** para o usuário autenticado.
- A seleção das dez notificações deve considerar a ordenação cronológica decrescente, conforme data/hora registrada pelo backend.
- Notificações anteriores devem continuar disponíveis pelo acesso ao histórico completo.
- A consulta deve respeitar permissões, confidencialidade e o estado real de leitura de cada notificação.
- Critérios de paginação/carregamento do histórico e tratamento de notificações com data/hora igual permanecem pendentes de especificação técnica.

### Marcação de notificações como lidas — decisão aprovada (09/11/2026)

- O usuário deve poder marcar cada notificação individualmente como **lida**.
- O painel deve oferecer também a ação **Marcar todas como lidas**, aplicável às notificações que o usuário tem autorização para visualizar e que estejam não lidas no momento da execução.
- A marcação de leitura deve ser uma ação explícita; abrir ou fechar o painel não altera o estado de leitura.
- Após confirmação de persistência pelo backend, atualizar os indicadores de leitura das notificações e o contador de não lidas no sino.
- A operação deve ser vinculada ao usuário autenticado, respeitar permissões e ser persistida no backend; o frontend não pode ser autoridade nem declarar sucesso antes da confirmação.
- Registrar a alteração de estado de leitura conforme a política de auditoria/notificações a ser detalhada; retenção e histórico específico de leitura permanecem pendentes.

### Categorias de notificações — decisão aprovada (09/11/2026)

O sistema utilizará inicialmente as seguintes categorias para organizar as notificações:

- **Aprovações**
- **Alterações de cadastro**
- **Exclusões**
- **Segurança**
- **Sistema**

As categorias devem ser apresentadas de forma clara no painel e no histórico de notificações. A classificação de cada evento, eventuais subcategorias, ícones, cores, filtros e regras para eventos que possam se enquadrar em mais de uma categoria permanecem pendentes de detalhamento. A lista poderá ser ampliada mediante decisão aprovada, sem criar categorias automaticamente por iniciativa do frontend.

### Prioridade visual das notificações — decisão aprovada (09/11/2026)

As notificações terão quatro níveis de prioridade:

- **Crítica**
- **Alta**
- **Normal**
- **Baixa**

A prioridade é um atributo distinto da categoria da notificação. A categoria informa o assunto (Aprovações, Alterações de cadastro, Exclusões, Segurança ou Sistema); a prioridade indica o grau de atenção exigido. A classificação de cada evento deverá ser definida por regras de negócio no backend, não por decisão do frontend. Critérios objetivos de enquadramento, apresentação visual/sonora, escalonamento, filtros e eventual tratamento especial de notificações críticas permanecem pendentes de especificação.

### Critérios gerais de prioridade das notificações — decisão aprovada (09/11/2026)

A prioridade deverá refletir a urgência e o impacto do evento, segundo critérios gerais:

- **Crítica:** risco imediato à segurança ou à integridade dos dados.
- **Alta:** ação administrativa importante que exige atenção rápida.
- **Normal:** atualizações e solicitações que precisam ser acompanhadas, sem caracterização de urgência alta ou crítica.
- **Baixa:** avisos informativos, sem necessidade de ação imediata.

O enquadramento de eventos concretos será realizado por regras de negócio no backend. Estes critérios gerais não constituem, por si só, uma matriz completa de classificação: o mapeamento de cada evento, eventuais exceções, apresentação visual/sonora, escalonamento e tratamento especial de notificações críticas ainda precisam ser especificados. A prioridade não deve ser elevada indiscriminadamente, para preservar o significado dos níveis de urgência.

### Reconhecimento e ciclo de vida das notificações críticas — decisão aprovada (09/11/2026)

- Notificações de prioridade **Crítica** terão destaque visual próprio no painel e permanecerão identificáveis enquanto aguardarem reconhecimento.
- O ciclo do alerta distinguirá três estados: **Aguardando reconhecimento**, **Reconhecido** e **Resolvido**. Reconhecimento e resolução são eventos diferentes; abrir ou marcar como lida não equivale a reconhecer, e reconhecer não significa que o problema foi solucionado.
- Qualquer Administrador autorizado a visualizar o alerta poderá reconhecê-lo. O primeiro reconhecimento aceito pelo backend ficará registrado como reconhecimento responsável; os demais Administradores poderão consultar quem reconheceu e quando.
- O backend validará autorização e concorrência atomicamente, impedindo reconhecimentos simultâneos conflitantes ou sobrescrita silenciosa do responsável.
- O reconhecimento registrará ator, data/hora e resultado na auditoria. Não apagará nem alterará a ocorrência original, não a resolverá automaticamente e não removerá seu histórico.
- Após reconhecido, o alerta deixará de constar como aguardando reconhecimento, mas continuará visível e acompanhável enquanto não estiver resolvido, com indicação distinta de seu estado.
- O sino apresentará a quantidade de alertas críticos ainda não reconhecidos.
- O sistema evitará repetição sonora indefinida. Preferências individuais de som e permissões continuam aplicáveis.
- Leitura, reconhecimento e resolução são estados/ações distintos e devem ser mantidos separadamente.
- Critérios para declarar uma ocorrência resolvida, responsáveis pela resolução, evidências exigidas, eventual reabertura, escalonamento e detalhes visuais/sonoros permanecem pendentes.

### Resolução de notificações críticas — decisão aprovada (09/11/2026)

- Um Administrador autorizado poderá declarar uma notificação crítica como **Resolvida**.
- A resolução exigirá justificativa obrigatória, registrada junto ao evento.
- O backend validará autorização, estado atual e concorrência antes de efetivar a resolução; a interface só confirmará após persistência bem-sucedida.
- A resolução será registrada na auditoria com Administrador responsável, data/hora, justificativa e resultado.
- A resolução não apagará a ocorrência original, o reconhecimento anterior nem a linha do tempo do alerta.
- A ação de resolver será distinta de marcar como lida e de reconhecer o alerta.
- Critérios objetivos para considerar cada tipo de ocorrência resolvido, evidências/documentos eventualmente exigidos, reabertura e escalonamento permanecem pendentes de definição.

### Reabertura de notificações críticas — decisão aprovada (09/11/2026)

- Uma notificação crítica marcada como **Resolvida** poderá ser reaberta somente por um Administrador autorizado.
- A reabertura exigirá justificativa obrigatória.
- O backend validará autorização, estado atual e concorrência antes de efetivar a reabertura; a interface só confirmará após persistência bem-sucedida.
- A reabertura será registrada na mesma linha do tempo do alerta, com Administrador responsável, data/hora, justificativa e resultado.
- A resolução anterior e todos os eventos anteriores permanecerão preservados no histórico; reabrir não apagará nem sobrescreverá a resolução anterior.
- Após a reabertura, o alerta retornará ao estado **Aguardando reconhecimento** e exigirá novo reconhecimento por Administrador autorizado. O reconhecimento anterior permanecerá preservado no histórico, mas não satisfará o novo ciclo.
- O backend controlará a transição de estado e a concorrência; a interface só confirmará a reabertura após persistência bem-sucedida.

### Lembretes de alertas críticos sem reconhecimento — decisão aprovada (09/11/2026)

- Se um alerta crítico permanecer em **Aguardando reconhecimento**, o primeiro lembrete será enviado após 30 minutos sem reconhecimento.
- Enquanto permanecer sem reconhecimento, novos lembretes serão enviados em intervalos de 30 minutos, até o limite máximo de três lembretes por ciclo.
- Os lembretes serão direcionados aos Administradores autorizados a visualizar o alerta.
- Ao ocorrer reconhecimento válido, os lembretes daquele ciclo serão interrompidos.
- Cada reabertura inicia um novo ciclo de reconhecimento e reinicia a contagem de lembretes, sem apagar os ciclos anteriores do histórico.
- Após o envio efetivo do terceiro lembrete, não haverá novos lembretes automáticos naquele ciclo. O alerta permanecerá aguardando reconhecimento até uma ação administrativa; não haverá reconhecimento, resolução, transferência de titularidade ou encerramento automático.
- O backend controlará agendamento, contagem, elegibilidade, envio efetivo e concorrência. Falhas de envio não poderão ser contabilizadas como lembrete efetivamente enviado.
- Cada lembrete e resultado de envio será registrado na linha do tempo/auditoria, com data/hora e ciclo correspondente.

### Apresentação visual de alertas críticos — decisão aprovada (09/11/2026)

- O sino global exibirá indicador visual vermelho e quantidade de alertas críticos em **Aguardando reconhecimento**. O indicador/contagem será atualizado somente com estado confirmado pelo backend e deixará de incluir cada alerta após seu reconhecimento válido.
- O painel aberto pelo sino dará destaque visual próprio aos alertas críticos ainda não reconhecidos, com prioridade visual sobre notificações não críticas.
- Entre alertas críticos, será preservada a ordem cronológica, do mais recente para o mais antigo. As demais notificações serão apresentadas depois, também em ordem cronológica.
- Cada alerta crítico exibirá sua prioridade e estado operacional de forma textual, sem depender exclusivamente de cor ou som.
- Alertas críticos reconhecidos continuarão identificados como críticos, mas com apresentação distinta do estado **Aguardando reconhecimento**.
- Alertas resolvidos deixarão a lista de pendências ativas, mas permanecerão disponíveis no histórico completo.
- Alertas reabertos voltarão a receber o destaque de **Aguardando reconhecimento** e serão contabilizados novamente no sino, conforme o novo ciclo.
- O painel não marcará notificações como lidas, reconhecidas ou resolvidas apenas por ser aberto ou fechado.
- A apresentação visual não substituirá controles de acesso nem regras de negócio. Classificação, prioridade, estado e contagens serão definidos/validados pelo backend; o frontend apenas apresentará os dados confirmados.
- O destaque visual deverá ser claro e consistente, sem transformar notificações não críticas em alertas urgentes. Detalhes finais de cores, ícones, acessibilidade e responsividade permanecem sujeitos à especificação visual e testes de aceite.

### Alertas críticos quando Administradores estiverem desconectados — decisão aprovada (09/11/2026)

- A criação e a manutenção de um alerta crítico não dependerão de haver Administrador conectado. O alerta e sua linha do tempo serão persistidos no backend normalmente.
- Notificações e lembretes destinados aos Administradores autorizados serão registrados de forma durável no sistema de notificações do backend, mesmo quando os destinatários estiverem desconectados. Ao retornarem e sincronizarem o sistema, os usuários autorizados poderão consultar os avisos pendentes e o histórico correspondente.
- A desconexão de todos os Administradores não pausará, reiniciará nem estenderá os prazos dos alertas ou dos ciclos de lembretes. Os prazos continuarão sendo controlados pelo backend, com base nos horários registrados.
- O registro de cada lembrete deverá preservar o horário previsto, o resultado da persistência/entrega no sistema de notificações e o ciclo correspondente. Falhas reais de persistência/entrega continuarão sujeitas à regra já aprovada de não contabilização como envio efetivo.
- A reconexão não poderá criar duplicatas nem disparar novamente sons de forma excessiva. Os avisos atrasados serão apresentados como notificações pendentes, respeitando a ordem e o estado atual do alerta; o histórico dos eventos não será apagado.
- Antes de exibir o conteúdo após a reconexão, o backend deverá revalidar as permissões atuais do usuário. A desconexão não concede acesso e a revogação de permissão impede a exposição de conteúdo protegido.
- Nenhuma ação será executada automaticamente porque os Administradores estavam desconectados: o alerta não será reconhecido, resolvido, encerrado ou transferido por esse motivo.


### Ocorrências críticas simultâneas — decisão aprovada (09/11/2026)

- Cada ocorrência crítica será tratada como alerta independente, com identificador próprio e ciclo de vida próprio.
- Cada alerta manterá sua própria prioridade, estado, reconhecimento, resolução, eventual reabertura, lembretes e linha do tempo.
- Reconhecer, resolver ou reabrir um alerta não alterará o estado nem os prazos dos demais alertas.
- A contagem do sino corresponderá ao total de alertas críticos distintos em **Aguardando reconhecimento**, sem agrupar ocorrências diferentes em um único registro.
- O painel poderá apresentar vários alertas simultaneamente, mantendo cada ocorrência identificável e seu histórico acessível.
- O backend será responsável por persistência, identidade, autorização, concorrência, contagens e transições independentes; o frontend apenas apresentará os estados confirmados.
- Operações em lote, agrupamento que esconda identidades ou resolução conjunta não estão autorizados por esta decisão e exigem definição específica antes de serem oferecidos.


### Limite de alertas críticos exibidos simultaneamente — decisão aprovada (09/11/2026)

- O painel exibirá no máximo **5 alertas críticos simultaneamente** na área de visualização inicial, para evitar sobrecarga e preservar a legibilidade.
- Quando houver mais de cinco alertas críticos, os excedentes permanecerão registrados e acessíveis por paginação ou pela opção **Ver todos**; não poderão ser descartados, ocultados permanentemente ou perder seu histórico.
- A ordenação inicial será da ocorrência mais recente para a mais antiga, respeitando a prioridade e o estado definidos pelo backend.
- O contador do sino continuará representando o total de alertas críticos distintos em **Aguardando reconhecimento**, inclusive os que não estiverem na primeira visualização de cinco itens.
- O limite de cinco é exclusivamente de apresentação simultânea; não limita a quantidade de alertas que o sistema pode registrar ou manter pendentes.
- A identidade, o reconhecimento, a resolução, a reabertura, os lembretes e a linha do tempo de cada alerta continuarão independentes.
- O backend fornecerá os dados, a contagem e as permissões; o frontend aplicará o limite de apresentação sem alterar o estado dos alertas.


### Reincidência de manifestações em alertas críticos — decisão aprovada (09/11/2026)

- Quando uma nova manifestação corresponder à mesma ocorrência crítica que já possui alerta aberto/não resolvido, o sistema não criará um segundo alerta para duplicar a ocorrência.
- A nova manifestação será registrada na linha do tempo do alerta original, preservando data/hora, origem e informações necessárias para auditoria e acompanhamento.
- Problemas efetivamente distintos deverão gerar alertas independentes, cada um com identidade, estado, reconhecimento, resolução, lembretes e linha do tempo próprios.
- A correlação entre uma nova manifestação e uma ocorrência já aberta deverá ser validada pelo backend; o frontend não poderá decidir sozinho que dois eventos são iguais.
- A identificação da mesma ocorrência utilizará uma chave de correlação gerada e validada exclusivamente pelo backend.
- Para vincular uma nova manifestação a um alerta existente, o backend deverá confirmar, no mínimo: mesma origem/módulo, mesmo tipo de falha ou regra crítica, mesmo registro/recurso/entidade afetada e mesma chave de correlação.
- A vinculação só poderá ocorrer enquanto o alerta original estiver aberto e não resolvido. Um alerta reconhecido, mas ainda não resolvido, continua elegível; reconhecimento não equivale a resolução.
- Se o alerta anterior já estiver resolvido, uma manifestação posterior será tratada como nova ocorrência e gerará novo alerta.
- Se a manifestação afetar outro registro/recurso, corresponder a outro tipo de falha ou não houver evidência suficiente para confirmar equivalência, o backend deverá criar alerta independente. Na dúvida, não agrupar.
- A chave e a decisão de correlação não poderão ser fornecidas ou impostas pelo frontend. O backend controlará geração, validação, concorrência e vinculação de forma auditável.
- A definição da estrutura técnica da chave e dos atributos específicos por tipo de ocorrência permanece pendente de especificação técnica antes da implementação.
- A inclusão de uma manifestação em alerta existente não poderá apagar, substituir ou reiniciar silenciosamente o histórico, o reconhecimento ou os prazos do alerta original.


### Nova ocorrência após resolução de alerta crítico — decisão aprovada (09/11/2026)

- Se um problema voltar a se manifestar após o alerta anterior ter sido formalmente resolvido, o sistema criará um novo alerta, com identificador e ciclo de vida próprios.
- O novo alerta manterá uma referência histórica ao alerta anterior relacionado, sem alterar o estado **Resolvido** do alerta anterior.
- A relação histórica não significa reabertura, continuidade automática ou transferência de reconhecimento, responsável, lembretes ou prazos.
- O novo alerta seguirá o fluxo normal de classificação, reconhecimento, lembretes, resolução e auditoria.
- A relação entre os alertas será validada e persistida pelo backend; o frontend apenas apresentará a referência autorizada.
- A referência histórica não poderá expor informações de alertas anteriores a usuários sem permissão para consultá-los.


### Histórico de reincidências de alertas críticos — decisão aprovada (09/11/2026)

- O painel administrativo terá uma visualização própria de **Histórico de reincidências**, separada da lista de alertas críticos pendentes.
- A visualização permitirá consultar grupos de alertas relacionados à mesma ocorrência ao longo do tempo, mantendo cada alerta como registro independente.
- Para cada relação histórica, serão apresentados, conforme permissão: identificadores dos alertas relacionados, datas de criação e resolução, estados e quantidade de ocorrências/alertas vinculados.
- A consulta histórica não altera estado, reconhecimento, responsável, prazos ou resolução de qualquer alerta e não executa ações em lote.
- Alertas pendentes continuarão na área de pendências; a visualização histórica não os substituirá nem os ocultará.
- O backend será responsável por manter as relações, quantidades e dados apresentados, validar permissões e preservar a trilha de auditoria. O frontend apenas exibirá os dados autorizados.
- A consulta deverá respeitar as permissões de acesso aos alertas relacionados, sem revelar dados protegidos de ocorrências ou registros não autorizados.


### Filtros do histórico de reincidências — decisão aprovada (09/11/2026)

- O Histórico de reincidências permitirá filtrar por período, tipo de ocorrência, estado do alerta e identificação do registro/recurso afetado, respeitando as permissões do usuário.
- Os filtros serão editados sem disparar consultas automaticamente. A consulta somente será executada quando o usuário acionar explicitamente **Aplicar filtros**.
- Enquanto os critérios estiverem sendo editados, os resultados da última consulta aplicada permanecerão visíveis e inalterados.
- O usuário poderá descartar a edição dos critérios sem alterar os filtros e resultados anteriormente aplicados.
- A aplicação dos filtros será processada pelo backend, que validará parâmetros, autorização e escopo dos dados antes de retornar resultados.
- A consulta não alterará alertas, relações históricas, estados ou registros de auditoria; será somente leitura, sem ações em lote.


### Paginação do histórico de reincidências — decisão aprovada (09/11/2026)

- A paginação do Histórico de reincidências terá **20 registros por página** como padrão.
- O usuário poderá selecionar 20, 50 ou 100 registros por página.
- O sistema não carregará todo o histórico de uma só vez; o backend retornará apenas a página solicitada, respeitando filtros, ordenação, permissões e escopo autorizado.
- A troca de página ou de quantidade por página não poderá alterar os alertas nem seus históricos; trata-se apenas de navegação de consulta.
- A paginação deverá manter os filtros aplicados e a ordenação vigente enquanto o usuário navega entre páginas.
- O backend validará os parâmetros de paginação e evitará exposição de registros fora do escopo autorizado.
### Exportação do histórico de reincidências — decisão aprovada (09/11/2026)

- O Histórico de reincidências permitirá exportar os resultados em **Excel** e **PDF**.
- A exportação respeitará os filtros e o escopo da consulta efetivamente aplicados; critérios apenas editados e ainda não aplicados não poderão alterar silenciosamente o conteúdo exportado.
- O backend validará a autorização do usuário, inclusive as permissões administrativas aplicáveis, no momento da solicitação e da geração do arquivo.
- A exportação conterá somente registros e campos que o solicitante esteja autorizado a consultar, sem ampliar acesso por meio do arquivo gerado.
- Cada operação de exportação será registrada no Log de Atividades/auditoria, com usuário, data/hora, formato solicitado, filtros/escopo aplicados e resultado da operação, sem registrar conteúdo sensível desnecessário.
- A exportação é uma operação de consulta: não altera alertas, relações históricas, estados ou registros de origem.
- A geração e a disponibilização do arquivo só serão apresentadas como concluídas após confirmação do backend; falhas ou interrupções não poderão ser indicadas como sucesso.
- Limites de volume, expiração/armazenamento temporário dos arquivos, proteção contra compartilhamento indevido e critérios de formatação permanecem pendentes de especificação técnica.

### Proteção dos arquivos exportados do histórico de reincidências — decisão aprovada (09/11/2026)

- Os arquivos exportados serão temporários e não terão armazenamento permanente automático.
- O acesso será disponibilizado por link individual, vinculado ao usuário autorizado que solicitou a exportação.
- O link expirará automaticamente após **30 minutos**.
- Os arquivos não poderão ser disponibilizados por endereço público ou acesso anônimo.
- No momento do download, o backend deverá revalidar a identidade, a autorização e as permissões atuais do usuário.
- O backend controlará geração, armazenamento temporário, vínculo do link ao usuário, expiração e autorização de download.
- A interface não poderá confirmar disponibilidade ou download antes da confirmação correspondente do backend.
- A implementação deverá impedir que o compartilhamento do link, por si só, conceda acesso a outro usuário.

### Limites de processamento e volume da exportação — decisão aprovada (09/11/2026)

- Cada usuário poderá manter no máximo **1 exportação em processamento** por vez.
- Se o usuário solicitar outra exportação enquanto já houver uma em processamento, o sistema deverá informar que existe uma solicitação em andamento e não iniciar uma segunda simultaneamente.
- Cada arquivo de exportação poderá conter no máximo **10.000 registros**.
- Consultas com mais de 10.000 registros deverão ser divididas em arquivos menores, cada um respeitando o limite máximo; não será permitido gerar um único arquivo acima desse limite.
- Os limites serão impostos e validados pelo backend; não poderão depender exclusivamente de controles ou validações do frontend.
- A interface informará o estado da solicitação com base no retorno confirmado pelo backend, sem indicar conclusão antecipada.
- Regras técnicas de contagem, concorrência entre solicitações simultâneas, retomada após falha e experiência de divisão de consultas permanecem pendentes de especificação.

### Tratamento de falha na exportação — decisão aprovada (09/11/2026)

- Toda falha de exportação deverá ser registrada no Log de Atividades, com identificação da solicitação, usuário, data/hora e resultado da operação.
- Arquivos incompletos ou cuja integridade não tenha sido confirmada não poderão ser disponibilizados para download.
- A vaga de processamento do usuário somente será liberada após o backend confirmar o encerramento da tarefa, inclusive em caso de falha.
- Após a confirmação do encerramento, o usuário poderá solicitar novamente a exportação.
- Uma solicitação que falhou não será contabilizada nem apresentada como exportação concluída.
- O backend será responsável por determinar e persistir o estado final da tarefa; a interface apenas refletirá o resultado confirmado.

### Cancelamento de exportação em processamento — decisão aprovada (09/11/2026)

- O usuário que solicitou uma exportação poderá solicitar seu cancelamento enquanto ela estiver em processamento.
- O pedido de cancelamento não libera imediatamente a vaga de processamento.
- A vaga somente será liberada após o backend confirmar que a tarefa foi efetivamente encerrada por cancelamento.
- Até essa confirmação, a exportação continuará ocupando a vaga única de processamento do usuário.
- A interface só apresentará o estado **Cancelada** após confirmação do backend; enquanto aguarda, deverá indicar que o cancelamento está em processamento/aguardando confirmação.
- Se a tarefa já tiver terminado ou não puder mais ser cancelada quando o pedido for processado, o backend retornará o estado real, sem a interface declarar cancelamento concluído.
- O backend será responsável por validar a solicitação, controlar concorrência com conclusão/falha e persistir o estado final.

### Auditoria do cancelamento de exportação — decisão aprovada (09/11/2026)

- Todo pedido de cancelamento deverá gerar registro no Log de Atividades, identificando a solicitação de exportação, o usuário solicitante e a data/hora do pedido.
- O resultado final deverá ser registrado separadamente, com data/hora e estado confirmado pelo backend: cancelada, concluída, falha ou cancelamento não efetivado conforme o estado real da tarefa.
- O registro deverá distinguir claramente o pedido de cancelamento da confirmação de cancelamento efetivo.
- A auditoria será persistida e protegida pelo backend, sem possibilidade de edição ou exclusão pela interface.
- A interface só apresentará o resultado final após confirmação do backend.

### Acompanhamento e histórico das exportações — decisão aprovada (09/11/2026)

- O sistema deverá disponibilizar uma área para o usuário acompanhar as solicitações de exportação feitas por ele e consultar seu histórico.
- Cada solicitação deverá apresentar seu estado, conforme persistido e confirmado pelo backend.
- Estados de acompanhamento:
  - **Aguardando processamento**
  - **Em processamento**
  - **Cancelamento solicitado**
  - **Concluída**
  - **Falhou**
  - **Cancelada**
- A solicitação de cancelamento não será apresentada como cancelamento concluído; o estado **Cancelamento solicitado** permanecerá até o backend confirmar o resultado final.
- A área deverá refletir as mudanças de estado conforme as atualizações confirmadas pelo backend, sem antecipar resultados.
- Quando a exportação for concluída, a disponibilidade do arquivo e do link de download deverá respeitar as regras já aprovadas de proteção, vínculo individual e expiração de 30 minutos.
- O usuário só poderá consultar solicitações às quais tenha autorização; o backend validará identidade e permissões e não permitirá acesso aos registros de outros usuários sem autorização específica.
- Critérios de retenção do histórico, filtros, paginação e detalhamento visual permanecem pendentes de definição.

### Localização da área de exportações — decisão aprovada (09/11/2026)

- A área de acompanhamento e histórico de exportações ficará em **Configurações → Exportações**.
- Haverá também um acesso permanente pelo menu do usuário, direcionando para a mesma área, sem criar uma segunda área ou histórico independente.
- O histórico operacional de exportações permanecerá separado do **Log de Atividades**: o primeiro serve para acompanhar solicitações e seus estados; o segundo mantém os registros de auditoria das operações.
- A separação visual não elimina nem duplica os registros de auditoria. Eventos relevantes da exportação continuarão registrados no Log de Atividades conforme as regras aprovadas.
- O backend continuará validando identidade e permissões para consulta e acesso aos arquivos; a localização no menu não concede privilégios adicionais.

### Retenção do histórico de exportações — decisão aprovada (09/11/2026)

- O histórico operacional das solicitações de exportação ficará disponível para consulta por **15 meses**.
- O prazo deverá permitir que o usuário consulte e obtenha relatórios referentes a períodos anteriores dentro dessa janela.
- A retenção de 15 meses aplica-se aos registros e metadados do histórico operacional; não altera a regra de arquivos exportados temporários nem a expiração de **30 minutos** dos links individuais de download.
- O prazo de retenção do histórico operacional não define nem altera a retenção do Log de Atividades, que permanece sujeito a regra própria.
- O backend controlará o prazo de retenção e a autorização de consulta; critérios técnicos de expurgo após o prazo deverão ser definidos sem comprometer obrigações de auditoria ou integridade.

### Filtros do histórico de exportações — decisão aprovada (09/11/2026)

- A área de histórico deverá permitir filtrar solicitações por:
  - **Período:** intervalo de datas, limitado à janela de retenção de 15 meses.
  - **Estado da exportação:** Aguardando processamento, Em processamento, Cancelamento solicitado, Concluída, Falhou e Cancelada.
  - **Usuário solicitante:** disponível somente para usuários que tenham autorização para consultar solicitações de outros usuários; para os demais, a consulta ficará restrita às próprias solicitações.
  - **Formato do arquivo:** Excel ou PDF.
- Os filtros poderão ser combinados para refinar os resultados.
- O backend deverá validar identidade, permissões e escopo de cada consulta, inclusive o filtro por usuário solicitante. O frontend não poderá ampliar o conjunto de registros acessíveis.
- Os resultados deverão respeitar também a retenção de 15 meses e as regras de acesso individual aos arquivos exportados.
- A aplicação/limpeza dos filtros, a paginação e a ordenação dos resultados estão definidas.


### Aplicação e limpeza dos filtros do histórico de exportações — decisão aprovada (09/11/2026)

- A seleção ou edição dos critérios não executará consulta automaticamente.
- O botão **Aplicar filtros** executará a consulta com os critérios selecionados.
- O botão **Limpar filtros** removerá os critérios selecionados.
- Enquanto o usuário editar critérios ainda não aplicados, os resultados da última consulta aplicada permanecerão visíveis e inalterados.
- Somente uma nova ação explícita em **Aplicar filtros** substituirá os resultados pela consulta correspondente aos novos critérios.
- A execução, validação de parâmetros, identidade, permissões e escopo permanecerão sob autoridade do backend.


### Paginação do histórico de exportações — decisão aprovada (09/11/2026)

- A paginação utilizará **20 registros por página** como padrão.
- O usuário poderá selecionar **20, 50 ou 100 registros por página**.
- O backend retornará somente os registros da página solicitada, sem exigir o carregamento integral do histórico.
- Os filtros efetivamente aplicados deverão ser preservados durante a navegação entre páginas.
- A paginação, seus parâmetros e o escopo dos resultados serão validados pelo backend.
- A ordenação padrão será pela data e horário da solicitação, da mais recente para a mais antiga; o usuário poderá alternar para a ordem da mais antiga para a mais recente. A ordenação escolhida será preservada durante a navegação entre páginas. Quando duas ou mais solicitações tiverem a mesma data e horário, o identificador único da solicitação será usado como critério adicional de desempate, garantindo uma ordem estável.


### Ordenação do histórico de exportações — decisão aprovada (09/11/2026)

- A ordenação padrão será pela data e horário da solicitação, da mais recente para a mais antiga.
- O usuário poderá alternar para a ordem da mais antiga para a mais recente.
- A ordenação escolhida deverá ser preservada durante a navegação entre páginas.
- Quando duas ou mais solicitações tiverem a mesma data e horário, o identificador único da solicitação será utilizado como critério adicional de desempate, garantindo uma ordem estável.
- A ordenação, os critérios e a paginação serão validados e executados pelo backend.


### Tela de detalhes da solicitação de exportação — decisão aprovada (09/11/2026)

Ao selecionar uma solicitação no histórico, o usuário poderá abrir uma visualização individual, somente leitura, com os seguintes dados, conforme disponibilidade e autorização:

- **Identificação:** identificador único da solicitação e usuário solicitante.
- **Solicitação:** data e horário da solicitação, formato do arquivo (Excel ou PDF) e filtros efetivamente utilizados.
- **Processamento:** estado atual confirmado pelo backend e datas/horários de início e encerramento, quando disponíveis.
- **Resultado:** quantidade de registros exportados e resultado final confirmado.
- **Cancelamentos e falhas:** motivo, quando aplicável, e respectivos registros de data e horário.
- **Download:** acesso ao arquivo somente quando a exportação estiver concluída, o usuário estiver autorizado e o link ainda estiver dentro do prazo de validade de 30 minutos.
- **Auditoria:** histórico dos eventos relevantes da solicitação, sem possibilidade de edição ou exclusão pela interface.

A consulta não altera a solicitação nem seus registros. O backend valida identidade, permissões e dados apresentados; a interface não poderá antecipar estados ou resultados não confirmados.

### Consulta dos detalhes durante o processamento — decisão aprovada (09/11/2026)

- Os detalhes de uma solicitação poderão ser consultados em qualquer estado, inclusive **Aguardando processamento**, **Em processamento** e **Cancelamento solicitado**, sem necessidade de aguardar o encerramento.
- Enquanto a solicitação estiver ativa, a visualização apresentará os dados e eventos já disponíveis, atualizados conforme as confirmações persistidas pelo backend.
- Informações ainda não disponíveis, como horário de encerramento, quantidade final de registros ou resultado final, não serão presumidas nem preenchidas antecipadamente.
- A consulta continuará sendo somente leitura; abrir ou atualizar os detalhes não altera o processamento, não solicita cancelamento e não interfere na tarefa.
- Identidade, permissões, estado e conteúdo exibido serão validados pelo backend.

### Atualização automática dos detalhes da exportação — decisão aprovada (09/11/2026)

- Com a tela de detalhes aberta, as informações da solicitação deverão ser atualizadas automaticamente, sem exigir atualização manual do usuário.
- As atualizações deverão refletir somente estados, dados e eventos confirmados pelo backend.
- O mecanismo deverá ser controlado para evitar consultas excessivas, tráfego desnecessário e sobrecarga do sistema.
- A atualização automática será apenas de consulta: não poderá alterar a solicitação, interferir no processamento ou solicitar cancelamento.
- A frequência, o mecanismo técnico, o comportamento em caso de perda de conexão e a suspensão/redução de atualizações quando a tela não estiver ativa permanecem pendentes de especificação técnica.

### Perda e recuperação de conexão na atualização dos detalhes — decisão aprovada (09/11/2026)

- Se a conexão for perdida enquanto a tela de detalhes estiver aberta, o sistema deverá preservar na tela os últimos dados recebidos e confirmados pelo backend.
- A interface deverá informar claramente que está sem conexão e que os dados exibidos correspondem à última atualização confirmada, evitando apresentá-los como atuais.
- O sistema deverá tentar restabelecer a conexão e retomar a atualização automática quando a conectividade voltar.
- Após a reconexão, deverá buscar e validar o estado atual no backend antes de apresentar os dados como atualizados.
- A perda ou recuperação da conexão não poderá alterar, reiniciar, cancelar ou duplicar a solicitação de exportação.
- O comportamento deverá respeitar as permissões vigentes e evitar tentativas de reconexão excessivas.

### Atualização dos detalhes quando a tela não estiver ativa — decisão aprovada (09/11/2026)

- Quando o usuário sair da tela de detalhes ou ela deixar de estar ativa/em primeiro plano, as consultas automáticas deverão ser suspensas ou reduzidas para evitar tráfego e consumo desnecessários.
- Ao retornar à tela ou torná-la ativa novamente, o sistema deverá solicitar imediatamente ao backend o estado atual da solicitação, respeitando identidade e permissões vigentes.
- Os dados anteriores permanecerão identificados como última atualização confirmada até que a nova consulta seja validada pelo backend.
- A suspensão ou redução das consultas não poderá pausar, reiniciar, cancelar ou alterar a solicitação de exportação.
- O mecanismo técnico e os limites de frequência para a tela ativa e inativa permanecem pendentes de definição.

### Frequência de atualização automática dos detalhes — decisão aprovada (09/11/2026)

- Enquanto a tela de detalhes estiver ativa e em primeiro plano, o sistema consultará o backend em intervalos de **10 segundos** para obter atualizações da solicitação.
- O intervalo é uma referência máxima de frequência; o mecanismo deverá evitar chamadas simultâneas, aplicar controle de carga e respeitar limites, falhas e capacidade do backend.
- Se uma consulta ainda estiver em andamento, não deverá ser iniciada outra consulta concorrente para a mesma tela/solicitação.
- Ao deixar a tela inativa ou em segundo plano, aplicam-se as regras aprovadas de suspensão ou redução das consultas; ao retornar, deverá ocorrer consulta imediata para validar o estado atual.
- O intervalo não altera a regra de que somente dados confirmados pelo backend podem ser apresentados como atuais.


## Central de Gerenciamento de Usuários — decisões aprovadas em 09/11/2026

### Proteção contra alterações de perfil
- Somente Administrador pode alterar o perfil de outro usuário.
- Um usuário não pode elevar as próprias permissões.
- Toda mudança de perfil exige confirmação explícita.
- A mudança só passa a valer após confirmação e persistência bem-sucedida pelo backend.
- A auditoria registra perfil anterior, perfil novo, responsável e data/hora.
- O sistema bloqueia o rebaixamento ou a suspensão da própria conta pelo último Administrador.
- A proteção deve impedir que o sistema fique sem Administrador por qualquer fluxo administrativo equivalente.

### Convites de usuários
- Convite individual enviado por e-mail.
- O link de convite tem validade de 24 horas.
- O convite permanece pendente até a conclusão do cadastro.
- Administrador pode reenviar ou cancelar convite.
- Convite expirado não concede acesso.
- O próprio usuário define sua senha; o Administrador não cria nem conhece a senha.
- A ativação depende da validação do convite e da confirmação do backend.
- O convite define o perfil inicial (Administrador, Editor ou Visualizador); o convidado não escolhe nem altera o próprio perfil durante o cadastro.
- Link individual, vinculado ao e-mail convidado e de uso único.
- Reenvio invalida imediatamente o link anterior.
- Convite cancelado não pode ser recuperado; deve ser emitido outro.
- Emissões, reenvios, cancelamentos, expirações e ativações ficam registrados na auditoria.

### Unicidade de e-mail e tratamento de convites/contas existentes
- E-mail de usuário ativo: bloquear novo convite e informar que já existe uma conta.
- E-mail com convite pendente: permitir reenviar o convite existente, invalidando o link anterior.
- E-mail de usuário suspenso: impedir criação de outra conta; reativação ocorre pela Central de Gerenciamento, somente por Administrador.
- E-mail com convite expirado: permitir novo convite, preservando o histórico do convite anterior.
- Cada e-mail identifica uma única conta no sistema; não criar duplicidades.

### Suspensão de usuários e sessões
- Após confirmação do backend, bloquear imediatamente o acesso do usuário suspenso.
- Invalidar todas as sessões abertas, inclusive em outros dispositivos.
- Revogar tokens de acesso e de renovação no backend.
- Tentativas de continuar usando o sistema devem exigir novo login.
- Registrar a suspensão e a invalidação das sessões na auditoria.
- Não basta impedir novos logins: sessões já abertas também precisam perder validade.

### Reativação de usuários
- Somente Administrador pode reativar usuário suspenso.
- A reativação exige confirmação explícita.
- Recuperar o perfil que o usuário possuía antes da suspensão.
- Não restaurar sessões ou tokens antigos.
- Exigir novo login após a reativação.
- Registrar responsável, data/hora e operação na auditoria.

### Alteração de e-mail
- O próprio usuário pode solicitar a alteração do e-mail.
- O usuário informa o novo endereço e recebe nele um link de confirmação.
- O e-mail só é alterado após a confirmação do novo endereço e a confirmação/persistência pelo backend.
- Até a confirmação, o e-mail antigo continua válido.
- O novo endereço não pode estar associado a outra conta, ativa ou suspensa.
- Registrar a operação na auditoria.


### Proteções adicionais para alteração de e-mail — decisão aprovada (09/11/2026)
- Exigir autenticação recente do usuário antes de iniciar a solicitação de alteração.
- Enviar aviso ao endereço de e-mail antigo informando que foi solicitada uma alteração.
- Permitir que o usuário conteste uma solicitação que não reconheça.
- Uma contestação válida bloqueia a alteração pendente; o e-mail cadastrado permanece inalterado até resolução.
- Registrar tentativas, avisos, contestações, bloqueios e resultados na auditoria, com responsável/ator e data/hora.


### Recuperação de senha — decisão aprovada (09/11/2026)
- Permitir que o usuário solicite recuperação de senha por e-mail.
- Enviar link individual, de uso único, com validade de 30 minutos.
- A emissão de um novo link invalida imediatamente o link anterior.
- A resposta da solicitação deve ser genérica, sem revelar se o endereço informado possui ou não uma conta.
- Após redefinição bem-sucedida da senha, invalidar todas as sessões anteriores do usuário.
- Registrar a solicitação e o resultado da recuperação na auditoria, sem registrar senha ou token em texto aberto.
