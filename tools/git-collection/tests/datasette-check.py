"""Optional HTTP smoke check; requires requirements-datasette.txt."""

import argparse
import asyncio
import json
from pathlib import Path
from urllib.parse import quote


def main() -> None:
    parser = argparse.ArgumentParser(description="Check Datasette table search and named queries locally.")
    parser.add_argument("--database", type=Path, help="Existing catalogue.sqlite file")
    parser.add_argument("--verbose", action="store_true", help="Print each checked URL")
    options = parser.parse_args()
    if options.database is None:
        parser.print_help()
        parser.exit(1, "--database is required.\n")
    if not options.database.is_file():
        parser.exit(1, "Database file does not exist. Create and scan a catalogue first.\n")
    try:
        from datasette.app import Datasette
    except ImportError:
        parser.exit(1, "Install requirements-datasette.txt in the folder-local environment first.\n")
    metadata_file = Path(__file__).resolve().parent.parent / "datasette-metadata.json"
    metadata = json.loads(metadata_file.read_text())
    name = options.database.stem
    metadata["databases"][name] = metadata["databases"].pop("catalogue")

    async def check() -> None:
        datasette = Datasette([str(options.database.resolve())], metadata=metadata)
        base = "/" + quote(name, safe="")
        urls = [base, base + "/commits", base + "/commits.json?_search=motion",
                base + "/recent.json", base + "/daily.json", base + "/search.json?query=motion"]
        for url in urls:
            response = await datasette.client.get(url)
            if response.status_code != 200:
                raise RuntimeError(f"{url}: HTTP {response.status_code}: {response.text[:500]}")
            if options.verbose:
                print(f"PASS: {url}")
        print("Datasette HTTP checks passed.")

    try:
        asyncio.run(check())
    except Exception as error:
        parser.exit(1, f"Datasette check failed: {error}\n")


if __name__ == "__main__":
    main()
