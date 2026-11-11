#!/usr/bin/env python3
"""Teste local da precedência documental da decisão 3B.1.7.

Não conecta ao PostgreSQL e não simula resultados de produção. Testa apenas a
função de decisão descrita no SQL, incluindo riscos críticos e indeterminações.
"""

from dataclasses import dataclass, field


@dataclass
class State:
    critical: set[str] = field(default_factory=set)
    indeterminate: set[str] = field(default_factory=set)
    can_create_temp: bool = False
    temporary_acceptance_valid: bool = False


def decide(s: State) -> str:
    if s.critical:
        return "REPROVADA"
    if s.indeterminate:
        return "INDETERMINADA"
    if s.can_create_temp and not s.temporary_acceptance_valid:
        return "INDETERMINADA"
    if s.can_create_temp:
        return "APROVACAO_CONDICIONAL_TEMPORARY"
    return "APROVADA"


cases = [
    ("todos os controles aprovados", State(), "APROVADA"),
    ("hash SHA-256 divergente", State(indeterminate={"has_stale_function_review"}), "INDETERMINADA"),
    ("função sem revisão individual", State(indeterminate={"has_missing_function_review"}), "INDETERMINADA"),
    ("aggregate sem cobertura", State(indeterminate={"has_missing_function_review", "has_nonverifiable_executable_function"}), "INDETERMINADA"),
    ("SECURITY DEFINER com privilégio do owner", State(critical={"has_owner_effective_privilege_risk"}), "REPROVADA"),
    ("metadados SECURITY DEFINER incompletos", State(indeterminate={"has_security_definer_metadata_indeterminate"}), "INDETERMINADA"),
    ("transaction_read_only desligado", State(critical={"transaction_read_only_ok"}), "REPROVADA"),
    ("default_transaction_read_only desligado", State(critical={"default_transaction_read_only_ok"}), "REPROVADA"),
    ("FDW com privilégio efectivo indevido", State(critical={"has_fdw_effective_privilege"}), "REPROVADA"),
    ("Foreign Server com privilégio efectivo indevido", State(critical={"has_server_effective_privilege"}), "REPROVADA"),
    ("Default ACL perigoso", State(indeterminate={"has_dangerous_default_acl"}), "INDETERMINADA"),
    ("TEMPORARY sem aceitação formal", State(can_create_temp=True), "INDETERMINADA"),
    ("TEMPORARY com aceitação formal válida", State(can_create_temp=True, temporary_acceptance_valid=True), "APROVACAO_CONDICIONAL_TEMPORARY"),
    ("ownership relevante não verificável", State(indeterminate={"ownership_catalogs_selectable"}), "INDETERMINADA"),
    ("indicador crítico isolado de Large Object", State(critical={"has_large_object_read"}), "REPROVADA"),
]

for name, state, expected in cases:
    actual = decide(state)
    assert actual == expected, f"{name}: expected {expected}, got {actual}"
    print(f"PASS | {name} | {actual}")

print(f"{len(cases)} cenários aprovados")
