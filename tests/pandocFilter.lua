-- poetry-filter.lua v0.1.2

local metadata = {}
local in_poem = false
local indent_type = nil
local numbering = false
local line_count = 0

function parseFrontMatter(meta)
    metadata = meta
    indent_type = meta.PForm or ""
    numbering = meta.PNumbering == "Alternate"
end

function processDirectives(inlines)
    local result = {}
    for _, inline in ipairs(inlines) do
        if inline.t == "Str" then
            if inline.text == "@@indent:metre" or inline.text == "@@indent:meter" then
                indent_type = "metre"
            elseif inline.text == "@@numbering:on" then
                numbering = true
            elseif inline.text == "@@numbering:off" then
                numbering = false
            elseif inline.text == "@@poem" then
                in_poem = true
            else
                table.insert(result, inline)
            end
        else
            table.insert(result, inline)
        end
    end
    return result
end

function processAlignment(inlines)
    if #inlines > 0 and inlines[1].t == "Str" and inlines[1].text:match("^%->") then
        local align = "right"
        if inlines[1].text:match("^%-><") then
            align = "center"
            inlines[1].text = inlines[1].text:sub(4)
        else
            inlines[1].text = inlines[1].text:sub(3)
        end
        return pandoc.Div(inlines, pandoc.Attr("", {}, {{"style", "text-align: " .. align .. ";"}}))
    end
    return inlines
end

function processIndentation(inlines)
    if #inlines > 0 and inlines[1].t == "Str" then
        local indent, rest = inlines[1].text:match("^(:+)(.*)$")
        if indent then
            inlines[1].text = rest
            return {pandoc.RawInline("html", string.rep("&nbsp;", #indent * 4)), table.unpack(inlines)}
        end
    end
    return inlines
end

function applyFormatting(para)
    if not in_poem then return para end

    local lines = pandoc.utils.split_blocks(pandoc.utils.stringify(para))
    local formatted_lines = {}

    for i, line in ipairs(lines) do
        local inlines = pandoc.read(line).blocks[1].content
        inlines = processDirectives(inlines)
        inlines = processAlignment(inlines)
        inlines = processIndentation(inlines)

        if numbering and i % 2 == 1 then
            line_count = line_count + 1
            table.insert(inlines, 1, pandoc.Str(tostring(math.ceil(i / 2)) .. ". "))
        end

        if metadata.PIndent == "Alternate" and i % 2 == 0 then
            table.insert(inlines, 1, pandoc.RawInline("html", "&nbsp;&nbsp;&nbsp;&nbsp;"))
        end

        table.insert(formatted_lines, inlines)
    end

    return pandoc.Div(
        pandoc.utils.map(formatted_lines, function(line)
            return pandoc.Plain(line)
        end),
        pandoc.Attr("", {"poetry"})
    )
end

function Pandoc(doc)
    parseFrontMatter(doc.meta)
    local new_blocks = {}
    for _, block in ipairs(doc.blocks) do
        if block.t == "Para" then
            table.insert(new_blocks, applyFormatting(block))
        else
            table.insert(new_blocks, block)
        end
    end
    return pandoc.Pandoc(new_blocks, doc.meta)
end

return {
    { Pandoc = Pandoc }
}
