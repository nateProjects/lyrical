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

# Standalone snippet for the continuation-line marker (tyger.poem has no
# naturally overlong lines to demonstrate it on).
cat > "$OUT_DIR/continuation.poem" <<'EOF'
@@poem:start
This is a long line that keeps going
+and here is its continuation
@@poem:end
EOF

# Standalone snippet for per-stanza numbering reset.
cat > "$OUT_DIR/stanza-numbering.poem" <<'EOF'
@@poem:start
@@numbering:stanza
First line of stanza one
Second line of stanza one

First line of stanza two
Second line of stanza two
@@poem:end
EOF

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

    # Attribution — semantic element, distinct from generic alignment
    grep -q 'class="attribution"' "$OUT_DIR/tyger.html" \
      && pass "poemParser.py – attribution in output" \
      || fail "poemParser.py – attribution in output"

    # Small caps
    grep -q "font-variant: small-caps" "$OUT_DIR/tyger.html" \
      && pass "poemParser.py – small caps in output" \
      || fail "poemParser.py – small caps in output"

    # Caesura
    grep -q 'class="caesura"' "$OUT_DIR/tyger.html" \
      && pass "poemParser.py – caesura in output" \
      || fail "poemParser.py – caesura in output"

    # Markers must not leak into output literally
    grep -vqE '~>|%%|\|\|' "$OUT_DIR/tyger.html" \
      && pass "poemParser.py – markers consumed (not in output)" \
      || fail "poemParser.py – markers leaked into output"

    # Continuation line
    python3 poemParser.py "$OUT_DIR/continuation.poem" > "$OUT_DIR/continuation.html" 2>/dev/null \
      && grep -q 'class="continuation"' "$OUT_DIR/continuation.html" \
      && pass "poemParser.py – continuation line in output" \
      || fail "poemParser.py – continuation line in output"

    # Per-stanza numbering reset — stanza one and stanza two both start at (1)
    python3 poemParser.py "$OUT_DIR/stanza-numbering.poem" > "$OUT_DIR/stanza-numbering.html" 2>/dev/null \
      && [ "$(grep -o '(1)' "$OUT_DIR/stanza-numbering.html" | wc -l)" -ge 2 ] \
      && pass "poemParser.py – per-stanza numbering reset in output" \
      || fail "poemParser.py – per-stanza numbering reset in output"

    # Stage 2 features via duet.poem — title/subtitle/dedication/epigraph,
    # section headings, speakers, refrains, strikethrough, erasure, foreign
    # language, page breaks, and the keep-together print hint.
    python3 poemParser.py duet.poem > "$OUT_DIR/duet.html" 2>/dev/null \
      && pass "poemParser.py – duet.poem → HTML" \
      || fail "poemParser.py – duet.poem → HTML"

    grep -q 'class="poem-title"' "$OUT_DIR/duet.html" \
      && grep -q 'class="poem-subtitle"' "$OUT_DIR/duet.html" \
      && grep -q 'class="dedication"' "$OUT_DIR/duet.html" \
      && grep -q 'class="epigraph"' "$OUT_DIR/duet.html" \
      && pass "poemParser.py – title/subtitle/dedication/epigraph in output" \
      || fail "poemParser.py – title/subtitle/dedication/epigraph in output"

    grep -q 'class="part-heading"' "$OUT_DIR/duet.html" \
      && pass "poemParser.py – section heading in output" \
      || fail "poemParser.py – section heading in output"

    grep -q 'class="speaker-name"' "$OUT_DIR/duet.html" \
      && pass "poemParser.py – speaker attribution in output" \
      || fail "poemParser.py – speaker attribution in output"

    grep -q 'class="refrain"' "$OUT_DIR/duet.html" \
      && pass "poemParser.py – refrain in output" \
      || fail "poemParser.py – refrain in output"

    grep -q '<del>summer</del>' "$OUT_DIR/duet.html" \
      && pass "poemParser.py – strikethrough in output" \
      || fail "poemParser.py – strikethrough in output"

    grep -q 'class="erasure"' "$OUT_DIR/duet.html" \
      && pass "poemParser.py – erasure in output" \
      || fail "poemParser.py – erasure in output"

    grep -q '<em lang="fr"' "$OUT_DIR/duet.html" \
      && pass "poemParser.py – foreign-language marker in output" \
      || fail "poemParser.py – foreign-language marker in output"

    grep -q 'page-break-after' "$OUT_DIR/duet.html" \
      && pass "poemParser.py – page-break hint in output" \
      || fail "poemParser.py – page-break hint in output"

    grep -q 'break-inside: avoid' "$OUT_DIR/duet.html" \
      && pass "poemParser.py – keep-together CSS in output (PKeep: Together)" \
      || fail "poemParser.py – keep-together CSS in output (PKeep: Together)"

    # Directives/markers must not leak into output literally
    grep -vqE '@@section|@@pagebreak|@WIND:|@LEAF:|~~|\[\[|\]\]|\{\{|\}\}' "$OUT_DIR/duet.html" \
      && pass "poemParser.py – stage 2 directives/markers consumed (not in output)" \
      || fail "poemParser.py – stage 2 directives/markers leaked into output"

  else
    skipped "poemParser.py tests" "markdown2 (pip install markdown2)"
  fi
