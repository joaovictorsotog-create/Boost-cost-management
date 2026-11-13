# Comparação de estratégias de bootstrap PostgreSQL

## Alternativa A — Baseline PostgreSQL autoritativo

**Descrição:** produzir uma versão inicial completa do schema PostgreSQL, com objetos, grants e helpers necessários, identificada por SHA; depois aplicar migrations incrementais novas.

**Vantagens:**

- elimina a ambiguidade do journal histórico;
- permite instalação limpa reproduzível;
- torna Costing, RLS e Supabase dependências explícitas;
- permite testar em cluster descartável antes de qualquer ambiente persistente.

**Riscos:**

- exige revisão e aprovação do baseline;
- pode divergir de bancos históricos se o inventário não for completo;
- requer plano de transição para instalações existentes.

**Avaliação:** melhor opção e recomendada.

## Alternativa B — Reconstrução controlada da cadeia histórica

**Descrição:** reconciliar SQLs, duplicidades, lacuna `0016`, journal e snapshots, mantendo a intenção histórica.

**Vantagens:** preserva maior rastreabilidade histórica e pode aproximar instalações já existentes.

**Riscos:**

- duplicidades `0007`, `0021`, `0027`, `0032` não têm resolução inequívoca no estado atual;
- histórico pode conter variantes incompatíveis;
- renumerar ou fabricar journal destruiria proveniência;
- ainda seria necessário resolver `rls_auto_enable`, `auth.uid()` e funções SECURITY DEFINER.

**Avaliação:** necessária como investigação de proveniência, mas não adequada como mecanismo automático de bootstrap agora.

## Alternativa C — Bootstrap inicial + migrations incrementais

**Descrição:** criar somente baseline mínimo e aplicar SQLs históricos restantes em sequência.

**Vantagens:** menor mudança aparente e rápida separação entre base e incrementos.

**Riscos:** o baseline mínimo ainda precisa escolher quais objetos de `0000`–`0035` são essenciais; o journal atual não informa o estado; RLS global depende de módulos e funções fora do Costing.

**Avaliação:** só é segura depois que a Alternativa A existir; isoladamente repete o problema histórico.

## Recomendação única

Adotar a **Alternativa A**, com o histórico reconciliado apenas como evidência e migração de instalações existentes. O baseline deve conter o schema PostgreSQL completo aprovado, incluindo objetos base, Costing, helpers, roles esperadas, grants, RLS e funções SECURITY DEFINER com `search_path = ''`. Depois, Costing deve seguir em migrations incrementais journalizadas.

Nenhuma dessas alternativas foi implementada nesta entrega.
