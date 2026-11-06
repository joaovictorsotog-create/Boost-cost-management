# Alianza — Sistema de Custos
## Registro de decisões funcionais recuperadas

**Documento:** Registro de decisões funcionais recuperadas  
**Projeto/repositório:** Boost Cost Management  
**Status:** Documento de trabalho — versão inicial, não é especificação funcional completa nem autorização de implementação  
**Data de consolidação:** 2026-11-06

> Este documento preserva decisões explicitamente confirmadas pelo usuário durante as conversas disponíveis. Não substitui a Ordem Mestra, a especificação funcional original de 381 linhas nem uma auditoria integral dessas fontes. Onde houver lacunas, elas são marcadas como pendentes em vez de preenchidas por suposição.

---

## 1. Objetivo do sistema

Construir um sistema de cadastro, composição e apuração de custos de produtos, tomando o cadastro de produtos e a estrutura de produtos do Omie como referência conceitual de organização.

A planilha existente é fonte de conhecimento sobre itens, composições e resultados históricos. **Ela não é a lei absoluta do novo sistema** e não deve determinar sozinha a arquitetura ou todas as regras funcionais.

O sistema deve representar a lógica real de custos da empresa, com cadastros reutilizáveis, estruturas multinível e atualização automática dos custos dependentes.

## 2. Cadastro Central único

1. Todo item é cadastrado uma única vez no Cadastro Central e armazenado no banco de dados.
2. Dentro da estrutura de qualquer produto, o usuário pesquisa o item cadastrado e o adiciona à composição.
3. O mesmo registro de item pode ser reutilizado em várias estruturas de produtos.
4. Não criar cópias independentes do mesmo item para cada produto.
5. A composição deve referenciar o identificador único do cadastro central.
6. O cadastro central deve comportar matérias-primas, componentes, fixadores, itens usinados, itens pintados, itens comprados, itens fabricados, subconjuntos e produtos finais, conforme a necessidade.
7. Não haverá uma distinção obrigatória de cadastro entre “produto fabricado” e “produto não fabricado”.
8. Um item pode ter custo direto cadastrado ou possuir uma estrutura própria. Se possuir estrutura, seu custo é composto a partir dos itens dessa estrutura; se não possuir, utiliza-se seu custo direto cadastrado, conforme a regra de custeio aplicável.
9. Um item que possua estrutura própria também pode ser reutilizado como componente em outra estrutura.

## 3. Estruturas de produtos

1. Um produto pode conter itens simples e outros itens que, por sua vez, possuem estruturas próprias.
2. A composição é multinível e reutilizável.
3. Cada vínculo entre produto e componente registra, no mínimo, o item referenciado e a quantidade utilizada. Outros dados específicos de utilização ainda precisam ser definidos.
4. Exemplo: o Mini Torniquete pode conter a Base de Mecanismo; a Base de Mecanismo possui sua própria composição de chapas, eixos, tubos e fixadores.
5. A mesma Base de Mecanismo pode ser reutilizada por outros produtos.
6. O sistema deve bloquear referências circulares entre estruturas (diretas ou indiretas). Essa proteção é técnica e não deve criar uma etapa operacional desnecessária para o usuário.

## 4. Custeio: escopo confirmado

O custo apurado deve incluir os materiais, componentes e serviços/itens de terceiros que geram custo direto para a empresa.

Incluem-se, conforme sua aplicação na estrutura:
- Chapas;
- Tubos;
- Fixadores;
- Componentes comprados;
- Itens individuais classificados em categorias como usinagem, pintura, corte laser e manufatura, quando possuem custo próprio e são utilizados no produto;
- Outros materiais ou componentes com custo direto aplicável.

**MOD interna e GGF ficam fora do cálculo atual.**

Importante: usinagem, pintura, corte laser e manufatura são categorias de classificação. Um item específico nessas categorias — por exemplo, um eixo sextavado classificado como Usinagem — é um registro individual do Cadastro Central, com identificação e custo próprio. Não confundir a categoria com um serviço genérico sem identidade.

A decisão do usuário esclarece que serviços/itens terceirizados entram no custo porque a empresa não executa esses processos internamente e recebe um custo do fornecedor, tal como recebe o custo de outros componentes.

## 5. Exemplo: eixo sextavado

- O eixo sextavado é cadastrado uma única vez no Cadastro Central.
- Sua categoria pode ser Usinagem.
- Ele pode ser pesquisado e adicionado a várias estruturas.
- Se seu custo unitário mudar, o usuário altera o valor no cadastro central uma única vez.
- O sistema recalcula automaticamente os custos de todas as estruturas dependentes.

## 6. Conversão de chapa e peso — regra confirmada parcialmente

Exemplo confirmado pelo usuário:
- Quantidade: 6 peças.
- Peso informado na composição: 2,15 kg no total das seis peças.
- Peso unitário: 2,15 kg ÷ 6 = 0,358333... kg por peça.
- Custo total do material: peso total × preço por kg.
- Custo unitário: custo total ÷ 6.

O desperdício da chapa já está incorporado na conversão interna de dimensão para peso. Não adicionar uma segunda parcela de desperdício sobre essa conversão.

