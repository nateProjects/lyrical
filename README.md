# Lyrical Poetry & Verse MarkDown

Goal: Create / format poetry in MarkDown. Output it to HTML / Typst / LaTeX / PDF / ePub

## Requirements

### macOS
```bash
brew install python pandoc typst
pip install markdown2
```
For Typst PDF output, install the required fonts:
```bash
brew install --cask font-eb-garamond font-cinzel-decorative
```

### Linux (Debian / Ubuntu)
```bash
sudo apt install python3 python3-pip pandoc
pip3 install markdown2
# Typst — no apt package; install via snap or direct download:
snap install typst
# or: curl -fsSL https://typst.community/typst-install/install.sh | sh
```
For Typst PDF output, install the required fonts (EB Garamond, Cinzel Decorative)
from your distro's font packages or download from [Google Fonts](https://fonts.google.com).

For pandoc PDF output a LaTeX engine is also required:
```bash
# macOS
brew install --cask mactex-no-gui   # or: brew install basictex
# Linux
sudo apt install texlive-xetex
```

## Usage

**HTML (Python)**
```
python poemParser.py <poem_file>
```

**HTML (pandoc + Lua filter)**
```
pandoc --lua-filter pandocFilter.lua poem.md -o poem.html
```

**PDF (pandoc + Lua filter)**
```
pandoc --lua-filter pandocFilter.lua poem.md -o poem.pdf
```
pandoc selects a LaTeX engine automatically; use `--pdf-engine=xelatex` (or `lualatex`) if you need Unicode or custom font support.

**Typst / PDF**
```
python mdToTypst.py <poem_file>          # generates <poem_file>.typ
typst compile <poem_file>.typ            # compiles to PDF
```

The generated `.typ` imports `chapBook.typ` (A5 chapbook layout).
Customise the title page by editing `book-title`, `author`, and `year` at the top of the generated file, or pass them via front matter in the source poem.

## MarkDown Spec

Worked examples: [tyger.poem](tyger.poem) (most features) and [continuation.poem](continuation.poem) (wrapped lines).

### Front matter

Metadata only — never rendered.

```
---
Title: The Tyger # space after : ignored
Author: William Blake
Year: 1794
PForm: Freeform # lower / upper case allowed
PIndent: Alternate
PMetre: ABAB # should also allow PMeter
PNumbering: Alternate
---
```

### Directives

```
@@indent:metre     # or @@indent:meter — alternate-indent every other line
@@numbering:on     # number every other line, e.g. (1), (2)...
@@numbering:off
@@poem             # or @@poem:start — begin poetry formatting
@@poem:end         # end poetry formatting (or end-of-file)
```

### Alignment

Generic per-line alignment. Works inside and outside `@@poem`.

```
->This sentence is right aligned.
-><This sentence is center aligned.
```

### Manual indenting

Each leading `:` adds one indent level. Excluded from line numbering and
metre-based alternate indent — it's an explicit indent, not a metre slot.

```
:Indent once
::Indent twice
```

### Attribution / byline

A right-aligned line tagged as attribution rather than generic alignment, so
it can be styled distinctly (e.g. italic, or moved to a title-page credit).

```
~>William Blake, 1794
```

### Continuation lines

`+` marks a line as the hanging-indented continuation of the line above it —
for a verse line too long to typeset on one line. It keeps the original
line's number and doesn't advance metre-based alternate indent.

```
This is a long line that keeps going
+and this is its wrapped continuation
```

### Caesura

`||` inserts a visible mid-line pause — a real rendered gap, not just a space.

```
What dread hand? || what dread feet?
```

### Small caps

Common for a poem's opening line or title.

```
%%Tyger Tyger%%, burning bright
```

### Backend support

Alignment, manual indent, and line numbering are HTML-only for now — the
Typst pipeline ([mdToTypst.py](mdToTypst.py)) strips those prefixes and
renders plain text instead, since `chapBook.typ` doesn't yet model per-line
alignment or a running counter.

| Feature | `poemParser.py` / `pandocFilter.lua` (HTML) | `mdToTypst.py` (Typst/PDF) |
|---|---|---|
| Alignment (`->`, `-><`) | ✓ | prefix stripped, alignment lost |
| Manual indent (`:`) | ✓ | prefix stripped, indent lost |
| Line numbering (`@@numbering`) | ✓ | not implemented |
| Continuation (`+`) | ✓ hanging indent | ✓ hanging indent |
| Attribution (`~>`) | ✓ `class="attribution"` | ✓ separate right-aligned italic block after the poem |
| Caesura (`\|\|`) | ✓ `class="caesura"` span | ✓ real `h(1em)` spacing |
| Small caps (`%%...%%`) | ✓ `font-variant: small-caps` | ✓ `smallcaps()` |
