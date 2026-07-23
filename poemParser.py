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


def preserve_line_breaks(text):
    processed = []
    for line in text.split('\n'):
        stripped = line.strip()
        if stripped == '':
            processed.append('\n\n')
        elif stripped.startswith('<') and stripped.endswith('>'):
            processed.append(line + '\n')
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
    """Expand inline poetic markers: %%small caps%% and || (caesura)."""
    text = re.sub(r'%%(.+?)%%', r'<span style="font-variant: small-caps;">\1</span>', text)
    text = text.replace('||', '<span class="caesura">&nbsp;&nbsp;&nbsp;&nbsp;</span>')
    return text


def format_poem(text, indent_alternate=False, numbering=False):
    result = []
    in_poem = False
    line_count = 0

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
            continue
        if s == '@@numbering:off':
            numbering = False
            continue

        # Attribution / byline — semantic right-aligned element, distinct from "->"
        if s.startswith('~>'):
            result.append(f'<div class="attribution" style="text-align: right;">{apply_inline_markers(s[2:])}</div>')
            continue

        # Alignment (works inside and outside poem mode)
        if s.startswith('-><'):
            result.append(f'<div style="text-align: center;">{apply_inline_markers(s[3:])}</div>')
            continue
        if s.startswith('->'):
            result.append(f'<div style="text-align: right;">{apply_inline_markers(s[2:])}</div>')
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


def convert_to_html(text, indent_alternate=False, numbering=False):
    formatted = format_poem(text, indent_alternate, numbering)
    return markdown2.markdown(preserve_line_breaks(formatted))


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
        ))
    else:
        print("No front matter found.")
        print("\nContent as HTML:")
        print(convert_to_html(body))
