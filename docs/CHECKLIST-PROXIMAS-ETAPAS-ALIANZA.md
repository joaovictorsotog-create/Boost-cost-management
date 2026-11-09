# Checklist de próximas etapas — Alianza Sistema de Custos

**Atualizado:** 09/11/2026  
**Base:** auditoria documental de 19 conversas do projeto localizadas no ZIP (8 de 27 ainda ausentes) e decisões registradas nos documentos funcionais.  
**Branch:** `docs/regras-custeio-cadastro-central`  
**Objetivo:** acompanhar o avanço incremental por módulo. As oito conversas ausentes não bloqueiam o trabalho; lacunas serão resolvidas quando forem relevantes. Este checklist não transforma pendências em decisões aprovadas.

Legenda:
- [x] concluído/documentado
- [ ] pendente
- [!] exige decisão explícita do usuário
- [~] depende de material ou validação externa

---

## 1. Consolidação documental já realizada

- [x] Auditar as 17 conversas correspondentes aos links compartilhados.
- [x] Criar `docs/AUDITORIA-CONVERSAS-PROJETO-2026-11-09.md`.
- [x] Atualizar `docs/REGISTRO-MESTRE-DECISOES-APROVADAS-E-PENDENCIAS.md`.
- [x] Atualizar `docs/REGRAS-FUNCIONAIS-CADASTRO-E-CUSTEIO.md`.
- [x] Recuperar e registrar unidades aprovadas: metro, kg, m² e unidade.
- [x] Recuperar e registrar acesso aprovado: login individual, 2FA, RLS e perfis Administrador, Editor e Visualizador.
- [x] Recuperar e registrar arquivamento do Log de Atividades: um ano no ambiente principal, depois arquivo; exclusão apenas por decisão expressa do administrador.
- [x] Registrar revisão semestral de custos, lembretes e regra de Gama manual/opcional.
- [x] Registrar arredondamento de apresentação individual por item.
- [x] Manter documentação na branch de documentação; sem merge, deploy ou implementação.

## 2. Completar a auditoria histórica

- [x] Identificar pelo metadado de projeto as 19 conversas do Alianza presentes no ZIP (36 conversas totais; 17 sem vínculo com este projeto).
- [x] Revisar as duas conversas omitidas dos 17 links iniciais: “Desenvolver Tabela Automatizada” e “Pesquisa sobre criação no Manus (1)”.
- [x] Registrar as decisões e limites de escopo dessas duas conversas no documento de auditoria e no Registro Mestre.
- [x] Confirmar que “Desenvolver Tabela Automatizada” pertence ao mesmo projeto Alianza, mas descreve aplicação separada do CRM.
- [~] As 8 conversas restantes não estão no ZIP atual; recuperar oportunisticamente quando forem disponibilizadas ou necessárias para resolver um ponto concreto.
- [x] Adotar continuidade incremental com o GitHub como fonte central de documentação.
- [x] Criar protocolo para classificar decisões, hipóteses, pendências e conflitos.
- [ ] Fazer conferência cruzada final com `BOOST-COST-MANAGEMENT-ORDEM-MESTRA.md` e a especificação funcional original de 381 linhas.
- [ ] Resolver e documentar divergências entre as fontes oficiais, sem escolher uma versão silenciosamente.

## 3. Fechar pendências funcionais — decisões do usuário

### 3.1 Exclusão e reativação de item em uso
- [x] Aprovar exclusão lógica mesmo quando houver vínculos atuais, com prévia resumida de impacto e confirmação exclusiva do Administrador.
- [x] Aprovar remoção automática das referências operacionais atuais e recálculo em cascata dos compostos dependentes após confirmação.
- [x] Aprovar preservação de fotografias históricas imutáveis de composição e custos anteriores à exclusão.
- [x] Aprovar preservação do registro original por exclusão lógica e reativação exclusiva pelo Administrador, sem restaurar vínculos antigos automaticamente.
- [ ] Especificar modelagem técnica, retenção e consulta administrativa dos registros excluídos e fotografias históricas.

### 3.2 Quantidade-base da estrutura
- [ ] [!] Definir se toda estrutura representa sempre uma unidade do produto ou se pode representar um lote com quantidade-base configurável.
- [ ] [!] Se houver lote, definir como converter o custo total da estrutura em custo unitário do produto.

