# B. Triggers de imutabilidade — análise independente

## SQL integral auditado

A migration `0037_costing_correction_integrity.sql` instala estes triggers:

```sql
CREATE OR REPLACE FUNCTION "prevent_published_cost_structure_mutation"() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD."status" <> 'DRAFT' THEN
      RAISE EXCEPTION 'Published cost structures are immutable';
    END IF;
    RETURN OLD;
  END IF;

  IF OLD."status" IN ('SUPERSEDED', 'INACTIVE') THEN
    RAISE EXCEPTION 'Published cost structures are immutable';
  END IF;

  IF OLD."status" = 'ACTIVE' THEN
    IF NEW."status" <> 'SUPERSEDED' OR
       ROW(NEW."id", NEW."organizationId", NEW."itemId", NEW."version", NEW."outputQuantity", NEW."createdAt") IS DISTINCT FROM
       ROW(OLD."id", OLD."organizationId", OLD."itemId", OLD."version", OLD."outputQuantity", OLD."createdAt") THEN
      RAISE EXCEPTION 'Active cost structures are immutable except for superseding';
    END IF;
  ELSIF OLD."status" = 'DRAFT' AND NEW."status" NOT IN ('DRAFT', 'ACTIVE') THEN
    RAISE EXCEPTION 'Invalid cost structure status transition';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS "cost_structures_published_immutable" ON "cost_structures";
CREATE TRIGGER "cost_structures_published_immutable" BEFORE UPDATE OR DELETE ON "cost_structures" FOR EACH ROW EXECUTE FUNCTION "prevent_published_cost_structure_mutation"();

CREATE OR REPLACE FUNCTION "prevent_published_cost_structure_line_mutation"() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  source_status text;
  destination_status text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT "status" INTO destination_status
    FROM "cost_structures"
    WHERE "organizationId" = NEW."organizationId" AND "id" = NEW."structureId";
    IF destination_status IS DISTINCT FROM 'DRAFT' THEN
      RAISE EXCEPTION 'Lines of published cost structures are immutable';
    END IF;
    RETURN NEW;
  END IF;

  SELECT "status" INTO source_status
  FROM "cost_structures"
  WHERE "organizationId" = OLD."organizationId" AND "id" = OLD."structureId";
  IF source_status IS DISTINCT FROM 'DRAFT' THEN
    RAISE EXCEPTION 'Lines of published cost structures are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;

  IF NEW."organizationId" <> OLD."organizationId" THEN
    RAISE EXCEPTION 'A cost structure line cannot change organization';
  END IF;
  SELECT "status" INTO destination_status
  FROM "cost_structures"
  WHERE "organizationId" = NEW."organizationId" AND "id" = NEW."structureId";
  IF destination_status IS DISTINCT FROM 'DRAFT' THEN
    RAISE EXCEPTION 'Lines of published cost structures are immutable';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS "cost_structure_lines_published_immutable" ON "cost_structure_lines";
CREATE TRIGGER "cost_structure_lines_published_immutable" BEFORE INSERT OR UPDATE OR DELETE ON "cost_structure_lines" FOR EACH ROW EXECUTE FUNCTION "prevent_published_cost_structure_line_mutation"();
```

O ficheiro integral preservado está em `files/drizzle/pg/0037_costing_correction_integrity.sql`.

## Matriz de operações

| Entidade/estado | INSERT | UPDATE | DELETE |
|---|---:|---:|---:|
| Linha em DRAFT | permitido | permitido se origem e destino forem DRAFT | permitido |
| Linha em ACTIVE | bloqueado | bloqueado | bloqueado |
| Linha em SUPERSEDED | bloqueado | bloqueado | bloqueado |
| Linha em INACTIVE | bloqueado | bloqueado | bloqueado |
| Estrutura DRAFT | não abrangido pelo trigger de mutação | DRAFT→DRAFT e DRAFT→ACTIVE permitidos | permitido |
| Estrutura ACTIVE | não aplicável | somente ACTIVE→SUPERSEDED, com campos protegidos inalterados | bloqueado |
| Estrutura SUPERSEDED | não aplicável | bloqueado | bloqueado |
| Estrutura INACTIVE | não aplicável | bloqueado | bloqueado |

Os campos protegidos de uma estrutura ACTIVE são `id`, `organizationId`, `itemId`, `version`, `outputQuantity` e `createdAt`. `updatedAt` pode acompanhar a transição legítima para `SUPERSEDED`.

## Evidências executadas

O executor PostgreSQL foi realmente executado com dados artificiais. As tentativas diretas incluíram:

- INSERT em ACTIVE, SUPERSEDED e INACTIVE;
- UPDATE de linha publicada;
- movimento de linha de DRAFT para ACTIVE;
- UPDATE simultâneo de `organizationId` e `structureId` numa execução adicional;
- DELETE de linha publicada;
- alteração direta de todos os campos protegidos da estrutura ACTIVE;
- transição ACTIVE→INACTIVE;
- UPDATE e DELETE de estruturas SUPERSEDED e INACTIVE;
- INSERT, UPDATE e DELETE positivos numa DRAFT.

O resultado SQL foi `direct-published-immutability-and-line-protection-ok` e, na prova adicional, `simultaneous-org-structure-protection-ok`.
