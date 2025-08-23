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

function extract_gcc_internal_quoted(str)
  local quoted = {}
  local s = str
  local qs = ""
  while s ~= "" do
    if s:sub(1, 2) == "%<" then
      s = s:sub(3)
      qs = s
    elseif s:sub(1, 2) == "%>" then
      table.insert(quoted, qs:sub(1, #qs - #s))
      s = s:sub(3)
    elseif s:sub(1, 1) == "%" then
      s = s:sub(3)
    else
      s = s:sub(2)
    end
  end
  return quoted
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
local function without_quoted_parts(msg, s)
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
  local without_quotes = without_quoted_parts(msg, msg.msgstr)
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
local function check_quoted_in_msgid(msg, quoted)
  if msg.msgstr:find(quoted, 1, true) then
    return
  end
  if msg.msgstr:find("%%<%-<Schlüssel>%[=<Wert>]%%>") and quoted == "-<key>[=<value>]" then
    return
  end
  if msg.msgstr:find("Name@Knotenname") and quoted == "name@nodename" then
    return
  end
  if msg.msgstr:find("delete%-Operator") and quoted == "operator delete" then
    return
  end
  warn(msg, ("Das Original enthält %q, die Übersetzung jedoch nicht."):format(quoted))
end

--- @param msg PoMessage
local function check_quoted_in_msgstr(msg, quoted)
  if msg.msgid == "function not considered for inlining"
    and msg.msgstr == "Funktion kommt nicht für »inline« in Betracht" then
    return
  end
  if msg.msgid == "function not inlinable"
    and msg.msgstr == "Funktion kann nicht »inline« sein" then
    return
  end
  if msg.msgid == "originally indirect function call not considered for inlining"
    and msg.msgstr == "ursprünglich indirekter Funktionsaufruf kommt nicht als »inline« in Betracht" then
    return
  end
  if msg.msgid == "this target is little-endian"
    and msg.msgstr == "Diese Zielarchitektur ist »Little Endian«" then
    return
  end
  if msg.msgid == "-J<directory>\tPut MODULE files in 'directory'."
    and msg.msgstr == "-J<Verzeichnis>\tMODULE-Dateien in »Verzeichnis« ablegen." then
    return
  end
  if msg.msgid:find("missing ampersand") and quoted == "&" then
    return
  end
  if msg.msgid:find("\"suspicious\"") and quoted == "verdächtigen" then
    return
  end
  if msg.msgid:find("\"suspicious\"") and quoted == "verdächtigen" then
    return
  end
  if msg.msgid:find("dangling else") and quoted == "hängendem else" then
    return
  end
  if msg.msgstr:find("<Bytes>") and quoted == "Bytes" then
    return
  end
  if msg.msgid:find("--param destructive-interference-size or constructive-interference-size", 1, true)
    and quoted == "--param constructive-interference-size" then
    return
  end
  if msg.msgid:find("default") and quoted == "default:" then
    return
  end
  if msg.msgid:find("Wtrailing-whitespace=blanks", 1, true) and quoted == "-Wtrailing-whitespace=blanks" then
    return
  end
  if msg.msgid:find("Wtrailing-whitespace=none", 1, true) and quoted == "-Wtrailing-whitespace=none" then
    return
  end
  if msg.msgstr:find("<Verzeichnis>") and quoted == "Verzeichnis" then
    return
  end
  if msg.msgid:find("the quote include path") and quoted == "#include \"…\"" then
    return
  end
  if msg.msgid:find("'after supernode'") and quoted == "nach dem Superknoten" then
    return
  end
  if msg.msgstr:find("Installationsname:Dateiname") and quoted == "Installationsname" then
    return
  end
  if msg.msgstr:find("Installationsname:Dateiname") and quoted == "Dateiname" then
    return
  end
  if msg.msgid:find("<path>") and quoted == "-seg_addr_table_filename <Pfad>" then
    return
  end
  if msg.msgid:find("\"no access\"") and quoted == "kein Zugriff" then
    return
  end
  if msg.msgid:find("'soft'") and quoted == "weich" then
    return
  end
  if msg.msgid:find(quoted:gsub("…$", ""), 1, true) then
    return
  end
  if msg.msgid:find("Using 0 for both values") and quoted == "0,0" then
    return
  end
  if msg.msgid:find("big[ %-]endian") and quoted == "Big Endian" then
    return
  end
  if msg.msgid:find("little[ %-]endian") and quoted == "Little Endian" then
    return
  end
  if msg.msgid:find("minterlink%-compressed") and quoted == "-minterlink-compressed" then
    return
  end
  if msg.msgid:find("whole program analysis") and quoted == "komplettes Programm" then
    return
  end
  if msg.msgid:find("Wstack%-usage=") and quoted == "-Wstack-usage=" then
    return
  end
  if msg.msgid:find("Wstack%-usage=") and quoted == "-Wstack-usage=<SIZE_MAX>" then
    return
  end
  if msg.msgid:find("switch's controlling expression") and quoted == "switch (…)" then
    return
  end
  if msg.msgid:find("and the first case") and quoted == "case:" then
    return
  end
  if msg.msgid:find("Inline") and quoted == "inline" then
    return
  end
  if msg.msgid:find("Trap if") and quoted == "trap" then
    return
  end
  if msg.msgid:find("Trap for") and quoted == "trap" then
    return
  end
  if msg.msgid:find("SSA%->normal") and quoted == "SSA -> Normal" then
    return
  end
  if msg.msgid:find("inlining") and quoted == "inline" then
    return
  end
  if msg.msgid:find("%-W<letter>") and quoted == "-W<Buchstabe>" then
    return
  end
  if msg.msgid:find("Merge subcommand usage:") and quoted == "merge" then
    return
  end
  if msg.msgid:find("Merge%-stream subcommand usage:") and quoted == "merge-stream" then
    return
  end
  if msg.msgid:find("Rewrite subcommand usage:") and quoted == "rewrite" then
    return
  end
  if msg.msgid:find("Overlap subcommand usage:") and quoted == "overlap" then
    return
  end
  if msg.msgid:find("declare target %%<link%%>") and quoted == "declare target link" then
    return
  end
  if msg.msgid:find("%%<%-gdwarf%%> %%<%-g%%s%%>") and quoted == "-gdwarf -g%s" then
    return
  end
  if msg.msgid:find("%%<%-<key>%[=<value>]%%>") and quoted == "-<Schlüssel>[=<Wert>]" then
    return
  end
  if msg.msgid:find("name@nodename") and quoted == "Name@Knotenname" then
    return
  end
  if msg.msgid:find("a quoted sequence") and quoted == "<…" then
    return
  end
  if msg.msgid:find("%%<%-mfloat%-abi=softfp%%> %%<%-mfpu=neon%%>")
    and quoted == "-mfloat-abi=softfp -mfpu=neon" then
    return
  end
  if msg.msgid:find("%%<%-mfloat%-abi=softfp%%> %%<%-mfpu=crypto%-neon%%>")
    and quoted == "-mfloat-abi=softfp -mfpu=crypto-neon" then
    return
  end
  if msg.msgid:find("%<-mpcrel%> %<-fPIC%>", 1, true)
    and quoted == "-mpcrel -fPIC" then
    return
  end
  if msg.msgid == "did you mean to use logical not?" and quoted == "!" then
    return
  end
  if msg.msgid:find("with type array of %qT", 1, true) and quoted == "Array von %T" then
    return
  end
  if msg.msgid == "typedef may not be a function definition" and quoted == "{ … }" then
    return
  end
  if msg.msgid == "typedef may not be a member function definition" and quoted == "{ … }" then
    return
  end
  if msg.msgid:find("include %%qs") and quoted == "include %s" then
    return
  end
  if msg.msgid:find("global module fragment contents") and quoted == "global-module-fragment" then
    return
  end
  if msg.msgid:find("pack indexing") and quoted == "pack-index" then
    return
  end
  if msg.msgid:find("private module fragment") and quoted == "private-module-fragment" then
    return
  end
  if msg.msgid:find("Use std=f202y") and quoted == "-std=f202y" then
    return
  end
  if msg.msgid == "Warn when deleting a pointer to incomplete type." and quoted == "delete" then
    return
  end
  warn(msg, ("Die Übersetzung enthält %q, das Original jedoch nicht."):format(quoted))
end

--- @param msg PoMessage
local function check_quoted_portions(msg)
  if msg.gcc_internal_format then
    if msg.msgid == "%<#pragma GCC target (string [,string]...)%> does not have a final %<)%>"
      and msg.msgstr == "%<#pragma GCC target (Zeichenkette [,Zeichenkette]...)%> hat kein abschließendes %<)%>" then
      return
    end
    if msg.msgid == "%<#pragma GCC optimize (string [,string]...)%> does not have a final %<)%>"
      and msg.msgstr == "%<#pragma GCC optimize (Zeichenkette [,Zeichenkette]...)%> hat kein abschließendes %<)%>" then
      return
    end
    local qid = extract_gcc_internal_quoted(msg.msgid)
    local qstr = extract_gcc_internal_quoted(msg.msgstr)
    --print('msgid',msg.msgid)
    --print('msgstr',msg.msgstr)
    local function remove_corresponding(id, str)
      local qi, qs
      for i, q in ipairs(qid) do
        --print('qid-entry', q)
        if q == id then
          qi = i
        end
      end
      for i, q in ipairs(qstr) do
        --print('qstr-entry', q)
        if q == str then
          qs = i
        end
      end
      -- print('id', id, 'str', str, 'qi', qi, 'qs', qs)
      if qi and qs then
        table.remove(qid, qi)
        table.remove(qstr, qs)
      end
    end
    remove_corresponding("and", "und")
    remove_corresponding("or", "oder")
    remove_corresponding("%wu^%wu", "%wu ^ %wu")
    remove_corresponding("vector=<line>", "vector=<Zeile>")
    remove_corresponding("__builtin_rx_mvtc (0, ... )", "__builtin_rx_mvtc (0, ...)")
    remove_corresponding("%E (expression)", "%E (Ausdruck)")
    remove_corresponding("concept <name> = <expr>", "concept <Name> = <Ausdruck>")
    remove_corresponding("lower-bound :", "untere-Grenze :")
    remove_corresponding("lower-bound : upper-bound", "untere-Grenze : obere-Grenze")
    remove_corresponding("[super ...]", "[super …]")

    -- XXX
    remove_corresponding("#pragma", "#pragma GHS endXXX")
    remove_corresponding("#pragma", "#pragma ghs section")
    remove_corresponding("#pragma", "#pragma ghs interrupt")
    remove_corresponding("#pragma", "#pragma ghs starttda")
    remove_corresponding("#pragma", "#pragma ghs startsda")
    remove_corresponding("#pragma", "#pragma ghs startzda")
    remove_corresponding("#pragma", "#pragma ghs endtda")
    remove_corresponding("#pragma", "#pragma ghs endsda")
    remove_corresponding("#pragma", "#pragma ghs endzda")
    remove_corresponding("pragma omp atomic compare", "#pragma omp atomic compare")
    remove_corresponding("pragma omp error", "#pragma omp error")
    remove_corresponding("pragma omp tile", "#pragma omp tile")
    remove_corresponding("pragma omp requires", "#pragma omp requires")
    remove_corresponding("pragma omp declare reduction", "#pragma omp declare reduction")
    remove_corresponding("pop_everything ()", "pop_everything")
    remove_corresponding("throw()", "throw")

    for _, quoted in ipairs(qid) do
      check_quoted_in_msgid(msg, quoted)
    end
    for _, quoted in ipairs(qstr) do
      check_quoted_in_msgstr(msg, quoted)
    end
  else
    local pattern = "»(.-)«"
    msg.msgid:gsub(pattern, function(quoted)
      check_quoted_in_msgid(msg, quoted)
      return nil
    end)
    msg.msgstr:gsub(pattern, function(quoted)
      check_quoted_in_msgstr(msg, quoted)
      return nil
    end)
  end
end

--- @param msgid string
--- @param msgstr string
function proofread(msg, msgid, msgstr)
  if msgstr == "" or msgstr == msgid or msg.fuzzy then
    return
  end
  if msgstr:find("^Interner Fehler: ") and msgstr:gsub("^%S+ %S+: ", "") == msgid then
    return
  end
  if msgstr:find("^Interner Compilerfehler: ") and msgstr:gsub("^%S+ %S+: ", "") == msgid then
    return
  end
  check_option_unquoted(msg)
  check_quoted_portions(msg)

  local msgid_orig = msgid
  local msgstr_orig = msgstr
  msgid = without_quoted_parts(msg, msgid)
  msgstr = without_quoted_parts(msg, msgstr)

  -- TODO: option -> Option/Schalter
  -- TODO: stattdessen -> verwenden Sie stattdessen ...
  if (msgstr:find("mit Schalter") or msgstr:find("mit dem Schalter"))
    and msgid:find("option")
    and msgid ~= "switch X conflicts with X switch and resulted in options %qs being added" then
    warn(msg, "»Schalter« sollte als »Option« übersetzt werden.")
  end
  if msgid:find("entit[yi]") and not msgstr:find("[Ee]ntität") and not msgstr:find("entity%-list") then
    warn(msg, "»entity« sollte als »Entität« übersetzt werden.")
  end
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
  if msgid:find("link") and not msgstr:find("[Bb][iu]nd")
    and msgid ~= "-fuse-linker-plugin is not supported in this configuration"
    and not msgid:find("Produce a Mach%-O dylinker")
    and not msgid:find("%-dylinker_install_name")
    and not msgid:find("%-multiply_defined_unused")
    and not msgid:find("minterlink%-compressed")
    and msgid ~= "argument of %qE attribute is not \"ilink1\" or \"ilink2\""
    and msgid ~= "argument of %qE attribute is not \"ilink\" or \"firq\"" then
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
  if msgstr:find("\"")
    and msgid ~= "Warn about deprecated space between \"\" and suffix in a user-defined literal operator."
    and msgid ~= "Implement DIP1000: Scoped pointers."
    and msgid ~= "Implement DIP1008: Allow exceptions in @nogc code."
    and msgid ~= "Implement DIP1021: Mutable function arguments."
    and msgid ~= "Revert DIP1000: Scoped pointers."
    and msgid ~= "%qE attribute applied to extern \"C\" declaration %qD"
  then
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
    local msgid_percent = extract_gcc_internal_percent(msgid_orig)
    local msgstr_percent = extract_gcc_internal_percent(msgstr_orig)
    if msgid_percent ~= msgstr_percent then
      print(msgid_percent, msgstr_percent)
      warn(msg, ("Prozent in unformatiert '%s' '%s'"):format(msgid_percent, msgstr_percent))
    end
  end
  if msg.c_format then
    local msgid_fmt = msgid:find("%%[0-9]*[$]+[sdf]")
    local msgstr_fmt = msgstr:find("%%[0-9]*[$]+[sdf]")
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
  if not redpattern then
    return s
  end
  return s:gsub(redpattern, color(31) .. color(4) .. "%1" .. color(0))
end

--- @param msg PoMessage
--- @param redpattern? string
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
