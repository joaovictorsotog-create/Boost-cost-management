# Estudo Comparativo de Arquitetura — Referências para o Alianza

**Status:** pesquisa técnica em andamento  
**Natureza:** documento de pesquisa e recomendações; não altera decisões funcionais aprovadas.  
**Branch de documentação:** `docs/regras-custeio-cadastro-central`

## 1. Objetivo e método

Este estudo investiga projetos de código aberto para identificar padrões técnicos úteis ao Alianza — Sistema de Custos. O objetivo é aprender com implementações reais, código, modelos de dados e testes, sem importar automaticamente funcionalidades ou regras de negócio de outros produtos.

A pesquisa deve avançar por domínios e módulos, registrando:
- repositório, branch e arquivos efetivamente inspecionados;
- comportamento comprovado pelo código ou pelos testes;
- limitações e aspectos não verificados;
- aderência ao escopo Alianza;
- recomendação: aproveitar, adaptar, rejeitar ou investigar;
- possíveis impactos nos documentos e na arquitetura do Alianza.

**Limite importante:** os repositórios são grandes. Este documento registra uma primeira rodada direcionada, não uma auditoria integral de ERPNext, InvenTree ou Odoo. Não se deve descrever a pesquisa como leitura de todo o código.

## 2. Referências prioritárias

| Projeto | Repositório | Papel na pesquisa |
|---|---|---|
| ERPNext | https://github.com/frappe/erpnext | ERP amplo; referência para serviços de domínio, BOM, validação e propagação de custos |
| InvenTree | https://github.com/inventree/InvenTree | Gestão de componentes e BOM; referência para modelos, integridade de estruturas, validação e auditoria |
| Odoo | https://github.com/odoo/odoo | Referência complementar para modularidade, ORM, permissões e fluxos empresariais |
| PDM-Web | https://github.com/jewisonj/PDM-Web | Referência complementar para roll-up de custos de BOM; foi consultado inicialmente apenas o guia documental |
| temp_label | https://github.com/ankit-tayal-devkraft/temp_label | Referência complementar de recomendações de auditoria; documento consultado, não implementação validada |

## 3. Primeira rodada: ERPNext

### 3.1 Arquivos inspecionados

