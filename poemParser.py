import re
import sys
import markdown2

# v0.2.0 - read front matter / parse markdown into HTML / format verse


def parse_front_matter(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    match = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
    if not match:
        return None, content

    metadata = {}
    for line in match.group(1).split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            metadata[key.strip()] = value.split('#')[0].strip()

    return metadata, content[match.end():].strip()


# Marks a result line as a standalone block (heading, divider, attribution
# div, ...) that must not get a trailing <br> — this can't be inferred from
# the line's own text shape any more, since an ordinary poem line wrapped in
# inline markers (e.g. a speaker label at the start, a foreign-phrase marker
# at the end) can *also* start and end with a tag.
_BLOCK_MARK = '\x00BLOCK\x00'


def block(html):
    return _BLOCK_MARK + html


def preserve_line_breaks(text):
    processed = []
    for line in text.split('\n'):
        stripped = line.strip()
        if stripped == '':
            processed.append('\n\n')
        elif stripped.startswith(_BLOCK_MARK):
            processed.append(stripped[len(_BLOCK_MARK):] + '\n')
        elif re.match(r'^#{1,6}\s', stripped):
            # Markdown heading — let markdown2 handle it as a block; no <br>
            processed.append(line + '\n')
        else:
            processed.append(line + '<br>\n')
    return ''.join(processed)


def _strip_directive_comment(text):
    idx = text.find(' #')
    return text[:idx].strip() if idx != -1 else text


def apply_inline_markers(text):
    """Expand inline poetic markers: %%small caps%%, ~~strikethrough~~,
    [[erasure]], {{lang:foreign text}} (or {{foreign text}} with no lang
    attribute), and || (caesura).

    Note: foreign-language marking uses {{...}} rather than the more
    obvious ^^...^^ because pandoc's markdown reader already treats ^text^
    as superscript — a bare "^^" is parsed as an *empty* superscript span
    and silently dropped, mangling the marker. Curly braces have no native
    meaning in body text for either markdown2 or pandoc.
    """
    text = re.sub(r'%%(.+?)%%', r'<span style="font-variant: small-caps;">\1</span>', text)
    text = re.sub(r'~~(.+?)~~', r'<del>\1</del>', text)
    text = re.sub(
        r'\[\[(.+?)\]\]',
        r'<span class="erasure" style="background: #000; color: transparent;">\1</span>',
        text,
    )
    text = re.sub(r'\{\{([a-z]{2,3}):(.+?)\}\}', r'<em lang="\1" class="foreign">\2</em>', text)
    text = re.sub(r'\{\{(.+?)\}\}', r'<em class="foreign">\1</em>', text)
    text = text.replace('||', '<span class="caesura">&nbsp;&nbsp;&nbsp;&nbsp;</span>')
    return text


_ROMAN_NUMERALS = [
    (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'),
    (100, 'C'), (90, 'XC'), (50, 'L'), (40, 'XL'),
    (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I'),
]


def to_roman(n):
    result = ''
    for value, symbol in _ROMAN_NUMERALS:
        while n >= value:
            result += symbol
            n -= value
    return result


def render_front_elements(metadata):
    """Render Title / Subtitle / Dedication / Epigraph as distinct semantic
    elements, ahead of the poem body — rather than folding them into a
    heading level or the poem text itself."""
    parts = []
    if metadata.get('Title'):
        parts.append(f'<h1 class="poem-title">{metadata["Title"]}</h1>')
    if metadata.get('Subtitle'):
        parts.append(f'<h2 class="poem-subtitle">{metadata["Subtitle"]}</h2>')
    if metadata.get('Dedication'):
        parts.append(
            f'<div class="dedication" style="text-align: center; font-style: italic;">'
            f'{metadata["Dedication"]}</div>'
        )
    if metadata.get('Epigraph'):
        html = (
            f'<blockquote class="epigraph" style="text-align: center; font-style: italic;">'
            f'<p>{metadata["Epigraph"]}</p>'
        )
        if metadata.get('EpigraphAttribution'):
            html += (
                f'<footer class="epigraph-attribution" style="text-align: right;">'
                f'{metadata["EpigraphAttribution"]}</footer>'
            )
        html += '</blockquote>'
        parts.append(html)
    return '\n'.join(parts)


def format_poem(text, indent_alternate=False, numbering=False, reset_per_stanza=False):
    result = []
    in_poem = False
    line_count = 0
    section_count = 0

    for line in text.split('\n'):
        s = line.strip()

        # Strip inline comments from directive lines only
        if s.startswith('@@') or s.startswith('->'):
            s = _strip_directive_comment(s)

        # Poem mode control
        if s in ('@@poem', '@@poem:start'):
            in_poem = True
            continue
        if s == '@@poem:end':
            in_poem = False
            continue

        # Inline directives (can appear anywhere in the body)
        if s in ('@@indent:metre', '@@indent:meter'):
            indent_alternate = True
            continue
        if s == '@@numbering:on':
            numbering = True
            reset_per_stanza = False
            continue
        if s == '@@numbering:stanza':
            numbering = True
            reset_per_stanza = True
            continue
        if s == '@@numbering:off':
            numbering = False
            continue
        if s == '@@pagebreak':
            result.append(block('<div style="page-break-after: always; break-after: page;"></div>'))
            continue

        # Section / part breaks within a longer sequence
        if s == '@@section':
            result.append(block('<div class="scene-break" style="text-align: center;">&middot;&nbsp;&middot;&nbsp;&middot;</div>'))
            continue
        section_match = re.match(r'^@@section:(.*)', s)
        if section_match:
            section_count += 1
            title = section_match.group(1).strip()
            result.append(block(
                f'<h2 class="part-heading"><span class="part-number">{to_roman(section_count)}</span> {title}</h2>'
            ))
            continue

        # Attribution / byline — semantic right-aligned element, distinct from "->"
        if s.startswith('~>'):
            result.append(block(f'<div class="attribution" style="text-align: right;">{apply_inline_markers(s[2:])}</div>'))
            continue

        # Alignment (works inside and outside poem mode)
        if s.startswith('-><'):
            result.append(block(f'<div style="text-align: center;">{apply_inline_markers(s[3:])}</div>'))
            continue
        if s.startswith('->'):
            result.append(block(f'<div style="text-align: right;">{apply_inline_markers(s[2:])}</div>'))
            continue

        # Continuation of a wrapped line — hanging-indented, not a new numbered verse line
        continuation_match = re.match(r'^\+(.*)', s)
        if continuation_match:
            indent = '<span class="continuation">' + '&nbsp;' * 4 + '</span>'
            result.append(indent + apply_inline_markers(continuation_match.group(1)))
            continue

        # Manual indentation via leading colons
        colon_match = re.match(r'^(:+)(.*)', s)
        if colon_match:
            depth = len(colon_match.group(1))
            result.append('&nbsp;' * (depth * 4) + apply_inline_markers(colon_match.group(2)))
            continue

        # Refrain — a repeated line, styled consistently wherever it recurs.
        # ("~~" is strikethrough, handled by apply_inline_markers, not a refrain.)
        if s.startswith('~') and not s.startswith('~~'):
            s = f'<span class="refrain" style="font-style: italic;">{s[1:]}</span>'

        # Speaker attribution for dramatic / persona poems
        speaker_match = re.match(r"^@([A-Za-z][\w' -]*):\s*(.*)", s)
        if speaker_match:
            speaker, rest = speaker_match.groups()
            label = (
                f'<span class="speaker-name" style="font-variant: small-caps; font-weight: bold;">'
                f'{speaker}</span>'
            )
            s = f'{label} {rest}'

        # Reset numbering at each stanza break, when enabled
        if in_poem and s == '' and reset_per_stanza:
            line_count = 0
            result.append(line)
            continue

        # Poem mode: alternate indentation and optional line numbering
        if in_poem and s:
            formatted = apply_inline_markers(s)
            if numbering and line_count % 2 == 0:
                formatted = f'({line_count // 2 + 1}) {formatted}'
            if indent_alternate and line_count % 2 == 1:
                formatted = '&nbsp;&nbsp;&nbsp;&nbsp;' + formatted
            line_count += 1
            result.append(formatted)
        else:
            result.append(apply_inline_markers(line))

    return '\n'.join(result)


def convert_to_html(
    text,
    indent_alternate=False,
    numbering=False,
    reset_per_stanza=False,
    keep_together=False,
    front_matter_html='',
):
    formatted = format_poem(text, indent_alternate, numbering, reset_per_stanza)
    html = markdown2.markdown(preserve_line_breaks(formatted))
    style = '<style>p { break-inside: avoid; page-break-inside: avoid; }</style>\n' if keep_together else ''
    header = f'{front_matter_html}\n' if front_matter_html else ''
    return header + style + html


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python poemParser.py <poem_file>")
        sys.exit(1)

    metadata, body = parse_front_matter(sys.argv[1])

    if metadata:
        print("Front Matter:")
        print(f"Title:     {metadata.get('Title', '')}")
        print(f"Author:    {metadata.get('Author', '')}")
        print(f"Year:      {metadata.get('Year', '')}")
        print(f"Form:      {metadata.get('PForm', '')}")
        print(f"Indent:    {metadata.get('PIndent', '')}")
        print(f"Metre:     {metadata.get('PMetre', '')}")
        print(f"Numbering: {metadata.get('PNumbering', '')}")

        indent = metadata.get('PIndent', '')
        num_setting = metadata.get('PNumbering', '').lower()

        print("\nContent as HTML:")
        print(convert_to_html(
            body,
            indent_alternate=(indent == 'Alternate'),
            numbering=(num_setting not in ('', 'off', 'none', 'false')),
            reset_per_stanza=(num_setting == 'stanza'),
            keep_together=(metadata.get('PKeep', '').lower() == 'together'),
            front_matter_html=render_front_elements(metadata),
        ))
    else:
        print("No front matter found.")
        print("\nContent as HTML:")
        print(convert_to_html(body))
