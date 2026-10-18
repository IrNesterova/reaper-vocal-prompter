-- Автотесты Vocal Prompter. Запуск из корня репозитория:
--   lua tests/run_tests.lua            (Lua 5.4, как в REAPER)
-- Выход с кодом 1, если хоть один тест упал.

local dir = (arg and arg[0] or "tests/run_tests.lua"):match("^(.*)[/\\]") or "."
package.path = dir .. "/?.lua;" .. package.path
local M = require "mocks"

local SCRIPT = dir .. "/../Vocal_Prompter.lua"
local API    = dir .. "/reaimgui_api_0.9.txt"

---------------------------------------------------------------------------
-- Мини-фреймворк
---------------------------------------------------------------------------
local passed, failed, failures = 0, 0, {}
local current_group = ""

local function group(name) current_group = name; print("\n" .. name) end

local function test(name, fn)
  local ok, e = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
    print("  ok   " .. name)
  else
    failed = failed + 1
    failures[#failures + 1] = current_group .. " › " .. name .. "\n" .. tostring(e)
    print("  FAIL " .. name)
  end
end

local function fmt(v)
  if type(v) == "string" then return string.format("%q", v) end
  return tostring(v)
end
local function eq(a, b, msg)
  if a ~= b then error((msg and (msg .. ": ") or "") .. "expected " .. fmt(b) .. ", got " .. fmt(a), 2) end
end
local function near(a, b, eps, msg)
  if type(a) ~= "number" or math.abs(a - b) > (eps or 1e-6) then
    error((msg and (msg .. ": ") or "") .. "expected ≈" .. tostring(b) .. ", got " .. tostring(a), 2)
  end
end
local function truthy(v, msg) if not v then error(msg or "expected truthy value", 2) end end
local function falsy(v, msg) if v then error(msg or ("expected falsy, got " .. fmt(v)), 2) end end
local function raises(fn, pattern)
  local ok, e = pcall(fn)
  if ok then error("expected an error", 2) end
  if pattern and not tostring(e):find(pattern, 1, true) then
    error("error " .. fmt(tostring(e)) .. " does not contain " .. fmt(pattern), 2)
  end
end

local function fresh(opts) return M.load_script(SCRIPT, API, opts) end

---------------------------------------------------------------------------
group("Разбор текста (parse_lyrics / to_lrc)")
---------------------------------------------------------------------------
local vp = fresh()

test("обычный текст, пустые строки пропускаются", function()
  local lines = vp.parse_lyrics("Первая строка\n\n  Вторая  \n\n")
  eq(#lines, 2); eq(lines[1].text, "Первая строка"); eq(lines[2].text, "Вторая"); falsy(lines[1].t)
end)

test("LRC с таймингами, сортировка по времени", function()
  local lines = vp.parse_lyrics("[00:12.50]Hello\n[00:05.00]World")
  eq(#lines, 2); eq(lines[1].text, "World"); near(lines[1].t, 5); near(lines[2].t, 12.5)
end)

test("несколько тегов времени на одной строке (повтор припева)", function()
  local lines = vp.parse_lyrics("[00:10.00][01:30.00]Chorus")
  eq(#lines, 2); near(lines[1].t, 10); near(lines[2].t, 90); eq(lines[2].text, "Chorus")
end)

test("минуты больше 59 и время без дробной части", function()
  local lines = vp.parse_lyrics("[75:01]Long")
  near(lines[1].t, 75 * 60 + 1)
end)

test("пустая строка с таймингом = проигрыш", function()
  local lines = vp.parse_lyrics("[00:01.00]A\n[00:05.00]\n[00:09.00]B")
  eq(#lines, 3); eq(lines[2].text, ""); near(lines[2].t, 5)
end)

test("теги [ar:] [ti:] → метаданные, остальные теги игнорируются", function()
  local lines, meta = vp.parse_lyrics("[ar: Nina Simone ]\n[ti:Feeling Good]\n[length:2:56]\n[by:x]\n[00:01.00]Birds")
  eq(#lines, 1); eq(meta.ar, "Nina Simone"); eq(meta.ti, "Feeling Good")
end)

test("BOM и CRLF", function()
  local lines = vp.parse_lyrics("\239\187\191[00:01.00]One\r\n[00:02.00]Two\r\n")
  eq(#lines, 2); eq(lines[1].text, "One"); eq(lines[2].text, "Two")
end)

test("квадратные скобки внутри строки не ломают разбор", function()
  local lines = vp.parse_lyrics("[00:01.00][Chorus] la la")
  eq(#lines, 1); eq(lines[1].text, "[Chorus] la la")
end)

test("to_lrc → parse_lyrics даёт то же самое", function()
  local src = vp.parse_lyrics("[00:01.25]Раз\n[01:02.50]Два\n[02:00.00]")
  local back = vp.parse_lyrics(vp.to_lrc(src))
  eq(#back, #src)
  for i = 1, #src do eq(back[i].text, src[i].text); near(back[i].t, src[i].t, 0.01) end
end)

test("to_lrc: строки без тайминга остаются как есть", function()
  eq(vp.to_lrc({ { text = "a" }, { text = "b", t = 61.5 } }), "a\n[01:01.50]b")
end)

---------------------------------------------------------------------------
group("Названия, ключи, строки")
---------------------------------------------------------------------------
test("song_name", function()
  eq(vp.song_name("Nina Simone", "Feeling Good"), "Nina Simone — Feeling Good")
  eq(vp.song_name(nil, "Только название"), "Только название")
  eq(vp.song_name(" Артист ", ""), "Артист")
  eq(vp.song_name(nil, nil), "")
end)

test("ulower понимает кириллицу, включая Ё", function()
  eq(vp.ulower("ПРИВЕТ Мир ЁЖ ABC"), "привет мир ёж abc")
end)

test("song_key склеивает версии одной песни", function()
  local k = vp.song_key("Feeling Good")
  eq(vp.song_key("Feeling Good (Remastered 2013)"), k)
  eq(vp.song_key("Feeling Good - Live at Montreux"), k)
  eq(vp.song_key("FEELING GOOD [Mono]"), k)
  eq(vp.song_key("Сон (Live)"), vp.song_key("сон"))
  truthy(vp.song_key("Sinnerman") ~= k)
end)

test("urlencode: пробелы, кириллица, спецсимволы", function()
  eq(vp.urlencode("a b&c"), "a%20b%26c")
  eq(vp.urlencode("Сон"), "%D0%A1%D0%BE%D0%BD")
  eq(vp.urlencode("safe-_.~"), "safe-_.~")
end)

test("fmt_time", function()
  eq(vp.fmt_time(0), "0:00.00"); eq(vp.fmt_time(83.456), "1:23.46"); eq(vp.fmt_time(-2.5), "-0:02.50")
end)

---------------------------------------------------------------------------
group("JSON")
---------------------------------------------------------------------------
test("объекты, массивы, числа, true/false/null", function()
  local d = vp.json_decode('{"a":[1,-2.5,3e2],"b":true,"c":false,"d":null,"e":{"f":"g"}}')
  eq(d.a[1], 1); near(d.a[2], -2.5); near(d.a[3], 300); eq(d.b, true); eq(d.c, false); eq(d.d, nil); eq(d.e.f, "g")
end)

test("экранирование и \\u, включая суррогатные пары", function()
  local d = vp.json_decode('["line\\nnext \\"q\\" \\\\ \\/", "\\u0421\\u043e\\u043d", "\\ud83c\\udfa4"]')
  eq(d[1], 'line\nnext "q" \\ /'); eq(d[2], "Сон"); eq(d[3], "🎤")
end)

test("пустые объект и массив, пробелы и переводы строк", function()
  local d = vp.json_decode(' [ {} , [ ] ,\n\t{ "x" : 1 } ] ')
  eq(#d, 3); eq(next(d[1]), nil); eq(#d[2], 0); eq(d[3].x, 1)
end)

test("ответ в формате LRCLIB", function()
  local d = vp.json_decode('[{"id":1,"trackName":"Feeling Good","artistName":"Nina Simone","albumName":"I Put a Spell on You","duration":176.0,"instrumental":false,"plainLyrics":"Birds flying high","syncedLyrics":"[00:01.00] Birds flying high"}]')
  eq(d[1].trackName, "Feeling Good"); near(d[1].duration, 176); truthy(d[1].syncedLyrics:find("Birds"))
end)

test("битый JSON → ошибка", function()
  raises(function() vp.json_decode('{"a": "unterminated') end)
  raises(function() vp.json_decode('<html>') end)
end)

---------------------------------------------------------------------------
group("Локализация")
---------------------------------------------------------------------------
test("у каждой строки есть оба перевода", function()
  for k in pairs(vp.STR.ru) do truthy(vp.STR.en[k], "нет en для " .. k) end
  for k in pairs(vp.STR.en) do truthy(vp.STR.ru[k], "нет ru для " .. k) end
end)

test("подстановки (%d, %s, %.1f…) совпадают в ru и en", function()
  local function specs(s) local t = {}; for p in s:gmatch("%%[%d%.]*[dsf]") do t[#t + 1] = p:sub(-1) end; return table.concat(t) end
  for k, ru in pairs(vp.STR.ru) do eq(specs(vp.STR.en[k]), specs(ru), "строка " .. k) end
end)

test("переключение языка запоминается", function()
  local v2, R = fresh()
  eq(v2.get_lang(), "ru")
  v2.set_lang("en"); eq(v2.T("tab_text"), "Lyrics"); eq(R.gext["VocalPrompter/lang"], "en")
  local v3 = fresh({ ext = { ["VocalPrompter/lang"] = "en" } })
  eq(v3.get_lang(), "en")
end)

---------------------------------------------------------------------------
group("Тайминги и текущая строка")
---------------------------------------------------------------------------
test("find_current с учётом порядка и вступления", function()
  local v2 = fresh()
  v2.set_lines(v2.parse_lyrics("[00:05.00]B\n[00:01.00]A\n[00:09.00]C"))
  local order = v2.timed_order()
  eq(v2.find_current(order, 0.5), nil, "вступление")
  eq(v2.S().lines[order[v2.find_current(order, 1)]].text, "A")
  eq(v2.S().lines[order[v2.find_current(order, 6)]].text, "B")
  eq(v2.S().lines[order[v2.find_current(order, 100)]].text, "C")
end)

test("тап проставляет время по очереди, не меньше нуля", function()
  local v2 = fresh()
  v2.set_lines(v2.parse_lyrics("A\nB\nC"))
  v2.do_tap(-0.3); v2.do_tap(4.2)
  eq(v2.S().lines[1].t, 0); near(v2.S().lines[2].t, 4.2); falsy(v2.S().lines[3].t); eq(v2.tap_idx(), 3)
  v2.do_tap(8); v2.do_tap(9)   -- лишний тап ничего не ломает
  near(v2.S().lines[3].t, 8)
end)

test("wrap_lines укладывает слова в ширину", function()
  local lines = vp.wrap_lines("one two three four five", 8 * 9)   -- мок: 8 px на символ
  for _, l in ipairs(lines) do truthy(utf8.len(l) <= 9 or not l:find(" "), "слишком длинная: " .. l) end
  eq(table.concat(lines, " "), "one two three four five")
  eq(vp.wrap_lines("", 100)[1], " ")
end)

---------------------------------------------------------------------------
group("Хранение в проекте")
---------------------------------------------------------------------------
test("сохранение и загрузка: текст, тайминги, название, сдвиг", function()
  local v2, R = fresh()
  v2.set_lines(v2.parse_lyrics("[00:01.50]Раз\tс табом\n[00:03.00]"), "Артист — Песня")
  v2.S().offset = 2.25; v2.S().lead = 0.5
  v2.save_state("P1")
  truthy(R.dirty_marks > 0, "проект помечен изменённым")
  v2.load_state("P1")
  local S = v2.S()
  eq(#S.lines, 2); eq(S.lines[1].text, "Раз\tс табом"); near(S.lines[1].t, 1.5); eq(S.lines[2].text, "")
  eq(S.name, "Артист — Песня"); near(S.offset, 2.25); near(S.lead, 0.5)
  local a, t = v2.queries(); eq(a, "Артист"); eq(t, "Песня")
end)

test("сохранение удаляет хвост старых строк", function()
  local v2, R = fresh()
  v2.set_lines(v2.parse_lyrics("1\n2\n3\n4")); v2.save_state("P1")
  v2.set_lines(v2.parse_lyrics("only")); v2.save_state("P1")
  eq(R.ext.P1.L2, nil); eq(R.ext.P1.n, "1")
end)

test("пустой проект загружается без ошибок", function()
  local v2 = fresh()
  v2.load_state("P1")
  eq(#v2.S().lines, 0); eq(v2.S().name, ""); near(v2.S().lead, 0.3)
end)

---------------------------------------------------------------------------
group("Переключение проектов (через главный цикл)")
---------------------------------------------------------------------------
local function with_lyrics(R, ptr, file, text, name)
  R.valid[ptr] = true
  R.ext[ptr] = { n = "1", L1 = "1.000\t" .. text, name = name }
end

test("другая вкладка проекта → её текст", function()
  local v2, R, G = fresh()
  M.frame(v2, G)
  with_lyrics(R, "P2", "C:\\b.rpp", "Hello", "Muse — Uprising")
  R.proj = { ptr = "P2", file = "C:\\b.rpp" }
  M.frame(v2, G)
  eq(v2.S().name, "Muse — Uprising"); eq(v2.S().lines[1].text, "Hello")
end)

test("та же вкладка, открыт другой файл → его текст, старый не затирает новый", function()
  local v2, R, G = fresh({ proj_ext = { n = "1", L1 = "1.000\tOld", name = "Old song" } })
  M.frame(v2, G)
  eq(v2.S().name, "Old song")
  -- File → Open в той же вкладке: указатель тот же, файл и данные другие
  R.ext.P1 = { n = "1", L1 = "2.000\tNew", name = "New song" }
  R.proj.file = "C:\\songs\\new.rpp"
  M.frame(v2, G)
  eq(v2.S().name, "New song"); eq(v2.S().lines[1].text, "New")
  eq(R.ext.P1.name, "New song", "данные нового проекта не перезаписаны старыми")
end)

test("закрытая вкладка: в недействительный проект ничего не пишется", function()
  local v2, R, G = fresh()
  M.frame(v2, G)
  v2.set_lines(v2.parse_lyrics("x"))      -- есть несохранённые изменения
  R.valid.P1 = false                       -- вкладку закрыли
  R.valid.P2 = true; R.proj = { ptr = "P2", file = "" }
  M.frame(v2, G)                           -- мок упадёт, если писать в P1
  eq(#v2.S().lines, 0)
end)

test("изменения сохраняются в проект сами", function()
  local v2, R, G = fresh()
  M.frame(v2, G)
  v2.set_lines(v2.parse_lyrics("Line"), "Song")
  M.frame(v2, G)
  eq(R.ext.P1.name, "Song"); eq(R.ext.P1.L1, "\tLine"); falsy(v2.dirty())
end)

---------------------------------------------------------------------------
group("Маркеры")
---------------------------------------------------------------------------
test("«В маркеры»: заменяет только свои маркеры, учитывает сдвиг", function()
  local v2, R = fresh()
  R.markers = { { pos = 1, name = "Verse", idx = 1 }, { pos = 2, name = "♪ старый", idx = 2 } }
  v2.set_lines(v2.parse_lyrics("[00:01.00]A\n[00:02.00]\n[00:03.00]B"))
  v2.S().offset = 10
  v2.export_markers()
  local names = {}
  for _, m in ipairs(R.markers) do names[#names + 1] = m.name .. "@" .. m.pos end
  eq(table.concat(names, ","), "Verse@1,♪ A@11.0,♪ B@13.0")
end)

---------------------------------------------------------------------------
group("Фоновый поиск (curl)")
---------------------------------------------------------------------------
local function utf16le_decode(s)
  assert(s:sub(1, 2) == "\255\254", "нет BOM UTF-16LE")
  local out, i = {}, 3
  while i <= #s do
    local cp = s:byte(i) | (s:byte(i + 1) << 8); i = i + 2
    if cp >= 0xD800 and cp <= 0xDBFF then
      local lo = s:byte(i) | (s:byte(i + 1) << 8); i = i + 2
      cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00)
    end
    out[#out + 1] = utf8.char(cp)
  end
  return table.concat(out)
end

test("Windows: .bat с удвоенными %, скрытый запуск через wscript, путь с кириллицей", function()
  local v2, R, G, fs = fresh({ os = "Win64" })
  falsy(v2.start_job("lrc_track", "https://lrclib.net/api/search?track_name=%D0%A1&artist_name=x"))
  local dir = R.resource .. "\\Data\\VocalPrompter\\"
  local bat = fs.files[dir .. "lrc_track.bat"]
  truthy(bat, "нет .bat")
  truthy(bat:find("track_name=%%D0%%A1&artist_name=x", 1, true), "% не удвоены")
  truthy(bat:find("--ssl-no-revoke", 1, true))
  truthy(bat:find('-o "lrc_track.part"', 1, true), "в .bat должны быть короткие имена")
  falsy(bat:find("Тест", 1, true), "в .bat не должно быть кириллического пути")
  local vbs = utf16le_decode(fs.files[dir .. "lrc_track.vbs"])
  truthy(vbs:find('sh.CurrentDirectory = "' .. R.resource .. '\\Data\\VocalPrompter"', 1, true))
  truthy(vbs:find('sh.Run "cmd.exe /C lrc_track.bat", 0, False', 1, true), "окно должно быть скрыто (0)")
  local ex = R.exec[#R.exec]
  truthy(ex.cmd:find("^wscript%.exe //B //Nologo"), ex.cmd); eq(ex.timeout, -1, "запуск без ожидания")
end)

test("macOS: .sh через /bin/sh, без ожидания", function()
  local v2, R, G, fs = fresh({ os = "OSX64", resource = "/Users/ira/Library/Application Support/REAPER" })
  falsy(v2.start_job("itunes", "https://itunes.apple.com/search?term=x"))
  local sh = fs.files[R.resource .. "/Data/VocalPrompter/itunes.sh"]
  truthy(sh and sh:find("curl -s -L", 1, true))
  truthy(R.exec[1].cmd:find('^/bin/sh "'), R.exec[1].cmd); eq(R.exec[1].timeout, -1)
end)

test("poll_job: готовый ответ, ошибка curl с подсказкой, таймаут", function()
  local v2, R, G, fs = fresh({ os = "Win64" })
  local dir = R.resource .. "\\Data\\VocalPrompter\\"
  v2.start_job("a", "u")
  eq(v2.poll_job("a"), nil, "пока идёт — nil")
  fs.files[dir .. "a.json"] = '[{"x":1}]'
  local st, data = v2.poll_job("a"); eq(st, "done"); eq(data[1].x, 1)

  v2.start_job("b", "u"); fs.files[dir .. "b.err"] = "28 \r\n"
  local st2, e = v2.poll_job("b"); eq(st2, "error"); eq(e[1], "err_net"); eq(e[2], "28"); truthy(e.hint)

  v2.start_job("c", "u"); R.clock = R.clock + 31
  local st3, e3 = v2.poll_job("c"); eq(st3, "error"); eq(e3[1], "err_timeout")

  v2.start_job("d", "u"); fs.files[dir .. "d.json"] = "<html>blocked</html>"
  local st4, e4 = v2.poll_job("d"); eq(st4, "error"); eq(e4[1], "err_parse")
end)

---------------------------------------------------------------------------
group("Поиск по исполнителю")
---------------------------------------------------------------------------
local LRC_ARTIST = [[[
 {"artistName":"Nina Simone","trackName":"Feeling Good","albumName":"I Put a Spell on You","duration":176,"plainLyrics":"x"},
 {"artistName":"Nina Simone","trackName":"Feeling Good (Remastered)","duration":177,"plainLyrics":"x","syncedLyrics":"[00:01.00]Birds"},
 {"artistName":"Muse","trackName":"Feeling Good","plainLyrics":"y"},
 {"artistName":"Nina Simone","trackName":"Instrumental","plainLyrics":null,"syncedLyrics":null}
]
]]
local ITUNES = [[{"resultCount":3,"results":[
 {"artistName":"Nina Simone","trackName":"Sinnerman","collectionName":"Pastel Blues","trackTimeMillis":622000},
 {"artistName":"Nina Simone","trackName":"Feeling Good - Live","collectionName":"Live"},
 {"artistName":"Nina Simone & Friends","trackName":"Ain't Got No, I Got Life"},
 {"artistName":"Other Artist","trackName":"Nope"}]}]]

local function search_env()
  local v2, R, G, fs = fresh({ os = "Win64" })
  return v2, R, G, fs, R.resource .. "\\Data\\VocalPrompter\\"
end

test("список песен: два источника, склейка дублей, фильтр по исполнителю, синхронный текст в приоритете", function()
  local v2, R, G, fs, dir = search_env()
  v2.start_search("nina simone", "")
  eq(v2.SR.view, "songs"); truthy(v2.SR.pending.lrc_artist and v2.SR.pending.itunes)
  fs.files[dir .. "lrc_artist.json"] = LRC_ARTIST
  fs.files[dir .. "itunes.json"] = ITUNES
  v2.poll_search()
  local titles = {}
  for _, s in ipairs(v2.SR.songs) do titles[#titles + 1] = s.title .. (s.lrc and (s.lrc.syncedLyrics and "[S]" or "[P]") or "") end
  eq(table.concat(titles, " | "), "Ain't Got No, I Got Life | Feeling Good[S] | Sinnerman")
  falsy(v2.SR.err)
end)

test("один источник упал — список из второго, без ошибки", function()
  local v2, R, G, fs, dir = search_env()
  v2.start_search("Nina Simone", "")
  fs.files[dir .. "itunes.err"] = "6"
  fs.files[dir .. "lrc_artist.json"] = LRC_ARTIST
  v2.poll_search(); v2.poll_search()
  eq(#v2.SR.songs, 1); falsy(v2.SR.err)
end)

test("оба источника упали — понятная ошибка", function()
  local v2, R, G, fs, dir = search_env()
  v2.start_search("Nina Simone", "")
  fs.files[dir .. "itunes.err"] = "6"; fs.files[dir .. "lrc_artist.err"] = "7"
  v2.poll_search()
  truthy(v2.SR.err); eq(v2.SR.err[1], "err_net")
end)

test("исполнитель не найден", function()
  local v2, R, G, fs, dir = search_env()
  v2.start_search("Qwertyuiop", "")
  fs.files[dir .. "itunes.json"] = '{"resultCount":0,"results":[]}'
  fs.files[dir .. "lrc_artist.json"] = "[]"
  v2.poll_search()
  eq(v2.SR.err[1], "err_no_songs")
end)

test("исполнитель + название → версии; пусто → «текста нет»", function()
  local v2, R, G, fs, dir = search_env()
  v2.start_search("Nina Simone", "Feeling Good")
  eq(v2.SR.view, "versions")
  local url = R.exec[#R.exec].cmd
  truthy(url, "запущен поиск")
  local bat = fs.files[dir .. "lrc_track.bat"]
  truthy(bat:find("track_name=Feeling%%20Good&artist_name=Nina%%20Simone", 1, true), bat)
  fs.files[dir .. "lrc_track.json"] = "[]"
  v2.poll_search()
  eq(v2.SR.err[1], "err_no_lyrics")
end)

test("пустой запрос → подсказка, ничего не запускается", function()
  local v2, R = search_env()
  v2.start_search("  ", "")
  eq(v2.SR.err[1], "err_empty_q"); eq(#R.exec, 0)
end)

---------------------------------------------------------------------------
group("Интерфейс (кадры с проверкой ReaImGui 0.9)")
---------------------------------------------------------------------------
test("все имена ReaImGui, которые скрипт использует, есть в API 0.9", function()
  local f = assert(io.open(SCRIPT, "r")); local src = f:read("a"); f:close()
  local api = M.new_imgui(API).api
  local missing = {}
  for name in src:gmatch("ImGui%.([%a_][%w_]*)") do
    if not api[name] then missing[#missing + 1] = name end
  end
  eq(table.concat(missing, ", "), "")
end)

test("регрессия: Col_TabSelected (нет в 0.9) не роняет скрипт", function()
  local v2, R, G = fresh()
  local ok = pcall(function() return G.module.Col_TabSelected end)
  falsy(ok, "мок должен падать как настоящий ReaImGui")
  eq(v2.imgui_has("Col_TabSelected"), nil)
  truthy(v2.imgui_has("Col_TabActive"))
  M.frame(v2, G)   -- тема применяется без ошибок
end)

local function prepare(state)
  local v2, R, G, fs = fresh({ os = "Win64" })
  if state ~= "empty" then
    v2.set_lines(v2.parse_lyrics("[00:01.00]Birds flying high you know how I feel\n[00:05.00]\n[00:09.00]Sun in the sky\n[00:12.00]Breeze driftin' on by"),
                 "Nina Simone — Feeling Good")
  end
  if state == "untimed" then v2.set_lines(v2.parse_lyrics("A\nB")) end
  if state == "songs" then
    v2.SR.view = "songs"; v2.SR.artist = "Nina Simone"
    v2.SR.songs = { { title = "Feeling Good", album = "Spell", dur = 176, lrc = { syncedLyrics = "x" } },
                    { title = "Sinnerman", dur = 622 }, { title = "Lilac Wine" } }
  elseif state == "versions" then
    v2.SR.view = "versions"; v2.SR.from_songs = true; v2.SR.versions_title = "Feeling Good"
    v2.SR.versions = { { artistName = "Nina Simone", trackName = "Feeling Good", duration = 176, syncedLyrics = "[00:01.00]x" },
                       { artistName = "Nina Simone", trackName = "Feeling Good", plainLyrics = "x" },
                       { artistName = "Nina Simone", trackName = "Feeling Good" } }
  elseif state == "searching" then
    v2.start_search("Nina", "")
  elseif state == "error" then
    v2.SR.view = "songs"; v2.SR.err = { "err_net", "28", hint = true }
  end
  return v2, R, G, fs
end

local STATES = { "empty", "untimed", "lyrics", "songs", "versions", "searching", "error" }
for _, lang in ipairs({ "ru", "en" }) do
  for _, tab in ipairs({ "tp", "ts", "tt", "tset" }) do
    test(("вкладка %s, язык %s: все состояния рисуются, Begin/End и Push/Pop парные"):format(tab, lang), function()
      for _, state in ipairs(STATES) do
        local v2, R, G = prepare(state)
        v2.set_lang(lang); G.tab = tab
        for _, pos in ipairs({ 0, 0.8, 1.2, 5, 10.5, 30 }) do
          R.play_state = 1; R.play_pos = pos
          local ok, e = pcall(M.frame, v2, G)
          if not ok then error(("state=%s pos=%s: %s"):format(state, pos, e), 0) end
        end
      end
    end)
  end
end

test("компактный режим, запись, попап «Вид», окно в доке и откреплено", function()
  for _, compact in ipairs({ false, true }) do
    for _, docked in ipairs({ false, true }) do
      local v2, R, G = prepare("lyrics")
      v2.VIEW.compact = compact; G.docked = docked
      G.popups["vp_view"] = true; G.popups["vp_ctx"] = true
      R.play_state = 5; R.play_pos = 6          -- 4 = запись
      M.frame(v2, G)
      truthy(G.has_text("● REC"), "нет индикатора записи")
      G.tab = "ts"; M.frame(v2, G)
    end
  end
end)

test("свёрнутое/невидимое окно: End не вызывается, кадр корректен", function()
  local v2, R, G = prepare("lyrics")
  G.begin_visible = false
  M.frame(v2, G)
end)

test("суфлёр показывает название, текущую и следующую строку", function()
  local v2, R, G = prepare("lyrics")
  v2.S().lead = 0
  R.play_state = 1; R.play_pos = 9.5
  M.frame(v2, G)
  truthy(G.has_text("Nina Simone — Feeling Good"), "нет названия")
  truthy(G.has_text("Sun in the sky"), "нет текущей строки")
  truthy(G.has_text("Breeze driftin' on by"), "нет следующей строки")
end)

test("суфлёр: вступление показывает обратный отсчёт; строка появляется раньше на lead", function()
  local v2, R, G = prepare("lyrics")
  v2.S().lead = 0.3
  R.play_state = 1; R.play_pos = 0.2
  M.frame(v2, G)
  truthy(G.has_text("вступление", true), "нет отсчёта")
  R.play_pos = 0.75         -- 0.75 + 0.3 ≥ 1.0 → уже первая строка
  M.frame(v2, G)
  truthy(G.has_text("Birds flying high", true), "строка не появилась заранее")
end)

test("кнопка TAP и клавиши Enter/T ставят тайминги", function()
  local v2, R, G = fresh()
  v2.set_lines(v2.parse_lyrics("A\nB\nC"))
  G.tab = "ts"; R.play_state = 1
  R.play_pos = 1; G.clicks.tap = true; M.frame(v2, G); G.clicks.tap = nil
  R.play_pos = 2; G.keys[G.module.Key_Enter] = true; M.frame(v2, G); G.keys = {}
  R.play_pos = 3; G.keys[G.module.Key_T] = true; M.frame(v2, G); G.keys = {}
  local L = v2.S().lines
  near(L[1].t, 1); near(L[2].t, 2); near(L[3].t, 3)
end)

test("«Применить» берёт текст из поля и название из тегов", function()
  local v2, R, G = fresh()
  G.tab = "tt"
  M.frame(v2, G)
  G.inputs.lyrics = "[ar:Muse]\n[ti:Uprising]\n[00:01.00]Paranoia"
  M.frame(v2, G); G.inputs.lyrics = nil
  G.clicks.apply = true; M.frame(v2, G); G.clicks.apply = nil
  eq(v2.S().name, "Muse — Uprising"); eq(v2.S().lines[1].text, "Paranoia")
end)

test("клик по песне → поиск версий; клик по версии → загрузка", function()
  local v2, R, G, fs = prepare("songs")
  G.tab = "tt"
  G.clicks.song2 = true; M.frame(v2, G); G.clicks.song2 = nil
  eq(v2.SR.view, "versions"); eq(v2.SR.versions_title, "Sinnerman")
  fs.files[R.resource .. "\\Data\\VocalPrompter\\lrc_track.json"] =
    '[{"artistName":"Nina Simone","trackName":"Sinnerman","syncedLyrics":"[00:02.00]Oh sinnerman"}]'
  M.frame(v2, G)
  G.clicks.res1 = true; M.frame(v2, G); G.clicks.res1 = nil
  eq(v2.S().name, "Nina Simone — Sinnerman"); eq(v2.S().lines[1].text, "Oh sinnerman")
  G.clicks.back = true; M.frame(v2, G); G.clicks.back = nil
  eq(v2.SR.view, "songs")
end)

test("настройки вида сохраняются", function()
  local v2, R, G = prepare("lyrics")
  G.popups["vp_view"] = true
  G.inputs.fs = 4; G.inputs.op = 0.5; G.inputs.cmp = true
  M.frame(v2, G)
  eq(v2.VIEW.fsize, 4); near(v2.VIEW.alpha, 0.5); eq(v2.VIEW.compact, true)
  eq(R.gext["VocalPrompter/fsize"], "4"); eq(R.gext["VocalPrompter/compact"], "1")
  local v3 = fresh({ ext = { ["VocalPrompter/fsize"] = "9", ["VocalPrompter/alpha"] = "0.01" } })
  eq(v3.VIEW.fsize, 4, "размер ограничен"); near(v3.VIEW.alpha, 0.15, 1e-9, "прозрачность ограничена")
end)

local function forced_size(G)
  for _, ns in ipairs(G.next_sizes) do
    if ns.cond == G.module.Cond_Always then return ns end
  end
end

test("сворачивание: окно разворачивается обратно в прежний размер", function()
  local v2, R, G = prepare("lyrics")
  G.win_w, G.win_h = 500, 700; M.frame(v2, G)          -- обычное окно
  falsy(forced_size(G), "без сворачивания размер не трогаем")
  G.begin_visible = false; M.frame(v2, G); M.frame(v2, G)   -- свернули
  -- развернули, но ReaImGui оставил высоту заголовка (баг SizeFull)
  G.begin_visible = true; G.win_w, G.win_h = 500, 27; M.frame(v2, G)
  G.win_w, G.win_h = 500, 27; M.frame(v2, G)
  local ns = forced_size(G)
  truthy(ns, "размер не восстановлен")
  eq(ns.w, 500); eq(ns.h, 700)
  G.win_h = 700; M.frame(v2, G)
  falsy(forced_size(G), "восстанавливаем один раз")
end)

test("сворачивание: если разворот сработал сам, ничего не делаем", function()
  local v2, R, G = prepare("lyrics")
  G.win_w, G.win_h = 500, 700; M.frame(v2, G)
  G.begin_visible = false; M.frame(v2, G)
  G.begin_visible = true; M.frame(v2, G); M.frame(v2, G)
  falsy(forced_size(G))
end)

test("сворачивание: окно в доке не трогаем; маленький размер не запоминаем", function()
  local v2, R, G = prepare("lyrics")
  G.docked = true; G.win_w, G.win_h = 300, 40; M.frame(v2, G)
  G.begin_visible = false; M.frame(v2, G)                 -- неактивная вкладка дока
  G.begin_visible = true; M.frame(v2, G); M.frame(v2, G)
  falsy(forced_size(G), "в доке размер задаёт REAPER")
  G.docked = false; G.win_w, G.win_h = 400, 50; M.frame(v2, G)   -- сжали вручную
  G.begin_visible = false; M.frame(v2, G)
  G.begin_visible = true; G.win_h = 27; M.frame(v2, G); M.frame(v2, G)
  falsy(forced_size(G), "без запомненного нормального размера не восстанавливаем")
end)

test("кнопка «Вид» и время помещаются в окно при любом названии и ширине", function()
  for _, name in ipairs({ "", "Muse — Uprising", "Nina Simone — I Put a Spell on You (Remastered 2013 Deluxe Edition)" }) do
    for _, w in ipairs({ 200, 300, 420, 900 }) do
      for _, rec in ipairs({ 0, 5 }) do
        local v2, R, G = prepare("lyrics")
        v2.S().name = name; G.avail_w = w; R.play_state = rec; R.play_pos = 3
        local ok, e = pcall(M.frame, v2, G)
        if not ok then error(("name=%q width=%d rec=%d: %s"):format(name, w, rec, e), 0) end
        truthy(G.has_text(v2.T("view")), "нет кнопки «Вид»")
      end
    end
  end
end)

test("все вкладки помещаются в узкое окно во всех темах", function()
  for _, th in ipairs(vp.THEMES) do
    for _, lang in ipairs({ "ru", "en" }) do
      for _, tab in ipairs({ "tp", "ts", "tt", "tset" }) do
        for _, w in ipairs({ 260, 340, 480 }) do
          local v2, R, G = prepare("lyrics")
          v2.set_lang(lang); v2.VIEW.theme = th.id; G.tab = tab; G.avail_w = w
          local ok, e = pcall(M.frame, v2, G)
          if not ok then error(("theme=%s lang=%s tab=%s width=%d: %s"):format(th.id, lang, tab, w, e), 0) end
        end
      end
    end
  end
end)

---------------------------------------------------------------------------
group("Настройки: тема и цвета")
---------------------------------------------------------------------------
test("выбор темы, акцента и своего цвета сохраняется", function()
  local v2, R, G = fresh()
  G.tab = "tset"
  G.clicks.th_light = true; M.frame(v2, G); G.clicks = {}
  eq(v2.VIEW.theme, "light"); eq(R.gext["VocalPrompter/theme"], "light")
  G.clicks.acc3 = true; M.frame(v2, G); G.clicks = {}
  eq(v2.VIEW.accent, v2.ACCENTS[3].c)
  G.inputs.acc_custom = 0x123456; M.frame(v2, G); G.inputs = {}
  eq(v2.VIEW.accent, 0x123456FF); eq(R.gext["VocalPrompter/accent"], tostring(0x123456FF))
  local v3 = fresh({ ext = { ["VocalPrompter/theme"] = "light", ["VocalPrompter/accent"] = tostring(0x123456FF) } })
  eq(v3.VIEW.theme, "light"); eq(v3.VIEW.accent, 0x123456FF)
end)

test("квадратики акцента показывают тот же цвет, что применяется", function()
  local v2, R, G = fresh()
  G.tab = "tset"; M.frame(v2, G)
  for i, acc in ipairs(v2.ACCENTS) do
    eq(G.swatches["acc" .. i], acc.c >> 8, "квадратик " .. v2.T(acc.name))
  end
end)

test("тема применяется к цветам интерфейса и суфлёра", function()
  local v2 = fresh()
  v2.VIEW.theme = "light"; v2.update_colors()
  truthy(v2.COL.bg > 0xE0000000, "фон светлой темы должен быть светлым")
  truthy(v2.COL.cur < 0x40404040, "текст светлой темы должен быть тёмным")
  v2.VIEW.theme = "dark"; v2.update_colors()
  truthy(v2.COL.bg < 0x30303030)
end)

test("текущая строка цветом акцента", function()
  local v2, R, G = fresh()
  v2.VIEW.accent = 0x60A5FAFF; v2.VIEW.accent_line = true; v2.update_colors()
  eq(v2.COL.cur, 0x60A5FAFF)
  v2.VIEW.accent_line = false; v2.update_colors()
  eq(v2.COL.cur, 0xFFFFFFFF)
  G.tab = "tset"; G.inputs.acl = true; M.frame(v2, G); G.inputs = {}
  eq(v2.VIEW.accent_line, true); eq(R.gext["VocalPrompter/accent_line"], "1")
end)

test("текст на акцентной кнопке читается: тёмный на светлом, светлый на тёмном", function()
  local v2 = fresh()
  v2.VIEW.accent = 0xF5C542FF; v2.update_colors(); eq(v2.COL.on_accent, 0x1B1016FF)
  v2.VIEW.accent = 0x1E3A8AFF; v2.update_colors(); eq(v2.COL.on_accent, 0xFFFFFFFF)
end)

test("сброс настроек и защита от мусора в сохранённых значениях", function()
  local v2, R, G = fresh()
  v2.VIEW.theme = "light"; v2.VIEW.accent = 0x123456FF; v2.VIEW.fsize = 4
  G.tab = "tset"; G.clicks.reset_view = true; M.frame(v2, G); G.clicks = {}
  eq(v2.VIEW.theme, "dark"); eq(v2.VIEW.fsize, 2); eq(v2.VIEW.accent, 0xFF6F9CFF)
  local v3 = fresh({ ext = { ["VocalPrompter/theme"] = "neon", ["VocalPrompter/accent"] = "abc" } })
  eq(v3.VIEW.theme, "dark"); eq(v3.VIEW.accent, 0xFF6F9CFF)
end)

test("язык переключается и во вкладке «Настройки»", function()
  local v2, R, G = fresh()
  G.tab = "tset"; G.clicks.lang_en = true; M.frame(v2, G); G.clicks = {}
  eq(v2.get_lang(), "en")
end)

test("mix и fit_text", function()
  eq(vp.mix(0x000000FF, 0xFFFFFFFF, 0.5), 0x808080FF)
  eq(vp.mix(0x102030FF, 0x102030FF, 0.7), 0x102030FF)
  local s = vp.fit_text("Nina Simone — I Put a Spell on You", 8 * 12)
  truthy(utf8.len(s) <= 12 and s:sub(-3) == "…", s)
  eq(vp.fit_text("short", 1000), "short")
end)

test("кнопка сворачивания на месте (нет NoCollapse)", function()
  local f = assert(io.open(SCRIPT, "r")); local src = f:read("a"); f:close()
  falsy(src:find("WindowFlags_NoCollapse", 1, true))
end)

---------------------------------------------------------------------------
print(("\n%d passed, %d failed"):format(passed, failed))
for _, f in ipairs(failures) do print("\n--- " .. f) end
if not VP_EMBEDDED then os.exit(failed == 0 and 0 or 1) end
return failed
