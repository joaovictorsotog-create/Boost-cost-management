# Instalação em banco vazio — escopo exato

## Comando

```text
scripts/run-costing-final-verification-pg.sh
```

## Estado inicial

Cluster PostgreSQL temporário criado por `initdb`, sem schema `drizzle`, sem
`__drizzle_migrations` e sem tabelas Costing. Não é banco de produção nem
Supabase remoto.

## Migrations realmente aplicadas

O runner Drizzle usou exclusivamente o journal atual:

```text
0000_eminent_mathemanic
0001_pink_pete_wisdom
0036_costing_foundation
0037_costing_correction_integrity
0038_costing_final_stabilization
0039_costing_rls_security
```

Foram criadas as oito tabelas Costing. O runner foi executado uma segunda vez;
a segunda execução concluiu com sucesso e sem duplicar objetos.

## Classificação

Isto comprova uma instalação específica do recorte Costing em banco vazio. Não
comprova instalação completa do Alianza, porque as migrations históricas
`0002–0035` não estão todas no journal atual.

## Dependências

A prova usa PostgreSQL 16 local, Drizzle Kit e dependências instaladas do
projeto. A prova RLS cria roles descartáveis e fixtures artificiais.

## Problemas históricos

Não existe migration PostgreSQL `0016`; há tags numéricos duplicados; e o
ensaio estrito da árvore histórica falha em `0002` pela referência a
`public.rls_auto_enable()` sem definição local. Nenhum desses problemas foi
reconstruído ou ocultado.