else
  skipped "poemParser.py tests" "python3"
fi

echo

# ── pandoc / Lua filter ───────────────────────────────────────────────────

if require pandoc; then

  pandoc --lua-filter pandocFilter.lua tyger.poem \
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

  # Attribution — semantic element, distinct from generic alignment
  grep -q 'class="attribution"' "$OUT_DIR/tyger_pandoc.html" \
    && pass "pandocFilter.lua – attribution in output" \
    || fail "pandocFilter.lua – attribution in output"

  # Small caps
  grep -q "font-variant: small-caps" "$OUT_DIR/tyger_pandoc.html" \
    && pass "pandocFilter.lua – small caps in output" \
    || fail "pandocFilter.lua – small caps in output"

  # Caesura
  grep -q 'class="caesura"' "$OUT_DIR/tyger_pandoc.html" \
    && pass "pandocFilter.lua – caesura in output" \
    || fail "pandocFilter.lua – caesura in output"

  # Markers must not leak into output literally
  grep -vqE '~>|%%|\|\|' "$OUT_DIR/tyger_pandoc.html" \
    && pass "pandocFilter.lua – markers consumed (not in output)" \
    || fail "pandocFilter.lua – markers leaked into output"

  # Continuation line
  pandoc --lua-filter pandocFilter.lua "$OUT_DIR/continuation.poem" \
      -f markdown -o "$OUT_DIR/continuation_pandoc.html" 2>/dev/null \
    && grep -q 'class="continuation"' "$OUT_DIR/continuation_pandoc.html" \
    && pass "pandocFilter.lua – continuation line in output" \
    || fail "pandocFilter.lua – continuation line in output"

  # Line breaks actually present between poem lines (regression check for a
  # pre-existing bug where sibling Plain blocks had no markup between them
  # and would collapse onto one line in a real browser)
  grep -q "<br" "$OUT_DIR/tyger_pandoc.html" \
    && pass "pandocFilter.lua – line breaks present between poem lines" \
    || fail "pandocFilter.lua – line breaks present between poem lines"

  # Per-stanza numbering reset — stanza one and stanza two both start at (1)
  pandoc --lua-filter pandocFilter.lua "$OUT_DIR/stanza-numbering.poem" \
      -f markdown -o "$OUT_DIR/stanza-numbering_pandoc.html" 2>/dev/null \
    && [ "$(grep -o '(1)' "$OUT_DIR/stanza-numbering_pandoc.html" | wc -l)" -ge 2 ] \
    && pass "pandocFilter.lua – per-stanza numbering reset in output" \
    || fail "pandocFilter.lua – per-stanza numbering reset in output"

  # Stage 2 features via duet.poem
  pandoc --lua-filter pandocFilter.lua duet.poem \
      -f markdown -o "$OUT_DIR/duet_pandoc.html" 2>/dev/null \
    && pass "pandocFilter.lua – duet.poem → HTML" \
    || fail "pandocFilter.lua – duet.poem → HTML"

  grep -q 'class="poem-title"' "$OUT_DIR/duet_pandoc.html" \
    && grep -q 'class="poem-subtitle"' "$OUT_DIR/duet_pandoc.html" \
    && grep -q 'class="dedication"' "$OUT_DIR/duet_pandoc.html" \
    && grep -q 'class="epigraph"' "$OUT_DIR/duet_pandoc.html" \
    && pass "pandocFilter.lua – title/subtitle/dedication/epigraph in output" \
    || fail "pandocFilter.lua – title/subtitle/dedication/epigraph in output"

  grep -q 'class="part-heading"' "$OUT_DIR/duet_pandoc.html" \
    && pass "pandocFilter.lua – section heading in output" \
    || fail "pandocFilter.lua – section heading in output"

  grep -q 'class="speaker-name"' "$OUT_DIR/duet_pandoc.html" \
    && pass "pandocFilter.lua – speaker attribution in output" \
    || fail "pandocFilter.lua – speaker attribution in output"

  grep -q 'class="refrain"' "$OUT_DIR/duet_pandoc.html" \
    && pass "pandocFilter.lua – refrain in output" \
    || fail "pandocFilter.lua – refrain in output"

  grep -q '<del>summer</del>' "$OUT_DIR/duet_pandoc.html" \
    && pass "pandocFilter.lua – strikethrough in output" \
    || fail "pandocFilter.lua – strikethrough in output"

  grep -q 'class="erasure"' "$OUT_DIR/duet_pandoc.html" \
    && pass "pandocFilter.lua – erasure in output" \
    || fail "pandocFilter.lua – erasure in output"

  grep -q '<em lang="fr"' "$OUT_DIR/duet_pandoc.html" \
    && pass "pandocFilter.lua – foreign-language marker in output" \
    || fail "pandocFilter.lua – foreign-language marker in output"

  grep -q 'page-break-after' "$OUT_DIR/duet_pandoc.html" \
    && pass "pandocFilter.lua – page-break hint in output" \
    || fail "pandocFilter.lua – page-break hint in output"

  grep -q 'break-inside: avoid' "$OUT_DIR/duet_pandoc.html" \
    && pass "pandocFilter.lua – keep-together CSS in output (PKeep: Together)" \
    || fail "pandocFilter.lua – keep-together CSS in output (PKeep: Together)"

  grep -vqE '@@section|@@pagebreak|@WIND:|@LEAF:|~~|\[\[|\]\]|\{\{|\}\}' "$OUT_DIR/duet_pandoc.html" \
    && pass "pandocFilter.lua – stage 2 directives/markers consumed (not in output)" \
    || fail "pandocFilter.lua – stage 2 directives/markers leaked into output"

  # pandoc → PDF (requires a LaTeX engine)
  if pandoc --lua-filter pandocFilter.lua tyger.poem \
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

  # Attribution is pulled out into its own aligned block, and inline markers
  # (small caps, caesura) are passed through untouched for poem() to render
  grep -q "align(right)" "$OUT_DIR/tyger.typ" \
    && pass "mdToTypst.py – attribution in output" \
    || fail "mdToTypst.py – attribution in output"

  grep -q "%%Tyger Tyger%%" "$OUT_DIR/tyger.typ" \
    && grep -q "hand || or eye" "$OUT_DIR/tyger.typ" \
    && pass "mdToTypst.py – inline markers passed through" \
    || fail "mdToTypst.py – inline markers passed through"

  # Continuation line — "+" prefix must survive extraction for poem() to interpret
  python3 mdToTypst.py "$OUT_DIR/continuation.poem" "$OUT_DIR/continuation.typ" 2>/dev/null \
    && grep -q '+and here is its continuation' "$OUT_DIR/continuation.typ" \
    && pass "mdToTypst.py – continuation marker passed through" \
    || fail "mdToTypst.py – continuation marker passed through"

  typst compile "$OUT_DIR/continuation.typ" "$OUT_DIR/continuation_typst.pdf" 2>/dev/null \
    && [ -s "$OUT_DIR/continuation_typst.pdf" ] \
    && pass "typst compile → PDF (continuation line)" \
    || fail "typst compile → PDF (continuation line)"

  # Stage 2 features via duet.poem — extraction preserves the raw markers,
  # and poem()/render-poem-line in chapBook.typ must compile them without error.
  python3 mdToTypst.py duet.poem "$OUT_DIR/duet.typ" 2>/dev/null \
    && grep -q 'align(center)\[#emph\[A Small Dialogue\]\]' "$OUT_DIR/duet.typ" \
    && grep -q 'align(center)\[#emph\[For anyone who has ever argued with the wind\]\]' "$OUT_DIR/duet.typ" \
    && pass "mdToTypst.py – subtitle/dedication/epigraph in output" \
    || fail "mdToTypst.py – subtitle/dedication/epigraph in output"

  grep -q '@@section:Call' "$OUT_DIR/duet.typ" \
    && grep -q '@@pagebreak' "$OUT_DIR/duet.typ" \
    && pass "mdToTypst.py – section/pagebreak markers passed through" \
    || fail "mdToTypst.py – section/pagebreak markers passed through"

  grep -q '@WIND:' "$OUT_DIR/duet.typ" \
    && grep -q '{{fr:' "$OUT_DIR/duet.typ" \
    && grep -q '~The seasons' "$OUT_DIR/duet.typ" \
    && pass "mdToTypst.py – speaker/refrain/foreign-language markers passed through" \
    || fail "mdToTypst.py – speaker/refrain/foreign-language markers passed through"

  typst compile "$OUT_DIR/duet.typ" "$OUT_DIR/duet_typst.pdf" 2>/dev/null \
    && [ -s "$OUT_DIR/duet_typst.pdf" ] \
    && pass "typst compile → PDF (duet.poem, all Stage 2 markers)" \
    || fail "typst compile → PDF (duet.poem, all Stage 2 markers)"

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
