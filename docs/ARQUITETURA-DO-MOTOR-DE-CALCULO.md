# Arquitetura do Motor de Cálculo

**Status:** proposta técnica para revisão  
**Escopo:** arquitetura e comportamento interno do motor de cálculo de custos do Alianza  
**Natureza:** este documento não transforma recomendações técnicas em decisões de negócio aprovadas. As regras funcionais já aprovadas nos documentos mestres permanecem prevalecentes. Pontos explicitamente indicados como pendentes exigem validação antes da implementação.

## 1. Objetivo

Definir uma arquitetura para calcular o custo unitário dos itens compostos a partir de suas estruturas, propagar alterações de custo aos itens dependentes e manter consistência, rastreabilidade e previsibilidade.

O motor deve ser um serviço central no backend, independente das telas. A interface solicita operações e apresenta resultados; não executa nem reproduz regras de cálculo.

## 2. Limites de escopo

O motor atende ao custeio industrial definido pelo Alianza. Não deve incorporar, por iniciativa técnica, módulos ou conceitos que foram excluídos do escopo, como impostos, preço de venda, margem, canais comerciais, estoque, compras, fornecedores vinculados, histórico de compras, MOD, GGF, operações de produção ou valorização de estoque.

Também não deve introduzir multiplicadores comerciais, fatores Alpha/Beta ou custos adicionais sem decisão funcional expressa.

## 3. Responsabilidades e componentes

A separação lógica proposta é:

1. **Cadastro Central:** mantém identidade do item, descrição, família, unidade, tipo, situação e custo unitário vigente quando aplicável.
2. **Serviço de Estruturas:** mantém as linhas de composição, os vínculos com itens centrais, quantidades, ordenação manual e observações.
3. **Motor de Cálculo:** valida a estrutura, resolve dependências, calcula custos compostos e identifica os itens que precisam ser recalculados.
4. **Persistência de custos:** mantém o custo vigente e os registros históricos correspondentes, de forma consistente.
5. **Auditoria central:** registra eventos relevantes da operação, sem criar um mecanismo de auditoria paralelo dentro do motor.

Essas responsabilidades são limites lógicos; não determinam, por si só, a divisão em microsserviços, tecnologias ou processos separados.

## 4. Modelo conceitual

- **Item simples:** possui custo unitário informado manualmente, sujeito às permissões e ao fluxo de aprovação aplicáveis.
- **Item composto:** possui uma estrutura e seu custo unitário é calculado pelo motor. O custo manual fica bloqueado.
- **Linha de estrutura:** referencia um item existente no Cadastro Central e informa a quantidade utilizada, além de ordenação e observação quando existentes.
- **Dependência:** relação em que um item composto utiliza outro item como componente. Um componente pode participar de várias estruturas.
- **Custo vigente:** valor oficial atual do item, utilizado nos cálculos subsequentes.
- **Histórico de custo:** registro separado do valor vigente, preservado conforme as regras de histórico e auditoria.

O item deve ser referenciado pelo seu identificador central. Uma estrutura não deve criar cópias independentes de componentes do Cadastro Central.

## 5. Regra matemática

Para um item composto:

\[
C_{unitário}=\frac{\sum_{i=1}^{n}(Q_i\times C_i)}{Q_{saída}}
\]

Onde:

- \(Q_i\) é a quantidade do componente na linha da estrutura;
- \(C_i\) é o custo unitário vigente do componente;
- \(n\) é o número de linhas da estrutura;
- \(Q_{saída}\) é a quantidade de unidades acabadas representada pela estrutura (quantidade-base de produção).

Se o componente também for composto, seu custo unitário deve ser obtido pelo cálculo recursivo de sua própria estrutura, respeitando a dependência entre itens.

### 5.1 Regras de aplicação

- Linhas repetidas do mesmo componente são consideradas individualmente; seus valores são somados naturalmente.
- O custo manual do item composto não é somado aos custos dos filhos. Isso evita dupla contagem.
- Desperdícios e perdas já incorporados aos custos conforme o método aprovado não devem ser aplicados novamente pelo motor.
- Cada item possui uma unidade definida. Não realizar conversões automáticas entre unidades.
- A quantidade da linha deve ser interpretada na unidade definida para o componente, segundo as regras de cadastro.
- A quantidade-base de saída é positiva e representa quantas unidades acabadas a estrutura produz. Quando omitida, vale 1.
- Para uma estrutura de lote, as quantidades e custos das linhas representam o consumo/custo total do lote; o custo unitário é obtido dividindo o custo total pela quantidade-base.
- Perdas e aproveitamento já incorporados às quantidades ou aos custos da linha não podem ser adicionados novamente.
- Se a divisão resultar em decimal periódico, o motor não deve arredondar silenciosamente enquanto a precisão interna e o ponto de arredondamento não estiverem formalmente definidos.
- Itens inativos ou excluídos não podem ser incluídos em novas estruturas, respeitadas as regras de exclusão e preservação histórica.

