"""Run SQL scripts to create and load raw tables via psql."""

import subprocess
import sys
from pathlib import Path

from src.config import PROJECT_ROOT, SQL_DIR, get_postgres_url


def run_sql_file(sql_path: Path) -> None:
    url = get_postgres_url()
    cmd = ["psql", url, "-v", "ON_ERROR_STOP=1", "-f", str(sql_path)]
    subprocess.run(cmd, check=True, cwd=PROJECT_ROOT)


def main() -> None:
    scripts = [
        SQL_DIR / "01_create_raw_tables.sql",
        SQL_DIR / "02_load_raw_data.sql",
    ]
    for script in scripts:
        print(f"Running {script.name}...")
        run_sql_file(script)
    print("Raw layer loaded.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode)
