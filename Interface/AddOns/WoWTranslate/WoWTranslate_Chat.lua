-- Split outgoing UTF-8 text without discarding bytes or breaking hyperlinks.
-- links uses the positions returned by FindAllHyperlinks in WoWTranslate.lua.
function WoWTranslate_SplitChatMessage(text, links)
    local chunks = {}
    local length = string.len(text)
    local start = 1
    local linkIndex = 1
    links = links or {}

    while start <= length do
        local pos = start
        local boundary = nil
        while pos <= length do
            local unitEnd
            local link = links[linkIndex]
            if link and link.startPos == pos then
                unitEnd = link.endPos
                if unitEnd - pos + 1 > 255 then
                    return nil, "A hyperlink exceeds the chat message limit"
                end
            else
                unitEnd = pos
                -- Continuation bytes belong to the preceding UTF-8 character.
                while unitEnd < length do
                    local byte = string.byte(text, unitEnd + 1)
                    if byte < 128 or byte >= 192 then break end
                    unitEnd = unitEnd + 1
                end
            end
            if unitEnd - start + 1 > 255 then break end
            local unit = string.sub(text, pos, unitEnd)
            if string.find(unit, "%s") or unit == "." or unit == "!" or unit == "?"
                or unit == "。" or unit == "！" or unit == "？" then
                boundary = unitEnd
            end
            pos = unitEnd + 1
            if link and unitEnd == link.endPos then linkIndex = linkIndex + 1 end
        end
        local finish = pos - 1
        if pos <= length and boundary then finish = boundary end
        table.insert(chunks, string.sub(text, start, finish))
        start = finish + 1
        -- A preferred boundary may put an already-scanned link in the next chunk.
        linkIndex = 1
        while links[linkIndex] and links[linkIndex].endPos < start do
            linkIndex = linkIndex + 1
        end
    end
    return chunks
end