### 5.2 Exemplo de referência

| Componente | Quantidade | Custo unitário | Subtotal |
|---|---:|---:|---:|
| Eixo | 1 un | R$ 10,00 | R$ 10,00 |
| Chapa de aço | 3 kg | R$ 10,00 | R$ 30,00 |
| Parafuso M6 | 4 un | R$ 1,00 | R$ 4,00 |
| **Total** | | | **R$ 44,00** |

O exemplo demonstra a soma por linha para quantidade-base igual a 1. Para lotes, divide-se o custo total pela quantidade de unidades acabadas representada. Não se definem conversões automáticas nem arredondamentos internos adicionais.

## 6. Fluxo de cálculo e recálculo

Quando uma alteração autorizada modificar um custo simples, uma estrutura, um vínculo ou outro dado que afete o custo:

1. O backend recebe e autentica a operação, verificando a permissão e o fluxo de aprovação aplicável.
2. Identifica o item diretamente alterado e os itens compostos que dependem dele, direta ou indiretamente.
3. Valida as referências, situações dos itens, quantidades e integridade das estruturas envolvidas.
4. Detecta ciclos antes de iniciar a persistência dos novos custos.
5. Organiza os itens dependentes em uma ordem válida de cálculo, das dependências mais profundas até os itens finais.
6. Calcula cada composto somando quantidade multiplicada pelo custo unitário vigente de cada componente.
7. Persiste os custos atualizados e seus registros históricos dentro de uma operação consistente.
8. Emite os eventos necessários para a auditoria central.
9. Após a confirmação do backend, disponibiliza os novos valores às consultas e interfaces dependentes.

O recálculo deve alcançar todos os dependentes afetados, não apenas os pais diretos. Uma falha não pode deixar parte da cadeia com valores novos e outra parte com valores antigos como se a operação tivesse sido concluída.

## 7. Validações e integridade

O backend é a autoridade final das validações. A validação na interface serve apenas para orientar o usuário e não substitui a validação transacional.

O motor deve verificar, no mínimo:

- existência dos itens referenciados;
- tipo e situação compatíveis com a inclusão em uma nova estrutura;
- estrutura válida para o tipo de item;
- quantidades válidas conforme regra funcional;
- ausência de autorreferência e de ciclos indiretos;
- consistência dos vínculos e das versões dos dados utilizados no cálculo.

Ao detectar um ciclo, a resposta técnica deve identificar o caminho de dependências que forma o ciclo, para permitir correção. Não basta interromper o processamento com erro genérico.

A regra exata para quantidades zero ou negativas ainda deve ser consolidada com as regras de negócio antes da implementação. Não assumir silenciosamente que são permitidas.

## 8. Transações e concorrência

A atualização de um item e o recálculo de seus dependentes devem ser tratados como uma única operação lógica consistente.

Propostas técnicas:

- usar transação no backend para impedir persistência parcial;
- identificar e bloquear, ou controlar por versão, os registros afetados;
- adquirir bloqueios em ordem determinística para reduzir risco de deadlocks;
- revalidar as versões dos dados antes da confirmação;
- em conflito concorrente, rejeitar ou solicitar nova tentativa explícita, sem sobrescrever silenciosamente uma alteração;
- registrar falhas e conflitos relevantes na auditoria.

A estratégia concreta — bloqueio pessimista, controle otimista por versão ou combinação — deve ser escolhida após análise da tecnologia de persistência e testes de concorrência.

Ainda é necessário avaliar o volume máximo esperado de dependências. Não se recomenda fixar um limite arbitrário de níveis sem evidência. Também não se deve decidir antecipadamente entre processamento síncrono e fila assíncrona sem medições de volume, latência e comportamento transacional.

## 9. Precisão e arredondamento

A regra aprovada para apresentação é arredondar a terceira casa decimal: de 0 a 5, para baixo; acima de 5, para cima.

Para valores monetários, a implementação deve usar representação decimal de precisão controlada, e não ponto flutuante binário comum.

A precisão interna, a escala de armazenamento e o momento exato do arredondamento ainda precisam ser definidos. Como recomendação técnica, evitar arredondar cada parcela prematuramente: preservar precisão durante a soma e aplicar a regra aprovada no ponto de apresentação ou no ponto formalmente definido para persistência.

Antes da implementação, definir e testar:
- escala interna;
- escala persistida;
- ponto de arredondamento;
- tratamento de valores negativos, se algum caso legítimo existir;
- consistência entre custo unitário, simulação e relatórios.

## 10. Histórico e auditoria

O custo vigente e o histórico devem permanecer separados.

Cada alteração de custo efetivamente persistida deve permitir rastrear, conforme as regras centrais de auditoria:

- item afetado;
- valor anterior e novo;
- origem da alteração;
- responsável e data/hora;
- referência à operação que provocou o recálculo;
- resultado da operação;
- relação com os itens dependentes atualizados.

