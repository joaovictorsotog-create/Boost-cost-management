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

 
### Encerramento voluntário da análise

- [x] Aprovar ação **Encerrar análise sem decisão**, com confirmação explícita.
- [x] Retornar a solicitação para **Pendente** após persistência confirmada pelo backend e liberar a titularidade.
- [x] Auditar o encerramento voluntário.
- [x] Definir que fechar navegador, sair do sistema ou ficar inativo não encerra a análise.
- [x] Manter o limite de três lembretes sem liberação automática.
- [ ] Especificar critérios técnicos e testes de aceite para transição, liberação de titularidade e auditoria.

 
### Reassunção após encerramento voluntário

- [x] Permitir que qualquer Administrador autorizado, inclusive o que encerrou a análise anterior, assuma novamente a solicitação quando estiver Pendente.
- [x] Registrar cada assunção como novo ciclo, com responsável e data/hora próprios.
- [x] Preservar ciclos anteriores no histórico/auditoria.
- [ ] Definir critérios técnicos e testes de aceite para histórico de múltiplos ciclos e concorrência na reassunção.

 
### Perda inesperada de acesso durante análise

- [x] Manter solicitação em **Em análise** e preservar titularidade após falha de conexão, sessão encerrada ou navegador fechado.
- [x] Permitir que o Administrador titular retome a análise após autenticar-se novamente e passar pelas validações do backend.
- [x] Impedir que outros Administradores assumam ou decidam enquanto a titularidade estiver ativa.
- [x] Manter lembretes aprovados sem liberação automática após o terceiro lembrete.
- [ ] Definir critérios técnicos e testes de aceite para retomada, autenticação, indisponibilidade prolongada e recuperação de falhas.

 
### Transferência de titularidade após o terceiro lembrete

- [x] Habilitar transferência para outro Administrador somente após o envio efetivo do terceiro lembrete.
- [x] Exigir ação explícita e justificativa obrigatória do Administrador que assumirá.
- [x] Validar elegibilidade, autorização e titularidade no backend, com operação atômica contra concorrência.
- [x] Registrar titular anterior, novo titular, justificativa, responsável e data/hora.
- [x] Preservar histórico, lembretes e ciclos anteriores; não decidir automaticamente a solicitação.
- [ ] Definir critérios técnicos e testes de aceite para elegibilidade, concorrência, notificações e auditoria da transferência.

 
### Notificação após transferência de titularidade

- [x] Notificar o Administrador anterior após a transferência ser persistida.
- [x] Informar novo titular e justificativa registrada.
- [x] Vincular a notificação à solicitação e respeitar permissões.
- [x] Manter rastreabilidade do envio/resultado sem restaurar poderes ao titular anterior.
- [ ] Definir canal, política de tentativas, falhas de entrega e critérios de aceite das notificações.

 
### Notificação ao novo titular após transferência

- [x] Notificar o novo Administrador após a transferência ser persistida.
- [x] Identificar a solicitação e fornecer acesso direto à análise e ao histórico anterior.
- [x] Preservar ciclos e registros anteriores, respeitando permissões.
- [x] Manter rastreabilidade do envio/resultado.
- [ ] Definir canal, política de tentativas, falhas de entrega e critérios de aceite das notificações.

 
### Reinício dos lembretes após transferência

- [x] Iniciar novo ciclo de inatividade a partir da efetivação da transferência no backend.
- [x] Zerar a contagem operacional de lembretes para o novo titular, sem apagar o histórico anterior.
- [x] Enviar até três lembretes a cada 30 minutos de inatividade.
- [x] Habilitar nova transferência somente após o terceiro lembrete efetivo do ciclo atual.
- [ ] Definir critérios técnicos e testes de aceite para relógio, reprocessamento, duplicidade e concorrência entre transferência e lembrete.

 
### Histórico de justificativas de transferência

