#!/usr/bin/env python3
import csv
import html
from pathlib import Path

ARTIFACTS_ROOT = Path("docs/artifacts")

def csv_to_html_table(csv_path: Path) -> str:
    with csv_path.open(newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))

    title = csv_path.name
    if not rows:
        return "<!doctype html><meta charset='utf-8'><p><em>Empty CSV.</em></p>"

    header = rows[0]
    body = rows[1:]

    out = []
    out.append("<!doctype html>")
    out.append("<meta charset='utf-8'>")
    out.append(f"<title>{html.escape(title)}</title>")
    out.append("<style>")
    out.append(":root{color-scheme: dark;}")
    out.append(
        "body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;"
        "padding:16px;margin:0;background:#0b1220;color:#e6eefc;}"
    )
    out.append("a{color:#8ab4f8;}")
    out.append("h1{margin:0 0 12px 0;font-size:20px;}")
    out.append("table{border-collapse:collapse;width:100%;}")
    out.append("th,td{border:1px solid rgba(138,180,248,0.25);padding:6px 10px;font-size:14px;vertical-align:top;color:inherit;}")
    out.append("th{position:sticky;top:0;background:#102a43;color:#cfe3ff;font-weight:600;z-index:1;}")
    out.append("tr:nth-child(even) td{background:#0e1a2b;}")
    out.append("tr:nth-child(odd)  td{background:#0b1220;}")
    out.append("</style>")

    out.append(f"<h1>{html.escape(title)}</h1>")
    out.append(f"<p><a href='{html.escape(title)}' download>Download CSV</a></p>")
    out.append("<div style='overflow:auto; max-height: 75vh; border: 1px solid rgba(138,180,248,0.25); border-radius:10px;'>")
    out.append("<table><thead><tr>")
    for h in header:
        out.append(f"<th>{html.escape(h)}</th>")
    out.append("</tr></thead><tbody>")
    for r in body:
        out.append("<tr>")
        for cell in r:
            out.append(f"<td>{html.escape(cell)}</td>")
        out.append("</tr>")
    out.append("</tbody></table></div>")

    return "\n".join(out)

def main() -> int:
    if not ARTIFACTS_ROOT.is_dir():
        print(f"No artifacts root: {ARTIFACTS_ROOT}")
        return 0

    csv_files = sorted(ARTIFACTS_ROOT.glob("*/assembly/*.csv"))
    if not csv_files:
        print(f"No CSV files found under: {ARTIFACTS_ROOT}/*/assembly/")
        return 0

    count = 0
    for csv_path in csv_files:
        html_path = csv_path.with_suffix(csv_path.suffix + ".html")  # .csv.html
        html_path.write_text(csv_to_html_table(csv_path), encoding="utf-8")
        print(f"Wrote {html_path}")
        count += 1

    print(f"Rendered {count} CSV table(s).")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
