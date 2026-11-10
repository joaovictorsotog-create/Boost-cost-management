# Matriz de integridade e controles — Alianza

**Status:** proposta técnica derivada das regras aprovadas e estudos de referência.  
**Objetivo:** transformar riscos de integridade em controles verificáveis. Não representa implementação concluída.

## 1. Matriz de controles

| Domínio | Risco | Controle exigido/proposto | Evidência verificável | Estado |
|---|---|---|---|---|
| Identidade do item | ID duplicado ou reutilizado | Restrição única no banco + validação backend; IDs reservados não reutilizam | Teste de concorrência e constraint | Regra aprovada; algoritmo de geração divergente |
| Cadastro | Alteração por perfil indevido | Autorização no backend por ação/recurso/estado | Testes API positivos e negativos | Regra aprovada |
| Família | Família inativada com itens vinculados | Bloquear até reclassificação; transação na mudança | Teste de integridade referencial | Regra aprovada |
| Unidade | Conversão implícita incorreta | Unidade única por item; sem conversão automática | Testes de validação/cálculo | Regra aprovada |
| Estrutura | Ciclo direto/indireto | Validação de grafo antes de persistir | Testes de ciclo e concorrência | Regra aprovada |
| Cálculo | Dupla contagem | Custo do composto deriva da estrutura; contabilizar cada ocorrência e consolidar submontagens sem somar filhos novamente | Testes de estruturas repetidas e multinível | Regra aprovada |
| Cálculo | Precisão e arredondamento inconsistente | Decimal exato/precisão interna definida; arredondamento de apresentação aprovado | Testes de fronteira decimal | Regra parcial; precisão interna pendente |
| Cascata | Custos de pais ficam desatualizados | Orquestrar dependências e persistir resultado consistente | Teste de cascata e rollback | Regra aprovada; protocolo técnico pendente |
| Cascata | Estado parcial anunciado como concluído | Estado explícito da operação; conclusão só após commit final | Teste de falha intermediária | Proposta técnica |
| Concorrência | Lost update | Controle de versão e/ou bloqueio no ciclo read-modify-write | Teste com conexões simultâneas | Proposta técnica |
| Aprovação | Dois Admins assumem/decidem ao mesmo tempo | Compare-and-set/lock transacional; titularidade única | Teste concorrente | Regra aprovada |
| Aprovação | Aprovação sobre dado alterado | Revalidar valores, referências e permissões no ato de decisão | Teste de conflito entre prévia e confirmação | Regra aprovada |
| Importação | Prévia altera cadastro | Staging isolado, sem persistência no domínio antes da confirmação | Teste de não mutação | Regra aprovada |
| Importação | Linha inválida invalida indevidamente linhas válidas ou vice-versa | Aprovação parcial por linha; transação por linha/grupo dependente | Testes mistos de linhas válidas/inválidas | Regra aprovada; granularidade técnica pendente |
| Importação | Reenvio duplica efeito | Chave de idempotência/lote e estado de execução | Teste de repetição | Proposta técnica |
| Auditoria | Evento ausente ou editável | Escrita backend no mesmo limite transacional quando possível; append-only lógico; proteção de acesso | Teste de cobertura e tentativa de alteração | Regra aprovada |
| Auditoria | Segredo exposto | Não persistir segredo; mascarar antes de log/consulta/exportação | Testes de redaction | Regra aprovada |
| Auditoria | Adulteração não detectada | Verificação diária e após eventos de infraestrutura; evidências preservadas | Teste de divergência/alerta | Regra aprovada |
| Tempo real | Evento enviado antes de rollback | Publicar somente após commit | Teste de rollback sem evento | Proposta técnica |
| Tempo real | Cliente perde evento | Reconciliação via API após reconexão | Teste desconecta/reconecta | Proposta técnica |
| Notificação | Usuário acessa notificação alheia | Consulta privada por destinatário + autorização backend | Teste de acesso cruzado | Regra aprovada |
| Exportação | Arquivo acessível sem autorização | Link temporário não público; permissão revalidada a cada acesso | Teste de expiração e acesso anônimo | Regra aprovada |
| Tarefa | Retry duplica alterações | Idempotência, tentativas limitadas e classificação de falha | Teste de repetição e falha | Proposta técnica |
| Backup | Backup não restaura | Teste periódico de restauração e evidência | Relatório de restore | Frequência/retention pendentes |
| Segurança | Enumeração/abuso de API | Rate limit, monitoramento e contenção proporcional | Teste de abuso e alertas | Regra aprovada |
| Incidente | Evidência sobrescrita | Preservação, cadeia de custódia, registro de ações | Simulado e revisão | Regra aprovada |

## 2. Limites transacionais recomendados

Não existe uma transação universal para todo o sistema. O limite deve corresponder à unidade de consistência do domínio.