- [x] Disponibilizar ao novo titular a justificativa da transferência atual e todas as justificativas anteriores.
- [x] Vincular cada justificativa ao respectivo evento, responsáveis/titulares e data/hora.
- [x] Preservar histórico cumulativo, sem sobrescrita ou exclusão.
- [x] Respeitar permissões de acesso ao histórico.
- [ ] Definir critérios técnicos, retenção e testes de aceite para integridade e consulta do histórico.


### Histórico integral de atividades da análise

- [x] Registrar cronologicamente início e retomada da análise e encerramento sem decisão.
- [x] Registrar lembretes enviados, ciclos, transferências de titularidade e justificativas.
- [x] Registrar aprovação, rejeição e consultas/ações relevantes realizadas durante a análise.
- [x] Identificar em cada evento a solicitação, o ator responsável, data/hora, operação e resultado.
- [x] Preservar histórico cumulativo, sem sobrescrita ou exclusão pela interface; backend como fonte de verdade.
- [ ] Definir critérios de relevância e granularidade para registro de consultas e ações.
- [ ] Definir retenção, permissões detalhadas, integridade técnica e critérios de aceite/testes do histórico.


### Linha do tempo única da solicitação

- [x] Aprovar uma linha do tempo cronológica única por solicitação.
- [x] Reunir nela eventos de análise, retomada, encerramento, lembretes, transferências, justificativas, ações relevantes e decisão final.
- [x] Exibir responsável, data/hora, operação e resultado, com contexto aplicável.
- [x] Preservar sequência temporal entre ciclos e titulares; usar registros do backend como fonte de verdade.
- [ ] Definir filtros, paginação, agrupamento visual e critérios de apresentação.


### Filtros da linha do tempo da solicitação

- [x] Aprovar filtro por responsável.
- [x] Aprovar filtro por tipo de evento.
- [x] Manter filtros como recursos de consulta, sem alterar ou excluir registros históricos.
- [x] Preservar a ordem cronológica e disponibilizar a visão completa sem filtros.
- [x] Aplicar permissões no backend também aos resultados filtrados.
- [ ] Definir detalhes visuais, paginação e critérios técnicos de aceite.


### Seleção múltipla nos filtros da linha do tempo

- [x] Permitir múltiplos responsáveis selecionados simultaneamente.
- [x] Permitir múltiplos tipos de evento selecionados simultaneamente.
- [x] Permitir combinar os filtros de responsável e tipo de evento.
- [x] Permitir remover seleções individualmente e limpar todos os filtros.
- [x] Preservar a cronologia e manter filtros sem efeito sobre os registros originais.
- [ ] Definir detalhes visuais e critérios técnicos de aceite.


### Aplicação explícita dos filtros da linha do tempo

- [x] Exigir ação explícita pelo botão **Aplicar filtros** para atualizar os resultados.
- [x] Não atualizar a linha do tempo a cada seleção ou remoção de critério.
- [x] Permitir limpar os filtros e retornar à visão cronológica completa.
- [x] Preservar cronologia, permissões e integridade do histórico após a aplicação.
- [ ] Definir detalhes visuais, estados do botão e critérios técnicos de aceite.


### Preservação dos resultados durante edição dos filtros

- [x] Distinguir critérios aplicados de critérios temporariamente em edição.
- [x] Manter a última consulta aplicada visível durante a edição.
- [x] Atualizar resultados somente após novo clique em **Aplicar filtros**.
- [x] Permitir descartar a edição sem alterar filtros e resultados aplicados.
- [x] Manter backend como autoridade para permissões e execução da consulta.
- [ ] Definir detalhes visuais dos estados de edição/cancelamento e critérios técnicos de aceite.


### Aviso ao sair com filtros ainda não aplicados

- [x] Exibir notificação ao tentar sair com critérios de filtro alterados e ainda não aplicados.
- [x] Oferecer opção para descartar alterações e sair.
- [x] Oferecer opção para permanecer na tela e manter a edição temporária.
- [x] Preservar os últimos filtros aplicados e seus resultados ao descartar a edição.
- [x] Não exibir aviso quando não houver alterações temporárias pendentes.
- [ ] Definir detalhes visuais, cobertura de navegação e critérios técnicos de aceite.