A fórmula completa da conversão dimensional, os parâmetros e as regras de precisão ainda precisam ser documentados. Não inferir fórmula geométrica ou fator de perda sem confirmação.

## 7. Atualização automática de custos em cascata

1. O preço vigente é mantido no cadastro central do item.
2. Quando o usuário altera o preço de uma chapa, tubo, usinagem, pintura, corte laser, fixador ou outro componente/insumo com custo próprio, o sistema deve identificar todas as estruturas que utilizam aquele registro.
3. O sistema recalcula automaticamente os itens estruturados dependentes, subconjuntos e produtos finais, propagando o novo custo por toda a cadeia.
4. O usuário não deve precisar abrir e editar cada estrutura individualmente.
5. A atualização deve ocorrer automaticamente e refletir-se nos custos apresentados pelo sistema em tempo real, sem exigir recálculo manual por produto.

Exemplo: uma chapa muda de R$ 8,59/kg para R$ 9,00/kg. Todos os itens, subconjuntos e produtos finais que dependem daquela chapa devem ter seus custos atualizados automaticamente.

A implementação deve considerar consistência transacional, dependências e desempenho em árvores grandes. Esses detalhes técnicos ainda não estão definidos.

## 8. Histórico e rastreabilidade — necessidade identificada, regra ainda aberta

A atualização automática não deve apagar silenciosamente a possibilidade de compreender alterações anteriores. O histórico de preços e custos foi identificado como necessidade importante na documentação e nas pendências do projeto.

Ainda precisam ser decididos:
- Se haverá histórico de cada alteração de preço;
- Como consultar o custo em uma data passada;
- Se serão preservadas versões de composição;
- Como lidar com mudanças retroativas;
- Qual será a política de vigência e arredondamento.

Não assumir que essas regras já estão aprovadas apenas porque foram mencionadas como necessidades.

## 9. Referência Omie

Usar como referência conceitual:
- Cadastro central de produtos/itens;
- Busca de itens já cadastrados ao compor um produto;
- Reutilização do mesmo item em diferentes estruturas;
- Estrutura de produto em múltiplos níveis;
- Quantidade de cada componente na composição.

Não copiar automaticamente:
- Mecanismos fiscais, SPED ou classificações fiscais;
- Regras de estoque/produção sem confirmação;
- Custos MOD e GGF;
- Regras de perda ou custeio que contrariem as decisões deste projeto.

A referência Omie é inspiração de organização funcional, não uma especificação a ser reproduzida integralmente.

## 10. Segurança e arquitetura já registradas em outras decisões

Estes pontos vêm de conversas anteriores e da Ordem Mestra, mas devem ser rastreados contra a versão integral dos documentos antes de implementação:
- Login individual;
- 2FA;
- Políticas RLS;
- Supabase independente do CRM;
- Separação entre configurações administrativas do sistema de custos e configurações comerciais/operacionais do CRM;
- Não executar deploy, migrations remotas ou alterações na infraestrutura existente sem aprovação explícita.

A stack e a arquitetura técnica detalhada não devem ser escolhidas apenas com base neste registro.

## 11. Decisões ainda pendentes

1. Fórmula completa de conversão de dimensões em peso para chapas e outros materiais.
2. Unidades de medida e conversões permitidas para cada tipo de item.
3. Como registrar preço por unidade, kg, metro, barra, serviço ou outra referência.
4. Como tratar compra em barras comerciais, sobras e arredondamentos de consumo.
5. Como modelar itens terceirizados e seus preços (por peça, lote, operação, hora ou outra unidade).
6. Regras de precisão decimal e arredondamento.
7. Histórico, vigência e consulta de custos anteriores.
8. Comportamento diante de alteração retroativa de preço ou composição.
9. Papéis, permissões e organizações.
10. Fluxo de autenticação, 2FA e recuperação de acesso.
11. Política de exclusão lógica/física.
12. Política de logs e retenção.
13. Regras de simulação, aprovação ou publicação de alterações, caso necessárias.
14. Quais informações da planilha são apenas demonstrativas/históricas e quais representam dados necessários ao novo cadastro.
15. Reconciliar este registro com a especificação funcional original de 381 linhas e com a Ordem Mestra.

## 12. Princípios que não devem ser perdidos

- Cadastrar uma vez; reutilizar em qualquer estrutura.
- A estrutura referencia o cadastro central, não duplica o item.
- Não separar obrigatoriamente produtos fabricados e comprados.
- Um item pode ter composição própria e também compor outros produtos.
- Alteração de custo no cadastro central propaga automaticamente para toda a cadeia dependente.
- Custos diretos de materiais, componentes e itens/serviços terceirizados entram no cálculo.
- MOD interna e GGF não entram no cálculo atual.
- Categorias classificam itens; a categoria, sozinha, não substitui o cadastro individual do item.
- A planilha é material de referência, não autoridade absoluta.
- Omie é referência funcional, não cópia integral.
- Não preencher lacunas com suposições; registrar pendências e confirmar com o usuário.

---

**Controle de versão:** primeira consolidação das decisões recuperadas em 2026-11-06. Atualizar este documento quando novas regras forem confirmadas, mantendo explícita a diferença entre decisão aprovada, hipótese e pendência.