O motor deve emitir eventos para o mecanismo central de auditoria, sem implementar uma segunda trilha de auditoria concorrente.

A atualização em cascata deve preservar coerência histórica: não deve existir um estado oficial em que apenas parte da cadeia tenha sido atualizada. As regras aprovadas de exclusão lógica e preservação de fotografias históricas continuam aplicáveis. O desenho detalhado das fotografias históricas e sua retenção ainda precisa ser especificado.

## 11. Simulação de custos

A simulação deve reutilizar a mesma lógica de cálculo do motor, em modo de leitura, para evitar divergência entre estimativa e custo oficial.

A simulação por quantidade deve:

- percorrer a estrutura multinível;
- considerar componentes repetidos por ocorrência;
- utilizar os custos vigentes na data de referência;
- apresentar custo total e custo unitário estimado;
- identificar a data de referência dos custos utilizados;
- não alterar estrutura nem custo oficial;
- não criar ordem de produção ou movimentação de estoque.

O histórico de simulações não está aprovado e, portanto, não integra esta proposta como requisito. Sua eventual inclusão depende de decisão futura.

## 12. Cópia de estruturas

Ao copiar uma estrutura, devem ser preservadas as referências aos mesmos itens do Cadastro Central, sem duplicar seus IDs. Quantidades, unidades, ordenação e observações aplicáveis devem ser preservadas.

A estrutura copiada deve ter identidade própria e alterações independentes da estrutura de origem. Após a cópia, o custo deve ser calculado pelo motor com base nos custos vigentes. A operação deve respeitar permissões, prévia/confirmar quando aplicável e auditoria.

## 13. Testes e critérios técnicos de aceite

A implementação deverá incluir testes automatizados para, no mínimo:

1. cálculo de item composto com componentes simples;
2. composição com três ou mais níveis;
3. componente repetido em linhas distintas;
4. alteração de custo simples atualizando os compostos dependentes;
5. recálculo em cascata de múltiplos níveis;
6. bloqueio de ciclo direto;
7. bloqueio de ciclo indireto, com identificação do caminho;
8. impedimento de inclusão de item inativo em nova estrutura;
9. comportamento de exclusão lógica, vínculos e fotografia histórica;
10. cópia de estrutura sem duplicar IDs centrais e com independência entre origem e cópia;
11. simulação sem alteração de custo oficial ou estrutura;
12. rollback integral diante de falha durante recálculo;
13. duas alterações concorrentes sem sobrescrita silenciosa;
14. precisão e arredondamento em valores de fronteira;
15. resultado determinístico para o mesmo conjunto de dados e a mesma referência de custos;
16. propagação correta para todas as consultas dependentes após confirmação do backend.

Os testes de desempenho e escala devem usar cenários representativos de quantidade de itens, profundidade e número de dependências, definidos a partir de dados esperados do negócio.

## 14. Decisões ainda pendentes

Esta proposta não fecha os seguintes pontos:

- precisão interna, escala persistida e ponto formal de arredondamento;
- validação definitiva de quantidades zero ou negativas;
- estratégia de concorrência e bloqueios na tecnologia escolhida;
- limiares de volume e decisão entre processamento síncrono ou assíncrono;
- limites operacionais de tempo, memória e tamanho de grafo, definidos por benchmark;
- desenho e retenção das fotografias históricas;
- política de recuperação e reprocessamento em falhas técnicas;
- metas de latência e critérios de desempenho.

Esses itens devem ser resolvidos antes da implementação correspondente, sem presumir aprovação por constarem neste documento.

## 15. Referências técnicas consultadas

A pesquisa foi uma inspeção direcionada de arquivos e trechos específicos dos repositórios públicos abaixo; não representa auditoria integral dos projetos.

- **ERPNext — serviço de custeio de BOM:** https://github.com/frappe/erpnext/blob/develop/erpnext/manufacturing/doctype/bom/services/costing.py
- **ERPNext — modelo de BOM:** https://github.com/frappe/erpnext/blob/develop/erpnext/manufacturing/doctype/bom/bom.py
- **ERPNext — testes de BOM:** https://github.com/frappe/erpnext/blob/develop/erpnext/manufacturing/doctype/bom/test_bom.py
- **InvenTree — modelos de Part e BOM:** https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/part/models.py
- **PDM-Web — guia de cálculo acumulado de custo de BOM:** https://github.com/jewisonj/PDM-Web/blob/main/Documentation/06-BOM-COST-ROLLUP-GUIDE.md

Os projetos de referência possuem escopos e regras próprios. Foram considerados apenas padrões pertinentes, como cálculo recursivo, propagação a dependentes, detecção de ciclos, validação e testes. Funcionalidades específicas de estoque, produção, perdas, moedas e operações não devem ser copiadas automaticamente para o Alianza.