### Navegação global e proteção de filtros não aplicados

- [x] Aprovar botões globais **Voltar** e **Avançar** no cabeçalho padrão do Alianza.
- [x] Aprovar comandos de teclado compatíveis, incluindo **Esc** para voltar dentro do Alianza quando aplicável, sem conflito com ações contextuais como fechar modais.
- [x] Exigir confirmação ao sair por botões, atalhos ou navegação do navegador quando houver filtros não aplicados ou outra edição protegida.
- [x] Preservar integralmente a edição ao escolher permanecer; ao descartar e sair, preservar filtros e resultados anteriormente aplicados.
- [x] Cobrir navegação interna, voltar/avançar do navegador e recarregamento; usar aviso nativo do navegador para fechamento de aba/janela quando disponível.
- [ ] Definir comportamento sem histórico, responsividade, compatibilidade de atalhos e critérios técnicos/testes de aceite.

### Estado dos botões de navegação sem histórico disponível

- [x] Desabilitar **Voltar** quando não houver tela anterior no histórico.
- [x] Desabilitar **Avançar** quando não houver tela posterior no histórico.
- [x] Não executar navegação artificial; refletir o histórico real.

### Preservação do contexto na navegação Voltar/Avançar

- [x] Preservar e restaurar a posição de rolagem ao voltar/avançar.
- [x] Preservar e restaurar os filtros aplicados da tela correspondente.
- [x] Respeitar permissões e validade atual dos dados durante a restauração.
- [x] Manter a proteção já aprovada para filtros temporários não aplicados.
- [ ] Definir implementação técnica e critérios de aceite para dados alterados/removidos ou permissões modificadas enquanto a tela estava fora de foco.

### Revalidação ao retornar à tela — decisão aprovada

- [x] Revalidar dados e permissões ao retornar por Voltar/Avançar; backend como autoridade.
- [x] Atualizar a tela se registros tiverem sido excluídos ou permissões tiverem sido revogadas enquanto ela estava fora de foco.
- [x] Informar claramente o que mudou, sem expor dados que o usuário não esteja mais autorizado a acessar.
- [x] Preservar apenas critérios de consulta ainda válidos e atualizar os resultados conforme o estado atual.
- [ ] Definir apresentação das mensagens, tratamento de múltiplas alterações e critérios técnicos/testes de aceite.

### Comunicação das alterações ao retornar à tela — decisão aprovada

- [x] Exibir avisos objetivos e não intrusivos para alterações relevantes desde a última visualização.
- [x] Informar exclusões e remover os registros excluídos dos resultados atuais.
- [x] Informar revogação de acesso sem revelar dados protegidos e impedir a visualização não autorizada.
- [x] Atualizar dados modificados e indicar que houve atualização desde a última visita.
- [x] Consolidar múltiplas alterações em um único resumo, evitando notificações repetitivas.
- [x] Não exibir aviso quando não houver alterações relevantes.
- [ ] Definir textos finais, apresentação visual, classificação de relevância e critérios técnicos/testes de aceite.

### Conteúdo do resumo consolidado de alterações — decisão aprovada

- [x] Apresentar quantidade de alterações separada por categoria (exclusões, atualizações e alterações de permissão, por exemplo).
- [x] Permitir compreender volume e natureza das mudanças sem abrir cada aviso individualmente.
- [x] Impedir que contagens ou detalhes do resumo revelem dados de registros cujo acesso foi revogado.
- [ ] Definir textos finais, apresentação visual, critérios de classificação/contagem e critérios técnicos/testes de aceite.

### Sino de notificações e alertas sonoros — decisão aprovada

- [x] Manter o resumo consolidado permanentemente acessível pelo sino de notificações.
- [x] Exibir indicador visual enquanto houver notificações não lidas.
- [x] Permitir consultar o resumo por categoria ao acionar o sino.
- [x] Manter o indicador até as notificações serem marcadas como lidas.
- [x] Oferecer opções de alerta sonoro, incluindo ativar/desativar o som.
- [x] Evitar repetição sonora indefinida e excesso de notificações.
- [x] Respeitar permissões e confidencialidade nos avisos.
- [ ] Definir configuração detalhada, seleção de sons, volume, disparo, frequência, agrupamento e sincronização entre dispositivos.

