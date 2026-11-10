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


## 10. Segunda rodada: Odoo

### 10.1 Arquivos inspecionados

- [Diretrizes de segurança do Odoo](https://github.com/odoo/odoo/blob/20.0/skills/odoo-guidelines/guidelines/security.md)
- [Camada SQL e transações — sql_db.py](https://github.com/odoo/odoo/blob/20.0/odoo/sql_db.py)
- [Testes de importação — test_import.py](https://github.com/odoo/odoo/blob/20.0/addons/test_import_export/tests/test_import.py)
- [Testes de mensagens e notificações — test_message_post.py](https://github.com/odoo/odoo/blob/20.0/addons/test_mail/tests/test_message_post.py)

### 10.2 Padrões observados

**Segurança por padrão e menor privilégio.** As diretrizes consultadas descrevem acesso negado por padrão quando não há concessão explícita, permissões vinculadas a grupos e restrições adicionais por domínio. A diretriz também alerta que operações privilegiadas como `sudo()` e SQL direto exigem revisão de segurança específica.

**Concorrência e recuperação de transações.** A camada SQL declara exceções de concorrência que podem ser repetidas, incluindo falha de serialização e deadlock, e implementa savepoints com rollback em saídas malsucedidas. Isso demonstra que a concorrência precisa ser tratada no nível transacional, e não apenas por bloqueios na interface.

**Importação testada por cenários.** A suíte de importação contém testes para campos obrigatórios, somente leitura, relações e estruturas de campos, demonstrando o valor de testar mapeamento e validação de importação como comportamento de domínio, não apenas como upload de planilha.

**Notificações e mensagens com testes próprios.** A suíte de mensagens testa diferentes perfis de usuário, notificações e permissões de acesso. O padrão útil é testar o efeito real da notificação e seus limites de acesso, não apenas a criação visual de um aviso.

### 10.3 Recomendações para o Alianza

- Manter negação por padrão e concessões explícitas por perfil/operação.
- Tratar permissões de backend como autoridade; esconder botão não é controle de acesso.
- Revisar cuidadosamente qualquer caminho que contorne o mecanismo normal de autorização.
- Projetar o recálculo para lidar com conflitos de transação, rollback e repetição segura quando aplicável.
- Fazer importação Excel com mapeamento, prévia, validação de referências, relatório de erros e confirmação explícita.
- Testar notificações com perfis diferentes e verificar que a consulta de conteúdo também respeita permissões.

### 10.4 Limitações

A diretriz de segurança consultada é documentação de desenvolvimento e não deve ser confundida com uma auditoria de todas as regras efetivamente carregadas em produção. A camada SQL e os testes foram inspecionados parcialmente. Não foi feita análise integral do ORM, do sistema de permissões, do pipeline de importação ou do barramento de notificações do Odoo.

## 11. Nova matriz de padrões transversais

| Padrão | Fonte | Direção para Alianza |
|---|---|---|
| Negação por padrão e concessão explícita | Odoo security guidelines | Adotar como princípio de segurança |
| Menor privilégio e revisão de caminhos privilegiados | Odoo security guidelines | Adotar na revisão de APIs e serviços |
| Savepoint e tratamento de falhas transacionais | Odoo sql_db.py | Investigar estratégia equivalente na tecnologia escolhida |
| Repetição de falhas de serialização/deadlock | Odoo sql_db.py | Projetar retry somente com idempotência e limites claros |
| Testes de mapeamento e validação de importação | Odoo test_import.py | Incorporar à especificação de importação Excel |
| Testes de notificações por perfil | Odoo test_message_post.py | Incorporar à estratégia de testes de notificações |

## 12. Próximas frentes atualizadas

Além das frentes já listadas, aprofundar:
- política de retry, idempotência e savepoints para recálculos concorrentes;
- matriz de autorização por operação e testes negativos;
- importação com prévia, mapeamento e validação de referências;
- testes de notificação e isolamento de conteúdo por perfil.


## 13. Terceira rodada: InvenTree — permissões, tarefas e auditoria em profundidade

### 13.1 Arquivos inspecionados

- [Permissões de usuários — users/permissions.py](https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/users/permissions.py)
- [Endpoints de usuários — users/api.py](https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/users/api.py)
- [Tarefas de background — InvenTree/tasks.py](https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/InvenTree/tasks.py)
- [Testes de tarefas — test_tasks.py](https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/InvenTree/test_tasks.py)
- [Modelos de auditoria — audit/models.py](https://github.com/inventree/InvenTree/blob/master/src/backend/InvenTree/audit/models.py)
- [Documentação do log de auditoria](https://github.com/inventree/InvenTree/blob/master/docs/docs/concepts/audit.md)

### 13.2 Permissões

O método `check_user_role()` verifica se o usuário está ativo, trata superusuário, consulta permissões associadas a grupos e utiliza cache de sessão para evitar repetir verificações frequentes. O endpoint de perfil próprio limita os campos editáveis e restringe os métodos HTTP aceitos.

**Aplicação ao Alianza:**
- Centralizar autorização no backend e modelar permissões por ação e recurso.
- Considerar cache somente se houver estratégia segura de invalidação quando papéis ou permissões mudarem.
- Bloquear explicitamente usuários inativos.
- Limitar cada endpoint aos campos e operações que realmente precisa oferecer.
- Testar chamadas diretas à API, não apenas a visibilidade de botões.

O cache de permissões não deve ser copiado sem projeto de invalidação: uma permissão revogada não pode continuar efetiva por cache desatualizado.

### 13.3 Tarefas agendadas e execução assíncrona

`schedule_task()` evita criar registros duplicados para a mesma função agendada; quando a tarefa já existe, atualiza seus parâmetros. Os testes verificam que a segunda programação atualiza a frequência sem criar uma segunda tarefa.

Os testes também exercitam falhas e novas tentativas de tarefas assíncronas, distinguindo falha de uma tentativa de falha definitiva após o limite de tentativas. Uma falha ainda elegível para nova tentativa não deve gerar prematuramente uma notificação de falha final.

**Aplicação ao Alianza:**
- Identidade estável para tarefas agendadas, evitando duplicidade.
- Estado explícito da execução: aguardando, em execução, concluída ou falha, com tentativas e resultado.
- Separar falha transitória de falha definitiva.
- Definir limite de tentativas, timeout, observabilidade e alerta apenas após o critério de falha final.
- Projetar idempotência antes de permitir retry de operações com efeitos persistentes.
- Garantir que reprocessar uma tarefa não duplique histórico, notificações, exportações ou alterações de custo.

Não há decisão aqui de adotar uma fila ou tecnologia específica. A necessidade de execução assíncrona deve ser medida para cada operação.

### 13.4 Auditoria: contexto e relações

A documentação do InvenTree descreve registros de criação, alteração e exclusão em modelos selecionados, com data/hora, ator, campos alterados, valores anteriores/novos e origem. Também registra informações de requisição, como IP remoto e identificador de correlação, e identifica tarefas de background como origem de alterações.

O modelo de auditoria complementa o registro com referência ao objeto pai, ator, origem, evento nomeado, observações e mascaramento de valores sensíveis. O username é preservado como texto para que a identidade histórica não desapareça se a conta for removida.

**Aplicação ao Alianza:**
- Adotar um identificador de correlação por operação para conectar alterações em cascata.
- Registrar ator, origem (interface, API, importação, tarefa interna), instante, operação, resultado e referência ao evento.
- Relacionar alterações de linhas/componentes ao histórico do item composto.
- Preservar identificador textual do responsável como dado histórico, mesmo se a conta for posteriormente desativada ou excluída, respeitando política de dados.
- Mascarar segredos antes da persistência do log.
- Distinguir alteração de campo de evento de negócio (por exemplo, aprovação, transferência de titularidade, exclusão lógica ou recálculo em cascata).

### 13.5 Uma ressalva importante: a auditoria do InvenTree não cobre tudo

A documentação do InvenTree informa expressamente que alterações feitas pela ferramenta de importação de dados não são registradas no log de auditoria. Também apenas determinados modelos são auditados, e campos derivados são excluídos.

Para o Alianza, isso é uma **limitação a não reproduzir**. Como as regras aprovadas exigem auditoria para operações de impacto e não permitem contornar o fluxo de aprovação por importação, qualquer importação deverá produzir eventos auditáveis equivalentes às alterações manuais, com identificação da origem, usuário, lote, prévia aprovada, resultado e erros.

A documentação também informa que alterações nas configurações de auditoria são sempre registradas, mesmo quando o log é desativado ou sua retenção é alterada. É um padrão interessante de proteção contra alteração silenciosa dos próprios controles de auditoria; sua implementação exigiria armazenamento e controles independentes suficientemente protegidos.

### 13.6 Limites da inspeção

A documentação descreve o comportamento esperado e os arquivos inspecionados demonstram parte da implementação. Não foi feita análise integral da configuração de todas as permissões, da infraestrutura de filas, da política completa de retenção ou da resistência do log a um administrador de banco de dados privilegiado.

## 14. Lições consolidadas para o Alianza

1. **Autorização:** verificar usuário ativo, papel, recurso, ação e escopo no backend; testar explicitamente negações.
2. **Cache:** só armazenar decisões de permissão com invalidação robusta e imediata após mudança de papel.
3. **Auditoria:** padronizar contexto e correlação de operação; auditar importações e processos internos sem exceção silenciosa.
4. **Relações históricas:** apresentar no histórico do composto as alterações relevantes de seus componentes.
5. **Eventos de negócio:** separar eventos nomeados de simples diferenças de campos.
6. **Tarefas:** distinguir tentativas, falhas transitórias e falhas finais; evitar duplicidade e efeitos repetidos.
7. **Controles de auditoria:** alterações na configuração do próprio mecanismo devem gerar evidência independente e rastreável.

## 15. Pontos para possível evolução dos documentos do Alianza

Os aprendizados justificam avaliar, sem aprovação automática:
- identificador de correlação comum para uma operação de recálculo em cascata;
- auditoria obrigatória de importações, tarefas internas e operações via API;
- histórico do item composto com eventos relevantes das linhas componentes;
- política de invalidação de cache após mudança de permissões;
- modelo de execução e reprocessamento idempotente para tarefas assíncronas;
- trilha específica para mudanças nas configurações de auditoria.
