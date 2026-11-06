# Alianza — Modelo Funcional de Dados (proposta v0.1)

**Status:** proposta para validação funcional; não aprovada para implementação.  
**Base:** decisões registradas em `REGISTRO-DECISOES-FUNCIONAIS-RECUPERADAS.md`.  
**Objetivo:** transformar as decisões confirmadas em um modelo conceitual consistente, sem escolher stack, ORM ou esquema físico de banco.

## 1. Regras de modelagem

1. Um item possui identidade única no Cadastro Central.
2. Uma estrutura não cria um novo cadastro de componente: ela referencia um item existente.
3. Um item pode ser componente de vários outros itens.
4. Um item pode possuir sua própria estrutura e também ser componente de outro item.
5. O custo de um item sem estrutura vem de seu custo direto cadastrado.
6. O custo de um item com estrutura é calculado a partir de sua composição.
7. Materiais, componentes e itens/serviços terceirizados que participam diretamente da composição entram no custo. MOD interna e GGF ficam fora do escopo atual.
8. Categoria é classificação; não define sozinha o tratamento de custo.
9. Mudanças em um custo direto devem invalidar/recalcular todos os custos dependentes.
10. Ciclos na relação entre estruturas são proibidos.

## 2. Entidades conceituais

### 2.1 Item

Representa qualquer material, componente, fixador, serviço terceirizado, subconjunto ou produto que precise ser identificado e reutilizado.

Campos conceituais:
- Identificador único;
- Código interno (regra de unicidade ainda pendente);
- Descrição/nome;
- Categoria;
- Unidade de medida de referência;
- Situação (ativo/inativo — política ainda pendente);
- Tipo de origem/custo, se necessário (não confundir com fabricado/comprado);
- Dados auxiliares específicos, somente quando necessários ao método de custeio.

**Não criar uma entidade separada para “fabricado” e outra para “comprado”.** A existência de estrutura própria determina se o custo é composto por estrutura ou obtido diretamente do cadastro, conforme decisão atual.

### 2.2 Categoria

Classifica itens para pesquisa, organização e relatórios.

Exemplos conhecidos: matéria-prima, fixadores, usinagem, pintura, corte laser, manufatura e embalagem.

A lista definitiva, hierarquia e obrigatoriedade de categoria ainda precisam ser confirmadas. Categoria não deve, por si só, excluir um item do custo.

### 2.3 Unidade de medida

Define a unidade na qual uma quantidade ou preço é expresso.

Exemplos que aparecem no contexto do projeto: unidade/peça, kg, metro e barra comercial.

O modelo deve distinguir:
- Unidade de referência do cadastro;
- Unidade usada na linha da estrutura;
- Unidade na qual o preço foi informado;
- Conversão entre unidades, quando permitida.

Não presumir que qualquer unidade pode ser convertida para qualquer outra. Conversões válidas precisam ser explícitas e controladas.

### 2.4 Custo direto / preço do item

Representa o valor informado para um item que não tem estrutura própria, ou o valor de referência usado pelo método de custeio daquele item.

Conceitos necessários:
- Valor;
- Unidade/base do preço (ex.: R$/kg, R$/m, R$/peça ou preço por serviço);
- Data de vigência ou referência temporal;
- Origem/fornecedor, se o negócio decidir controlar isso;
- Estado atual/histórico.

**Pendente:** definir se o cadastro guarda apenas um preço vigente com histórico ou múltiplas tabelas/listas de preço. Também falta definir moeda, precisão, arredondamento e política de vigência.

### 2.5 Estrutura do item

Representa a composição de um item por outros itens do Cadastro Central.

Conceitos necessários:
- Identificador da estrutura;
- Item-pai;
- Estado/versão da estrutura;
- Data de vigência, se houver;
- Linhas de composição.

A existência de estrutura própria faz o custo do item ser derivado da composição. Ainda precisa ser definida a regra para estrutura vazia, inativa, em edição ou com vigência futura.

