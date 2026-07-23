-- poetry-filter.lua v0.2.0

local in_poem = false
local indent_alternate = false
local numbering = false
local line_count = 0

function Meta(meta)
    if meta.PIndent then
        indent_alternate = pandoc.utils.stringify(meta.PIndent) == "Alternate"
    end
    if meta.PNumbering then
        local n = pandoc.utils.stringify(meta.PNumbering):lower()
        numbering = n ~= "off" and n ~= "" and n ~= "none" and n ~= "false"
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
local function get_text(inlines)
    local parts = {}
    for _, el in ipairs(inlines) do
        if el.t == "Str" then
            table.insert(parts, el.text)
        elseif el.t == "Space" then
            table.insert(parts, " ")
        elseif el.t == "Cite" then
            for _, citation in ipairs(el.citations) do
                table.insert(parts, "@" .. citation.id)
            end
        end
    end
    local text = table.concat(parts)
    local ci = text:find(" #")
    return ci and text:sub(1, ci - 1) or text
end

-- Does a line contain an inline poetic marker (small caps or caesura)?
local function has_markers(text)
    return text:find("%%%%.-%%%%") ~= nil or text:find("||", 1, true) ~= nil
end

-- Expand %%small caps%% and || (caesura) in a plain string into Inlines.
local function inline_markers(text)
    local out = pandoc.List({})
    local i, n = 1, #text
    while i <= n do
        local sc_s, sc_e, sc_body = text:find("%%%%(.-)%%%%", i)
        local cs_s = text:find("||", i, true)
        if sc_s and (not cs_s or sc_s <= cs_s) then
            if sc_s > i then out:insert(pandoc.Str(text:sub(i, sc_s - 1))) end
            out:insert(pandoc.RawInline("html",
                '<span style="font-variant: small-caps;">' .. sc_body .. '</span>'))
            i = sc_e + 1
        elseif cs_s then
            if cs_s > i then out:insert(pandoc.Str(text:sub(i, cs_s - 1))) end
            out:insert(pandoc.RawInline("html",
                '<span class="caesura">&nbsp;&nbsp;&nbsp;&nbsp;</span>'))
            i = cs_s + 2
        else
            out:insert(pandoc.Str(text:sub(i)))
            break
        end
    end
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
-- alignment directives which build raw HTML strings directly.
local function html_markers(s)
    s = s:gsub("%%%%(.-)%%%%", '<span style="font-variant: small-caps;">%1</span>')
    s = s:gsub("||", '<span class="caesura">&nbsp;&nbsp;&nbsp;&nbsp;</span>')
    return s
end

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
    if text == "@@numbering:on"  then numbering = true;  return nil end
    if text == "@@numbering:off" then numbering = false; return nil end

    -- Attribution / byline — semantic right-aligned element, distinct from "->"
    if text:match("^~>") then
        return pandoc.RawBlock("html",
            '<div class="attribution" style="text-align: right;">' .. html_markers(text:sub(3)) .. '</div>')
    end

    -- Alignment directives
    if text:match("^%-><") then
        return pandoc.RawBlock("html",
            '<div style="text-align: center;">' .. html_markers(text:sub(4)) .. '</div>')
    end
    if text:match("^%->") then
        return pandoc.RawBlock("html",
            '<div style="text-align: right;">' .. html_markers(text:sub(3)) .. '</div>')
    end

    -- Continuation of a wrapped line — hanging-indented, not a new numbered verse line
    local cont_rest = text:match("^%+(.*)")
    if cont_rest then
        local body = pandoc.List({
            pandoc.RawInline("html", '<span class="continuation">' .. string.rep("&nbsp;", 4) .. '</span>')
        })
        body:extend(text_to_inlines(cont_rest))
        return pandoc.Plain(body)
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

    -- Expand inline markers in the body text, whichever path produced `result`
    if is_manual_indent then
        if has_markers(rest) then
            result = pandoc.List({pandoc.RawInline("html", string.rep("&nbsp;", #colons * 4))})
            result:extend(inline_markers(rest))
        end
    elseif has_markers(text) then
        result = inline_markers(text)
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

    return pandoc.Plain(result)
end

function Para(para)
    local result = {}
    for _, line_inlines in ipairs(split_lines(para.content)) do
        if #line_inlines > 0 then
            local block = process_line(line_inlines)
            if block ~= nil then table.insert(result, block) end
        end
    end

    if #result == 0 then return {}
    elseif #result == 1 then return result[1]
    else return pandoc.Div(result, pandoc.Attr("", {"poetry"}))
    end
end

return {
    {Meta = Meta},
    {Para = Para},
}