### Preferências individuais de alertas sonoros — decisão aprovada

- [x] Manter preferências de alertas sonoros individuais por usuário.
- [x] Permitir ligar/desligar o som.
- [x] Permitir escolher entre diferentes sons.
- [x] Permitir ajustar o volume.
- [x] Permitir testar o som antes de salvar.
- [x] Aplicar as preferências individuais sem impor configuração global à empresa.
- [ ] Definir persistência, catálogo de sons, compatibilidade e tratamento de bloqueios de áudio pelo navegador/sistema.


### Localização das preferências individuais de notificações — decisão aprovada (09/11/2026)

- [x] Criar área própria em **Configurações → Notificações**.
- [x] Centralizar nessa área as preferências individuais de som: ativar/desativar, escolher som, ajustar volume e testar antes de salvar.
- [x] Manter preferências independentes por usuário, sem efeito sobre os demais.
- [x] Preservar notificações visuais e o funcionamento do sino mesmo quando o som estiver desativado.
- [ ] Detalhar persistência, catálogo de sons, compatibilidade e tratamento de bloqueios de áudio pelo navegador/sistema.


### Sino de notificações no cabeçalho global — decisão aprovada (09/11/2026)

- [x] Manter o sino de notificações sempre visível no cabeçalho global, independentemente do módulo/tela.
- [x] Permitir acesso ao resumo consolidado e ao indicador de notificações não lidas em toda a navegação autenticada.
- [x] Respeitar permissões e confidencialidade; a visibilidade do sino não ativa som automaticamente nem altera preferências individuais.

### Abertura do painel do sino de notificações — decisão aprovada (09/11/2026)

- [x] Abrir o painel ao clicar no sino, logo abaixo dele e alinhado ao canto superior direito.
- [x] Manter o painel flutuante, sem retirar o usuário da tela ou do módulo atual.
- [x] Respeitar permissões e confidencialidade ao apresentar notificações e resumo.
- [ ] Definir dimensões, responsividade, comportamento de fechamento e detalhes visuais.

### Fechamento do painel do sino de notificações — decisão aprovada (09/11/2026)

- [x] Fechar ao clicar novamente no sino.
- [x] Fechar ao clicar fora do painel.
- [x] Fechar ao pressionar **Esc**, sem navegar para outra tela.
- [x] Não marcar notificações como lidas apenas por fechar o painel.
- [ ] Definir acessibilidade, gerenciamento de foco e compatibilidade técnica.

### Largura e adaptação do painel de notificações — decisão aprovada (09/11/2026)

- [x] Adotar largura adaptável ao espaço disponível, sem largura fixa universal.
- [x] Respeitar os limites da área visível da tela, sem cortar ou tornar o painel inacessível.
- [x] Manter formato compacto junto ao sino em telas maiores e adaptar a largura em telas menores.
- [x] Preservar a tela atual e as regras de abertura/fechamento.
- [ ] Definir medidas exatas, margens e pontos de quebra na especificação visual/técnica.

### Conteúdo inicial do painel de notificações — decisão aprovada (09/11/2026)

- [x] Exibir notificações recentes no painel.
- [x] Mostrar data, horário, categoria e indicação de leitura/não leitura em cada notificação.
- [x] Disponibilizar acesso ao histórico completo.
- [x] Preservar o estado de leitura ao abrir ou fechar o painel.
- [x] Aplicar permissões e confidencialidade ao painel e ao histórico.
- [ ] Definir quantidade de recentes, ordenação, paginação, categorias definitivas e ação de marcar como lida.

### Quantidade de notificações recentes no painel — decisão aprovada (09/11/2026)

