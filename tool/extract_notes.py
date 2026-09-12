#!/usr/bin/env python3
"""Extract per-chapter study notes from the source textbook epub.

The output is written to ``assets/notes/chNN.json``, which is gitignored: the
book is copyrighted, this repository is public, and the extracted prose is the
book's text. Run this locally to get study notes inside your own build; do not
commit what it produces.

    python3 tool/extract_notes.py                      # uses the repo symlink
    python3 tool/extract_notes.py --epub /path/to.epub
    python3 tool/extract_notes.py --chapter 5 --dry-run

Chapter files in the epub are named ``NN_CC__Title.xhtml`` where ``CC`` is the
book chapter number, which lines up 1:1 with the chapters in assets/syllabus.json.

What does and does not come across:

  * Prose paragraphs, section headings and bullet lists extract cleanly.
  * Terminal transcripts and command output do NOT. The book renders those as
    images (~46 per chapter), so they are skipped and the figure is noted in
    place. The app fills that gap from the question bank's own command answers.
  * Tables, review questions, answers and the end-of-chapter labs are dropped:
    the quiz is the app's job, and the labs are exercises rather than reading.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_EPUB = ROOT / "RHCSA-book-10th-edition.epub"
OUT_DIR = ROOT / "assets" / "notes"

# Everything from the first of these headings to the end of the chapter is
# back matter: self-test material the app already covers with its own bank.
END_MATTER = (
    "chapter summary",
    "review questions",
    "answers to review questions",
    "do-it-yourself challenge labs",
)

CAPTION = re.compile(r"^(figure|table)\s+\d", re.I)
BULLET_LEAD = re.compile(r"^[▸•▪‣·⁃]\s*")
TAG = re.compile(r"<[^>]+>")
PARA = re.compile(r"<p\b[^>]*class=\"([^\"]+)\"[^>]*>(.*?)</p>", re.S)
STRONG = re.compile(r"<strong\b[^>]*>(.*?)</strong>", re.S)


def text_of(fragment: str) -> str:
    """Strips markup and normalises whitespace to a single line."""
    return re.sub(r"\s+", " ", html.unescape(TAG.sub("", fragment))).strip()


def is_heading(fragment: str) -> bool:
    """True when the whole paragraph is bold and short enough to be a title.

    Requiring the bold run to cover the entire paragraph is what separates a
    real heading from body text that merely opens with a bold lead-in, such as
    "**Column 1:** Login name of the user".
    """
    full = text_of(fragment)
    if not full or len(full) > 120:
        return False
    bold = " ".join(text_of(m) for m in STRONG.findall(fragment)).strip()
    return bool(bold) and re.sub(r"\s+", " ", bold) == full


def chapter_files(zf: zipfile.ZipFile) -> dict[int, str]:
    """Maps book chapter number -> entry name, from the NN_CC__Title pattern."""
    found: dict[int, str] = {}
    for name in zf.namelist():
        m = re.search(r"/\d{2}_(\d{2})__", name)
        if m and name.endswith(".xhtml"):
            found[int(m.group(1))] = name
    return found


def heading_classes(paras: list[tuple[str, str]]) -> dict[str, int]:
    """Picks out the CSS classes used for headings and assigns them a level.

    The epub's class names are generated per build (C1336, C1337, ...) and
    differ between chapters, so they are inferred rather than hardcoded: a
    class counts as a heading class when most of its paragraphs are wholly
    bold. The rarer class is the major heading, the busier one its subsections.
    """
    total: dict[str, int] = {}
    bold: dict[str, int] = {}
    for cls, inner in paras:
        line = text_of(inner)
        # Figure and table captions are also wholly bold and short. Left in,
        # they form their own "heading class" and, being the rarest, would take
        # the top level away from the real section headings.
        if not line or CAPTION.match(line):
            continue
        total[cls] = total.get(cls, 0) + 1
        if is_heading(inner):
            bold[cls] = bold.get(cls, 0) + 1

    candidates = [c for c, n in bold.items() if n >= 2 and n / total[c] >= 0.7]
    # The chapter title's class occurs once and is filtered out above, which is
    # what we want: the title comes from the syllabus, not the body.
    ordered = sorted(candidates, key=lambda c: bold[c])
    return {cls: min(i + 1, 2) for i, cls in enumerate(ordered)}


def extract_chapter(zf: zipfile.ZipFile, entry: str, title: str = "") -> list[dict]:
    raw = zf.read(entry).decode("utf-8", "replace")
    body = raw[raw.find("<body") :]
    paras = PARA.findall(body)
    levels = heading_classes(paras)
    # The chapter opens by restating its own number and title, which the app
    # already shows in the app bar.
    redundant = {title.lower()} if title else set()

    sections: list[dict] = []
    current: dict | None = None

    for cls, inner in paras:
        line = text_of(inner)
        if not line:
            continue

        level = levels.get(cls)
        if level and is_heading(inner):
            if line.lower().strip(" :") in END_MATTER:
                break  # back matter starts here; stop reading the chapter
            if CAPTION.match(line):
                continue  # figure caption, not a section
            current = {"heading": line, "level": level, "blocks": []}
            sections.append(current)
            continue

        if current is None:
            if re.fullmatch(r"chapter\s+\d+", line, re.I) or (
                line.lower() in redundant
            ):
                continue
            # Front-of-chapter matter: the "major topics" bullets and the
            # objectives list. Kept under a synthetic opening section.
            current = {"heading": "Overview", "level": 1, "blocks": []}
            sections.append(current)

        if CAPTION.match(line):
            current["blocks"].append({"type": "caption", "text": line})
            continue

        bullet = BULLET_LEAD.match(line)
        current["blocks"].append(
            {
                "type": "bullet" if bullet else "p",
                "text": BULLET_LEAD.sub("", line) if bullet else line,
            }
        )

    # A section holding nothing but figure captions reads as a dead end.
    return [
        s for s in sections if any(b["type"] != "caption" for b in s["blocks"])
    ]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--epub", type=Path, default=DEFAULT_EPUB)
    ap.add_argument("--out", type=Path, default=OUT_DIR)
    ap.add_argument("--chapter", type=int, help="extract just this chapter")
    ap.add_argument("--dry-run", action="store_true", help="report, do not write")
    args = ap.parse_args()

    if not args.epub.exists():
        print(f"epub not found: {args.epub}", file=sys.stderr)
        print("pass --epub /path/to/book.epub", file=sys.stderr)
        return 1

    syllabus = json.loads((ROOT / "assets" / "syllabus.json").read_text())
    titles = {c["num"]: c["title"] for c in syllabus["chapters"]}

    with zipfile.ZipFile(args.epub) as zf:
        found = chapter_files(zf)
        missing = sorted(set(titles) - set(found))
        if missing:
            print(f"warning: no epub file for chapters {missing}", file=sys.stderr)

        wanted = [args.chapter] if args.chapter else sorted(found)
        if not args.dry_run:
            args.out.mkdir(parents=True, exist_ok=True)

        total_words = 0
        for num in wanted:
            if num not in found:
                print(f"chapter {num}: not in epub, skipped", file=sys.stderr)
                continue
            sections = extract_chapter(zf, found[num], titles.get(num, ""))
            words = sum(
                len(b["text"].split()) for s in sections for b in s["blocks"]
            )
            total_words += words
            print(
                f"ch{num:02d} {titles.get(num, '?')[:44]:<44} "
                f"{len(sections):>3} sections {words:>6} words"
            )
            if args.dry_run:
                continue
            payload = {
                "chapter": num,
                "title": titles.get(num, ""),
                "sections": sections,
            }
            (args.out / f"ch{num:02d}.json").write_text(
                json.dumps(payload, ensure_ascii=False, indent=1)
            )

    print(f"\n{total_words:,} words total")
    if not args.dry_run:
        print(f"written to {args.out}")
        print("these files are gitignored on purpose - do not commit them")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
