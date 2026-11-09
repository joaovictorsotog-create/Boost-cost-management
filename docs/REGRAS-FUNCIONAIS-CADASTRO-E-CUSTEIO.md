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