### 3.3 Precisão numérica
- [ ] [!] Definir a precisão interna de armazenamento e cálculo monetário.
- [ ] [!] Definir em qual etapa aplicar o arredondamento aprovado por item, sem perda acumulada de precisão nem dupla aplicação.
- [ ] Validar exemplos reais da planilha com os resultados esperados.

### 3.4 Aproveitamento de matéria-prima
- [ ] [!] Definir se haverá cálculo automático de aproveitamento de barras/tubos ou se o sistema usará apenas quantidades/pesos já preparados e informados pelo usuário.
- [ ] [!] Se houver aproveitamento automático, definir as regras, perdas, sobras reutilizáveis e unidade de cálculo antes de implementar.
- [ ] Não transformar observações da planilha em regra universal sem aprovação.

### 3.5 Fornecedores e valores
- [ ] [!] Confirmar se cada item terá apenas um custo vigente ou se haverá preços por fornecedor/tabelas diferentes.
- [ ] [!] Definir como tratar itens sem custo informado e estruturas incompletas, sem inventar custo zero como custo válido.

## 4. Validar regras técnicas e operacionais

- [ ] [!] Definir frequência, retenção e responsável pelo monitoramento dos backups automáticos.
- [ ] [!] Definir periodicidade e procedimento de teste de restauração de backup.
- [ ] [ ] Validar arquitetura de autenticação, 2FA e políticas RLS com os três níveis aprovados.
- [ ] [ ] Definir estratégia técnica de recálculo transacional e propagação multinível, respeitando atomicidade e prevenção de ciclos já aprovadas.
- [ ] [ ] Definir idempotência para importações, atualizações em lote e tentativas repetidas após falha.
- [ ] [ ] Definir como preservar versões/instantâneos de estrutura e memória de cálculo, além do histórico de custo já aprovado.
- [ ] [ ] Definir monitoramento e critérios de saúde para banco, autenticação e serviços internos.
- [ ] [ ] Confirmar dimensionamento da VPS e arquitetura de implantação com base em carga real; os dados KVM2 (2 vCPU, 8 GB RAM, 100 GB) são referência informada, não validação de capacidade.
- [ ] [!] Aprovar a stack tecnológica específica do Sistema de Custos. Não copiar automaticamente a stack do CRM.
- [ ] [ ] Revisar requisitos de segurança: frontend não confiável, validações críticas no backend e segredos protegidos.

## 5. Preparar especificação para implementação

- [ ] Consolidar todos os requisitos aprovados em uma única especificação funcional versionada.
- [ ] Criar matriz de rastreabilidade: requisito → conversa/fonte → aprovação → documento → módulo afetado → teste de aceite.
- [ ] Criar mapa de módulos e dependências (cadastro central, famílias, estruturas, custeio, histórico, importação, relatórios, configurações, usuários e auditoria).
- [ ] Descrever fluxos de criação, edição, exclusão, inativação e confirmação global.
- [ ] Descrever fluxo de alteração de custo e recálculo de todos os produtos dependentes.
- [ ] Descrever fluxo de importação/atualização em lote com prévia, erros por linha e aprovação parcial.
- [ ] Definir critérios de aceite verificáveis para cada regra.
- [ ] Revisar a especificação com o usuário antes de autorizar implementação.

## 6. Implementação — somente após fechamento e autorização

- [ ] [!] Receber autorização explícita para iniciar implementação.
- [ ] [ ] Preparar ambiente separado do CRM e banco Supabase próprio.
- [ ] [ ] Implementar primeiro fundações: autenticação, autorização, auditoria e configurações.
- [ ] [ ] Implementar cadastro central, famílias e unidades.
- [ ] [ ] Implementar estruturas multinível, prevenção de ciclos e custeio.
- [ ] [ ] Implementar recálculo transacional e histórico.
- [ ] [ ] Implementar importação/atualização em lote com aprovação.
- [ ] [ ] Implementar pesquisa global, notificações e relatórios.
- [ ] [ ] Executar testes unitários, integração, segurança, concorrência, falhas/rollback e testes de aceite.
- [ ] [ ] Revisar backup e restauração antes de produção.
- [ ] [ ] Solicitar autorização específica antes de merge para branch principal, deploy ou alteração de infraestrutura.