- [x] Exibir inicialmente as 10 notificações mais recentes.
- [x] Ordenar da mais recente para a mais antiga, conforme data/hora do backend.
- [x] Manter notificações anteriores no histórico completo.
- [x] Respeitar permissões, confidencialidade e estado de leitura.
- [ ] Definir paginação/carregamento do histórico e desempate de datas iguais.

### Marcação de notificações como lidas — decisão aprovada (09/11/2026)

- [x] Permitir marcar uma notificação individualmente como lida.
- [x] Disponibilizar **Marcar todas como lidas** para notificações não lidas autorizadas ao usuário.
- [x] Não alterar leitura apenas por abrir ou fechar o painel.
- [x] Atualizar indicadores somente após confirmação do backend.
- [x] Persistir o estado por usuário e validar a operação no backend.
- [ ] Detalhar auditoria e retenção do estado de leitura.

### Categorias de notificações — decisão aprovada (09/11/2026)

- [x] Definir categorias iniciais: Aprovações, Alterações de cadastro, Exclusões, Segurança e Sistema.
- [ ] Definir critérios de enquadramento de cada evento.
- [ ] Avaliar subcategorias e casos com possível enquadramento múltiplo.
- [ ] Definir ícones, cores e filtros por categoria.

### Prioridade visual das notificações — decisão aprovada (09/11/2026)

- [x] Definir níveis: Crítica, Alta, Normal e Baixa.
- [x] Separar prioridade da categoria temática.
- [x] Estabelecer classificação como regra de backend.
- [ ] Definir critérios objetivos de prioridade por evento.
- [ ] Definir apresentação visual/sonora, escalonamento, filtros e tratamento de críticas.

### Critérios gerais de prioridade das notificações — decisão aprovada (09/11/2026)

- [x] Definir **Crítica** como risco imediato à segurança ou à integridade dos dados.
- [x] Definir **Alta** como ação administrativa importante que exige atenção rápida.
- [x] Definir **Normal** como atualização ou solicitação que precisa ser acompanhada, sem urgência alta/crítica.
- [x] Definir **Baixa** como aviso informativo sem necessidade de ação imediata.
- [x] Manter o enquadramento de eventos sob responsabilidade do backend.
- [x] Evitar banalizar os níveis de urgência com classificações excessivas.
- [ ] Mapear eventos concretos, exceções e critérios de desempate/classificação.
- [ ] Definir apresentação visual/sonora, escalonamento e tratamento especial das notificações críticas.

### Reconhecimento e ciclo de vida das notificações críticas — decisão aprovada (09/11/2026)

- [x] Dar destaque visual próprio às notificações de prioridade Crítica.
- [x] Separar os estados **Aguardando reconhecimento**, **Reconhecido** e **Resolvido**.
- [x] Distinguir leitura, reconhecimento e resolução como ações/estados independentes.
- [x] Permitir reconhecimento por qualquer Administrador autorizado a visualizar o alerta.
- [x] Registrar o primeiro reconhecimento aceito pelo backend como responsável, com ator e data/hora.
- [x] Permitir que os demais Administradores consultem quem reconheceu e quando.
- [x] Exigir validação de autorização e concorrência atômica no backend.
- [x] Auditar o reconhecimento sem apagar, alterar ou resolver automaticamente a ocorrência.
- [x] Manter alerta reconhecido visível enquanto não resolvido, com indicação distinta.
- [x] Exibir no sino a quantidade de alertas críticos ainda não reconhecidos.
- [x] Evitar repetição sonora indefinida e respeitar preferências individuais.
- [ ] Definir responsáveis, critérios e evidências para resolução, reabertura e escalonamento.
- [ ] Definir detalhes visuais/sonoros e critérios técnicos/testes de aceite.

### Resolução de notificações críticas — decisão aprovada (09/11/2026)

- [x] Permitir que Administrador autorizado declare o alerta crítico como Resolvido.
- [x] Exigir justificativa obrigatória para a resolução.
- [x] Validar autorização, estado atual e concorrência no backend.
- [x] Registrar responsável, data/hora, justificativa e resultado na auditoria.
- [x] Preservar ocorrência original, reconhecimento e linha do tempo após resolução.
- [x] Manter resolução distinta de leitura e reconhecimento.
- [ ] Definir critérios objetivos de resolução por tipo de ocorrência.
- [ ] Definir quando evidências/documentos serão exigidos.
- [ ] Definir regras de reabertura e escalonamento.

