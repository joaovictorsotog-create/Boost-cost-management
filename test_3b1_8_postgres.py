#!/usr/bin/env python3
"""Testes PostgreSQL reais da Entrega 3B.1.8.

A suíte cria um cluster descartável, não usa Supabase e executa literalmente a
consulta da Etapa 13 extraída do SQL publicado. As entradas de revisão e de
aceitação são injetadas somente como CTE VALUES externas, sem gravar no banco.
"""
from __future__ import annotations
import hashlib, os, re, shutil, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SQL = ROOT / "alianza-entrega-3b1-role-auditoria.sql"
ROLE = "alianza_audit_ro"
SOCKET = Path(tempfile.mkdtemp(prefix="pg3b18-sock-"))
DATA = Path(tempfile.mkdtemp(prefix="pg3b18-data-"))
PORT = "55438"
BIN = Path("/usr/lib/postgresql/16/bin")

def cmd(args, *, user=None, check=True):
    env = os.environ.copy(); env["PATH"] = f"{BIN}:{env['PATH']}"
    if user: args = ["runuser", "-u", user, "--", *args]
    kwargs = {"text": True, "env": env, "check": check}
    if args and args[0] == "pg_ctl":
        kwargs.update(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        kwargs["capture_output"] = True
    return subprocess.run(args, **kwargs)

def psql(sql, *, role="ubuntu", db="audit_test"):
    return cmd(["psql", "-X", "-h", str(SOCKET), "-p", PORT, "-U", role, "-d", db, "-At", "-F", "|", "-v", "ON_ERROR_STOP=1", "-c", sql]).stdout.strip()

def sqlq(v, typ="text"):
    if v is None: return f"NULL::{typ}"
    if isinstance(v, bool): return ("TRUE" if v else "FALSE")
    return "'" + str(v).replace("'", "''") + "'::" + typ

def setup():
    cmd(["initdb", "-D", str(DATA), "--auth=trust", "--no-locale"])
    cmd(["pg_ctl", "-D", str(DATA), "-o", f"-k {SOCKET} -p {PORT} -h ''", "-w", "start"])
    cmd(["createdb", "-h", str(SOCKET), "-p", PORT, "audit_test"])
    psql("""
      CREATE ROLE alianza_audit_ro LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
        NOREPLICATION NOBYPASSRLS NOINHERIT;
      ALTER ROLE alianza_audit_ro SET default_transaction_read_only='on';
      CREATE SCHEMA audit_fixture; CREATE TABLE audit_fixture.anchor(id integer);
      CREATE SCHEMA supabase_migrations;
      CREATE TABLE supabase_migrations.schema_migrations(version text);
      GRANT USAGE ON SCHEMA supabase_migrations TO alianza_audit_ro;
      GRANT SELECT ON supabase_migrations.schema_migrations TO alianza_audit_ro;
      REVOKE CREATE ON SCHEMA public FROM PUBLIC;
      REVOKE CREATE ON DATABASE audit_test FROM PUBLIC;
      REVOKE TEMPORARY ON DATABASE audit_test FROM PUBLIC;
      CREATE FUNCTION audit_fixture.fn_ok() RETURNS integer LANGUAGE sql IMMUTABLE AS 'SELECT 1';
      CREATE FUNCTION audit_fixture.transfn(state integer, value integer) RETURNS integer LANGUAGE sql IMMUTABLE AS 'SELECT coalesce(state,0)+value';
      CREATE AGGREGATE audit_fixture.sum_ok(integer) (SFUNC=audit_fixture.transfn, STYPE=integer);
      CREATE PROCEDURE audit_fixture.proc_ok() LANGUAGE sql AS 'SELECT 1';
      REVOKE ALL ON FUNCTION audit_fixture.fn_ok() FROM PUBLIC;
      REVOKE ALL ON FUNCTION audit_fixture.transfn(integer,integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION audit_fixture.sum_ok(integer) FROM PUBLIC;
      REVOKE ALL ON PROCEDURE audit_fixture.proc_ok() FROM PUBLIC;
      GRANT EXECUTE ON FUNCTION audit_fixture.fn_ok() TO alianza_audit_ro;
      GRANT EXECUTE ON PROCEDURE audit_fixture.proc_ok() TO alianza_audit_ro;
      GRANT EXECUTE ON FUNCTION audit_fixture.sum_ok(integer) TO alianza_audit_ro;
    """)

def inventory():
    out = psql("""
      SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),
             CASE p.prokind WHEN 'f' THEN 'function' WHEN 'p' THEN 'procedure' WHEN 'a' THEN 'aggregate' WHEN 'w' THEN 'window_function' END,
             l.lanname,r.rolname,CASE WHEN p.prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END,
             CASE WHEN p.prokind IN ('f','p') THEN 'pg_get_functiondef' WHEN p.prokind='a' THEN 'pg_catalog.pg_aggregate' ELSE 'pg_catalog.pg_proc' END
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_language l ON l.oid=p.prolang JOIN pg_roles r ON r.oid=p.proowner
      WHERE n.nspname='audit_fixture' AND p.prokind IN ('f','p','a','w')
        AND has_function_privilege('alianza_audit_ro',p.oid,'EXECUTE')
      ORDER BY p.proname
    """)
    rows=[]
    for line in out.splitlines():
        if not line: continue
        s,n,args,typ,lang,owner,sec,source=line.split('|')
        # transfn is intentionally not executable by the audited role.
        raw=b"fixture-canonical-bytes"
        h=hashlib.sha256(raw).hexdigest()
        rows.append(dict(audit_id=f"audit-{n}",role_name=ROLE,snapshot_id="snap-1",schema_name=s,object_name=n,identity_arguments=args,object_type=typ,language_name=lang,owner_name=owner,security_mode=sec,extension_name=None,definition_normalized=False,definition_source=source,definition_encoding="UTF-8",definition_bytes_hex=raw.hex(),definition_sha256=h,definition_sha256_calculated=h,review_status="APPROVED",reviewer="reviewer@example.test",reviewed_at="2026-11-11 08:00:00+00",evidence_ref=f"evidence://{n}",technical_conclusion="reviewed",risk_justification="none"))
    return rows

def query_template():
    text=SQL.read_text()
    return text[text.index("-- ETAPA 13 —"):text.index("-- ETAPA 14 —")]

def render(rows, acceptance=None):
    q=query_template()
    vals=[]
    for r in rows:
        keys=["audit_id","role_name","snapshot_id","schema_name","object_name","identity_arguments","object_type","language_name","owner_name","security_mode","extension_name","definition_normalized","definition_source","definition_encoding","definition_bytes_hex","definition_sha256","definition_sha256_calculated","review_status","reviewer","reviewed_at","evidence_ref","technical_conclusion","risk_justification"]
        types=["text"]*11+["boolean","text","text","text","text","text","text","text","timestamptz","text","text","text"]
        vals.append("("+", ".join(sqlq(r[k], t) for k,t in zip(keys,types))+")")
    q=re.sub(r"(review_registry AS \(.*?FROM \(VALUES\s*)(\(.*?\))(\s*\) AS v)", lambda m:m.group(1)+(",\n    ".join(vals) if vals else "(NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::boolean,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::text,NULL::timestamptz,NULL::text,NULL::text,NULL::text)")+m.group(3), q, count=1, flags=re.S)
    a=acceptance or (None, None, None, None, None, None, None, False)
    atypes=["text","text","text","timestamptz","text","text","text","boolean"]
    av="("+", ".join(sqlq(x,t) for x,t in zip(a,atypes))+")"
    q=re.sub(r"(temporary_acceptance AS \(.*?FROM \(VALUES\s*)(\(.*?\))(\s*\) AS ta)", lambda m:m.group(1)+av+m.group(3), q, count=1, flags=re.S)
    return "SET alianza.audit_snapshot_id='snap-1';\n"+q

def run_case(name, rows, acceptance=None, temp=False):
    psql(f"REVOKE TEMPORARY ON DATABASE audit_test FROM PUBLIC; {'GRANT TEMPORARY ON DATABASE audit_test TO alianza_audit_ro;' if temp else ''}")
    path=DATA / f"{name}.sql"; path.write_text(render(rows, acceptance))
    r=cmd(["psql","-X","-h",str(SOCKET),"-p",PORT,"-U",ROLE,"-d","audit_test","-At","-F","|","-v","ON_ERROR_STOP=1","-f",str(path)], check=False)
    if r.returncode:
        raise RuntimeError(f"{name}: PostgreSQL exit {r.returncode}\nSTDOUT: {r.stdout}\nSTDERR: {r.stderr}")
    fields=[line.split('|') for line in r.stdout.splitlines() if line.strip()][-1]
    return dict(zip(["final_status","can_create_temp","all_valid","missing","stale","temp_valid"],[fields[0],fields[3],fields[36],fields[37],fields[38],fields[46]]))

def main():
    setup(); rows=inventory(); assert len(rows)>=3, rows
    cases=[]
    cases.append(("sem_revisao", run_case("sem_revisao", []), "final_status", "INDETERMINADA"))
    cases.append(("revisao_valida_f_p_a", run_case("valida", rows), "all_valid", "t"))
    bad=[dict(x) for x in rows]; bad[0]["definition_sha256_calculated"]="0"*64
    cases.append(("sha_divergente", run_case("sha", bad), "stale", "t"))
    cases.append(("aggregate_sem_revisao", run_case("aggmissing", [x for x in rows if x["object_type"]!="aggregate"]), "final_status", "INDETERMINADA"))
    valid_accept=("audit-temp-1",ROLE,"responsavel@example.test","2026-11-11 08:00:00+00","evidence://temporary-1","risco formalmente aceito","TEMPORARY",True)
    cases.append(("temporary_incompleta", run_case("tempbad", rows, ("audit-temp-1",ROLE,None,None,None,None,"TEMPORARY",False), True), "temp_valid", "f"))
    cases.append(("temporary_valida", run_case("tempok", rows, valid_accept, True), "temp_valid", "t"))
    for name,result,key,expected in cases:
        if result[key] != expected:
            raise AssertionError(f"{name}: {result} expected {key}={expected}")
        print(f"PASS | {name} | {result}")
    print(f"PostgreSQL {psql('SHOW server_version;')}")
    print(f"{len(cases)} cenários SQL reais executados")

try:
    main()
finally:
    cmd(["pg_ctl","-D",str(DATA),"-m","fast","-w","stop"], check=False)
    shutil.rmtree(SOCKET, ignore_errors=True); shutil.rmtree(DATA, ignore_errors=True)
