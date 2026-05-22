#!/usr/bin/env python3
"""
Convert a phpMyAdmin MySQL dump into Firestore seed JSON files.

This parser is intentionally dependency-free. It understands the INSERT shape
produced by phpMyAdmin dumps:

INSERT INTO `table` (`a`, `b`) VALUES
(1, 'x'),
(2, NULL);
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SEARCH_FIELDS = {
    "activity_logs": [
        "vessel_name",
        "pilot_name",
        "agency",
        "flag",
        "from_where",
        "to_where",
        "last_port",
        "next_port",
    ],
    "pilotage_logs": [
        "vessel_name",
        "pilot_name",
        "agency",
        "flag",
        "from_where",
        "to_where",
        "last_port",
        "next_port",
    ],
    "assistance_logs": [
        "vessel_name",
        "agency",
        "flag",
        "assist_tug_name",
        "from_where",
        "to_where",
        "last_port",
        "next_port",
    ],
    "assist_tugs": ["assist_tug_name"],
    "users": ["name", "email", "role"],
}

PASSWORD_FIELDS = {"password", "remember_token", "email_verified_at"}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def extract_insert_statements(sql: str) -> list[str]:
    statements: list[str] = []
    start = 0
    marker = "INSERT INTO"

    while True:
        idx = sql.find(marker, start)
        if idx == -1:
            break

        in_string = False
        escaped = False
        end = idx
        while end < len(sql):
            ch = sql[end]
            if in_string:
                if escaped:
                    escaped = False
                elif ch == "\\":
                    escaped = True
                elif ch == "'":
                    in_string = False
            else:
                if ch == "'":
                    in_string = True
                elif ch == ";":
                    statements.append(sql[idx : end + 1])
                    end += 1
                    break
            end += 1

        start = end

    return statements


def parse_insert_header(statement: str) -> tuple[str, list[str], str]:
    match = re.match(
        r"INSERT\s+INTO\s+`(?P<table>[^`]+)`\s*\((?P<cols>.*?)\)\s+VALUES\s*(?P<values>.*);",
        statement.strip(),
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not match:
        raise ValueError("Unsupported INSERT statement")

    table = match.group("table")
    cols = re.findall(r"`([^`]+)`", match.group("cols"))
    values = match.group("values").strip()
    return table, cols, values


def split_rows(values_sql: str) -> list[str]:
    rows: list[str] = []
    in_string = False
    escaped = False
    depth = 0
    buf: list[str] = []

    for ch in values_sql:
        if in_string:
            buf.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == "'":
                in_string = False
            continue

        if ch == "'":
            in_string = True
            if depth > 0:
                buf.append(ch)
        elif ch == "(":
            if depth == 0:
                buf = []
            else:
                buf.append(ch)
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                rows.append("".join(buf))
                buf = []
            else:
                buf.append(ch)
        else:
            if depth > 0:
                buf.append(ch)

    return rows


def split_values(row_sql: str) -> list[str]:
    values: list[str] = []
    in_string = False
    escaped = False
    buf: list[str] = []

    for ch in row_sql:
        if in_string:
            buf.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == "'":
                in_string = False
            continue

        if ch == "'":
            in_string = True
            buf.append(ch)
        elif ch == ",":
            values.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)

    values.append("".join(buf).strip())
    return values


def unescape_mysql_string(value: str) -> str:
    inner = value[1:-1]
    replacements = {
        "\\0": "\0",
        "\\'": "'",
        '\\"': '"',
        "\\b": "\b",
        "\\n": "\n",
        "\\r": "\r",
        "\\t": "\t",
        "\\Z": "\x1a",
        "\\\\": "\\",
    }
    for old, new in replacements.items():
        inner = inner.replace(old, new)
    return inner


def parse_value(raw: str) -> Any:
    upper = raw.upper()
    if upper == "NULL":
        return None
    if raw.startswith("'") and raw.endswith("'"):
        return unescape_mysql_string(raw)
    if re.fullmatch(r"-?\d+", raw):
        try:
            return int(raw)
        except ValueError:
            return raw
    if re.fullmatch(r"-?\d+\.\d+", raw):
        try:
            return float(raw)
        except ValueError:
            return raw
    return raw


def normalize_token_source(value: Any) -> list[str]:
    if value is None:
        return []
    text = str(value).lower()
    return re.findall(r"[a-z0-9]+", text)


def build_search_tokens(table: str, row: dict[str, Any]) -> list[str]:
    tokens: set[str] = set()
    for field in SEARCH_FIELDS.get(table, []):
        for token in normalize_token_source(row.get(field)):
            tokens.add(token)
            if len(token) >= 4:
                for size in range(3, min(len(token), 12) + 1):
                    tokens.add(token[:size])
    return sorted(tokens)


def clean_row(table: str, columns: list[str], values: list[Any]) -> dict[str, Any]:
    row = dict(zip(columns, values))

    if "id" in row:
        row["legacy_id"] = row["id"]

    if table == "users":
        for field in PASSWORD_FIELDS:
            row.pop(field, None)

    if table in SEARCH_FIELDS:
        row["search_tokens"] = build_search_tokens(table, row)

    if table in {"activity_logs", "pilotage_logs"} and "pilot_user_id" in row:
        row.setdefault("pilot_uid", None)

    return row


def parse_dump(sql: str) -> dict[str, list[dict[str, Any]]]:
    collections: dict[str, list[dict[str, Any]]] = {}

    for statement in extract_insert_statements(sql):
        table, columns, values_sql = parse_insert_header(statement)
        rows = collections.setdefault(table, [])

        for row_sql in split_rows(values_sql):
            raw_values = split_values(row_sql)
            values = [parse_value(raw) for raw in raw_values]
            if len(columns) != len(values):
                raise ValueError(
                    f"Column/value mismatch in {table}: {len(columns)} columns, {len(values)} values"
                )
            rows.append(clean_row(table, columns, values))

    return collections


def doc_id_for(row: dict[str, Any], index: int) -> str:
    legacy_id = row.get("legacy_id")
    if legacy_id is not None:
        return str(legacy_id)
    return f"row_{index + 1}"


def write_outputs(collections: dict[str, list[dict[str, Any]]], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, Any] = {"collections": {}}

    for table, rows in sorted(collections.items()):
        docs = [
            {
                "_doc_id": doc_id_for(row, index),
                **row,
            }
            for index, row in enumerate(rows)
        ]
        target = out_dir / f"{table}.json"
        target.write_text(
            json.dumps(docs, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        manifest["collections"][table] = {
            "file": target.name,
            "count": len(docs),
        }

    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert MySQL dump INSERT data to Firestore seed JSON files."
    )
    parser.add_argument("sql_dump", type=Path)
    parser.add_argument("--out", type=Path, default=Path("build/firestore_seed"))
    args = parser.parse_args()

    sql = read_text(args.sql_dump)
    collections = parse_dump(sql)
    write_outputs(collections, args.out)

    print(f"Wrote Firestore seed files to {args.out}")
    for table, rows in sorted(collections.items()):
        print(f"- {table}: {len(rows)} docs")


if __name__ == "__main__":
    main()
