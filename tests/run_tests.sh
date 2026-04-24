#!/usr/bin/env bash
# tests/run_tests.sh – smoke-test all Lyrical output paths
# Run from the project root: bash tests/run_tests.sh

set -uo pipefail

PASS=0
FAIL=0
SKIP=0
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

green() { printf '\033[32m✓\033[0m %s\n' "$*"; }
red()   { printf '\033[31m✗\033[0m %s\n' "$*"; }
skip()  { printf '\033[33m–\033[0m %s (skipped – %s not found)\n' "$1" "$2"; }

pass() { green "$1"; PASS=$((PASS + 1)); }
fail() { red   "$1"; FAIL=$((FAIL + 1)); }
skipped() { skip "$1" "$2"; SKIP=$((SKIP + 1)); }

require() { command -v "$1" &>/dev/null; }

echo "Output dir: $OUT_DIR"
echo

# ── Python / HTML ─────────────────────────────────────────────────────────

if require python3; then
  if python3 -c "import markdown2" 2>/dev/null; then

    python3 poemParser.py tyger.poem > "$OUT_DIR/tyger.html" 2>/dev/null \
      && grep -q "Tyger Tyger" "$OUT_DIR/tyger.html" \
      && pass "poemParser.py → HTML" \
      || fail "poemParser.py → HTML"

    # Alignment directives
    grep -q "text-align" "$OUT_DIR/tyger.html" \
      && pass "poemParser.py – alignment directives in output" \
      || fail "poemParser.py – alignment directives in output"

    # Alternate indentation
    grep -q "nbsp" "$OUT_DIR/tyger.html" \
      && pass "poemParser.py – alternate indentation in output" \
      || fail "poemParser.py – alternate indentation in output"

    # Line numbering
    grep -q "(1)" "$OUT_DIR/tyger.html" \
      && pass "poemParser.py – line numbering in output" \
      || fail "poemParser.py – line numbering in output"

    # No <br> inside headings
    grep -vq "<h[1-6].*<br>" "$OUT_DIR/tyger.html" \
      && pass "poemParser.py – no <br> inside headings" \
      || fail "poemParser.py – no <br> inside headings"

  else
    skipped "poemParser.py tests" "markdown2 (pip install markdown2)"
  fi
else
  skipped "poemParser.py tests" "python3"
fi

echo

# ── pandoc / Lua filter ───────────────────────────────────────────────────

if require pandoc; then

  pandoc --lua-filter tests/pandocFilter.lua tyger.poem \
      -f markdown -o "$OUT_DIR/tyger_pandoc.html" 2>/dev/null \
    && grep -q "Tyger Tyger" "$OUT_DIR/tyger_pandoc.html" \
    && pass "pandocFilter.lua → HTML" \
    || fail "pandocFilter.lua → HTML"

  # Alignment directives
  grep -q "text-align" "$OUT_DIR/tyger_pandoc.html" \
    && pass "pandocFilter.lua – alignment directives in output" \
    || fail "pandocFilter.lua – alignment directives in output"

  # Directives must not leak into output
  grep -vq "poem:start\|indent:metre\|numbering:on" "$OUT_DIR/tyger_pandoc.html" \
    && pass "pandocFilter.lua – directives consumed (not in output)" \
    || fail "pandocFilter.lua – directives leaked into output"

  # Alternate indentation
  grep -q "nbsp" "$OUT_DIR/tyger_pandoc.html" \
    && pass "pandocFilter.lua – alternate indentation in output" \
    || fail "pandocFilter.lua – alternate indentation in output"

  # Line numbering
  grep -q "(1)" "$OUT_DIR/tyger_pandoc.html" \
    && pass "pandocFilter.lua – line numbering in output" \
    || fail "pandocFilter.lua – line numbering in output"

  # pandoc → PDF (requires a LaTeX engine)
  if pandoc --lua-filter tests/pandocFilter.lua tyger.poem \
        -f markdown -o "$OUT_DIR/tyger_pandoc.pdf" 2>/dev/null; then
    [ -s "$OUT_DIR/tyger_pandoc.pdf" ] \
      && pass "pandocFilter.lua → PDF" \
      || fail "pandocFilter.lua → PDF — empty file"
  else
    skipped "pandocFilter.lua → PDF" "LaTeX engine (install texlive-xetex / mactex)"
  fi

else
  skipped "pandoc tests" "pandoc"
fi

echo

# ── Typst / PDF ───────────────────────────────────────────────────────────

if require typst && require python3; then

  # chapBook.typ must be co-located with any .typ that imports it
  cp chapBook.typ "$OUT_DIR/"

  python3 mdToTypst.py tyger.poem "$OUT_DIR/tyger.typ" 2>/dev/null \
    && grep -q "chapbook" "$OUT_DIR/tyger.typ" \
    && pass "mdToTypst.py → .typ" \
    || fail "mdToTypst.py → .typ"

  typst compile "$OUT_DIR/tyger.typ" "$OUT_DIR/tyger_typst.pdf" 2>/dev/null \
    && [ -s "$OUT_DIR/tyger_typst.pdf" ] \
    && pass "typst compile → PDF" \
    || fail "typst compile → PDF"

elif ! require typst; then
  skipped "Typst tests" "typst"
else
  skipped "Typst tests" "python3"
fi

# ── Summary ───────────────────────────────────────────────────────────────

echo
echo "────────────────────────────────"
printf "  passed: %d  failed: %d  skipped: %d\n" "$PASS" "$FAIL" "$SKIP"
echo "────────────────────────────────"

[ "$FAIL" -eq 0 ]
