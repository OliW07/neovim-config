"""Cache ClickHouse column metadata for sql-lsp using the existing chq login."""
import json
import os
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

QUERY = """
SELECT database, table, name, type
FROM system.columns
WHERE database = currentDatabase()
   OR (database = 'system' AND table IN ('columns', 'databases', 'functions', 'tables'))
ORDER BY database, table, position
FORMAT JSONEachRow
"""


def query(sql):
    result = subprocess.run([Path(__file__).with_name("chq"), "-"], input=sql,
                            capture_output=True, text=True, timeout=45)
    if result.returncode:
        raise ValueError(result.stderr.strip() or "ClickHouse query failed")
    return [json.loads(line) for line in result.stdout.splitlines()]


def refresh(path, function_path):
    tables = {}
    for row in query(QUERY):
        key = (row["database"], row["table"])
        tables.setdefault(key, []).append({
            "name": row["name"], "data_type": row["type"],
            "nullable": row["type"].startswith(("Nullable(", "LowCardinality(Nullable(")),
        })
    if not any(database == "prod" for database, _ in tables):
        raise ValueError("No prod tables returned. Keeping the existing catalog.")
    uri = path.as_uri()
    schema = {"id": str(uuid.uuid5(uuid.NAMESPACE_URL, uri)), "database": "",
              "source_uri": uri, "functions": [], "tables": [
                  {"name": f"{db}.{name}", "columns": cols}
                  for (db, name), cols in tables.items()]}
    functions = {r["name"]: r for r in query(
        "SELECT name, syntax, description, arguments, alias_to FROM system.functions FORMAT JSONEachRow"
    )}
    if not functions:
        raise ValueError("No ClickHouse functions returned. Keeping the existing catalog.")
    for name, row in functions.items():
        target = functions.get(row["alias_to"])
        if not row["syntax"] and target and target["syntax"]:
            row.update(description=target["description"], arguments=target["arguments"],
                       syntax=target["syntax"].replace(target["name"] + "(", name + "(", 1))
    save(function_path, functions)
    save(path, schema)
    print(f"Loaded {len(tables)} tables and {len(functions)} functions from ClickHouse")


def save(path, catalog):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = tempfile.NamedTemporaryFile(dir=path.parent, mode="w", delete=False)
    try:
        with tmp:
            json.dump(catalog, tmp)
        os.replace(tmp.name, path)
    finally:
        Path(tmp.name).unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        refresh(*(Path(arg).resolve() for arg in sys.argv[1:]))
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