### Reabertura de notificações críticas — decisão aprovada (09/11/2026)

- [x] Permitir reabertura somente por Administrador autorizado.
- [x] Exigir justificativa obrigatória para reabrir.
- [x] Validar autorização, estado atual e concorrência no backend.
- [x] Registrar reabertura na mesma linha do tempo, com responsável, data/hora, justificativa e resultado.
- [x] Preservar resolução anterior e todos os eventos históricos, sem sobrescrita.
- [x] Retornar o alerta reaberto ao estado **Aguardando reconhecimento**.
- [x] Exigir novo reconhecimento por Administrador autorizado a cada reabertura.
- [x] Preservar o reconhecimento anterior apenas como histórico, sem aproveitá-lo no novo ciclo.

### Lembretes de alertas críticos sem reconhecimento — decisão aprovada (09/11/2026)

- [x] Enviar primeiro lembrete após 30 minutos em Aguardando reconhecimento.
- [x] Repetir a cada 30 minutos enquanto não reconhecido, limitado a três lembretes por ciclo.
- [x] Destinar lembretes aos Administradores autorizados a visualizar o alerta.
- [x] Interromper lembretes do ciclo após reconhecimento válido.
- [x] Reiniciar contagem a cada reabertura, preservando ciclos anteriores.
- [x] Cessar lembretes automáticos após o terceiro envio efetivo, sem ação automática sobre o alerta.
- [x] Não transferir titularidade, reconhecer, resolver ou encerrar automaticamente após o limite.
- [x] Contabilizar somente envios efetivos e manter agendamento/contagem sob controle do backend.
- [x] Registrar lembretes, resultados, datas/horários e ciclo na linha do tempo/auditoria.

### Apresentação visual de alertas críticos — decisão aprovada (09/11/2026)

- [x] Exibir indicador vermelho no sino com a quantidade de alertas críticos aguardando reconhecimento.
- [x] Atualizar indicador e contagem somente com estado confirmado pelo backend.
- [x] Dar destaque visual aos alertas críticos não reconhecidos no painel.
- [x] Exibir alertas críticos antes das notificações não críticas.
- [x] Preservar ordem cronológica decrescente entre alertas críticos e, separadamente, entre as demais notificações.
- [x] Manter identificação de criticidade após reconhecimento, com estado visual distinto.
- [x] Retirar alertas resolvidos das pendências ativas, preservando-os no histórico.
- [x] Retornar alertas reabertos ao destaque e à contagem de aguardando reconhecimento.
- [x] Não alterar leitura, reconhecimento ou resolução ao abrir/fechar o painel.
- [x] Manter classificação, estado e contagem sob autoridade do backend.
- [ ] Especificar cores, ícones, acessibilidade, responsividade e testes de aceite.

### Alertas críticos com Administradores desconectados — decisão aprovada (09/11/2026)

- [x] Não condicionar criação/persistência de alertas críticos à presença de Administradores conectados.
- [x] Persistir notificações e lembretes destinados aos Administradores autorizados para consulta posterior.
- [x] Disponibilizar avisos pendentes e histórico quando o usuário autorizado retornar e sincronizar o sistema.
- [x] Manter prazos e ciclos de lembretes sob controle do backend, sem pausa ou reinício por desconexão.
- [x] Registrar horários previstos, resultados de persistência/entrega e ciclos.
- [x] Não contabilizar falhas reais de persistência/entrega como envio efetivo.
- [x] Evitar duplicatas e repetição sonora excessiva na reconexão.
- [x] Revalidar permissões antes de exibir conteúdo após reconexão.
- [x] Não executar reconhecimento, resolução, encerramento ou transferência automáticos por ausência de Administradores.


### Ocorrências críticas simultâneas — decisão aprovada (09/11/2026)

