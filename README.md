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

```
# front matter - do not display on output
---
Title: The Tyger # space after : ignored 
Author: William Blake 
Year: 1794 
PForm: Freeform # lower / upper case allowed
PIndent: Alternate
PMetre: ABAB # should also allow PMeter
PNumbering: Alternate
---
# Markdown

# Assignments
@@indent:metre # or @@indent:meter
@@numbering:off
@@poem # start poetry formatting

# Alignment
->This sentence is right aligned.
-><This sentence is center aligned.

# Manual Indenting
:Indent once
::Indent twice
```
