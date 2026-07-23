// chapBook.typ – A5 poetry chapbook template
// Usage: #import "chapBook.typ": chapbook, poem
//        #show: chapbook.with(title: "...", author: "...", year: "...")

// ── Typography helpers ────────────────────────────────────────────────────
#let nbsp-em = "\u{2060}—"   // em-dash with word-joiner (avoids orphan dash)
#let nbsp-el = "\u{2060}…"   // ellipsis with word-joiner

#let scene-break(content: [· · ·], spacing: 2em) = {
  set align(center)
  block(above: spacing, below: spacing, text(1em, content))
}

// Converts straight quotes to typographic curly quotes for common poetry patterns
#let process-quotes(text) = {
  let result = text
  result = result.replace("\n'", "\n\u{2018}")  // opening at line start
  result = result.replace(" '", " \u{2018}")    // opening after space
  result = result.replace(",'", ",\u{2019}")    // closing after comma
  result = result.replace(".'", ".\u{2019}")    // closing after period
  result = result.replace("'.", "\u{2019}.")
  result = result.replace("',", "\u{2019},")
  result = result.replace("?'", "?\u{2019}")
  result = result.replace("!'", "!\u{2019}")
  return result
}

// Renders one poem line's text, expanding inline markers:
//   %%text%%       → small caps
//   ~~text~~       → strikethrough
//   [[text]]       → visible erasure (a redacted block, for erasure poetry)
//   {{lang:text}}  → foreign-language emphasis, tagged with its language
//   {{text}}       → foreign-language emphasis, no language tag
//   ||             → caesura (a visible mid-line gap)
// Scans by grapheme cluster rather than byte, so multi-byte characters (e.g.
// the curly quotes from process-quotes) are never split mid-character.
#let render-poem-line(line) = {
  let cl = line.clusters()
  let n = cl.len()
  let starts-with-at = (pos, token) => {
    let tok = token.clusters()
    pos + tok.len() <= n and cl.slice(pos, pos + tok.len()).join("") == token
  }
  let find-close = (pos, token) => {
    let tok-len = token.clusters().len()
    let j = pos
    while j + tok-len <= n {
      if starts-with-at(j, token) { return j }
      j += 1
    }
    none
  }
  let out = []
  let i = 0
  while i < n {
    if starts-with-at(i, "||") {
      out += h(1em)
      i += 2
    } else if starts-with-at(i, "%%") {
      let close = find-close(i + 2, "%%")
      if close != none {
        out += smallcaps(cl.slice(i + 2, close).join(""))
        i = close + 2
      } else { out += cl.at(i); i += 1 }
    } else if starts-with-at(i, "~~") {
      let close = find-close(i + 2, "~~")
      if close != none {
        out += strike(cl.slice(i + 2, close).join(""))
        i = close + 2
      } else { out += cl.at(i); i += 1 }
    } else if starts-with-at(i, "[[") {
      let close = find-close(i + 2, "]]")
      if close != none {
        let redacted = cl.slice(i + 2, close).join("")
        out += box(fill: black, text(fill: black)[#redacted])
        i = close + 2
      } else { out += cl.at(i); i += 1 }
    } else if starts-with-at(i, "{{") {
      let close = find-close(i + 2, "}}")
      if close != none {
        let inner = cl.slice(i + 2, close).join("")
        let colon = inner.position(":")
        if colon != none and colon <= 3 {
          out += emph(inner.slice(colon + 1))
        } else {
          out += emph(inner)
        }
        i = close + 2
      } else { out += cl.at(i); i += 1 }
    } else {
      out += cl.at(i)
      i += 1
    }
  }
  out
}

// ── Poem typesetter ────────────────────────────────────────────────────────
// metre: a string of characters where each unique character maps to an indent
//   level, cycling per line.  "ab" = alternate (a=flush, b=indented).
//   "abba" = ABBA rhyme indentation, etc.
// A line prefixed with "+" is a continuation of the previous line (e.g. a
// long line wrapped for print): it gets a hanging indent instead of a metre
// slot, and doesn't advance the metre cycle for the lines that follow it.
// A line prefixed with "~" (not "~~", which is strikethrough) is a refrain,
// underlined so it stands out wherever it recurs. A line of the form
// "@Name: text" gets Name rendered as a small-caps speaker label.
// "@@section" (bare, or "@@section:Title") inserts a numbered part break;
// "@@pagebreak" forces a page break — both are lines on their own.
#let poem(
  text,
  metre: "ab",
  indent-size: 1.5em,
  verse-spacing: 1em,
  keep-indent-on-wrap: true,
  keep-verses-together: true,
) = {
  set par(first-line-indent: 0em)
  let processed-text = process-quotes(text)
  let all-lines = processed-text.split("\n")
  let metre-chars = metre.clusters()
  let unique-chars = metre-chars.dedup()
  let indent-map = (:)
  for (i, char) in unique-chars.enumerate() {
    indent-map.insert(char, i * indent-size)
  }

  let verses = ()
  let current-verse = ()
  for line in all-lines {
    let trimmed = line.trim()
    if trimmed == "@@section" or trimmed.starts-with("@@section:") {
      if current-verse.len() > 0 {
        verses.push((kind: "verse", lines: current-verse))
        current-verse = ()
      }
      let title = if trimmed == "@@section" { none } else { trimmed.slice(10).trim() }
      verses.push((kind: "section", title: title))
    } else if trimmed == "@@pagebreak" {
      if current-verse.len() > 0 {
        verses.push((kind: "verse", lines: current-verse))
        current-verse = ()
      }
      verses.push((kind: "pagebreak"))
    } else if trimmed == "" {
      if current-verse.len() > 0 {
        verses.push((kind: "verse", lines: current-verse))
        current-verse = ()
      }
    } else {
      current-verse.push(trimmed)
    }
  }
  if current-verse.len() > 0 {
    verses.push((kind: "verse", lines: current-verse))
  }

  let section-count = 0
  for (verse-index, entry) in verses.enumerate() {
    if entry.kind == "pagebreak" {
      pagebreak()
    } else if entry.kind == "section" {
      if verse-index > 0 { v(verse-spacing) }
      if entry.title == none {
        scene-break()
      } else {
        section-count += 1
        align(center)[
          #strong(numbering("I", section-count)) #h(0.5em) #smallcaps(entry.title)
        ]
      }
    } else {
    if verse-index > 0 { v(verse-spacing) }
    let verse = entry.lines
    let verse-content = {
      let line-count = 0
      for (i, line) in verse.enumerate() {
        let is-continuation = line.starts-with("+")
        let content-line = if is-continuation { line.slice(1) } else { line }
        let is-speaker = content-line.starts-with("@") and not content-line.starts-with("@@")
        let is-refrain = content-line.starts-with("~") and not content-line.starts-with("~~")

        let rendered = if is-speaker {
          let colon = content-line.position(":")
          if colon != none {
            let name = content-line.slice(1, colon)
            let rest = content-line.slice(colon + 1).trim()
            strong(smallcaps(name)) + [ ] + render-poem-line(rest)
          } else {
            render-poem-line(content-line)
          }
        } else if is-refrain {
          underline(render-poem-line(content-line.slice(1)))
        } else {
          render-poem-line(content-line)
        }

        if is-continuation {
          box(width: 100% - indent-size, pad(left: indent-size)[
            #set par(hanging-indent: indent-size)
            #rendered
          ])
        } else {
          let metre-char = metre-chars.at(calc.rem(line-count, metre-chars.len()))
          let indent-amount = indent-map.at(metre-char)
          if indent-amount > 0pt {
            if keep-indent-on-wrap {
              box(width: 100% - indent-amount, pad(left: indent-amount)[
                #set par(hanging-indent: indent-amount)
                #rendered
              ])
            } else {
              h(indent-amount)
              rendered
            }
          } else {
            rendered
          }
          line-count += 1
        }
        if i < verse.len() - 1 { linebreak() }
      }
    }
    if keep-verses-together {
      block(breakable: false)[#verse-content]
    } else {
      verse-content
    }
    }
  }
}

// ── Chapbook document template ─────────────────────────────────────────────
// Apply with: #show: chapbook.with(title: "...", author: "...", year: "...")
#let chapbook(
  title: "Book Title",
  author: "Author Name",
  year: "2025",
  chapter-top-spacing: 1cm,
  doc,
) = {
  set text(region: "GB")
  set text(font: "EB Garamond", size: 10pt)
  set page(
    width: 105mm,
    height: 148mm,
    margin: (top: 1.5cm, bottom: 1.5cm, inside: 2.5cm, outside: 1.5cm),
  )
  set par(
    first-line-indent: 0.5cm,
    spacing: 0.7em,
    justify: false,
  )

  // ── Title page ────────────────────────────────────────────────────────
  align(center)[
    #block({
      set par(leading: 0.6em)
      text(size: 32pt, weight: "bold")[#title]
    })
    #set par(leading: 0.7em)
    \ \
    #text(size: 16pt, weight: "bold")[#author] \
    \
    #emph[© #year #author]
  ]
  pagebreak()
  pagebreak()

  // ── Footer: centred page number, suppressed on section pages ──────────
  set par(justify: false)
  set page(
    footer: context {
      let current-page = here().page()
      if here().page-numbering() == none { return }
      let on-section = query(heading.where(level: 1))
        .any(h => h.location().page() == current-page)
      if on-section { return }
      align(center, counter(page).display())
    },
  )

  // ── Heading styles ─────────────────────────────────────────────────────
  // Level 1 (= heading): section divider, no page break
  show heading.where(level: 1): it => {
    v(chapter-top-spacing)
    set align(center)
    set text(font: "Cinzel Decorative", size: 16pt, weight: "bold")
    block(smallcaps(text(it.body)))
    v(1em)
  }
  // Level 2 (== heading): poem / chapter title, always starts a new page
  show heading.where(level: 2): it => {
    pagebreak()
    v(chapter-top-spacing)
    set align(center)
    set text(font: "Cinzel Decorative", size: 16pt, weight: "bold")
    block(smallcaps(text(it.body)))
    v(1em)
  }

  // ── Ensure body opens on a recto (odd) page ───────────────────────────
  context {
    let p = counter(page).get().first()
    if calc.even(p) {
      page(header: none, footer: none, numbering: none)[]
    }
  }

  set align(left)
  set page(numbering: "1")
  counter(page).update(1)

  doc
}
