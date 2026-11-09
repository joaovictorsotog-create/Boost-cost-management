# Protocolo de continuidade e decisões incrementais — Alianza Sistema de Custos

**Status:** adotado como método de trabalho a partir de 09/11/2026  
**Branch:** `docs/regras-custeio-cadastro-central`  
**Objetivo:** permitir que o projeto avance com a documentação já consolidada, sem exigir a recuperação prévia de todas as conversas históricas.

## 1. Fonte central de continuidade

O GitHub é a referência documental de continuidade do projeto. Antes de propor ou responder sobre uma regra já tratada:

1. Consultar o Registro Mestre de Decisões.
2. Consultar as Regras Funcionais de Cadastro e Custeio.
3. Consultar a Ordem Mestra e a especificação funcional original quando estiverem disponíveis.
4. Consultar este protocolo e o checklist para saber o estado atual do trabalho.
5. Usar conversas antigas como fonte complementar quando acessíveis, sem bloquear o avanço por sua ausência.

A documentação registra requisitos e decisões; não comprova que estejam implementados.

## 2. Classificação obrigatória de cada assunto

Todo requisito, dúvida ou proposta deve receber uma destas classificações:

- **APROVADO:** confirmação explícita do usuário, com contexto suficiente.
- **BASE DOCUMENTAL:** regra registrada nos documentos atuais, ainda sujeita a conferência de precedência caso surja conflito com fonte oficial.
- **PENDENTE DE DECISÃO:** exige resposta ou escolha explícita do usuário.
- **HIPÓTESE TÉCNICA:** alternativa proposta para viabilizar análise; não é decisão funcional nem autorização de implementação.
- **CONFLITO:** duas fontes ou decisões parecem divergir; suspender apenas o ponto afetado e apresentar as evidências.
- **FORA DE ESCOPO:** assunto que não pertence ao Sistema de Custos conforme o escopo aprovado.

Não transformar hipótese, recomendação ou silêncio do usuário em aprovação.

## 3. Fluxo incremental de trabalho

1. Escolher um módulo ou fluxo por vez.
2. Levantar o que já está aprovado e registrado.
3. Descrever o comportamento esperado usando apenas as regras conhecidas.
4. Identificar lacunas concretas que impedem especificar aquele ponto.
5. Fazer ao usuário somente a pergunta mais importante para resolver a lacuna atual.
6. Após a resposta, registrar a decisão com data, contexto e impacto nos documentos.
7. Continuar para o próximo ponto, sem reabrir decisões já fechadas.

A falta das oito conversas ainda não localizadas no ZIP de 06/11/2026 não bloqueia o trabalho. Se uma conversa ausente contiver uma decisão relevante descoberta depois, ela será incorporada como atualização, com origem e histórico preservados.

## 4. Como tratar conflitos e novas informações

- Não apagar silenciosamente uma regra antiga.
- Registrar a regra anterior, a nova evidência, a decisão do usuário e os documentos/módulos afetados.
- Se o conflito puder alterar custo, integridade, segurança ou arquitetura, não avançar com implementação desse ponto até resolvê-lo.
- Se a divergência não afetar o módulo em andamento, isolá-la como pendência e continuar o trabalho não bloqueado.
- Ao receber planilhas, exemplos ou documentos, tratá-los como evidência e contexto; não converter automaticamente cada fórmula/observação em regra universal.

## 5. Registro e versionamento no GitHub

Quando uma decisão for confirmada ou uma regra for consolidada:

1. Atualizar o Registro Mestre.
2. Atualizar o documento funcional do módulo afetado.
3. Atualizar este protocolo/checklist quando o estado do trabalho mudar.
4. Registrar a fonte: conversa, arquivo, exemplo ou confirmação nesta sessão.
5. Fazer commit na branch de documentação.
6. Informar ao usuário o que mudou e o que continua pendente.

Não fazer merge, deploy, migration, alteração de banco remoto ou infraestrutura sem autorização específica.

## 6. Ritmo e limites

- Trabalhar por módulos/fluxos pequenos, com entregas verificáveis.
- Não tentar reconstruir todo o histórico antes de produzir especificação útil.
- Não fazer perguntas repetidas quando a resposta já estiver documentada.
- Não preencher lacunas com suposições para acelerar.
- Não iniciar implementação enquanto os requisitos do módulo não tiverem clareza suficiente e autorização explícita.
- A auditoria das conversas restantes pode ocorrer oportunisticamente quando o usuário trouxer uma conversa ou quando ela for necessária para resolver um conflito específico.

## 7. Primeiro roteiro de trabalho

Ordem sugerida, ajustável conforme dependências encontradas:

1. Cadastro Central: campos, tipos Simples/Composto, famílias, unidades e estados.
2. Estrutura do produto: inclusão de componentes, quantidades, hierarquia e resumo por família.
3. Motor de custeio: fórmulas, precisão, arredondamento, custos incompletos e propagação.
4. Alterações e confirmações: prévia, impactos, confirmação, cancelamento e transação.
5. Histórico, revisão semestral, alertas e auditoria.
6. Importação/atualização em lote.
7. Usuários, permissões, segurança e configurações.
8. Pesquisa, navegação, relatórios e responsividade.
9. Arquitetura, backup, implantação e testes de aceite.

A sequência não significa que todos os itens acima estejam aprovados em detalhe. As decisões existentes continuam prevalecendo; as lacunas são resolvidas quando o respectivo módulo for trabalhado.

## 8. Limite de cobertura histórica conhecido

O ZIP exportado em 06/11/2026 contém 36 conversas, das quais 19 foram identificadas pelo metadado do projeto e revisadas. O usuário mencionou 27 conversas no projeto; portanto, oito não aparecem nesse ZIP. Esse limite deve ser transparente, mas não constitui bloqueio para a continuidade incremental.