---

## 7. Ordem recomendada de trabalho

1. **Trabalhar por módulo**, começando pelo Cadastro Central e depois Estrutura do Produto.
2. Recuperar decisões já documentadas e identificar apenas as lacunas do módulo atual.
3. Resolver cada pendência quando ela bloquear a especificação daquele fluxo.
4. Consultar a Ordem Mestra e a especificação de 381 linhas quando forem necessárias para precedência ou validação.
5. Produzir especificação e critérios de aceite incrementalmente.
6. Incorporar conversas ausentes oportunisticamente, sem bloquear o projeto.
7. Só iniciar implementação mediante autorização explícita.

## 8. Regra de atualização deste checklist

- Marcar uma tarefa como concluída somente após evidência verificável.
- Decisões novas devem registrar data, contexto e confirmação explícita do usuário.
- Sugestões do assistente não são decisões aprovadas.
- Pendências não devem ser resolvidas por suposição.
- Atualizar este arquivo e o Registro Mestre juntos quando uma decisão for fechada.


## 9. Protocolo de continuidade

- [x] Criar `docs/PROTOCOLO-DE-CONTINUIDADE-E-DECISOES-INCREMENTAIS.md`.
- [x] Definir o GitHub como fonte central de continuidade documental.
- [x] Definir classificação de aprovado, base documental, pendente, hipótese técnica, conflito e fora de escopo.
- [x] Definir fluxo de trabalho por módulo, com decisões registradas após confirmação.
- [ ] Iniciar especificação incremental do Cadastro Central.


## 10. Atualização após aprovação da Central de Aprovações (09/11/2026)

- [x] Aprovar organização visual e funcional da Central de Aprovações, com área administrativa própria, contador, filtros, comparação de valores, impacto, histórico, notificações e acompanhamento pelo Editor.
- [x] Aprovar estados **Pendente** e **Em análise**, com identificação do Administrador responsável pela análise.
- [x] Definir que abrir para consulta não assume a análise nem altera o estado.
- [x] Impedir decisões simultâneas: enquanto uma solicitação estiver em análise, outros Administradores podem consultar, mas não aprovar/rejeitar.
- [x] Prever retorno a **Pendente** quando a análise for abandonada ou encerrada sem decisão.
- [ ] Especificar prazo e mecanismo de liberação automática de análises abandonadas.
- [ ] Especificar tecnicamente concorrência, titularidade da análise, transições de estado e critérios de auditoria.
- [ ] Definir critérios de aceite e cenários de teste da Central de Aprovações.


### Lembretes de solicitações em análise

- [x] Enviar o primeiro lembrete após 30 minutos sem atividade.
- [x] Repetir lembretes em intervalos de 30 minutos, com limite máximo de 3 por solicitação.
- [x] Após o terceiro lembrete, interromper notificações e aguardar a manifestação do Administrador responsável.
- [x] Manter a solicitação **Em análise** após o limite, sem liberação ou decisão automática.
- [ ] Especificar implementação técnica do agendamento, registro de entrega e prevenção de duplicidade.


### Princípio obrigatório: backend como autoridade

- [x] Aprovar backend como autoridade exclusiva para validação e execução de todas as regras de negócio.
- [x] Exigir validação no backend para permissões, estados, custeio, recálculos, aprovações, exclusões, reativações, limites e agendamentos.
- [x] Impedir que chamadas diretas a APIs, manipulação do frontend, importações ou operações em massa contornem regras.
- [x] Exigir que o frontend só informe sucesso após confirmação do backend.
- [ ] Detalhar controles técnicos, testes de segurança e critérios de aceite por módulo antes da implementação.

 
### Exclusividade de análise entre Administradores

- [x] Definir que o primeiro Administrador cuja operação for aceita pelo backend assume a solicitação.
- [x] Permitir consulta aos demais Administradores, sem permitir que assumam, aprovem ou rejeitem enquanto houver titular.
- [x] Exibir quem está conduzindo a análise e impedir tomada de controle forçada.
- [x] Definir que tentativas simultâneas serão resolvidas pelo backend, aceitando apenas uma titularidade.
- [ ] Especificar mecanismo técnico atômico de concorrência, recuperação de falhas e liberação de análises abandonadas.
