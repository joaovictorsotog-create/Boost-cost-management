# Regras funcionais — Cadastro Central e formação do custo

**Projeto:** Alianza — Sistema de Custos  
**Repositório:** Boost Cost Management  
**Status:** decisões funcionais consolidadas em 06/11/2026  
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

**Custo unitário do composto = soma do (quantidade utilizada de cada componente × custo unitário vigente desse componente), com conversões de unidade aplicáveis.**

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
- Histórico de preços e custos é desejável e consta do escopo em discussão, mas campos, vigência, autoria, retenção e forma de consulta ainda precisam ser especificados antes da implementação.

## 8. Exemplo de comportamento da interface

| Tipo do item | Origem do custo unitário | Campo/janela de preço |
|---|---|---|
| Simples | Valor informado manualmente | Editável |
| Composto | Soma calculada da estrutura | Bloqueado para edição manual; valor calculado visível |

A interface deve deixar evidente quando o custo é manual e quando é calculado, sem permitir que o usuário confunda ou sobrescreva as duas origens.

## 9. Pontos ainda não decididos

Não assumir decisões para os pontos abaixo sem confirmação:

1. Unidades de medida suportadas e conversões permitidas entre unidade, kg, g, metro, mm etc.
2. Quantidade-base da estrutura (sempre uma unidade ou lote de produção configurável).
3. Regras universais de aproveitamento de barras/tubos e arredondamento de compras.
4. Precisão interna, arredondamento e apresentação monetária.
5. Se e como o histórico armazenará preços anteriores, custos calculados, data/hora e usuário responsável.
6. Como tratar alterações em estruturas já utilizadas, versões e custos históricos.
7. Tratamento específico do fator Gama, ainda pendente de esclarecimento.
8. Se haverá preço por fornecedor, múltiplas tabelas ou apenas um preço vigente por item.
9. Comportamento para itens inativos, sem preço, ou com estrutura incompleta.

## 10. Limites deste registro

- Este documento registra entendimento funcional, não especifica tabelas, endpoints, jobs ou tecnologia.
- Não autoriza alterar VPS, CRM, infraestrutura, banco remoto, migrations ou realizar deploy.
- A planilha de preços é referência para exemplos e entendimento, não deve impor sozinha a lógica do sistema.
- A referência ao Omie é inspiração para cadastro e reutilização de itens/estruturas, não para copiar regras fiscais ou funcionalidades não solicitadas.
- Em caso de conflito com a Ordem Mestra ou com a especificação funcional original, registrar a divergência e resolver antes de implementar; não substituir silenciosamente documentos oficiais.
