# Alianza Costing — Mapa de dependências

## Grafo principal

```text
0000 baseline
 ├─ organizations ───────────────┐
 ├─ users ── supabaseAuthId (0001)│
 └─ organization_members ────────┘
                                  │
                                  ▼
                         0036_costing_foundation
                                  │
       ┌──────────────────────────┼───────────────────────────┐
       ▼                          ▼                           ▼
   cost_groups              cost_items                 gamma_settings
       │                          │                           │
       │                          ▼                           │
       │                   cost_structures                   │
       │                          │                           │
       ├───────────────► structure_lines                       │
       │                          │                           │
       └───────────────► gamma_groups                          │
                                  │                           │
                                  ▼                           ▼
                           cost_calculations ◄──── settings/groups
                                  │
                         immutable trigger
```

## Dependências de tabela

- Todas as sete tabelas Costing referenciam `organizations("id")` por `organizationId`.
- `cost_items` referencia `cost_groups` por `(organizationId, groupId)`.
- `cost_structures` referencia `cost_items` por `(organizationId, itemId)`.
- `cost_structure_lines` referencia `cost_structures` e `cost_items` por chaves compostas tenant-scoped.
- `cost_calculations` referencia `cost_items` e opcionalmente `cost_structures` por chaves compostas.
- `costing_gamma_settings` referencia `organizations` e impõe uma configuração por organização.
- `costing_gamma_groups` referencia `organizations` e `cost_groups` por chaves compostas.
- `cost_calculations` é protegido por `prevent_cost_calculation_update()` e trigger `cost_calculations_immutable`.

## Dependências de identidade/RLS

`rls_multitenant.sql` depende de objetos que não são criados por `0036`:

- `public.users`;
- `public.organization_members`;
- `public.organizations`;
- `auth.uid()` da infraestrutura Supabase;
- roles `anon`, `authenticated` e `app_runtime`;
- funções/helpers `private.*` de migrations históricas ou do próprio payload;
- diversas tabelas não-Costing listadas no loop global.

As funções `SECURITY DEFINER` principais definidas/hardenizadas pelo payload usam `set search_path = ''`. A existência e a assinatura das funções históricas opcionais são verificadas condicionalmente com `to_regprocedure`, mas isso não transforma o payload em bootstrap independente.

## Escopo do preflight

`apply-supabase-rls.mjs` faz preflight de ambiente, URL, project ref e hostname; depois lê e executa o arquivo global `drizzle/pg/rls_multitenant.sql` em transação. Portanto:

```text
preflight seguro de destino
        + payload global RLS
        ≠ instalação/validação exclusiva do Costing
```

A camada de transporte está fail-closed para production e destinos não autorizados, mas o escopo do SQL continua global. Para teste Costing-only é necessário um payload distinto ou um banco descartável explicitamente preparado com baseline compatível.

## Dependências de backend

- `server/routers.ts` registra `costingRouter`.
- `server/routers/costing.ts` expõe `calculate`, `calculateWithGamma`, `createSnapshot`, `snapshots` e `publishStructure`.
- `server/db/costing.ts` lê itens/estruturas/Gama, cria snapshots e publica estruturas.
- `server/lib/appRuntimeDb.ts` pode fornecer conexão `app_runtime` por request quando habilitada e exige readiness em produção.
- A autorização de tenant ocorre no procedimento e a identidade de organização é um input validado; o fluxo integrado real ainda requer ambiente autorizado.

## Gaps de dependência

- Não há UI/hook frontend encontrado para chamar os endpoints Costing.
- Não há endpoints CRUD para cadastrar/editar grupos, itens, preços manuais, estruturas ou Gama.
- O backend de cálculo recebe itens no endpoint `calculate`, enquanto o snapshot autoritativo lê itens do banco; o teste funcional deve distinguir esses dois contratos.
- A cadeia Drizzle journal/meta não cobre a migration 0036.
