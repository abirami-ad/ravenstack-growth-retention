"""Run a .sql file against the raw CSVs. Usage: python analysis/run.py <file.sql>

Creates one view per table over data/raw first so the analysis files stay clean.
"""
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"

TABLES = ["accounts", "subscriptions", "feature_usage", "support_tickets", "churn_events"]

SETUP = "\n".join(
    f"CREATE VIEW {t} AS SELECT * FROM read_csv_auto('{RAW / f'ravenstack_{t}.csv'}', header=true);"
    for t in TABLES
)

DEBUG = False  # left over from debugging the splitter, keep for now


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: python analysis/run.py <file.sql>")
    sql = Path(sys.argv[1]).read_text()

    con = duckdb.connect()
    con.execute(SETUP)

    # let duckdb do the statement splitting, safer than naive ';' split
    # (comments can contain semicolons. learned this one the hard way)
    stmts = con.extract_statements(sql)

    for s in stmts:
        if s.type == duckdb.StatementType.SELECT:
            cur = con.execute(s.query)
            cols = [d[0] for d in cur.description]
            rows = cur.fetchall()
            print("\n-- result")
            print("\t".join(cols))
            for r in rows:
                print("\t".join("NULL" if v is None else str(v) for v in r))
    con.close()


if __name__ == "__main__":
    main()