- [BOMCostingService — costing.py](https://github.com/frappe/erpnext/blob/develop/erpnext/manufacturing/doctype/bom/services/costing.py)
- [Modelo BOM — bom.py](https://github.com/frappe/erpnext/blob/develop/erpnext/manufacturing/doctype/bom/bom.py)
- [Testes de BOM — test_bom.py](https://github.com/frappe/erpnext/blob/develop/erpnext/manufacturing/doctype/bom/test_bom.py)

### 3.2 Padrões confirmados no código

**Serviço de domínio separado.** O cálculo foi extraído para `BOMCostingService`, mantendo no modelo principal delegações de compatibilidade. Isso reduz a concentração de lógica de cálculo no modelo e oferece uma fronteira de responsabilidade mais clara.

**Propagação para os pais.** `update_cost()` compara o custo anterior e o novo e, quando há alteração, chama `_update_parent_boms()`. O método localiza estruturas que utilizam a BOM alterada e atualiza recursivamente seus pais.

**Cálculo de custo unitário.** `get_bom_unitcost()` considera o custo total e o rendimento bom. Essa regra depende de perdas e quantidades de produção do ERPNext; não deve ser copiada para o Alianza, cujo escopo e regras são diferentes.

**Validação da árvore.** O modelo possui `check_recursion()`, percorre estruturas relacionadas e lança um erro específico `BOMRecursionError` ao identificar recursão.

**Testes de recursão.** `test_bom_recursion_1st_level` e `test_bom_recursion_transitive` cobrem ciclos diretos e indiretos.

**Validação em etapas.** O modelo organiza validações em métodos menores, como `_validate_setup()`, `_validate_materials_and_cost()` e `_validate_uoms_and_goods()`. O conceito de decompor validações por responsabilidade é útil, embora as regras específicas de manufatura não se apliquem ao Alianza.

### 3.3 O que aproveitar ou adaptar

- Separar o motor de cálculo do modelo de cadastro e da interface.
- Propagar recálculos aos dependentes quando o custo efetivamente muda.
- Validar ciclos diretos e indiretos antes de persistir.
- Manter testes explícitos de recursão transitiva.
- Organizar validações em etapas nomeadas e testáveis.

### 3.4 O que não importar

O serviço ERPNext também calcula operações, taxas horárias, matéria-prima, itens secundários, listas de preço, conversões monetárias, perdas de processo, valorização e outros conceitos de manufatura. Esses elementos não fazem parte do escopo aprovado do Alianza e não devem ser incorporados por analogia.

### 3.5 Limitações da inspeção

Foi inspecionada uma seleção de arquivos e métodos, não todo o fluxo de persistência, transações, filas ou concorrência do ERPNext. A propagação recursiva observada não é prova suficiente, isoladamente, de como todos os cenários concorrentes são tratados.

## 4. Primeira rodada: InvenTree

### 4.1 Arquivos inspecionados

- [Modelos Part e BOM — part/models.py](https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/part/models.py)
- [Modelos de auditoria — audit/models.py](https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/audit/models.py)

### 4.2 Padrões confirmados no código

**Validação recursiva de composição.** `Part.check_add_to_bom()` verifica autorreferência, relações de variantes e a presença do item pai nas estruturas descendentes. A verificação recursiva pode retornar falso ou lançar erro, conforme o modo solicitado.

**Prevenção de recursão em consultas.** `getRequiredParts(recursive=True)` acumula itens já encontrados em um conjunto, evitando repetir visitas durante a expansão.

**Checksum da estrutura.** `get_bom_hash()` percorre linhas ordenadas de forma consistente e produz um hash da estrutura. `is_bom_valid()` compara o hash calculado com o armazenado; `validate_bom()` registra a validação, usuário e data.

**Histórico de linhas associado ao conjunto pai.** O modelo de auditoria permite associar alterações de objetos filhos ao histórico de um objeto pai. O código documenta que essa associação pode preservar a consulta do histórico do pai mesmo depois da exclusão do filho.

**Contexto de auditoria.** O gerenciador de auditoria complementa eventos com ator, origem, referência ao pai, tipo de evento, observações e deltas. Há também tratamento para mascarar valores sensíveis antes de gravá-los no log.

### 4.3 O que aproveitar ou adaptar

- Verificação de ciclos com caminho de dependência compreensível.
- Conjunto de visitados em percursos recursivos para evitar trabalho repetido.
- Hash determinístico da estrutura para detectar alterações posteriores à validação.
- Associação de eventos dos componentes ao histórico do item composto.
- Contexto explícito de ator, origem e tipo de evento na auditoria.
- Mascaramento de dados sensíveis no momento da gravação, não apenas na tela.

### 4.4 Cuidados e limites

O checksum observado usa MD5 para identificar mudanças na composição. Isso pode ser útil como mecanismo de detecção de alteração acidental, mas não deve ser tratado como assinatura criptográfica forte nem como prova de imutabilidade. Para o Alianza, se o recurso for adotado, avaliar SHA-256 ou mecanismo apropriado e manter a auditoria protegida em camada separada.

InvenTree possui variantes, itens opcionais, consumíveis, perdas, setup, arredondamento de quantidade, substituições, estoque e outros recursos. Não importar essas regras automaticamente.

### 4.5 Limitações da inspeção

Foram inspecionados trechos dos modelos e do mecanismo de auditoria. Não foi feita auditoria completa dos sinais, permissões, APIs, migrações, tarefas assíncronas ou de todos os caminhos de exclusão e concorrência.

## 5. Matriz preliminar de aderência ao Alianza

| Padrão observado | Decisão preliminar | Justificativa |
|---|---|---|
| Serviço central de cálculo separado das telas | Aproveitar | Alinha-se ao motor independente no backend |
| Recálculo de dependentes após alteração de custo | Aproveitar | Necessário ao custo multinível |
| Detecção de ciclos diretos e indiretos | Aproveitar | Protege integridade da estrutura |
| Testes de recursão transitiva | Aproveitar | Evita regressão em dependências profundas |
| Percurso com conjunto de visitados | Adaptar | Útil para percursos e diagnósticos; não substitui validação de ciclo |
| Hash determinístico da estrutura | Investigar/adaptar | Pode detectar alteração estrutural desde a validação |
| Histórico de filho integrado ao histórico do pai | Aproveitar como conceito | Útil para rastrear alterações de componentes |
| Contexto de ator, origem e evento na auditoria | Aproveitar | Melhora rastreabilidade |
| Mascaramento de dados sensíveis na gravação | Aproveitar | Reduz risco de persistir segredos no histórico |
| Operações, estoque, preço de venda, moedas, compras e produção | Rejeitar no escopo atual | Complexidade e regras fora do produto aprovado |
| Variantes, substituições e consumíveis | Rejeitar por enquanto | Não há requisito aprovado que justifique essa complexidade |

## 6. Implicações para a arquitetura do Alianza

A pesquisa reforça a arquitetura já proposta para o motor de cálculo e sugere ampliar a investigação em cinco áreas:

1. **Grafo de dependências:** representação, detecção de ciclos, ordenação topológica, identificação de dependentes e eficiência em grafos grandes.
2. **Consistência transacional:** atomicidade do recálculo, concorrência, bloqueios, idempotência e recuperação de falhas.
3. **Integridade estrutural:** checksum/versionamento de estruturas, validação explícita e fotografia histórica.
4. **Auditoria:** eventos de domínio, associação entre pai e componentes, contexto do ator/origem e proteção de dados sensíveis.
5. **Arquitetura de aplicação:** fronteiras de módulos, serviços, APIs, permissões e separação entre interface e regras de domínio.

Esses pontos são linhas de investigação, não novas decisões funcionais.

## 7. Próximas frentes de pesquisa

### ERPNext
- Framework e ciclo de vida dos documentos.
- Transações, hooks, eventos e filas.
- Permissões, papéis e validações no backend.
- Histórico/versionamento e trilhas de auditoria.
- Importação, pré-validação e operações em lote.
- Testes de integração e infraestrutura de testes.

### InvenTree
- APIs e serialização.
- Permissões e autenticação.
- Auditoria completa e eventos de domínio.
- Tarefas assíncronas, filas e reprocessamento.
- Importação e validação em lote.
- Integridade de relações e exclusões.
- Testes de modelos e serviços.

### Odoo
- Modularidade e dependências entre módulos.
- ORM e limites entre modelos/serviços.
- Segurança por grupos, ACL e regras de registro.
- Transações e tarefas agendadas.
- Testes automatizados e padrões de extensão.

## 8. Regras para incorporar aprendizados ao Alianza

Cada aprendizado deve ser documentado com:
- fonte e arquivo exato;
- trecho ou comportamento verificado;
- problema que resolve;
- aderência às regras já aprovadas;
- riscos e custo de adoção;
- decisão preliminar (aproveitar, adaptar, rejeitar ou investigar);
- documento do Alianza que precisaria ser atualizado;
- testes necessários para provar a implementação.

Nenhum código de terceiros deve ser copiado sem verificar licença, obrigações de atribuição, compatibilidade e necessidade. Preferir aprender o padrão e implementar uma solução própria quando isso reduzir acoplamento ou obrigações desnecessárias.

## 9. Referências da primeira rodada

- ERPNext costing service: https://github.com/frappe/erpnext/blob/develop/erpnext/manufacturing/doctype/bom/services/costing.py
- ERPNext BOM model: https://github.com/frappe/erpnext/blob/develop/erpnext/manufacturing/doctype/bom/bom.py
- ERPNext BOM tests: https://github.com/frappe/erpnext/blob/develop/erpnext/manufacturing/doctype/bom/test_bom.py
- InvenTree Part/BOM models: https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/part/models.py
- InvenTree audit models: https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/audit/models.py
- PDM-Web BOM cost roll-up guide: https://github.com/jewisonj/PDM-Web/blob/main/Documentation/06-BOM-COST-ROLLUP-GUIDE.md
- temp_label audit notes: https://github.com/ankit-tayal-devkraft/temp_label/blob/main/audit.md
