import re
import markdown2

# v0.1.5 - will read front matter / parse markdown into HTML / alternate verse lines
# Consider whether need line breaks for all markdown

def parse_markdown_front_matter(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    # Find the front matter section
    front_matter_match = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
    
    if not front_matter_match:
        return None, content

    front_matter = front_matter_match.group(1)
    remaining_content = content[front_matter_match.end():].strip()
    
    # Parse the front matter
    metadata = {}
    for line in front_matter.split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            key = key.strip()
            value = value.split('#')[0].strip()  # Remove comments and strip whitespace
            metadata[key] = value

    return metadata, remaining_content

def preserve_line_breaks(text):
    # Replace single newlines with <br> tags, but preserve paragraph breaks
    lines = text.split('\n')
    processed_lines = []
    for line in lines:
        if line.strip() == '':
            processed_lines.append('\n\n')  # Preserve paragraph breaks
        else:
            processed_lines.append(line + '<br>\n')
    return ''.join(processed_lines)

def format_poem(text, indent_alternate=False):
    lines = text.split('\n')
    formatted_lines = []
    in_poem = False
    line_count = 0

    for line in lines:
        if line.strip() == '@@poem:start':
            in_poem = True
            formatted_lines.append(line)
        elif line.strip() == '@@poem:end':
            in_poem = False
            formatted_lines.append(line)
        elif in_poem:
            if indent_alternate and line_count % 2 == 1:
                formatted_lines.append('&nbsp;&nbsp;&nbsp;&nbsp;' + line)
            else:
                formatted_lines.append(line)
            line_count += 1
        else:
            formatted_lines.append(line)

    return '\n'.join(formatted_lines)

def convert_to_html(markdown_text, indent_alternate=False):
    # Format the poem if necessary
    formatted_text = format_poem(markdown_text, indent_alternate)
    
    # Preprocess the text to preserve line breaks
    preprocessed_text = preserve_line_breaks(formatted_text)
    
    # Use markdown2 to convert Markdown to HTML
    html_content = markdown2.markdown(preprocessed_text)
    
    return html_content

# Example usage
file_path = 'poem02.md'  # Replace with the actual path to your markdown file
result, remaining_text = parse_markdown_front_matter(file_path)

if result:
    poemTitle = result.get('Title')
    poemAuthor = result.get('Author')
    poemYear = result.get('Year')
    poemForm = result.get('PForm')
    poemIndent = result.get('PIndent')
    poemMetre = result.get('PMetre')
    poemNumbering = result.get('PNumbering')

    print("Front Matter:")
    print(f"Title: {poemTitle}")
    print(f"Author: {poemAuthor}")
    print(f"Year: {poemYear}")
    print(f"Form: {poemForm}")
    print(f"Indent: {poemIndent}")
    print(f"Metre: {poemMetre}")
    print(f"Numbering: {poemNumbering}")
    
    print("\nRemaining Content as HTML:")
    indent_alternate = poemIndent == "Alternate"
    html_content = convert_to_html(remaining_text, indent_alternate)
    print(html_content)
else:
    print("No front matter found in the markdown file.")
    print("\nEntire Content as HTML:")
    html_content = convert_to_html(remaining_text)
    print(html_content)
