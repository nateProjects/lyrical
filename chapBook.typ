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
//   %%text%%  → small caps
//   ||        → caesura (a visible mid-line gap)
#let render-poem-line(line) = {
  let segments = line.split("||")
  for (seg-index, segment) in segments.enumerate() {
    if seg-index > 0 { h(1em) }
    let sc-parts = segment.split("%%")
    for (part-index, part) in sc-parts.enumerate() {
      if calc.rem(part-index, 2) == 1 { smallcaps(part) } else { part }
    }
  }
}

// ── Poem typesetter ────────────────────────────────────────────────────────
// metre: a string of characters where each unique character maps to an indent
//   level, cycling per line.  "ab" = alternate (a=flush, b=indented).
//   "abba" = ABBA rhyme indentation, etc.
// A line prefixed with "+" is a continuation of the previous line (e.g. a
// long line wrapped for print): it gets a hanging indent instead of a metre
// slot, and doesn't advance the metre cycle for the lines that follow it.
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
    if trimmed == "" {
      if current-verse.len() > 0 {
        verses.push(current-verse)
        current-verse = ()
      }
    } else {
      current-verse.push(trimmed)
    }
  }
  if current-verse.len() > 0 {
    verses.push(current-verse)
  }
  for (verse-index, verse) in verses.enumerate() {
    if verse-index > 0 { v(verse-spacing) }
    let verse-content = {
      let line-count = 0
      for (i, line) in verse.enumerate() {
        let is-continuation = line.starts-with("+")
        let rendered = render-poem-line(if is-continuation { line.slice(1) } else { line })
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
