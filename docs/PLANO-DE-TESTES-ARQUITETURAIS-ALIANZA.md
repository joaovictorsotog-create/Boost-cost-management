# Plano de testes arquiteturais — Alianza

**Status:** plano proposto. Nenhum teste abaixo é declarado implementado.  
**Objetivo:** definir evidências necessárias para confiar na integridade, segurança e comportamento do sistema.

## 1. Estratégia

A pirâmide de testes deve combinar:
1. testes unitários de domínio;
2. testes de aplicação e autorização;
3. testes de integração com banco e serviços;
4. testes de concorrência com conexões reais;
5. testes de segurança e abuso;
6. testes operacionais de recuperação e observabilidade.

Testes não devem depender exclusivamente da interface. Para regras críticas, chamar os casos de uso e endpoints diretamente.

## 2. Suítes e cenários

### A. Cadastro Central
- Criar item Simples com custo manual.
- Criar item Composto e impedir edição manual do custo.
- Validar ID duplicado, reservado, inativo e exclusão lógica.
- Validar descrição duplicada permitida e distinção por ID.
- Exigir família e unidade válidas.
- Impedir família com vínculos de ser inativada antes da reclassificação.
- Verificar permissões por Administrador, Editor e Visualizador.
- Garantir que campos somente leitura não possam ser alterados via API.
- Testar pesquisa por ID, descrição e descrição complementar respeitando permissões e inativos.

### B. Estruturas e motor de cálculo
- Estrutura de um nível.
- Estrutura multinível.
- Mesmo componente repetido em duas linhas.
- Mesmo componente em diferentes produtos.
- Item composto utilizado como componente de outro composto.
- Custo unitário = soma de quantidade × custo do componente.
- Quantidade-base/lote conforme regra que vier a ser consolidada.
- Sem conversão automática de unidade.
- Sem reaplicação de desperdício.
- Sem custo manual para composto.
- Gama não aplicada automaticamente.
- Pintura/usinagem entram somente como itens/serviços inseridos na estrutura.
- Corte a laser não gera custo automático.
- Testes de arredondamento nos limites 1,545 e valores próximos, conforme regra aprovada.
- Precisão interna não pode ser fixada antes da decisão técnica.

### C. Ciclos e dependências
- Autorreferência direta.
- Ciclo indireto de dois itens.
- Ciclo indireto com três ou mais níveis.
- Grafo acíclico com componentes compartilhados.
- Mudança de custo em item simples recalcula todos os pais dependentes.
- Alteração de estrutura recalcula descendentes/pais corretos.
- Falha em etapa intermediária não deixa custo parcial publicado como definitivo.
- Recalcular duas vezes sem alteração não duplica histórico indevidamente nem cria efeitos duplicados.

### D. Transações e rollback
- Falha ao persistir histórico deve reverter alteração crítica associada quando a política exigir atomicidade.
- Falha ao persistir auditoria deve impedir concluir operação crítica.
- Falha durante cascata deve manter estado coerente e auditável.
- Erro de validação no meio de operação em lote deve respeitar granularidade definida.
- Falha de notificação externa não reverte operação já confirmada; deve permitir reentrega controlada.
- Evento realtime não é emitido se a transação sofrer rollback.

### E. Concorrência
Executar com transações/conexões independentes, barreiras e sincronização determinística:
- dois usuários alterando o mesmo item;
- duas atualizações em campos diferentes do mesmo item;
- dois administradores assumindo a mesma solicitação;
- dois administradores decidindo a mesma solicitação;
- custo de componente mudando durante recálculo;
- exclusão lógica simultânea a alteração de estrutura;
- confirmação de importação após mudança de versão do registro;
- geração simultânea do mesmo próximo ID;
- duas cascatas com dependências compartilhadas;
- retry após deadlock/timeout.

Critério: sem lost update, duplicidade, decisão dupla ou estado parcialmente confirmado; conflito deve ser explícito e auditado.

### F. Aprovações e permissões
- Editor propõe somente campos permitidos.
- Editor não altera diretamente os campos oficiais por API.
- Visualizador não altera dados.
- Administrador pode aprovar/rejeitar conforme estado.
- Abertura para consulta não assume análise.
- Apenas uma titularidade ativa por solicitação.
- Transferência exige justificativa e preserva ciclo anterior.
- Encerramento sem decisão devolve estado correto.
- Lembretes respeitam intervalos e limites aprovados.
- Usuário sem permissão não acessa solicitação por URL/ID direto.
- Mudança de papel revoga acesso sem depender de cache antigo.

### G. Importação e operações em lote
- Arquivo válido e mapeamento correto.
- Colunas obrigatórias ausentes.
- Campo somente leitura no arquivo.
- ID inexistente/duplicado/reservado.
- Linha com referência a item inativo.
- Mistura de linhas válidas e inválidas: somente linhas válidas aprovadas são aplicadas.
- Prévia não altera cadastro, custo, histórico nem auditoria de domínio de alteração efetiva.
- Dados mudam entre prévia e confirmação: revalidar e pedir nova confirmação ou rejeitar linha afetada.
- Reenvio do mesmo lote não duplica alterações.
- Importação registra usuário, origem, resultado, erros e linhas efetivamente aplicadas.
- Falha numa cascata originada por linha impede sucesso falso daquela linha.
- Auditoria cobre importações; registro operacional do lote não a substitui.

