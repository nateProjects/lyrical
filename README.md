# Lyrical Poetry & Verse MarkDown

Goal: Create / format poetry in MarkDown. Output it to HTML / Typst / LaTeX / PDF / ePub

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
