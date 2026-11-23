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


def refresh(path):
    result = subprocess.run([Path(__file__).with_name("chq"), "-"], input=QUERY,
                            capture_output=True, text=True, timeout=45)
    if result.returncode:
        raise ValueError(result.stderr.strip() or "ClickHouse query failed")
    tables = {}
    for line in result.stdout.splitlines():
        row = json.loads(line)
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
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = tempfile.NamedTemporaryFile(dir=path.parent, mode="w", delete=False)
    try:
        with tmp:
            json.dump(schema, tmp)
        os.replace(tmp.name, path)
    finally:
        Path(tmp.name).unlink(missing_ok=True)
    print(f"Loaded {len(tables)} tables from ClickHouse")


if __name__ == "__main__":
    try:
        refresh(Path(sys.argv[1]).resolve())
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