### H. Auditoria e histórico
- Cada operação crítica gera evento.
- Ator/origem/instante/objeto/resultado/correlação preenchidos.
- Valores sensíveis mascarados ou omitidos.
- Usuário comum e Administrador não alteram/apagam log pela UI/API comum.
- Alteração de configuração de auditoria gera evidência.
- Verificação de integridade detecta adulteração simulada.
- Divergência preserva original/evidência e gera alerta.
- Histórico de custo não é apagado por alteração de estrutura.
- Fotografia histórica permanece consultável após exclusão lógica.
- Auditoria registra tarefas internas e ações via API.

### I. Atualização em tempo real e notificações
- Evento publicado somente após commit.
- Nenhum evento após rollback.
- Cliente consulta API após receber evento.
- Evento duplicado não duplica ação.
- Evento fora de ordem não regride estado.
- Reconexão recupera estado via API.
- Notificação privada não pode ser lida por outro usuário.
- Fechar painel não marca notificação como lida.
- Leitura não reconhece alerta crítico.
- Reconhecimento não resolve alerta.
- Reabertura reinicia ciclo de reconhecimento conforme regra aprovada.

### J. Relatórios e exportações
- Filtros combinados e paginação.
- Respeito às permissões no relatório e na exportação.
- Segredos e campos restritos não aparecem no arquivo.
- Link expira e não funciona anonimamente.
- Permissão é revalidada no acesso ao arquivo.
- Arquivo incompleto não é disponibilizado.
- Limite de registros e divisão em partes conforme regra aprovada.
- Histórico operacional registra geração, falha, cancelamento e conclusão.

### K. Tarefas e recuperação
- Tarefa idempotente em repetição.
- Falha transitória e falha final são diferenciadas.
- Limite de tentativas e timeout respeitados.
- Tarefa duplicada não executa efeitos duplicados.
- Cancelamento não libera recurso antes da confirmação do backend.
- Reinício do worker recupera tarefas conforme política.
- Backup é restaurado em ambiente controlado e comparado.
- Procedimento de recuperação preserva auditoria e histórico.

### L. Segurança e abuso
- Acesso horizontal a item de outro escopo/usuário.
- Escalada de papel via payload.
- Chamada direta a endpoint oculto na interface.
- Enumeração de IDs.
- Rate limit e abuso distribuído.
- Token/chave/segredo em logs, exportações e mensagens de erro.
- Sessão revogada e 2FA.
- RLS com políticas de leitura e escrita testadas.
- Acesso privilegiado e tentativas de contornar auditoria.
- Testes de segurança independentes trimestrais e após mudanças relevantes.

## 3. Severidade e bloqueios

Usar a classificação aprovada no projeto:
- P0: contenção imediata; primeira medida em até 4 horas; bloqueia nova versão até correção/reteste ou exceção formal válida.
- P1: correção até 2 dias úteis.
- P2: correção até 15 dias úteis.
- P3: correção até 60 dias úteis.

Exceção P0 não apaga classificação, exige dois Administradores distintos, justificativa, prazo máximo de sete dias e renovações formalmente aprovadas conforme regra existente.

Falha só é encerrada após correção, reteste independente aprovado, evidências e validação por Administrador diferente. Recorrência reabre e mantém vínculo com ocorrência anterior quando houver correlação técnica suficiente.

## 4. Critérios de saída antes de produção

- Nenhum P0/P1 aberto sem tratamento formal aprovado.
- Todos os testes críticos de domínio, autorização e transação aprovados.
- Testes concorrentes executados em banco equivalente ao ambiente alvo.
- Backup restaurado com evidência.
- Auditoria validada e protegida.
- Monitoramento e alertas operacionais ativos.
- Plano de rollback e resposta a incidentes revisados.
- Permissões de produção e segredos revisados.
- Aprovação formal de release conforme governança do projeto.

## 5. Evidência de execução

Cada execução de suíte deve registrar:
- identificador e versão/commit testado;
- ambiente e configuração relevante;
- data/hora;
- responsável;
- suíte e casos executados;
- aprovados/reprovados/ignorados;
- evidência dos defeitos;
- severidade e responsável pela correção;
- reteste e decisão final.

## 6. Referências internas
- [Arquitetura Técnica Consolidada](ARQUITETURA-TECNICA-CONSOLIDADA-ALIANZA.md)
- [Matriz de Integridade](MATRIZ-DE-INTEGRIDADE-E-CONTROLES-ALIANZA.md)
- [Regras Funcionais](REGRAS-FUNCIONAIS-CADASTRO-E-CUSTEIO.md)
- [Registro Mestre](REGISTRO-MESTRE-DECISOES-APROVADAS-E-PENDENCIAS.md)
