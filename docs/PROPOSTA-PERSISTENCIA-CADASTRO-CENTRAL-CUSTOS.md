# Proposta de persistência — Cadastro Central de Custos

**Status:** proposta técnica em implementação controlada; não autoriza migration, DDL ou gravação no banco.

## Objetivo

Persistir o cadastro de custos em estrutura própria, separada do catálogo comercial. O modelo respeita as decisões já aprovadas: grupos manuais por organização, itens com preço unitário genérico, composição por referências a itens, conversões dimensionais e Gama em configuração independente.

## Modelo inicial proposto

| Entidade | Finalidade |
|---|---|
| `cost_groups` | Grupos criados manualmente por organização, com nome, ordem e estado. |
| `cost_items` | Cadastro central de itens simples ou compostos, grupo opcional, código, nome, unidade de referência e custo manual quando simples. |
| `cost_structures` | Versões de composição de um item, com quantidade-base de saída e estado da versão. |
| `cost_structure_lines` | Componentes referenciados por ID, quantidade, unidade informada, ordem e observação. |
| `cost_calculations` | Registro do resultado exato calculado, separado da estrutura e dos dados de entrada. |
| `costing_gamma_settings` | Ativação e percentual da Gama por organização; percentual inicial proposto de 1,2%. |
| `costing_gamma_groups` | Relação explícita dos grupos selecionados para receber Gama. |

Todas as entidades pertencem a uma organização. Relações entre grupo, item, estrutura e componente devem validar também a organização, impedindo referências cruzadas entre tenants.

## Precisão e representação monetária

- Custo manual: decimal de texto/SQL com escala de três casas, sem conversão para ponto flutuante binário.
- Resultado exato: numerador e denominador inteiros armazenados como texto, preservando frações periódicas e valores maiores que a escala de exibição.
- Resultado apresentado: campo decimal separado com até três casas, produzido exclusivamente pela regra de arredondamento aprovada.
- Não usar `number` para valores monetários persistidos nem usar o campo apresentado como entrada de um cálculo posterior.

## Integridade proposta

- Itens simples usam custo manual; itens compostos usam uma estrutura válida. Não misturar os dois modos na mesma versão de item.
- Linhas de composição referenciam itens existentes na mesma organização.
- Exclusão física de itens referenciados deve ser restringida; a desativação preserva histórico.
- Estruturas possuem versão e estado. A política de qual versão pode ser considerada vigente e a garantia de apenas uma versão ativa por item ainda precisam ser fechadas antes da migration.
- Ciclos diretos e indiretos continuam sendo rejeitados pelo domínio de cálculo; a validação transacional de gravação também deverá impedir a persistência de ciclos.
- Gama permanece fora dos grupos e da recursão genérica. A aplicação será calculada separadamente sobre os grupos explicitamente selecionados.

## Estado da implementação

- Criado o arquivo de definição Drizzle `drizzle/pg/schema.costing.ts` no branch de implementação, sem gerar ou executar migration.
- O arquivo ainda não está conectado ao repositório de consultas nem à camada de persistência.
- Não há migration, DDL, gravação, deploy ou alteração de banco nesta etapa.
- A configuração padrão `drizzle.config.ts` ainda aponta para o schema MySQL. A trilha PostgreSQL/Supabase existente usa arquivos específicos em `drizzle/pg`; a configuração e o journal de migrations precisam ser reconciliados antes de qualquer geração/aplicação.
- O motor de cálculo é stateless e a API atual apenas calcula; o CRUD persistente ainda não foi implementado.

## Bloqueios antes de persistir

1. Confirmar identidade inequívoca de banco não produtivo.
2. Reconciliar inventário físico, schema PostgreSQL, migrations aplicadas e journal.
3. Desenhar e revisar RLS para todas as tabelas, incluindo leitura e escrita por `app_runtime`, com isolamento por organização.
4. Validar as constraints compostas e o comportamento de exclusão/arquivamento.
5. Testar rollback real e concorrência antes de liberar migrations.
6. Definir política de versão ativa, histórico/snapshot e recálculo de dependentes.

**Conclusão:** o modelo de dados está esboçado no código, mas não está pronto para uso persistente. Nenhuma tabela existe no banco por causa deste trabalho, e nenhuma gravação de custos deve ser habilitada até que os bloqueios acima sejam resolvidos.
