"""Parse stdin in the selected SQL dialect locally; never execute it or access a DB."""
import json
import sys

import sqlglot
from sqlglot.errors import ParseError, TokenError


def diagnostics(text, dialect="clickhouse"):
    lines = text.splitlines() or [""]
    try:
        sqlglot.parse(text, read=dialect)
        return []
    except ParseError as error:
        result = []
        for item in error.errors:
            row = max(0, min(item.get("line", 1) - 1, len(lines) - 1))
            end = max(0, min(item.get("col", 1), len(lines[row])))
            start = max(0, end - len(item.get("highlight", "")))
            result.append({"lnum": row, "col": len(lines[row][:start].encode()),
                           "end_lnum": row, "end_col": len(lines[row][:end].encode()),
                           "message": item["description"], "severity": 1,
                           "source": f"SQLGlot ({dialect})"})
        return result
    except TokenError as error:
        return [{"lnum": 0, "col": 0, "message": str(error), "severity": 1,
                 "source": f"SQLGlot ({dialect})"}]


if __name__ == "__main__":
    print(json.dumps(diagnostics(sys.stdin.read(), sys.argv[1] if len(sys.argv) > 1 else "clickhouse")))