### 2.1 Uma alteração simples
Persistir valor, histórico e auditoria essencial na mesma transação quando residirem no mesmo banco. Publicar eventos externos após commit.

### 2.2 Uma cascata de custo
Tratar a cascata como uma operação correlacionada. Os custos vigentes dos compostos afetados e os registros de histórico devem representar um estado coerente. Se o volume exigir execução assíncrona, definir estado de processamento e estratégia que impeça apresentar resultado parcial como definitivo.

### 2.3 Importação
A regra funcional permite confirmar linhas válidas e deixar linhas inválidas de fora. Logo:
- prévia e validação são independentes da aplicação;
- cada linha ou conjunto de linhas interdependentes deve ter limite transacional explícito;
- uma linha aprovada que dispara cascata não pode persistir custo simples sem completar ou registrar corretamente a operação derivada;
- o resultado do lote distingue sucesso, falha e não processado;
- a auditoria registra cada alteração efetiva e o lote de origem.

### 2.4 Aprovação
A assunção de titularidade e a decisão precisam ser atômicas. A aprovação e a alteração oficial não podem divergir: ou ambas persistem, ou nenhuma é considerada concluída.

### 2.5 Exportação
A geração do arquivo pode ser assíncrona. A disponibilização do arquivo só ocorre após conclusão e validação; falha não libera arquivo parcial como válido.

## 3. Concorrência e ordenação

- Identificar o conjunto de registros afetados antes de bloquear.
- Adquirir bloqueios em ordem estável (por ID) quando bloqueio pessimista for escolhido.
- Verificar versão/timestamp esperado antes de gravar.
- Se a versão mudou, abortar ou solicitar nova confirmação; nunca sobrescrever silenciosamente.
- Testar deadlock, timeout e retry.
- Retry só é seguro se a operação for idempotente e não repetir efeitos externos.
- Gerar IDs por restrição única no banco, não apenas por consulta prévia da interface.

## 4. Auditoria e consistência de eventos

Cada operação relevante deve ter um correlation_id estável. Eventos de auditoria devem conter, conforme aplicável:
- identificador único;
- ator e identificador histórico;
- origem: interface, API, importação ou tarefa;
- ação e objeto;
- instante;
- resultado;
- justificativa;
- lote/operação correlacionada;
- referência a valores anteriores/novos, com mascaramento;
- versão ou fotografia relacionada.

A escrita de auditoria deve falhar junto com a operação crítica quando a regra exigir evidência inseparável. Para efeitos externos (e-mail, WebSocket, webhook), usar publicação após commit, preferencialmente via outbox transacional ou padrão equivalente.

A verificação criptográfica do log e a proteção contra administrador privilegiado exigem desenho próprio; hash em tabela no mesmo banco não impede, por si só, adulteração por um agente com privilégio suficiente.

## 5. Segurança e autorização

- Negação por padrão.
- Validar autorização em cada endpoint, inclusive operações em lote.
- Não confiar em botões ocultos, validação do navegador ou IDs difíceis de adivinhar.
- RLS no banco complementa, mas não substitui a lógica de negócio.
- Mudanças de papel e revogações devem invalidar cache/sessão de modo previsível.
- Importação, exportação, tarefas internas e API usam as mesmas regras de domínio.
- Segredos nunca são exportáveis nem visíveis em auditoria.

## 6. Integridade histórica

- Histórico de custo não é log de auditoria.
- Fotografia de estrutura preserva a composição usada em um cálculo anterior.
- Exclusão lógica não apaga referências históricas.
- A alteração de estrutura vigente não deve reescrever o passado.
- Política de retenção precisa ser específica por categoria documental e respeitar os prazos já aprovados.

## 7. Questões técnicas a fechar

1. Banco e garantias transacionais reais.
2. Estratégia de concorrência por operação.
3. Limite máximo de componentes e profundidade, se necessário, com base em uso real.
4. Estratégia de cascata síncrona/assíncrona.
5. Outbox e entrega de eventos.
6. Precisão interna e tipo decimal.
7. Versionamento e fotografia de estrutura.
8. Chaves de idempotência e política de retry.
9. Frequência/retenção de backup e testes de restauração.
10. Modelo de proteção de auditoria contra privilégios de infraestrutura.

## 8. Referências internas
- [Arquitetura Técnica Consolidada](ARQUITETURA-TECNICA-CONSOLIDADA-ALIANZA.md)
- [Plano de Testes Arquiteturais](PLANO-DE-TESTES-ARQUITETURAIS-ALIANZA.md)
- [Regras Funcionais](REGRAS-FUNCIONAIS-CADASTRO-E-CUSTEIO.md)
- [Estudo Comparativo](ESTUDO-COMPARATIVO-ARQUITETURA-REFERENCIAS.md)