### 2.6 Linha de composição

Vínculo entre um item-pai e um item-componente já cadastrado.

Campos conceituais mínimos:
- Estrutura à qual pertence;
- Item-componente referenciado;
- Quantidade necessária;
- Unidade da quantidade;
- Fator/conversão aplicável, quando houver;
- Dados de consumo específicos do método, quando necessários.

Não duplicar na linha a descrição, o cadastro ou o preço do item-componente como se fossem um novo item. A linha referencia o cadastro central; valores calculados podem ser apresentados como resultado/snapshot.

**Pendente:** definir se uma linha aceita perda adicional, rendimento, quantidade fixa por lote, dimensões, peso total, peso unitário ou parâmetros de conversão. A regra confirmada para chapa diz que o desperdício já está incorporado na conversão interna de dimensão para peso; portanto, não adicionar perda duplicada nesse caso.

### 2.7 Resultado de custo calculado

Representa o resultado da apuração para um item/estrutura em determinado contexto temporal.

Conceitos úteis:
- Item calculado;
- Custo total da estrutura;
- Custo unitário do item-pai;
- Data/hora do cálculo;
- Versão da estrutura considerada;
- Referências aos preços/valores usados;
- Estado do cálculo (válido, desatualizado, em processamento ou erro), se o desenho técnico exigir.

A necessidade de consultar custos anteriores foi identificada, mas o formato de snapshots e a retenção ainda não foram aprovados.

### 2.8 Dependência de custo

Representa ou permite descobrir que estruturas dependem de determinado item.

Exemplo:
- Chapa A é componente da Base de Mecanismo;
- Base de Mecanismo é componente do Mini Torniquete;
- Alteração do custo da Chapa A afeta a Base e o Mini Torniquete.

Pode ser uma relação derivada das linhas de composição ou uma estrutura técnica de dependências. A decisão entre cálculo sob demanda, fila de recálculo ou materialização de dependências é arquitetural e fica para etapa posterior.

## 3. Relações conceituais

- Categoria 1:N Item (se for confirmada uma categoria principal por item; múltiplas categorias ainda não foram decididas).
- Item 1:0..N Estruturas/versões (a cardinalidade histórica depende da política de versões ainda pendente).
- Estrutura 1:N Linhas de composição.
- Cada Linha de composição referencia exatamente um Item-componente.
- Item pode ser referenciado por N linhas de composição.
- Item pode ter custo direto ou custo derivado da estrutura, conforme regra de custeio vigente.
- Resultado de custo pertence a um item e referencia a estrutura e os valores utilizados no cálculo.

## 4. Fluxo funcional esperado

1. Usuário cadastra um item no Cadastro Central.
2. Informa identificação, categoria, unidade e custo direto/base de preço quando aplicável.
3. Se o item tiver composição, cria sua estrutura.
4. Na estrutura, pesquisa itens já cadastrados e adiciona os componentes existentes.
5. Informa quantidade e unidade de consumo; preenche parâmetros adicionais somente quando o método exigir.
6. O sistema calcula o custo da estrutura e o custo unitário do item-pai.
7. O item composto pode ser pesquisado e reutilizado em outra estrutura.
8. Quando o custo direto de um componente muda, o sistema encontra todos os itens dependentes e atualiza os resultados de custo em cascata.
9. O usuário consulta o custo atual e, após definição da política histórica, poderá consultar valores anteriores.

## 5. Exemplos de cálculo que o modelo precisa suportar

### 5.1 Componente precificado por kg

Se uma linha consome 2,15 kg e o preço cadastrado é R$ P por kg:

- Custo da linha = 2,15 × P.
- Se a linha representa 6 peças e os 2,15 kg são o peso total dessas seis peças, o peso unitário de referência é 2,15 ÷ 6.
- Não multiplicar novamente o peso total por seis.

### 5.2 Item precificado por unidade

