-- poetry-filter.lua v0.3.0

local in_poem = false
local indent_alternate = false
local numbering = false
local reset_per_stanza = false
local line_count = 0
local section_count = 0

local ROMAN_TABLE = {
    {1000, "M"}, {900, "CM"}, {500, "D"}, {400, "CD"},
    {100, "C"}, {90, "XC"}, {50, "L"}, {40, "XL"},
    {10, "X"}, {9, "IX"}, {5, "V"}, {4, "IV"}, {1, "I"},
}

local function to_roman(n)
    local parts = {}
    for _, pair in ipairs(ROMAN_TABLE) do
        local value, symbol = pair[1], pair[2]
        while n >= value do
            table.insert(parts, symbol)
            n = n - value
        end
    end
    return table.concat(parts)
end

function Meta(meta)
    if meta.PIndent then
        indent_alternate = pandoc.utils.stringify(meta.PIndent) == "Alternate"
    end
    if meta.PNumbering then
        local n = pandoc.utils.stringify(meta.PNumbering):lower()
        numbering = n ~= "off" and n ~= "" and n ~= "none" and n ~= "false"
        reset_per_stanza = (n == "stanza")
    end
    return meta
end

-- Split a flat list of Inlines into per-line sublists at SoftBreak/LineBreak
local function split_lines(inlines)
    local lines = {{}}
    for _, el in ipairs(inlines) do
        if el.t == "SoftBreak" or el.t == "LineBreak" then
            table.insert(lines, {})
        else
            table.insert(lines[#lines], el)
        end
    end
    if #lines[#lines] == 0 then table.remove(lines) end
    return lines
end

-- Stringify a line's inlines, stripping trailing " # ..." directive comments.
-- Pandoc parses @@directive as Str("@") + Cite(id="directive"), so Cite
-- elements are reconstructed as "@id" to restore the original @@ text.
-- Recurses into any inline container (Emph, Strong, Strikeout, Superscript,
-- ...) via its .content — otherwise a native pandoc element sitting next to
-- one of our own markers on the same line would silently vanish (not just
-- lose its styling) whenever that line gets rebuilt from this flat string.
local function get_text(inlines)
    local parts = {}
    local function walk(list)
        for _, el in ipairs(list) do
            if el.t == "Str" then
                table.insert(parts, el.text)
            elseif el.t == "Space" or el.t == "SoftBreak" then
                table.insert(parts, " ")
            elseif el.t == "Cite" then
                for _, citation in ipairs(el.citations) do
                    table.insert(parts, "@" .. citation.id)
                end
            elseif el.content then
                walk(el.content)
            end
        end
    end
    walk(inlines)
    local text = table.concat(parts)
    local ci = text:find(" #")
    return ci and text:sub(1, ci - 1) or text
end

-- Inline marker definitions: symmetric delimiter pairs, each rendering its
-- captured inner text to an HTML string. "~~" (strikethrough) is deliberately
-- absent — pandoc's reader already parses it natively into a Strikeout node,
-- and get_text()/inline_markers() only need to run when *our* markers are
-- present, so plain-line Strikeout formatting survives untouched.
--
-- Foreign-language marking uses {{...}} rather than the more obvious
-- ^^...^^ because pandoc's reader treats ^text^ as superscript — a bare
-- "^^" parses as an *empty* superscript span and is silently dropped by
-- get_text(), mangling the marker. Curly braces have no native meaning.
local INLINE_MARKERS = {
    {open = "%%", close = "%%", render = function(inner)
        return '<span style="font-variant: small-caps;">' .. inner .. '</span>'
    end},
    {open = "[[", close = "]]", render = function(inner)
        return '<span class="erasure" style="background: #000; color: transparent;">' .. inner .. '</span>'
    end},
    {open = "{{", close = "}}", render = function(inner)
        local lang, rest = inner:match("^(%a%a%a?):(.*)$")
        if lang then
            return '<em lang="' .. lang .. '" class="foreign">' .. rest .. '</em>'
        end
        return '<em class="foreign">' .. inner .. '</em>'
    end},
}

-- Does a line contain an inline poetic marker (small caps, erasure, foreign
-- language, or caesura)?
local function has_markers(text)
    if text:find("||", 1, true) then return true end
    for _, m in ipairs(INLINE_MARKERS) do
        if text:find(m.open, 1, true) then return true end
    end
    return false
end

-- Expand inline markers in a plain string into pandoc Inlines.
local function inline_markers(text)
    local out = pandoc.List({})
    local buf = {}
    local function flush()
        if #buf > 0 then
            out:insert(pandoc.Str(table.concat(buf)))
            buf = {}
        end
    end
    local i, n = 1, #text
    while i <= n do
        if text:sub(i, i + 1) == "||" then
            flush()
            out:insert(pandoc.RawInline("html", '<span class="caesura">&nbsp;&nbsp;&nbsp;&nbsp;</span>'))
            i = i + 2
        else
            local matched = false
            for _, m in ipairs(INLINE_MARKERS) do
                if text:sub(i, i + #m.open - 1) == m.open then
                    local close_start = text:find(m.close, i + #m.open, true)
                    if close_start then
                        flush()
                        local inner = text:sub(i + #m.open, close_start - 1)
                        out:insert(pandoc.RawInline("html", m.render(inner)))
                        i = close_start + #m.close
                        matched = true
                        break
                    end
                end
            end
            if not matched then
                table.insert(buf, text:sub(i, i))
                i = i + 1
            end
        end
    end
    flush()
    return out
end

-- Plain text and markers behave alike here: rebuild inlines only when a
-- marker is actually present, otherwise return the text as a single Str
-- (kept separate from the caller's original `inlines` so directive prefixes
-- can be stripped first without disturbing any richer formatting elsewhere).
local function text_to_inlines(text)
    if has_markers(text) then return inline_markers(text) end
    return pandoc.List({pandoc.Str(text)})
end

-- Simple string-level version of the same expansion, for the pre-existing
-- alignment/attribution directives which build raw HTML strings directly —
-- those lines are already fully flattened text, so there's no native AST
-- formatting left to preserve, and "~~" is handled manually here too.
local function html_markers(s)
    s = s:gsub("%%%%(.-)%%%%", '<span style="font-variant: small-caps;">%1</span>')
    s = s:gsub("~~(.-)~~", '<del>%1</del>')
    s = s:gsub("%[%[(.-)%]%]", '<span class="erasure" style="background: #000; color: transparent;">%1</span>')
    s = s:gsub("{{(%a%a%a?):(.-)}}", '<em lang="%1" class="foreign">%2</em>')
    s = s:gsub("{{(.-)}}", '<em class="foreign">%1</em>')
    s = s:gsub("||", '<span class="caesura">&nbsp;&nbsp;&nbsp;&nbsp;</span>')
    return s
end

-- process_line returns either nil (directive, consumed), {kind = "block",
-- node = <a block-level pandoc node>}, or {kind = "inline", inlines = <List>}
-- for ordinary poem-line content that Para() should join with line breaks.
local function process_line(inlines)
    local text = get_text(inlines)

    -- Directives — consume without output
    if text == "@@poem" or text == "@@poem:start" then
        in_poem = true;  return nil
    end
    if text == "@@poem:end" then
        in_poem = false; return nil
    end
    if text == "@@indent:metre" or text == "@@indent:meter" then
        indent_alternate = true; return nil
    end
    if text == "@@numbering:on" then
        numbering = true; reset_per_stanza = false; return nil
    end
    if text == "@@numbering:stanza" then
        numbering = true; reset_per_stanza = true; return nil
    end
    if text == "@@numbering:off" then numbering = false; return nil end
    if text == "@@pagebreak" then
        return {kind = "block", node = pandoc.RawBlock("html",
            '<div style="page-break-after: always; break-after: page;"></div>')}
    end

    -- Section / part breaks within a longer sequence
    if text == "@@section" then
        return {kind = "block", node = pandoc.RawBlock("html",
            '<div class="scene-break" style="text-align: center;">&middot;&nbsp;&middot;&nbsp;&middot;</div>')}
    end
    local section_title = text:match("^@@section:%s*(.*)")
    if section_title then
        section_count = section_count + 1
        return {kind = "block", node = pandoc.RawBlock("html",
            '<h2 class="part-heading"><span class="part-number">' .. to_roman(section_count) ..
            '</span> ' .. section_title .. '</h2>')}
    end

    -- Attribution / byline — semantic right-aligned element, distinct from "->"
    if text:match("^~>") then
        return {kind = "block", node = pandoc.RawBlock("html",
            '<div class="attribution" style="text-align: right;">' .. html_markers(text:sub(3)) .. '</div>')}
    end

    -- Alignment directives
    if text:match("^%-><") then
        return {kind = "block", node = pandoc.RawBlock("html",
            '<div style="text-align: center;">' .. html_markers(text:sub(4)) .. '</div>')}
    end
    if text:match("^%->") then
        return {kind = "block", node = pandoc.RawBlock("html",
            '<div style="text-align: right;">' .. html_markers(text:sub(3)) .. '</div>')}
    end

    -- Continuation of a wrapped line — hanging-indented, not a new numbered verse line
    local cont_rest = text:match("^%+(.*)")
    if cont_rest then
        local body = pandoc.List({
            pandoc.RawInline("html", '<span class="continuation">' .. string.rep("&nbsp;", 4) .. '</span>')
        })
        body:extend(text_to_inlines(cont_rest))
        return {kind = "inline", inlines = body}
    end

    -- Manual indentation via leading colons
    local colons, rest = text:match("^(:+)(.*)")
    local is_manual_indent = colons ~= nil
    local result = is_manual_indent
        and pandoc.List({
                pandoc.RawInline("html", string.rep("&nbsp;", #colons * 4)),
                pandoc.Str(rest)
            })
        or  pandoc.List(inlines)

    if is_manual_indent then
        if has_markers(rest) then
            result = pandoc.List({pandoc.RawInline("html", string.rep("&nbsp;", #colons * 4))})
            result:extend(inline_markers(rest))
        end
    else
        -- Refrain — a repeated line, styled consistently wherever it recurs.
        -- ("~~" is strikethrough, left to pandoc's native Strikeout parsing.)
        local refrain_rest = (text:sub(1, 1) == "~" and text:sub(1, 2) ~= "~~") and text:sub(2) or nil
        -- Speaker attribution for dramatic / persona poems
        local speaker, speaker_rest = text:match("^@(%a[%w %-']*):%s*(.*)")

        if refrain_rest then
            result = pandoc.List({
                pandoc.RawInline("html", '<span class="refrain" style="font-style: italic;">')
            })
            result:extend(text_to_inlines(refrain_rest))
            result:insert(pandoc.RawInline("html", '</span>'))
        elseif speaker then
            result = pandoc.List({pandoc.RawInline("html",
                '<span class="speaker-name" style="font-variant: small-caps; font-weight: bold;">' ..
                speaker .. '</span> ')})
            result:extend(text_to_inlines(speaker_rest))
        elseif has_markers(text) then
            result = inline_markers(text)
        end
    end

    -- Poem mode: alternate indentation and optional line numbering.
    -- Colon-indented lines have an explicit indent, so skip alternate indent for them.
    if in_poem then
        if numbering and not is_manual_indent and line_count % 2 == 0 then
            result:insert(1, pandoc.Str("(" .. tostring(math.floor(line_count / 2) + 1) .. ") "))
        end
        if indent_alternate and not is_manual_indent and line_count % 2 == 1 then
            result:insert(1, pandoc.RawInline("html", "&nbsp;&nbsp;&nbsp;&nbsp;"))
        end
        line_count = line_count + 1
    end

    return {kind = "inline", inlines = result}
end

-- Joins consecutive "inline" lines with real LineBreak elements (-> <br/>)
-- into one Plain per run, while "block" lines (headings, dividers, attribution)
-- stand alone — without this, sibling Plain blocks inside the wrapping Div
-- have no markup between them and collapse onto a single line in HTML.
function Para(para)
    if in_poem and reset_per_stanza then
        line_count = 0
    end

    local blocks = {}
    local current = pandoc.List({})

    local function flush()
        if #current > 0 then
            table.insert(blocks, pandoc.Plain(current))
            current = pandoc.List({})
        end
    end

    for _, line_inlines in ipairs(split_lines(para.content)) do
        if #line_inlines > 0 then
            local piece = process_line(line_inlines)
            if piece ~= nil then
                if piece.kind == "block" then
                    flush()
                    table.insert(blocks, piece.node)
                else
                    if #current > 0 then current:insert(pandoc.LineBreak()) end
                    current:extend(piece.inlines)
                end
            end
        end
    end
    flush()

    if #blocks == 0 then return {}
    elseif #blocks == 1 then return blocks[1]
    else return pandoc.Div(blocks, pandoc.Attr("", {"poetry"})) end
end

-- Title / Subtitle / Dedication / Epigraph as distinct semantic elements
-- ahead of the poem body, and the opt-in "keep stanzas together" print hint —
-- both need the whole document (doc.meta + doc.blocks), not just one element.
function Pandoc(doc)
    local function get(key)
        local v = doc.meta[key]
        return v and pandoc.utils.stringify(v) or nil
    end

    local title = get("Title")
    local subtitle = get("Subtitle")
    local dedication = get("Dedication")
    local epigraph = get("Epigraph")
    local epigraph_attr = get("EpigraphAttribution")
    local keep = get("PKeep")

    local header = {}
    if title then
        table.insert(header, pandoc.RawBlock("html", '<h1 class="poem-title">' .. title .. '</h1>'))
    end
    if subtitle then
        table.insert(header, pandoc.RawBlock("html", '<h2 class="poem-subtitle">' .. subtitle .. '</h2>'))
    end
    if dedication then
        table.insert(header, pandoc.RawBlock("html",
            '<div class="dedication" style="text-align: center; font-style: italic;">' .. dedication .. '</div>'))
    end
    if epigraph then
        local html = '<blockquote class="epigraph" style="text-align: center; font-style: italic;"><p>' ..
            epigraph .. '</p>'
        if epigraph_attr then
            html = html .. '<footer class="epigraph-attribution" style="text-align: right;">' ..
                epigraph_attr .. '</footer>'
        end
        html = html .. '</blockquote>'
        table.insert(header, pandoc.RawBlock("html", html))
    end
    if keep and keep:lower() == "together" then
        table.insert(header, pandoc.RawBlock("html",
            '<style>.poetry { break-inside: avoid; page-break-inside: avoid; }</style>'))
    end

    for i = #header, 1, -1 do
        table.insert(doc.blocks, 1, header[i])
    end
    return doc
end

return {
    {Meta = Meta},
    {Para = Para},
    {Pandoc = Pandoc},
}