- [x] Manter identidade própria para cada ocorrência crítica simultânea.
- [x] Manter estado, reconhecimento, resolução, reabertura, lembretes e linha do tempo independentes por alerta.
- [x] Impedir que ações em um alerta alterem os demais.
- [x] Contabilizar no sino cada alerta distinto em **Aguardando reconhecimento**.
- [x] Manter cada ocorrência identificável no painel e com histórico próprio.
- [x] Concentrar persistência, autorização, concorrência, contagens e transições no backend.
- [x] Não autorizar agrupamento que esconda identidades nem operações em lote/resolução conjunta sem decisão específica.


### Limite de alertas críticos exibidos simultaneamente — decisão aprovada (09/11/2026)

- [x] Limitar a cinco a quantidade de alertas críticos exibidos simultaneamente na visualização inicial do painel.
- [x] Manter ocorrências excedentes persistidas e acessíveis por paginação ou **Ver todos**.
- [x] Ordenar a visualização inicial da ocorrência mais recente para a mais antiga.
- [x] Manter o contador do sino correspondente ao total de alertas críticos distintos em **Aguardando reconhecimento**, não apenas aos cinco exibidos.
- [x] Definir o limite como regra de apresentação, sem limitar registros ou alertas pendentes.
- [x] Preservar identidade, ciclo de vida e histórico independentes de cada alerta.
- [x] Manter dados, contagens e permissões sob autoridade do backend.


### Reincidência de manifestações em alertas críticos — decisão aprovada (09/11/2026)

- [x] Não criar alerta duplicado quando nova manifestação corresponder à mesma ocorrência crítica ainda aberta/não resolvida.
- [x] Registrar cada nova manifestação na linha do tempo do alerta original, com dados necessários para auditoria.
- [x] Manter alertas independentes para problemas efetivamente distintos.
- [x] Exigir correlação validada pelo backend; frontend não decide equivalência por conta própria.
- [x] Preservar histórico, reconhecimento e prazos do alerta original ao anexar manifestação.
- [x] Definir chave de correlação gerada e validada exclusivamente pelo backend.
- [x] Exigir correspondência de origem/módulo, tipo de falha/regra crítica e registro/recurso/entidade afetada para vincular manifestações.
- [x] Permitir anexar manifestações a alertas reconhecidos, mas ainda não resolvidos.
- [x] Após resolução, tratar manifestação posterior como nova ocorrência e gerar novo alerta.
- [x] Na ausência de evidência suficiente ou diante de divergência, criar alerta independente; na dúvida, não agrupar.
- [x] Impedir que o frontend defina ou imponha a correlação.
- [ ] Especificar estrutura técnica da chave e atributos específicos por tipo de ocorrência.


### Nova ocorrência após resolução de alerta crítico — decisão aprovada (09/11/2026)

- [x] Criar novo alerta quando o problema voltar após a resolução formal do anterior.
- [x] Atribuir ao novo alerta identidade e ciclo de vida próprios.
- [x] Manter referência histórica ao alerta anterior relacionado.
- [x] Não reabrir nem alterar o estado resolvido do alerta anterior.
- [x] Não transferir automaticamente reconhecimento, responsável, lembretes ou prazos.
- [x] Validar e persistir a relação no backend, respeitando permissões de consulta.
- [x] Submeter o novo alerta ao fluxo normal de classificação, reconhecimento, lembretes, resolução e auditoria.


### Histórico de reincidências de alertas críticos — decisão aprovada (09/11/2026)

- [x] Criar visualização administrativa própria para **Histórico de reincidências**, separada dos alertas pendentes.
- [x] Permitir consultar alertas relacionados à mesma ocorrência sem fundir registros independentes.
- [x] Exibir, conforme permissões, identificadores, datas de criação/resolução, estados e quantidade de alertas relacionados.
- [x] Manter a consulta histórica sem alterar estados ou executar ações em lote.
- [x] Manter relações, dados, auditoria e autorização sob controle do backend.
- [x] Respeitar permissões e impedir exposição de informações protegidas por meio das relações históricas.