Se uma linha consome Q unidades e o preço é R$ P por unidade:

- Custo da linha = Q × P.

### 5.3 Item terceirizado com preço próprio

Um eixo sextavado classificado como Usinagem pode ser cadastrado como item com custo próprio. Se usado em várias estruturas, a alteração de seu preço deve recalcular todas as estruturas dependentes. A unidade/base de preço exata desse exemplo ainda deve ser confirmada.

### 5.4 Material comprado em barra comercial

A planilha contém exemplo de consumo em metros e compra em barras comerciais de comprimento fixo. Isso sugere necessidade potencial de distinguir consumo líquido da composição e unidade/formato de compra.

**Não está aprovado como regra universal:** arredondar automaticamente a compra para barras inteiras, ratear sobras ou atribuir custo de sobra. Essas regras precisam de confirmação antes de entrar no cálculo oficial.

## 6. Regras de integridade

- Impedir que um item seja componente de si mesmo.
- Impedir ciclos indiretos entre estruturas.
- Impedir linhas que referenciem itens inexistentes ou indisponíveis segundo a política de status.
- Validar compatibilidade de unidades e conversões.
- Não permitir que uma categoria altere silenciosamente a inclusão/exclusão do custo.
- Garantir que o recálculo em cascata não publique resultados parciais inconsistentes.
- Preservar referências suficientes para explicar como um custo foi formado, conforme a política de histórico que vier a ser aprovada.

## 7. Pendências que bloqueiam o esquema definitivo

| ID | Decisão necessária | Por que importa |
|---|---|---|
| M-01 | Um item pode ter mais de uma estrutura/versão vigente? | Define versionamento e seleção da composição. |
| M-02 | Um item com estrutura também pode manter preço direto alternativo? | Define prioridade e cenários de comparação. |
| M-03 | O que significa estrutura vazia, inativa ou em edição? | Evita custo zero ou custo direto aplicado indevidamente. |
| M-04 | Quais unidades e conversões são aceitas? | Evita misturar kg, m, peça, barra e serviços sem regra. |
| M-05 | Como modelar dimensões, espessura, densidade e peso de chapas? | Necessário para formalizar conversão sem duplicar desperdício. |
| M-06 | Como tratar barras comerciais, sobras e rendimento? | Define custo real de materiais vendidos/comprados em formatos comerciais. |
| M-07 | Como são precificados serviços terceirizados? | Pode ser por peça, lote, operação ou outra base. |
| M-08 | Como versionar preços e estruturas e consultar custo histórico? | Necessário para rastreabilidade temporal. |
| M-09 | Qual precisão e regra de arredondamento? | Evita divergência acumulada nos custos. |
| M-10 | O recálculo deve ser síncrono ou assíncrono? | Define experiência, desempenho e consistência. |
| M-11 | Qual regra para itens inativos já usados em estruturas? | Preserva composições históricas sem permitir uso indevido. |
| M-12 | Quais atributos e códigos são obrigatórios no Cadastro Central? | Define validação e qualidade do cadastro. |

## 8. Fora do escopo desta proposta

- Escolha de stack, framework, ORM ou provedor;
- DDL/migrations ou desenho físico de tabelas;
- Implementação de algoritmo de recálculo;
- Alteração de CRM, VPS, Supabase remoto ou infraestrutura;
- Regras fiscais, SPED ou Bloco K;
- MOD interna e GGF;
- Decisões ainda não confirmadas pelo usuário.

## 9. Próxima validação recomendada

Validar primeiro as regras de modelagem que afetam diretamente o custo e o cadastro: M-02 (estrutura versus preço direto), M-04 (unidades/conversões), M-05 (chapa), M-06 (barras/sobras) e M-07 (serviços terceirizados). Depois fechar histórico e estratégia de recálculo.

**Este documento é uma proposta de modelo conceitual. Não converter diretamente em migrations ou código antes da validação das pendências.**
