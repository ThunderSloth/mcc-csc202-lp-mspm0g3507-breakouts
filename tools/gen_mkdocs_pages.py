#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from dataclasses import dataclass

REPO = Path(__file__).resolve().parents[1]
DOCS = REPO / "docs"
ART = DOCS / "artifacts"

BOARDS = ["2-term", "3-term", "led-module"]

@dataclass
class Board:
    slug: str          # "2-term"
    title: str         # "2-Term Breakout"
    project: str       # "CSC202_LP_MSPM0G3507_2TERM_BREAKOUT"

def infer_project(board_slug: str) -> str:
    schem_dir = ART / board_slug / "docs" / "schematic"
    pdfs = sorted(schem_dir.glob("*.pdf"))
    if not pdfs:
        raise SystemExit(f"ERROR: No schematic PDFs found in {schem_dir}")
    name = pdfs[0].name
    if name.endswith("-schematic.pdf"):
        return name[: -len("-schematic.pdf")]
    return name.rsplit(".", 1)[0]

def board_title(slug: str) -> str:
    if slug == "2-term":
        return "2-Term Breakout"
    if slug == "3-term":
        return "3-Term Breakout"
    if slug == "led-module":
        return "LED Display Module"
    return slug

def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")
    print(f"Wrote {path.relative_to(REPO)}")

def board_md(b: Board) -> str:
    p = b.project
    s = b.slug
    return f"""# {b.title}

This page hosts the complete set of design, assembly, and fabrication artifacts generated from the KiCad project via **KiBot**.

---

## 📐 Design

- **Schematic (PDF)** [[view]](artifacts/{s}/docs/schematic/{p}-schematic.pdf)
- **PCB Render — Top (2D)** [[view]](artifacts/{s}/docs/renders/{p}-top.png)
- **PCB Render — Bottom (2D)** [[view]](artifacts/{s}/docs/renders/{p}-bottom.png)

---

## 🔧 Assembly

- **Interactive BOM (iBOM)** [[view]](artifacts/{s}/docs/ibom/{p}-ibom.html)
- **Bill of Materials (CSV)** [[view]](artifacts/{s}/assembly/{p}-bom.csv.html) [[download]](artifacts/{s}/assembly/{p}-bom.csv)
- **Assembly Drawing (PDF)** [[view]](artifacts/{s}/docs/assembly/{p}-assembly-top.pdf)

---

## ⚙️ Fabrication

- **Fabrication Drawing (PDF)** [[view]](artifacts/{s}/docs/fab/{p}-fab-drawing.pdf)
- **Gerbers & Drill Files (ZIP)** [[download]](artifacts/{s}/fab/{p}_fab.zip)

---

## 🧊 Mechanical

- **3D STEP Model** [[download]](artifacts/{s}/mcad/{p}-3D.step)
"""

def index_md(boards: list[Board]) -> str:
    lines = []
    lines.append("# CSC-202 LP-MSPM0G3507 Breakouts — Hardware Documentation")
    lines.append("")
    lines.append(
        "This site hosts the complete set of design, assembly, and fabrication artifacts generated from the KiCad projects via **KiBot**."
    )
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## ℹ️ Project")
    lines.append("GitHub Repository: [ThunderSloth/mcc-csc202-lp-mspm0g3507-breakouts](https://github.com/ThunderSloth/mcc-csc202-lp-mspm0g3507-breakouts)")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## 📁 Boards")

    for b in boards:
        # path to top render inside docs/ (MkDocs root)
        top_img = f"artifacts/{b.slug}/docs/renders/{b.project}-top.png"

        lines.append(f"### {b.title}")
        lines.append("")
        lines.append(f"[![{b.title} top render]({top_img})]({b.slug}.md)")
        lines.append("")
        lines.append(f"➡️ [Open page]({b.slug}.md)")
        lines.append("")
        lines.append("---")
        lines.append("")

    return "\n".join(lines)

def main() -> int:
    if not ART.is_dir():
        print(f"ERROR: missing {ART}")
        return 2

    boards: list[Board] = []
    for slug in BOARDS:
        proj = infer_project(slug)
        boards.append(Board(slug=slug, title=board_title(slug), project=proj))

    write(DOCS / "index.md", index_md(boards))
    for b in boards:
        write(DOCS / f"{b.slug}.md", board_md(b))

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
