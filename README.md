# Lyrical Poetry & Verse MarkDown

Create / format poetry in MarkDown. Output it to HTML / Typst / LaTeX / PDF / ePub

![](tests/tyger.jpg | width=640)

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

Worked examples: [tyger.poem](tyger.poem) (most line- and word-level features),
[continuation.poem](continuation.poem) (wrapped lines), and
[duet.poem](duet.poem) (front matter, sections, speakers, refrains, erasure).

### Front matter

Metadata only — never rendered as poem *body* text, though `Title`, `Subtitle`,
`Dedication`, and `Epigraph`/`EpigraphAttribution` are rendered as their own
elements ahead of the poem — see [Title, subtitle, dedication, epigraph](#title-subtitle-dedication-epigraph) below.

```
---
Title: The Tyger # space after : ignored
Subtitle: A Question in Verse
Author: William Blake
Year: 1794
Dedication: For readers of Songs of Experience
Epigraph: Little Lamb, who made thee?
EpigraphAttribution: from The Lamb, Songs of Innocence
PForm: Freeform # lower / upper case allowed
PIndent: Alternate
PMetre: ABAB # should also allow PMeter
PNumbering: Alternate # or Stanza, to restart numbering at each blank line
PKeep: Together # or Auto — see Keep stanzas together, below
---
```

### Directives

```
@@indent:metre     # or @@indent:meter — alternate-indent every other line
@@numbering:on     # number every other line, e.g. (1), (2)...
@@numbering:stanza # same, but the count restarts at each blank line
@@numbering:off
@@poem             # or @@poem:start — begin poetry formatting
@@poem:end         # end poetry formatting (or end-of-file)
@@section          # a bare part break — a centred "· · ·" divider
@@section:Title    # a numbered, titled part break — "I  Title", "II  Title", ...
@@pagebreak        # force a page break at this point
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

### Strikethrough and erasure

`~~text~~` strikes text through. `[[text]]` visibly redacts it (a solid
black block) — the words are still present in the source and in a
screen-reader/copy-paste of the output, just visually blacked out — for
erasure poetry or marking a visible revision.

```
A line with a ~~mistake~~ correction and [[a secret]] left in.
```

Combining either of these with a speaker, refrain, or manual-indent prefix
*on the same line* is one case worth knowing about: in the pandoc backend,
`~~text~~` is parsed natively before our filter ever runs, so if something
else on that line (a `@Speaker:`, a `~refrain`, or a `:indent`) forces the
line to be rebuilt, the strikethrough *styling* is lost — the words
themselves are always preserved, never silently dropped. Give a
strikethrough its own plain line if you need it to survive pandoc alongside
one of those prefixes; the Python and Typst backends don't have this
limitation.

### Foreign-language / semantic italics

`{{lang:text}}` marks text as a different language, distinct from ordinary
`*emphasis*` — it carries a real `lang` attribute (`<em lang="fr">`) rather
than just looking italic. Leave off the language code (`{{text}}`) for
foreign-or-borrowed text with no specific tag.

```
{{fr:Je ne sais pas.}} I only know the ground is close.
```

(This uses `{{...}}` rather than the more obvious `^^...^^` because pandoc's
reader already treats `^text^` as superscript, which mangles a bare `^^`.)

### Title, subtitle, dedication, epigraph

Set via front matter (`Title`, `Subtitle`, `Dedication`, `Epigraph`,
`EpigraphAttribution`) — see the [Front matter](#front-matter) example above.
Each renders as its own distinct element ahead of the poem body, rather than
just another heading level or a line folded into the verse itself.

### Section / part breaks

`@@section` inserts a plain centred divider; `@@section:Title` inserts a
numbered, titled part break (numbered with roman numerals, restarting the
count at 1 per poem) — for splitting a longer sequence into movements.

```
@@section:Envoi
```

### Speaker attribution

`@Name:` at the start of a line labels it as spoken by `Name` — for
dramatic or persona poems. Only the first line of a speech needs the label;
lines after it are ordinary poem lines.

```
@HAMLET: To be, or not to be, that is the question.
```

### Refrains

A leading `~` (not `~>`, which is [attribution](#attribution--byline), and
not `~~`, which is strikethrough) marks a line as a refrain, styled
consistently wherever it recurs — for villanelles, pantoums, and other forms
built on repeated lines.

```
~And miles to go before I sleep.
```

### Page breaks

`@@pagebreak` forces a page break at that point in the poem — for print/PDF
output. It has no visible effect in an on-screen HTML view.

### Per-stanza line numbering

`PNumbering: Stanza` (front matter) or `@@numbering:stanza` (directive)
restarts the line count at 1 for each stanza, instead of counting straight
through the whole poem — common in scholarly or formal editions. HTML-only;
see the backend-support table below.

### Keep stanzas together (widow/orphan control)

`PKeep: Together` (front matter) hints to the renderer that a stanza
shouldn't be split across a page/print boundary — the usual fix for widow
and orphan lines. The Typst backend already keeps stanzas together by
default; set `PKeep: Auto` there to allow them to break freely instead.

### Backend support

Alignment, manual indent, and line numbering (continuous or per-stanza) are
HTML-only for now — the Typst pipeline ([mdToTypst.py](mdToTypst.py)) strips
those prefixes and renders plain text instead, since `chapBook.typ` doesn't
yet model per-line alignment or a running counter.

| Feature | `poemParser.py` / `pandocFilter.lua` (HTML) | `mdToTypst.py` (Typst/PDF) |
|---|---|---|
| Alignment (`->`, `-><`) | ✓ | prefix stripped, alignment lost |
| Manual indent (`:`) | ✓ | prefix stripped, indent lost |
| Line numbering, continuous or per-stanza (`@@numbering`) | ✓ | not implemented |
| Continuation (`+`) | ✓ hanging indent | ✓ hanging indent |
| Attribution (`~>`) | ✓ `class="attribution"` | ✓ separate right-aligned italic block after the poem |
| Caesura (`\|\|`) | ✓ `class="caesura"` span | ✓ real `h(1em)` spacing |
| Small caps (`%%...%%`) | ✓ `font-variant: small-caps` | ✓ `smallcaps()` |
| Strikethrough (`~~...~~`) | ✓ (native pandoc AST when alone on a line; see [above](#strikethrough-and-erasure)) | ✓ `strike()` |
| Erasure (`[[...]]`) | ✓ `class="erasure"`, black-on-black span | ✓ solid black box |
| Foreign language (`{{lang:text}}`) | ✓ `<em lang="...">` | ✓ `emph()` (no language tag — Typst PDF text has no `lang` attribute to set) |
| Title / Subtitle / Dedication / Epigraph | ✓ own elements, rendered ahead of the poem | ✓ own blocks, rendered ahead of the poem |
| Section / part breaks (`@@section`, `@@section:Title`) | ✓ divider / numbered `<h2>` | ✓ divider / numbered heading via `scene-break()` |
| Speaker attribution (`@Name:`) | ✓ `class="speaker-name"` | ✓ bold small caps |
| Refrains (`~line`) | ✓ `class="refrain"`, italic | ✓ `underline()` |
| Page breaks (`@@pagebreak`) | ✓ print-CSS hint (`page-break-after`) | ✓ real `pagebreak()` |
| Keep stanzas together (`PKeep`) | ✓ opt-in print-CSS hint | ✓ on by default (`keep-verses-together`), opt out with `PKeep: Auto` |
