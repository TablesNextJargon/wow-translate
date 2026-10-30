-- Run from the repository root: lua tests/outgoing_chat.lua
dofile("Interface/AddOns/WoWTranslate/WoWTranslate_Chat.lua")

local cases = 0
local function check(text, links)
    local chunks, err = WoWTranslate_SplitChatMessage(text, links)
    assert(chunks, err)
    assert(table.concat(chunks) == text, "Text was lost or reordered")
    for _, chunk in ipairs(chunks) do
        assert(string.len(chunk) <= 255, "Chat byte limit exceeded")
        local first = string.byte(chunk, 1)
        assert(first < 128 or first >= 192, "Split inside a UTF-8 character")
    end
    cases = cases + 1
    return chunks
end

assert(table.getn(check("short message")) == 1)
assert(table.getn(check(string.rep("a", 255))) == 1)
assert(table.getn(check(string.rep("a", 256))) == 2)
assert(table.getn(check(string.rep("中", 85))) == 1)
assert(table.getn(check(string.rep("中", 86))) == 2)
check(string.rep("中", 200))
check(string.rep("😀", 100))
check(string.rep("Keep renew rolling. 保持恢复。 ", 20))
check(string.rep("a", 254) .. "中")
check(string.rep("a", 253) .. "😀")

local link = "|cff0070dd|Hitem:123:0:0:0|h[测试物品]|h|r"
local text = string.rep("中", 80) .. link .. string.rep("文", 100)
local chunks = check(text, {{startPos = 241, endPos = 240 + string.len(link)}})
local intact = false
for _, chunk in ipairs(chunks) do
    if string.find(chunk, link, 1, true) then intact = true end
end
assert(intact, "Clickable hyperlink was split")
check("prefix " .. link .. string.rep("中", 100),
    {{startPos = 8, endPos = 7 + string.len(link)}})
local oversized = string.rep("x", 256)
assert(not WoWTranslate_SplitChatMessage(oversized, {{startPos = 1, endPos = 256}}))

-- Exercise the actual outgoing hook with a mocked translation response and send API.
local file = assert(io.open("Interface/AddOns/WoWTranslate/WoWTranslate.lua", "r"))
local source = file:read("*a")
file:close()
local hookStart = assert(string.find(source, "local function HookedSendChatMessage", 1, true))
local hookEnd = assert(string.find(source, "-- Track if hook is installed", hookStart, true))
local linkStart = assert(string.find(source, "local function FindAllHyperlinks", 1, true))
local linkEnd = assert(string.find(source, "-- Split message into segments", linkStart, true))
local loadCode = loadstring or load
local hook = assert(loadCode(string.sub(source, linkStart, linkEnd - 1) ..
    string.sub(source, hookStart, hookEnd - 1) .. "\nreturn HookedSendChatMessage"))()

DebugLog = function() end
WoWTranslateDB = {outgoingEnabled = true, outgoingChannels = {WHISPER = true},
    outgoingFromLang = "en", outgoingToLang = "zh"}
ContainsOutgoingTargetLanguage = function() return false end
SplitIntoSegments = function(msg) return {{text = msg}} end
BuildTranslatableText = function(segments) return segments[1].text end
PreprocessOutgoing = function(msg) return msg end
ReconstructMessage = function(_, translation) return translation end
GetTime = function() return 0 end
outgoingCounter = 0
outgoingQueue = {}
local sent = {}
originalSendChatMessage = function(msg, chatType, language, channel)
    assert(chatType == "WHISPER" and language == nil and channel == "Mage")
    table.insert(sent, msg)
end
local translated = "给法师能量灌注，保持旗手身上的恢复。" ..
    string.rep("如果盗贼先手攻击你，使用心灵尖啸，骗掉脚踢后再读条快速治疗。", 3)
WoWTranslate_API = {
    IsAvailable = function() return true end,
    TranslateOutgoing = function(_, callback) callback(translated) end
}
local example = "Pop PI on the mage and keep renew rolling on the FC. If the rogue opens on you, psychic scream and try to juke the kick before hard casting flash heal."
hook(example, "WHISPER", nil, "Mage")
assert(table.getn(sent) > 1, "Long translation should send multiple messages")
assert(table.concat(sent) == translated, "Outgoing hook dropped translated text")
for _, msg in ipairs(sent) do assert(string.len(msg) <= 255) end

sent = {}
translated = "短消息"
hook(example, "WHISPER", nil, "Mage")
assert(table.getn(sent) == 1 and sent[1] == translated)
print("Passed " .. cases .. " splitter cases and outgoing hook integration checks")
