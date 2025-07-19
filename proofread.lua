-- usage: lua proofread.lua <file>…

function extract_gcc_internal_percent(str)
  local percents = ""
  local s = str
  while s ~= "" do
    local _, _, prefix = s:find("^(%%[#.lqz0-9]*[<>{}CDEFHILRSTXZderstuvx])")
    if prefix then
      percents = percents .. prefix
      s = s:sub(1 + #prefix)
    elseif s:find("^%%%%") then
      s = s:sub(3)
    elseif s:find("^%%") then
      error(("extract_gcc_internal_percent: '%s' in '%s'"):format(s, str), 0)
    else
      s = s:sub(2)
    end
  end
  return percents
end

function extract_c_format_percent(str)
  local percents = ""
  local s = str
  while s ~= "" do
    local _, _, prefix = s:find("^(%%[#.lz0-9]*[dfosux])")
    if prefix then
      percents = percents .. prefix
      s = s:sub(1 + #prefix)
    elseif s:find("^%%%%") then
      s = s:sub(3)
    elseif s:find("^%%") then
      error(("extract_c_format_percent: '%s' in '%s'"):format(s, str), 0)
    else
      s = s:sub(2)
    end
  end
  return percents
end

--- XXX: Ist strenggenommen redundant.
--- XXX: Wie kann diese Info automatisch aus po.lua importiert werden?
--- @shape PoMessage
--- @field id number
--- @field file string
--- @field comments string[]
--- @field msgid string
--- @field msgstr string
--- @field format table<string, boolean>
--- @field gcc_internal_format boolean
--- @field gfc_internal_format boolean
--- @field c_format boolean
--- @field no_c_format boolean

--- @param msg PoMessage
--- @param s string
--- @return string
local function gcc_internal_format_without_quoted_parts(msg, s)
  if msg.gcc_internal_format then
    return (s:gsub("%%<.-%%>", "X"))
  end
  return (s:gsub("».-«", "X"))
end

--- @param s string
--- @param from string
--- @param to string
local function replace_once(s, from, to)
  local replaced, n = s:gsub(from:gsub("[+%-]", "%%%1"), to)
  if n == 1 then
    return replaced
  end
  return s
end

--- @param msg PoMessage
local function check_option_unquoted(msg)
  if msg.msgid == ""
    or msg.msgstr:find("^ ")
    or msg.msgid:find("^%(Obsolete.*\t")
    or msg.msgid == "%s%sGGC heuristics: --param ggc-min-expand=%d --param ggc-min-heapsize=%d\n"
    or msg.msgid == "Abbreviation for \"-g -feliminate-unused-debug-symbols\"."
    or msg.msgid == "Abbreviation for \"-g -fno-eliminate-unused-debug-symbols\"." then
    return
  end
  local without_quotes = gcc_internal_format_without_quoted_parts(msg, msg.msgstr)
  --- @param option string
  for option in without_quotes:gmatch(" (%-[%-0-9A-Z_a-z]+=?[+%-0-9:A-Z_a-z]*)") do
    if not option:match("^%-[0-9]+$")
      and msg.msgid:find(option, 1, true)
      and option ~= "--"
      and option ~= "-INF" then
      warn(msg, ("Option »%s«"):format(option))
      if msg.gcc_internal_format then
        msg.msgstr = replace_once(msg.msgstr, option, "%%<" .. option .. "%%>")
      else
        msg.msgstr = replace_once(msg.msgstr, option, "»" .. option .. "«")
      end
    end
  end
end

--- @param msg PoMessage
local function check_quoted_portions(msg)
  local pattern = msg.gcc_internal_format and "%%<(.-)%%>" or "»(.-)«"
  msg.msgid:gsub(pattern, function(quoted)
    --print("msgid quoted", quoted)
    if not msg.msgstr:find(quoted, 1, true) then
      warn(msg, ("Das Original enthält %q, die Übersetzung jedoch nicht."):format(quoted), nil)
    end
    return nil
  end)
  msg.msgstr:gsub(pattern, function(quoted)
    --print("msgstr quoted", quoted)
    if not msg.msgid:find(quoted:gsub("…$", ""), 1, true) then
      warn(msg, ("Die Übersetzung enthält %q, das Original jedoch nicht."):format(quoted), nil)
    end
    return nil
  end)
end

function proofread(msg, msgid, msgstr)
  if msgstr == "" or msgstr == msgid or msg.fuzzy then
    return
  end
  check_option_unquoted(msg)
  check_quoted_portions(msg)
  if true then return end

  -- TODO: option -> Option/Schalter
  -- TODO: stattdessen -> verwenden Sie stattdessen ...
  -- TODO: Verwendung mit Schalter -> mit der
  if msgid:find("^[Uu]sage:") and not msgstr:find("^Aufruf:") then
    warn(msg, "»usage« sollte mit »Aufruf« übersetzt werden.", "^%a+")
  end
  if msgid:find("^%s") and not msgstr:find("^%s") then
    warn(msg, "Da im englischen Text Leerzeichen am Zeilenanfang sind, sollte das im deutschen Text auch so sein.")
  end
  if msgid:find("%s$") and not msgstr:find("%s$")
    and msgid ~= "Negation of unsigned expression at %L not permitted " then
    warn(msg, "Da im englischen Text Leerzeichen am Zeilenende sind, sollte das im deutschen Text auch so sein.")
  end
  if msgid:find("link") and not msgstr:find("[Bb][iu]nd") then
    warn(msg, "»link« sollte als »Bindung« übersetzt werden.")
  end
  if msgid:find("seek") and msgstr:find("[Ss]uch") and not msgstr:find("[Ss]pr[iu]ng") and not msgstr:find("[Ss]eek") then
    warn(msg,
      "»seek« sollte mit »springen/gesprungen« übersetzt werden. " ..
      "(Nicht mit »suchen«, da das zu viele andere Bedeutungen hat.)",
      "[Ss]uch%a*")
  end
  if msgstr:find("%%[<>]") and not msgid:find("%%[<>]") and not msg.gcc_internal_format then
    warn(msg, "»%<« in String ohne gcc-internal-format.")
  end
  if msgstr:find("\"") then
    warn(msg,
      "Im deutschen Text sollten keine \"geraden\", " ..
      "sondern „diese“ oder »jene« Anführungszeichen benutzt werden.",
      "\\\"")
    msg.msgstr = msgstr:gsub("\\\"([%a%%][^\"]*%a)\\\"", "»%1«")
  end
  if msgstr:find("%f[%l]the%f[%L]") and msgid ~= "" then
    warn(msg, "»the« gefunden – möglicherweise nicht vollständig übersetzt.")
  end
  if not msg.gcc_internal_format and not msg.c_format and not msg.no_c_format then
    local msgid_percent = extract_gcc_internal_percent(msgid)
    local msgstr_percent = extract_gcc_internal_percent(msgstr)
    if msgid_percent ~= msgstr_percent then
      warn(msg, ("Prozent in unformatiert '%s' '%s'"):format(msgid_percent, msgstr_percent))
    end
  end
  if msg.c_format then
    local msgid_fmt = msgid:find("%%[0-9]*[$]*[sdf]")
    local msgstr_fmt = msgstr:find("%%[0-9]*[$]*[sdf]")
    if not msgid_fmt ~= not msgstr_fmt then
      warn(msg, "Prozent mit Positionsangabe")
    end
  end
end

local haveColor = os.getenv("TERM") ~= nil

function color(n)
  return haveColor and string.char(0x1B) .. "[" .. n .. "m" or ""
end

function highlight(s, n)
  return color(n) .. s .. color(0)
end

function markred(s, redpattern)
  if not redpattern then return s end
  return s:gsub(redpattern, color(31) .. color(4) .. "%1" .. color(0))
end

--- @param msg PoMessage
--- @param redpattern string | nil
function warn(msg, warning, redpattern)
  local function fmtmsg(s)
    return "\"" .. s:gsub("\"", "\\\""):gsub("\\n(.)", "\\n\"\n\"%1") .. "\""
  end

  print(color(32) .. "file: " .. msg.file .. color(0))
  print(color(32) .. "id: " .. msg.id .. color(0))
  for _, comment in ipairs(msg.comments) do
    print(color(37) .. comment .. color(0))
  end
  print(color(32) .. "msgid: " .. fmtmsg(msg.msgid) .. color(0))
  for k, v in pairs(msg) do
    if k:find("^msgstr") then
      print(k .. ": " .. markred(fmtmsg(msg[k]), redpattern))
    end
  end
  print(color(33) .. "W: " .. warning .. color(0))
  print("")
end

function proofread_file(fname)
  local file = require("proofread/po").File:new()
  file:parse(fname)
  --- @param msg PoMessage
  for _, msg in ipairs(file.messages) do
    if msg.msgstr ~= nil then
      proofread(msg, msg.msgid, msg.msgstr)
    end
  end
  file:write(fname .. "c")
end

function main(arg)
  if os.getenv("USERPROFILE") and not os.getenv("HOME") then
    os.execute("chcp 65001 > nul")
  end
  for _, fname in ipairs(arg) do
    proofread_file(fname)
  end
end

main(arg)
