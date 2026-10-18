-- @description Vocal Prompter — lyrics teleprompter for recording vocals
-- @version 1.1.1
-- @author Irina Nesterova
-- @license MIT
-- @link https://github.com/IrNesterova/reaper-vocal-prompter
-- @about
--   # Vocal Prompter
--   Shows the current lyric line in big text while you record or play back.
--   Paste lyrics, open .txt/.lrc, or search LRCLIB (by artist + title, or by
--   artist only to browse their songs). Tap timings to the backing track.
--   Lyrics are stored inside each project. Russian / English UI.
--   Requires ReaImGui.
--
-- Суфлёр для записи вокала: крупно показывает текущую строку текста.
-- Вкладки: Суфлёр / Синхро / Текст. Интерфейс RU/EN.
-- Данные хранятся в самом проекте (.rpp). Нужен ReaImGui.

local r = reaper
local SEC = "VocalPrompter"

---------------------------------------------------------------------------
-- Локализация / Localization
---------------------------------------------------------------------------
local STR = {
  ru = {
    need_imgui      = "Для суфлёра нужен ReaImGui (версия 0.9 или новее).\n\nExtensions → ReaPack → Browse packages → найди «ReaImGui» → Install, затем перезапусти REAPER.",
    tab_prompter    = "Суфлёр",
    tab_sync        = "Синхро",
    tab_text        = "Текст",
    lang_tip        = "Switch to English",

    no_text         = "Пока нет текста. Вставь его во вкладке «Текст».",
    no_timing       = "У строк нет таймингов. Открой «Синхро», включи минус и протапай начало каждой строки.",
    intro           = "вступление… %.1f",

    offset          = "Начало песни в проекте, с",
    offset_cursor   = "= курсор",
    lead            = "Показывать раньше на, с",
    sync_need_text  = "Сначала добавь текст во вкладке «Текст».",
    tap             = "TAP   (Enter / T)",
    next_tap        = "Следующий тап: %d. %s",
    all_tapped      = "Все строки протаплены. Клик по строке — перетапать с неё.",
    tap_restart     = "Тапать с начала",
    clear_timing    = "Стереть тайминги",
    clear_timing_q  = "Стереть все тайминги?",
    to_markers      = "В маркеры",
    markers_undo    = "Vocal Prompter: строки в маркеры",
    undock          = "Открепить",
    dock            = "В док",
    interlude       = "♪ (проигрыш)",

    text_hint       = "Вставь текст (Ctrl+V) — обычный или LRC с таймингами [мм:сс.xx]. Пустые строки пропускаются.",
    apply           = "Применить",
    open_file       = "Открыть файл…",
    open_title      = "Открыть текст песни",
    clear           = "Очистить",
    clear_q         = "Удалить текст из проекта?",
    not_applied     = "не применено",
    search_head     = "Найти онлайн (LRCLIB)",
    artist          = "Исполнитель",
    title           = "Название",
    search          = "Искать",
    searching       = "Ищу…",
    sec_short       = "%.0f с",
    synced          = "[с таймингами]",
    plain           = "[только текст]",
    none            = "[нет текста]",

    err_empty_q     = "введи название",
    err_tmp         = "не могу записать временный файл",
    err_parse       = "не разобрала ответ сервера",
    err_nothing     = "ничего не нашлось — попробуй без исполнителя или латиницей",
    err_net         = "ошибка сети (curl %s)",
    err_net_hint    = " — сайт LRCLIB недоступен из твоей сети (может помочь VPN)",
    err_timeout     = "сервер не ответил за %d с — возможно, LRCLIB недоступен без VPN",

    song            = "Песня",
    view            = "Вид",
    tab_settings    = "Настройки",
    sec_theme       = "Тема",
    theme_dark      = "Тёмная",
    theme_midnight  = "Полночь",
    theme_light     = "Светлая",
    sec_accent      = "Цвет акцента",
    acc_pink        = "Розовый",
    acc_violet      = "Фиолетовый",
    acc_blue        = "Синий",
    acc_teal        = "Бирюзовый",
    acc_green       = "Зелёный",
    acc_yellow      = "Жёлтый",
    acc_orange      = "Оранжевый",
    acc_red         = "Красный",
    acc_custom      = "Свой цвет",
    accent_line     = "Текущая строка цветом акцента",
    sec_prompter    = "Суфлёр",
    sec_language    = "Язык интерфейса",
    reset_view      = "Сбросить настройки",
    reset_view_q    = "Вернуть настройки вида по умолчанию?",
    all_settings    = "Цвета и остальное — во вкладке «Настройки».",
    font_size       = "Размер текста",
    opacity         = "Непрозрачность фона",
    opacity_note    = "Прозрачность видна, когда окно откреплено от дока.",
    compact         = "Только суфлёр (без вкладок)",
    compact_tip     = "Настройки вида (или правый клик по окну)",
    sec_text        = "Текст",
    sec_timing      = "Тайминг",
    sec_lines       = "Строки",
    song_hint       = "Исполнитель — Название",
    search_hint     = "Только исполнитель → список его песен. Исполнитель + название → сразу текст.",
    songs_of        = "Песни: %s (%d)",
    filter          = "Фильтр",
    back_songs      = "← к песням",
    versions_of     = "Версии: %s",
    has_lyrics      = "[есть текст]",
    err_no_songs    = "у этого исполнителя ничего не нашлось — проверь написание",
    err_no_lyrics   = "для этой песни текста в LRCLIB нет",
  },
  en = {
    need_imgui      = "Vocal Prompter needs ReaImGui (v0.9 or newer).\n\nExtensions → ReaPack → Browse packages → find \"ReaImGui\" → Install, then restart REAPER.",
    tab_prompter    = "Prompter",
    tab_sync        = "Sync",
    tab_text        = "Lyrics",
    lang_tip        = "Переключить на русский",

    no_text         = "No lyrics yet. Paste them in the \"Lyrics\" tab.",
    no_timing       = "Lines have no timing. Open \"Sync\", play the backing track and tap the start of each line.",
    intro           = "intro… %.1f",

    offset          = "Song start in project, s",
    offset_cursor   = "= cursor",
    lead            = "Show early by, s",
    sync_need_text  = "Add lyrics in the \"Lyrics\" tab first.",
    tap             = "TAP   (Enter / T)",
    next_tap        = "Next tap: %d. %s",
    all_tapped      = "All lines tapped. Click a line to re-tap from it.",
    tap_restart     = "Tap from start",
    clear_timing    = "Clear timing",
    clear_timing_q  = "Clear all timings?",
    to_markers      = "To markers",
    markers_undo    = "Vocal Prompter: lines to markers",
    undock          = "Undock",
    dock            = "Dock",
    interlude       = "♪ (interlude)",

    text_hint       = "Paste lyrics (Ctrl+V) — plain text or LRC with [mm:ss.xx] timings. Empty lines are skipped.",
    apply           = "Apply",
    open_file       = "Open file…",
    open_title      = "Open lyrics",
    clear           = "Clear",
    clear_q         = "Remove lyrics from this project?",
    not_applied     = "not applied",
    search_head     = "Search online (LRCLIB)",
    artist          = "Artist",
    title           = "Title",
    search          = "Search",
    searching       = "Searching…",
    sec_short       = "%.0f s",
    synced          = "[synced]",
    plain           = "[plain text]",
    none            = "[no lyrics]",

    err_empty_q     = "enter a title",
    err_tmp         = "can't write temp file",
    err_parse       = "couldn't parse server response",
    err_nothing     = "nothing found — try without the artist or in Latin script",
    err_net         = "network error (curl %s)",
    err_net_hint    = " — LRCLIB is unreachable from your network (a VPN may help)",
    err_timeout     = "no response in %d s — LRCLIB may be unreachable without a VPN",

    song            = "Song",
    view            = "View",
    tab_settings    = "Settings",
    sec_theme       = "Theme",
    theme_dark      = "Dark",
    theme_midnight  = "Midnight",
    theme_light     = "Light",
    sec_accent      = "Accent color",
    acc_pink        = "Pink",
    acc_violet      = "Violet",
    acc_blue        = "Blue",
    acc_teal        = "Teal",
    acc_green       = "Green",
    acc_yellow      = "Yellow",
    acc_orange      = "Orange",
    acc_red         = "Red",
    acc_custom      = "Custom color",
    accent_line     = "Current line in accent color",
    sec_prompter    = "Prompter",
    sec_language    = "Interface language",
    reset_view      = "Reset settings",
    reset_view_q    = "Restore default view settings?",
    all_settings    = "Colors and more are in the \"Settings\" tab.",
    font_size       = "Text size",
    opacity         = "Background opacity",
    opacity_note    = "Transparency shows when the window is undocked.",
    compact         = "Prompter only (no tabs)",
    compact_tip     = "View settings (or right-click the window)",
    sec_text        = "Lyrics",
    sec_timing      = "Timing",
    sec_lines       = "Lines",
    song_hint       = "Artist — Title",
    search_hint     = "Artist only → list of their songs. Artist + title → lyrics right away.",
    songs_of        = "Songs by %s (%d)",
    filter          = "Filter",
    back_songs      = "← back to songs",
    versions_of     = "Versions: %s",
    has_lyrics      = "[lyrics]",
    err_no_songs    = "nothing found for this artist — check the spelling",
    err_no_lyrics   = "no lyrics for this song on LRCLIB",
  },
}

local lang = r.GetExtState(SEC, "lang")
if lang ~= "ru" and lang ~= "en" then lang = "ru" end

local function T(key, ...)
  local s = STR[lang][key] or STR.ru[key] or key
  if select("#", ...) > 0 then return string.format(s, ...) end
  return s
end

local function set_lang(l)
  lang = l
  r.SetExtState(SEC, "lang", l, true)
end

---------------------------------------------------------------------------
-- ReaImGui
---------------------------------------------------------------------------
if not r.ImGui_GetBuiltinPath then
  r.MB(T("need_imgui"), "Vocal Prompter", 0)
  return
end
package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'

local ctx = ImGui.CreateContext('Vocal Prompter')

-- Шрифты: несколько размеров заранее (переключаются в настройках вида)
local BIG_SIZES = { 28, 36, 46, 60 }
local MID_SIZES = { 18, 22, 27, 34 }
local F_BIG, F_MID = {}, {}
for i = 1, #BIG_SIZES do
  F_BIG[i] = ImGui.CreateFont('sans-serif', BIG_SIZES[i]); ImGui.Attach(ctx, F_BIG[i])
  F_MID[i] = ImGui.CreateFont('sans-serif', MID_SIZES[i]); ImGui.Attach(ctx, F_MID[i])
end
local F_UI   = ImGui.CreateFont('sans-serif', 15); ImGui.Attach(ctx, F_UI)
local F_HEAD = ImGui.CreateFont('sans-serif', 18); ImGui.Attach(ctx, F_HEAD)
local F_TAP  = ImGui.CreateFont('sans-serif', 22); ImGui.Attach(ctx, F_TAP)

local function with_alpha(c, a) return (c & 0xFFFFFF00) | a end

-- Смешать два цвета RRGGBBAA: t = 0 → a, t = 1 → b
local function mix(a, b, t)
  local function ch(c, s) return (c >> s) & 0xFF end
  local out = 0
  for _, s in ipairs({ 24, 16, 8, 0 }) do
    out = out | (math.floor(ch(a, s) + (ch(b, s) - ch(a, s)) * t + 0.5) << s)
  end
  return out
end

-- Яркость цвета 0..1 (чтобы выбрать тёмный или светлый текст на кнопке)
local function luminance(c)
  return (0.299 * ((c >> 24) & 0xFF) + 0.587 * ((c >> 16) & 0xFF) + 0.114 * ((c >> 8) & 0xFF)) / 255
end

-- Темы: фон, рамки, текст. Акцент выбирается отдельно.
local THEMES = {
  { id = "dark", name = "theme_dark", c = {
      bg = 0x141418FF, popup = 0x1D1D24F8, border = 0x2A2A34FF,
      frame = 0x23232BFF, frame_hov = 0x2C2C36FF, frame_act = 0x34343FFF,
      title = 0x141418FF, title_act = 0x1A1A20FF,
      button = 0x272731FF, button_hov = 0x33333FFF,
      tab = 0x1A1A20FF, tab_hov = 0x33333FFF, tab_act = 0x2A2A34FF,
      scroll = 0x2C2C36FF, row_alt = 0xFFFFFF05, progress = 0x26262FFF,
      text = 0xE8E8F0FF, cur = 0xFFFFFFFF, next = 0xB4B4C4FF, dim = 0x70708AFF, faint = 0x50506AFF } },
  { id = "midnight", name = "theme_midnight", c = {
      bg = 0x0E1424FF, popup = 0x151D31F8, border = 0x223050FF,
      frame = 0x18223AFF, frame_hov = 0x202C48FF, frame_act = 0x283656FF,
      title = 0x0E1424FF, title_act = 0x131B30FF,
      button = 0x1B2640FF, button_hov = 0x25324FFF,
      tab = 0x131B30FF, tab_hov = 0x25324FFF, tab_act = 0x1F2B47FF,
      scroll = 0x223050FF, row_alt = 0xFFFFFF05, progress = 0x1C2740FF,
      text = 0xE2E8F6FF, cur = 0xFFFFFFFF, next = 0xA9B6D3FF, dim = 0x6A7898FF, faint = 0x46536FFF } },
  { id = "light", name = "theme_light", c = {
      bg = 0xF5F5F8FF, popup = 0xFFFFFFFA, border = 0xD8D8E0FF,
      frame = 0xE7E7EDFF, frame_hov = 0xDDDDE5FF, frame_act = 0xD3D3DDFF,
      title = 0xE9E9EFFF, title_act = 0xDFDFE7FF,
      button = 0xE3E3EAFF, button_hov = 0xD7D7E0FF,
      tab = 0xE5E5EBFF, tab_hov = 0xD7D7E0FF, tab_act = 0xFFFFFFFF,
      scroll = 0xC9C9D3FF, row_alt = 0x00000008, progress = 0xDCDCE4FF,
      text = 0x23232BFF, cur = 0x101016FF, next = 0x4E4E5CFF, dim = 0x8A8A99FF, faint = 0xB2B2C0FF } },
}
local THEME_BY_ID = {}
for _, th in ipairs(THEMES) do THEME_BY_ID[th.id] = th end

local ACCENTS = {
  { name = "acc_pink",   c = 0xFF6F9CFF },
  { name = "acc_violet", c = 0xA78BFAFF },
  { name = "acc_blue",   c = 0x60A5FAFF },
  { name = "acc_teal",   c = 0x2DD4BFFF },
  { name = "acc_green",  c = 0x5FD08AFF },
  { name = "acc_yellow", c = 0xF5C542FF },
  { name = "acc_orange", c = 0xFB923CFF },
  { name = "acc_red",    c = 0xF2545BFF },
}

-- Настройки вида (общие для всех проектов)
local VIEW_DEFAULTS = { fsize = 2, alpha = 1, compact = false, theme = "dark", accent = 0xFF6F9CFF, accent_line = false }
local function load_view()
  local function num(k) return tonumber(r.GetExtState(SEC, k)) end
  local th = r.GetExtState(SEC, "theme")
  return {
    fsize       = math.max(1, math.min(#BIG_SIZES, num("fsize") or VIEW_DEFAULTS.fsize)),
    alpha       = math.max(0.15, math.min(1, num("alpha") or VIEW_DEFAULTS.alpha)),
    compact     = r.GetExtState(SEC, "compact") == "1",
    theme       = THEME_BY_ID[th] and th or VIEW_DEFAULTS.theme,
    accent      = ((num("accent") or VIEW_DEFAULTS.accent) & 0xFFFFFF00) | 0xFF,
    accent_line = r.GetExtState(SEC, "accent_line") == "1",
  }
end
local VIEW = load_view()
local function save_view()
  r.SetExtState(SEC, "fsize", tostring(VIEW.fsize), true)
  r.SetExtState(SEC, "alpha", string.format("%.2f", VIEW.alpha), true)
  r.SetExtState(SEC, "compact", VIEW.compact and "1" or "0", true)
  r.SetExtState(SEC, "theme", VIEW.theme, true)
  r.SetExtState(SEC, "accent", tostring(VIEW.accent), true)
  r.SetExtState(SEC, "accent_line", VIEW.accent_line and "1" or "0", true)
end
local function reset_view()
  for k, v in pairs(VIEW_DEFAULTS) do VIEW[k] = v end
  save_view()
end

-- Текущие цвета: пересчитываются каждый кадр из темы и акцента
local COL = { rec = 0xFF4D5EFF, warn = 0xFFB86BFF, synced = 0x5FD08AFF }
local function update_colors()
  local p = THEME_BY_ID[VIEW.theme].c
  local light = VIEW.theme == "light"
  for k, v in pairs(p) do COL[k] = v end
  COL.accent       = VIEW.accent
  COL.accent_hov   = mix(VIEW.accent, light and 0x000000FF or 0xFFFFFFFF, 0.15)
  COL.accent_act   = mix(VIEW.accent, 0x000000FF, 0.15)
  COL.on_accent    = luminance(VIEW.accent) > 0.6 and 0x1B1016FF or 0xFFFFFFFF
  COL.warn         = light and 0xC2600CFF or 0xFFB86BFF
  COL.synced       = light and 0x16944AFF or 0x5FD08AFF
  if VIEW.accent_line then COL.cur = VIEW.accent end
end
update_colors()

local function theme_colors()
  local a = COL.accent
  return {
    { "WindowBg",         COL.bg },
    { "ChildBg",          0x00000000 },
    { "PopupBg",          COL.popup },
    { "Border",           COL.border },
    { "FrameBg",          COL.frame },
    { "FrameBgHovered",   COL.frame_hov },
    { "FrameBgActive",    COL.frame_act },
    { "TitleBg",          COL.title },
    { "TitleBgActive",    COL.title_act },
    { "TitleBgCollapsed", COL.title },
    { "Button",           COL.button },
    { "ButtonHovered",    COL.button_hov },
    { "ButtonActive",     with_alpha(a, 0x99) },
    { "Header",           with_alpha(a, 0x30) },
    { "HeaderHovered",    with_alpha(a, 0x48) },
    { "HeaderActive",     with_alpha(a, 0x70) },
    { "Separator",        COL.border },
    { "Tab",              COL.tab },
    { "TabHovered",       COL.tab_hov },
    { "TabActive",        COL.tab_act },
    { "TabSelected",      COL.tab_act },
    { "Text",             COL.text },
    { "TextDisabled",     COL.dim },
    { "SliderGrab",       a },
    { "SliderGrabActive", COL.accent_hov },
    { "CheckMark",        a },
    { "PlotHistogram",    a },
    { "ScrollbarBg",      0x00000000 },
    { "ScrollbarGrab",    COL.scroll },
    { "TableRowBg",       0x00000000 },
    { "TableRowBgAlt",    COL.row_alt },
    { "ResizeGrip",       0x00000000 },
    { "TextSelectedBg",   with_alpha(a, 0x55) },
  }
end
local THEME_VARS = {
  { "WindowPadding",     14, 12 },
  { "FramePadding",      10, 6 },
  { "ItemSpacing",       8, 8 },
  { "ItemInnerSpacing",  6, 6 },
  { "WindowRounding",    8 },
  { "ChildRounding",     8 },
  { "FrameRounding",     6 },
  { "PopupRounding",     8 },
  { "TabRounding",       6 },
  { "GrabRounding",      6 },
  { "ScrollbarRounding", 6 },
  { "ScrollbarSize",     10 },
  { "WindowBorderSize",  0 },
}
local FRAME_PAD_X = 10

-- ReaImGui падает при обращении к несуществующему имени, поэтому проверяем через pcall
local function imgui_has(name)
  local ok, v = pcall(function() return ImGui[name] end)
  if ok then return v end
  return nil
end

local function push_theme()
  update_colors()
  local nc, nv = 0, 0
  for _, c in ipairs(theme_colors()) do
    local id = imgui_has("Col_" .. c[1])
    if id then ImGui.PushStyleColor(ctx, id, c[2]); nc = nc + 1 end
  end
  for _, v in ipairs(THEME_VARS) do
    local id = imgui_has("StyleVar_" .. v[1])
    if id then ImGui.PushStyleVar(ctx, id, v[2], v[3]); nv = nv + 1 end
  end
  return nc, nv
end

-- Мелкие помощники интерфейса
local function section(label)
  if imgui_has("SeparatorText") then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, COL.dim)
    ImGui.SeparatorText(ctx, label)
    ImGui.PopStyleColor(ctx)
  else
    ImGui.Spacing(ctx); ImGui.TextColored(ctx, COL.dim, label); ImGui.Separator(ctx)
  end
end

local function accent_button(label, w, h)
  ImGui.PushStyleColor(ctx, ImGui.Col_Button,        COL.accent)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, COL.accent_hov)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,  COL.accent_act)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text,          COL.on_accent)
  local clicked = ImGui.Button(ctx, label, w, h)
  ImGui.PopStyleColor(ctx, 4)
  return clicked
end

-- Ширина кнопки с такой подписью (без ##id)
local function button_w(label)
  return ImGui.CalcTextSize(ctx, (label:gsub("##.*$", ""))) + FRAME_PAD_X * 2
end

-- Поставить следующий элемент в ту же строку, если влезает, иначе — с новой строки
local function flow(w)
  ImGui.SameLine(ctx)
  if ImGui.GetContentRegionAvail(ctx) < w then ImGui.NewLine(ctx) end
end

-- Обрезать текст с «…», чтобы влез в ширину (для текущего шрифта)
local function fit_text(s, maxw)
  if ImGui.CalcTextSize(ctx, s) <= maxw then return s end
  local chars = {}
  for _, c in utf8.codes(s) do chars[#chars + 1] = utf8.char(c) end
  while #chars > 1 do
    chars[#chars] = nil
    local t = table.concat(chars):gsub("%s+$", "") .. "…"
    if ImGui.CalcTextSize(ctx, t) <= maxw then return t end
  end
  return "…"
end

-- Перенос строки по словам под ширину (для текущего шрифта)
local function wrap_lines(text, maxw)
  local out, line = {}, ""
  for word in text:gmatch("%S+") do
    local cand = line == "" and word or (line .. " " .. word)
    if line ~= "" and ImGui.CalcTextSize(ctx, cand) > maxw then
      out[#out + 1] = line; line = word
    else
      line = cand
    end
  end
  if line ~= "" then out[#out + 1] = line end
  if #out == 0 then out[1] = " " end
  return out
end

---------------------------------------------------------------------------
-- Состояние
---------------------------------------------------------------------------
local S          -- { lines = { {text=, t=секунды от начала песни | nil} }, offset=, lead= }
local cur_proj
local dirty      = false
local tap_idx    = 1
local edit_buf   = ""
local buf_stale  = true
local edit_dirty = false
local dock_req   = nil
-- Размер окна до сворачивания (см. restore_after_collapse в главном цикле)
local WIN = { w = nil, h = nil, collapsed = false, restore = false }
local COLLAPSED_MAX_H = 60   -- выше этой высоты окно точно не «полоска-заголовок»
local q_artist, q_title = "", ""

local function mark_dirty() dirty = true end
local function E(key, ...) return { key, ... } end
local function err_text(e)
  if not e then return nil end
  return T(e[1], table.unpack(e, 2))
end

---------------------------------------------------------------------------
-- Время и текст
---------------------------------------------------------------------------
local function fmt_time(sec)
  if not sec then return "—" end
  local neg = sec < 0
  sec = math.abs(sec)
  local m = math.floor(sec / 60)
  return string.format("%s%d:%05.2f", neg and "-" or "", m, sec - m * 60)
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function parse_lyrics(text)
  text = text:gsub("^\239\187\191", "")
  local lines, timed, meta = {}, false, {}
  for raw in (text .. "\n"):gmatch("(.-)\r?\n") do
    local s, times = raw, {}
    while true do
      local m, sec, rest = s:match("^%s*%[(%d+):(%d+%.?%d*)%](.*)$")
      if not m then break end
      times[#times + 1] = tonumber(m) * 60 + tonumber(sec)
      s = rest
    end
    if #times == 0 then
      local tag, val = s:match("^%s*%[(%a+):(.*)%]%s*$")
      if tag then
        tag = tag:lower()
        if tag == "ar" or tag == "ti" then meta[tag] = trim(val) end
        s = ""
      end
    end
    s = trim(s)
    if #times > 0 then
      timed = true
      for _, t in ipairs(times) do lines[#lines + 1] = { text = s, t = t } end
    elseif s ~= "" then
      lines[#lines + 1] = { text = s }
    end
  end
  if timed then
    table.sort(lines, function(a, b) return (a.t or math.huge) < (b.t or math.huge) end)
  end
  return lines, meta
end

-- «Исполнитель — Название» из того, что известно
local function song_name(artist, title)
  artist, title = trim(artist or ""), trim(title or "")
  if artist ~= "" and title ~= "" then return artist .. " — " .. title end
  return artist ~= "" and artist or title
end

local function to_lrc(lines)
  local out = {}
  for _, l in ipairs(lines) do
    if l.t then
      local m = math.floor(l.t / 60)
      out[#out + 1] = string.format("[%02d:%05.2f]%s", m, l.t - m * 60, l.text)
    else
      out[#out + 1] = l.text
    end
  end
  return table.concat(out, "\n")
end

local function timed_order()
  local order = {}
  for i, l in ipairs(S.lines) do if l.t then order[#order + 1] = i end end
  table.sort(order, function(a, b) return S.lines[a].t < S.lines[b].t end)
  return order
end

local function find_current(order, t)
  local k = nil
  for j, i in ipairs(order) do
    if S.lines[i].t <= t then k = j else break end
  end
  return k
end

local function now_pos()
  local st = r.GetPlayState()
  if st & 1 == 1 or st & 4 == 4 then return r.GetPlayPosition(), st end
  return r.GetCursorPosition(), st
end

---------------------------------------------------------------------------
-- Сохранение в проект
---------------------------------------------------------------------------
local function load_state(proj)
  S = { lines = {}, offset = 0, lead = 0.3, name = "" }
  local _, n = r.GetProjExtState(proj, SEC, "n")
  for i = 1, (tonumber(n) or 0) do
    local _, v = r.GetProjExtState(proj, SEC, "L" .. i)
    local ts, txt = v:match("^([^\t]*)\t(.*)$")
    if ts then S.lines[#S.lines + 1] = { t = tonumber(ts), text = txt } end
  end
  local _, o = r.GetProjExtState(proj, SEC, "offset")
  local _, ld = r.GetProjExtState(proj, SEC, "lead")
  S.offset = tonumber(o) or 0
  S.lead   = tonumber(ld) or 0.3
  local _, nm = r.GetProjExtState(proj, SEC, "name")
  S.name = nm or ""
  -- подставить песню проекта в поля поиска
  local a, t = S.name:match("^(.-)%s+—%s+(.+)$")
  q_artist, q_title = a or "", t or S.name
  tap_idx = #S.lines + 1
  for i, l in ipairs(S.lines) do if not l.t then tap_idx = i break end end
  if tap_idx > #S.lines then tap_idx = 1 end
  buf_stale, edit_dirty, dirty = true, false, false
end

local function save_state(proj)
  r.SetProjExtState(proj, SEC, "", "")
  r.SetProjExtState(proj, SEC, "n", tostring(#S.lines))
  for i, l in ipairs(S.lines) do
    r.SetProjExtState(proj, SEC, "L" .. i, (l.t and string.format("%.3f", l.t) or "") .. "\t" .. l.text)
  end
  r.SetProjExtState(proj, SEC, "offset", string.format("%.4f", S.offset))
  r.SetProjExtState(proj, SEC, "lead",   string.format("%.3f", S.lead))
  r.SetProjExtState(proj, SEC, "name",   S.name)
  r.MarkProjectDirty(proj)   -- чтобы REAPER предложил сохранить проект
end

local function set_lines(lines, name)
  S.lines = lines
  -- только строка: set_lines(parse_lyrics(x)) передаёт вторым значением таблицу meta
  if type(name) == "string" then S.name = name end
  tap_idx = 1
  for i, l in ipairs(lines) do if not l.t then tap_idx = i break end end
  mark_dirty()
  buf_stale, edit_dirty = true, false
end

---------------------------------------------------------------------------
-- JSON
---------------------------------------------------------------------------
local function json_decode(s)
  local pos = 1
  local esc = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
  local function ws() pos = s:find("[^ \t\r\n]", pos) or #s + 1 end
  local val
  local function str()
    pos = pos + 1
    local out = {}
    while true do
      local c = s:sub(pos, pos)
      if c == "" then error("unterminated string") end
      if c == '"' then pos = pos + 1 break end
      if c == "\\" then
        local e = s:sub(pos + 1, pos + 1)
        if e == "u" then
          local cp = tonumber(s:sub(pos + 2, pos + 5), 16)
          pos = pos + 6
          if cp >= 0xD800 and cp <= 0xDBFF and s:sub(pos, pos + 1) == "\\u" then
            local lo = tonumber(s:sub(pos + 2, pos + 5), 16)
            cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
            pos = pos + 6
          end
          out[#out + 1] = utf8.char(cp)
        else
          out[#out + 1] = esc[e] or e
          pos = pos + 2
        end
      else
        local j = s:find('["\\]', pos)
        if not j then error("unterminated string") end
        out[#out + 1] = s:sub(pos, j - 1)
        pos = j
      end
    end
    return table.concat(out)
  end
  function val()
    ws()
    local c = s:sub(pos, pos)
    if c == "{" then
      pos = pos + 1; ws()
      local t = {}
      if s:sub(pos, pos) == "}" then pos = pos + 1 return t end
      while true do
        ws(); local k = str(); ws(); pos = pos + 1
        t[k] = val(); ws()
        local d = s:sub(pos, pos); pos = pos + 1
        if d == "}" then return t end
      end
    elseif c == "[" then
      pos = pos + 1; ws()
      local t = {}
      if s:sub(pos, pos) == "]" then pos = pos + 1 return t end
      while true do
        t[#t + 1] = val(); ws()
        local d = s:sub(pos, pos); pos = pos + 1
        if d == "]" then return t end
      end
    elseif c == '"' then return str()
    elseif s:sub(pos, pos + 3) == "true"  then pos = pos + 4 return true
    elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
    elseif s:sub(pos, pos + 3) == "null"  then pos = pos + 4 return nil
    else
      local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
      if not num or num == "" then error("bad json at " .. pos) end
      pos = pos + #num
      return tonumber(num)
    end
  end
  return val()
end

local function urlencode(s)
  return (s:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", c:byte()) end))
end

---------------------------------------------------------------------------
-- Онлайн-поиск — в фоне, чтобы REAPER не подвисал.
--   исполнитель + название → LRCLIB, список версий текста
--   только исполнитель     → список песен (iTunes Search API + LRCLIB),
--                            клик по песне → версии текста из LRCLIB
---------------------------------------------------------------------------
local IS_WIN = r.GetOS():match("Win") ~= nil
local SEARCH_TIMEOUT = 30
local jobs = {}   -- name → { json=, err=, part=, started= }

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close() return true end
  return false
end

local function read_file(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local d = f:read("a"); f:close()
  return d
end

-- lower с кириллицей (string.lower её не знает)
local CYR_LOWER = {}
do
  local up, lo = {}, {}
  for _, c in utf8.codes("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ") do up[#up + 1] = utf8.char(c) end
  for _, c in utf8.codes("абвгдеёжзийклмнопрстуфхцчшщъыьэюя") do lo[#lo + 1] = utf8.char(c) end
  for i = 1, #up do CYR_LOWER[up[i]] = lo[i] end
end
local function ulower(s)
  return (s:lower():gsub(utf8.charpattern, CYR_LOWER))
end

-- ключ для склейки дублей: «Feeling Good (Remastered 2013)» ≈ «Feeling Good»
local function song_key(title)
  local k = ulower(title)
  k = k:gsub("%b()", ""):gsub("%b[]", "")
  k = k:gsub("%s+%-%s+.*$", "")
  k = k:gsub("[%p]", " "):gsub("%s+", " ")
  return trim(k)
end

local function start_job(name, url)
  local sep = IS_WIN and "\\" or "/"
  local dir = (r.GetResourcePath() .. "/Data/VocalPrompter"):gsub("[/\\]", sep)
  r.RecursiveCreateDirectory(dir, 0)
  local base = dir .. sep .. name
  local job = { json = base .. ".json", err = base .. ".err", part = base .. ".part", started = r.time_precise() }
  os.remove(job.json); os.remove(job.err); os.remove(job.part)

  local cmd
  if IS_WIN then
    -- .bat работает с короткими именами файлов в своей папке (без полного пути —
    -- так не страшна кириллица в имени пользователя), а запускает его скрытно
    -- маленький .vbs через wscript — без мелькающего окна консоли.
    local u = url:gsub("%%", "%%%%")   -- в .bat знак % удваивается
    local bat = base .. ".bat"
    local f = io.open(bat, "wb")
    if not f then return E("err_tmp") end
    f:write('@echo off\r\n',
      'curl.exe -s -L --ssl-no-revoke --connect-timeout 10 -m 25 -A "VocalPrompter/1.0" -o "', name, '.part" "', u, '"\r\n',
      'if errorlevel 1 (echo %errorlevel% > "', name, '.err") else (move /Y "', name, '.part" "', name, '.json" >nul)\r\n')
    f:close()

    local vbs_src = 'Set sh = CreateObject("WScript.Shell")\r\n' ..
                    'sh.CurrentDirectory = "' .. dir .. '"\r\n' ..
                    'sh.Run "cmd.exe /C ' .. name .. '.bat", 0, False\r\n'
    -- wscript понимает не-ASCII пути только в UTF-16LE с BOM
    local u16 = { "\255\254" }
    for _, cp in utf8.codes(vbs_src) do
      if cp >= 0x10000 then
        cp = cp - 0x10000
        local hi, lo = 0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF)
        u16[#u16 + 1] = string.char(hi & 0xFF, hi >> 8, lo & 0xFF, lo >> 8)
      else
        u16[#u16 + 1] = string.char(cp & 0xFF, cp >> 8)
      end
    end
    local vbs = base .. ".vbs"
    f = io.open(vbs, "wb")
    if f then
      f:write(table.concat(u16)); f:close()
      cmd = 'wscript.exe //B //Nologo "' .. vbs .. '"'
    else
      cmd = 'cmd.exe /C "' .. bat .. '"'   -- запасной вариант
    end
  else
    local script = base .. ".sh"
    local f = io.open(script, "wb")
    if not f then return E("err_tmp") end
    f:write('#!/bin/sh\n',
      'curl -s -L --connect-timeout 10 -m 25 -A "VocalPrompter/1.0" -o "', job.part, '" "', url, '"\n',
      'rc=$?\n',
      'if [ $rc -ne 0 ]; then echo $rc > "', job.err, '"; else mv "', job.part, '" "', job.json, '"; fi\n')
    f:close()
    cmd = '/bin/sh "' .. script .. '"'
  end
  r.ExecProcess(cmd, -1)
  jobs[name] = job
  return nil
end

-- Возвращает "done", data | "error", err | nil (ещё идёт)
local function poll_job(name)
  local job = jobs[name]
  if not job then return end
  if file_exists(job.json) then
    jobs[name] = nil
    local ok, data = pcall(json_decode, read_file(job.json) or "")
    if not ok or type(data) ~= "table" then return "error", E("err_parse") end
    return "done", data
  elseif file_exists(job.err) then
    jobs[name] = nil
    local code = trim(read_file(job.err) or "?")
    local e = E("err_net", code)
    if code == "6" or code == "7" or code == "28" or code == "35" then e.hint = true end
    return "error", e
  elseif r.time_precise() - job.started > SEARCH_TIMEOUT then
    jobs[name] = nil
    return "error", E("err_timeout", SEARCH_TIMEOUT)
  end
end

local function busy() return next(jobs) ~= nil end
local function busy_since()
  local t = math.huge
  for _, j in pairs(jobs) do t = math.min(t, j.started) end
  return t
end

-- Состояние поиска
--   view: nil | "songs" | "versions"
local SR = {
  view = nil,
  artist = "",
  songs = nil,        -- { {title=, album=, dur=, lrc=результат LRCLIB|nil} }
  song_filter = "",
  versions = nil,     -- результаты LRCLIB
  versions_title = "",
  err = nil,
  pending = {},       -- что ждём: lrc_artist, itunes, lrc_track
  raw = {},
}

local LRC = "https://lrclib.net/api/search?"

local function search_track(artist, title)
  SR.versions, SR.err = nil, nil
  SR.versions_title = title
  local url = LRC .. "track_name=" .. urlencode(title)
  if artist ~= "" then url = url .. "&artist_name=" .. urlencode(artist) end
  SR.err = start_job("lrc_track", url)
  if not SR.err then SR.pending.lrc_track = true; SR.view = "versions" end
end

local function search_artist(artist)
  SR.songs, SR.versions, SR.err, SR.raw = nil, nil, nil, {}
  SR.artist, SR.song_filter = artist, ""
  SR.view = "songs"
  local e1 = start_job("lrc_artist", LRC .. "q=" .. urlencode(artist))
  if not e1 then SR.pending.lrc_artist = true end
  local e2 = start_job("itunes", "https://itunes.apple.com/search?entity=song&attribute=artistTerm&limit=200&term=" .. urlencode(artist))
  if not e2 then SR.pending.itunes = true end
  if e1 and e2 then SR.err = e1 end
end

local function start_search(artist, title)
  artist, title = trim(artist), trim(title)
  if title ~= "" then
    search_track(artist, title)
  elseif artist ~= "" then
    search_artist(artist)
  else
    SR.err = E("err_empty_q")
  end
end

-- Собрать список песен исполнителя из двух источников
local function build_song_list()
  local q = ulower(SR.artist)
  local by_key, list = {}, {}
  local function artist_ok(name) return name and ulower(name):find(q, 1, true) end
  local function add(title, album, dur, lrc)
    if not title or title == "" then return end
    local k = song_key(title)
    if k == "" then k = ulower(title) end
    local s = by_key[k]
    if not s then
      s = { title = title, album = album, dur = dur }
      by_key[k] = s
      list[#list + 1] = s
    end
    if lrc then
      -- лучше синхронизированный текст
      if not s.lrc or (lrc.syncedLyrics and not s.lrc.syncedLyrics) then s.lrc = lrc end
    end
  end

  for _, res in ipairs(SR.raw.lrc_artist or {}) do
    if artist_ok(res.artistName) and (res.syncedLyrics or res.plainLyrics) then
      add(res.trackName, res.albumName, res.duration, res)
    end
  end
  local it = SR.raw.itunes
  for _, res in ipairs(type(it) == "table" and it.results or {}) do
    if artist_ok(res.artistName) then
      add(res.trackName, res.collectionName, res.trackTimeMillis and res.trackTimeMillis / 1000)
    end
  end
  table.sort(list, function(a, b) return ulower(a.title) < ulower(b.title) end)
  return list
end

-- Каждый кадр
local function poll_search()
  for name in pairs(SR.pending) do
    local st, data = poll_job(name)
    if st then
      SR.pending[name] = nil
      if st == "done" then
        SR.raw[name] = data
      elseif name == "lrc_track" or not next(SR.pending) and not SR.raw.lrc_artist and not SR.raw.itunes then
        SR.err = data
      end
      if name == "lrc_track" and st == "done" then
        SR.versions = data
        if #data == 0 then SR.err = E("err_no_lyrics") end
      end
    end
  end
  if SR.view == "songs" and not SR.songs and not SR.pending.lrc_artist and not SR.pending.itunes
     and (SR.raw.lrc_artist or SR.raw.itunes) then
    SR.songs = build_song_list()
    if #SR.songs == 0 then SR.err = E("err_no_songs") end
  end
end

---------------------------------------------------------------------------
-- Маркеры на таймлайне
---------------------------------------------------------------------------
local MARK_PREFIX = "♪ "

local function export_markers()
  r.Undo_BeginBlock()
  local _, nm, nr = r.CountProjectMarkers(0)
  for i = nm + nr - 1, 0, -1 do
    local _, isrgn, _, _, name, idx = r.EnumProjectMarkers3(0, i)
    if not isrgn and name:sub(1, #MARK_PREFIX) == MARK_PREFIX then r.DeleteProjectMarker(0, idx, false) end
  end
  for _, l in ipairs(S.lines) do
    if l.t and l.text ~= "" then
      r.AddProjectMarker2(0, false, S.offset + l.t, 0, MARK_PREFIX .. l.text, -1, 0)
    end
  end
  r.Undo_EndBlock(T("markers_undo"), -1)
end

---------------------------------------------------------------------------
-- Настройки вида
---------------------------------------------------------------------------
local function prompter_controls(width)
  ImGui.SetNextItemWidth(ctx, width)
  local rv, v = ImGui.SliderInt(ctx, T("font_size") .. "###fs", VIEW.fsize, 1, #BIG_SIZES, "%d")
  if rv then VIEW.fsize = v; save_view() end
  ImGui.SetNextItemWidth(ctx, width)
  local rv2, v2 = ImGui.SliderDouble(ctx, T("opacity") .. "###op", VIEW.alpha, 0.15, 1.0, "%.2f")
  if rv2 then VIEW.alpha = v2; save_view() end
  ImGui.TextColored(ctx, COL.faint, T("opacity_note"))
  local rv3, v3 = ImGui.Checkbox(ctx, T("compact") .. "###cmp", VIEW.compact)
  if rv3 then VIEW.compact = v3; save_view() end
end

-- Быстрое меню «Вид» (кнопка в суфлёре и правый клик)
local function draw_view_settings()
  ImGui.TextColored(ctx, COL.dim, T("view"))
  prompter_controls(180)
  local rv, v = ImGui.Checkbox(ctx, T("accent_line") .. "###acl_q", VIEW.accent_line)
  if rv then VIEW.accent_line = v; save_view() end
  ImGui.TextColored(ctx, COL.faint, T("all_settings"))
end

-- Вкладка «Настройки»
local function draw_settings()
  section(T("sec_theme"))
  for i, th in ipairs(THEMES) do
    local label = T(th.name) .. "###th_" .. th.id
    if i > 1 then flow(button_w(label) + 24) end
    if ImGui.RadioButton(ctx, label, VIEW.theme == th.id) then VIEW.theme = th.id; save_view() end
  end

  section(T("sec_accent"))
  local sw = 30
  for i, acc in ipairs(ACCENTS) do
    if i > 1 then flow(sw) end
    local selected = (VIEW.accent & 0xFFFFFF00) == (acc.c & 0xFFFFFF00)
    if selected then
      ImGui.PushStyleColor(ctx, ImGui.Col_Border, COL.text)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 2)
    end
    -- с ColorEditFlags_NoAlpha ReaImGui ждёт 0xRRGGBB, а не 0xRRGGBBAA
    if ImGui.ColorButton(ctx, T(acc.name) .. "###acc" .. i, acc.c >> 8, ImGui.ColorEditFlags_NoAlpha, sw, sw) then
      VIEW.accent = acc.c; save_view()
    end
    if selected then ImGui.PopStyleVar(ctx); ImGui.PopStyleColor(ctx) end
  end
  -- свой цвет: ColorEdit3 работает с 0xRRGGBB
  local rv, rgb = ImGui.ColorEdit3(ctx, T("acc_custom") .. "###acc_custom", VIEW.accent >> 8,
                                   ImGui.ColorEditFlags_NoInputs)
  if rv then VIEW.accent = ((rgb & 0xFFFFFF) << 8) | 0xFF; save_view() end
  local rv2, v2 = ImGui.Checkbox(ctx, T("accent_line") .. "###acl", VIEW.accent_line)
  if rv2 then VIEW.accent_line = v2; save_view() end

  section(T("sec_prompter"))
  prompter_controls(-170)

  section(T("sec_language"))
  if ImGui.RadioButton(ctx, "Русский###lang_ru", lang == "ru") then set_lang("ru") end
  flow(button_w("English") + 24)
  if ImGui.RadioButton(ctx, "English###lang_en", lang == "en") then set_lang("en") end

  ImGui.Dummy(ctx, 0, 6)
  if ImGui.Button(ctx, T("reset_view") .. "###reset_view") then
    if r.MB(T("reset_view_q"), "Vocal Prompter", 4) == 6 then reset_view() end
  end
end

---------------------------------------------------------------------------
-- Вкладка «Суфлёр»
---------------------------------------------------------------------------
local function draw_prompter()
  local pos, st = now_pos()
  local recording = st & 4 == 4

  -- Верхняя строка: название песни слева; REC, время и кнопка «Вид» справа.
  -- Ширину меряем ДО названия: после него курсор уже на новой строке.
  local time_s = fmt_time(pos - S.offset)
  local rec_s  = "● REC"
  local view_label = T("view") .. "###view"
  local right_w = ImGui.CalcTextSize(ctx, time_s) + button_w(view_label) + 16
  if recording then right_w = right_w + ImGui.CalcTextSize(ctx, rec_s) + 8 end
  local x0 = ImGui.GetCursorPosX(ctx)
  local full_w = ImGui.GetContentRegionAvail(ctx)

  ImGui.PushFont(ctx, F_HEAD)
  local title = S.name ~= "" and S.name or "Vocal Prompter"
  ImGui.TextColored(ctx, S.name ~= "" and COL.next or COL.faint, fit_text(title, math.max(16, full_w - right_w - 12)))
  ImGui.PopFont(ctx)

  ImGui.SameLine(ctx, x0 + math.max(0, full_w - right_w))
  if recording then ImGui.TextColored(ctx, COL.rec, rec_s); ImGui.SameLine(ctx) end
  ImGui.TextColored(ctx, COL.dim, time_s)
  ImGui.SameLine(ctx)
  if ImGui.SmallButton(ctx, view_label) then ImGui.OpenPopup(ctx, "vp_view") end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, T("compact_tip")) end
  if ImGui.BeginPopup(ctx, "vp_view") then draw_view_settings(); ImGui.EndPopup(ctx) end

  ImGui.Separator(ctx)

  -- Сообщения, если суфлёру нечего показывать
  local function message(txt)
    ImGui.Dummy(ctx, 0, 20)
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.dim, txt)
    ImGui.PopTextWrapPos(ctx)
  end
  if #S.lines == 0 then return message(T("no_text")) end
  local order = timed_order()
  if #order == 0 then return message(T("no_timing")) end

  local t = pos - S.offset + S.lead
  local k = find_current(order, t)
  local fb, fm = F_BIG[VIEW.fsize], F_MID[VIEW.fsize]
  local function line_text(j) local i = order[j]; if not i then return nil end
    local s = S.lines[i].text; return s ~= "" and s or "♪" end

  -- Что рисуем: предыдущая, текущая (+ полоска), две следующие
  local items = {}
  local prev = k and line_text(k - 1)
  items[#items + 1] = { font = fm, color = COL.faint, text = prev or " " }
  items[#items + 1] = { gap = 6 }
  if k then
    items[#items + 1] = { font = fb, color = COL.cur, text = line_text(k) }
  else
    items[#items + 1] = { font = fb, color = COL.dim, text = T("intro", S.lines[order[1]].t - t) }
  end
  local frac
  if k and order[k + 1] then
    local a, b = S.lines[order[k]].t, S.lines[order[k + 1]].t
    frac = math.max(0, math.min(1, (t - a) / (b - a)))
  end
  items[#items + 1] = { progress = frac }
  local n1, n2 = line_text((k or 0) + 1), line_text((k or 0) + 2)
  if n1 then items[#items + 1] = { font = fm, color = COL.next, text = n1 } end
  if n2 then items[#items + 1] = { font = fm, color = COL.dim,  text = n2 } end

  -- Измеряем и центрируем блок по вертикали и каждую строку по горизонтали
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local x0, y0 = ImGui.GetCursorPosX(ctx), ImGui.GetCursorPosY(ctx)
  local maxw = math.max(50, avail_w - 16)
  local total = 0
  for _, it in ipairs(items) do
    if it.text then
      ImGui.PushFont(ctx, it.font)
      it.lines = wrap_lines(it.text, maxw)
      it.lh = ImGui.GetTextLineHeightWithSpacing(ctx)
      ImGui.PopFont(ctx)
      total = total + #it.lines * it.lh
    elseif it.gap then
      total = total + it.gap
    else
      total = total + 18
    end
  end
  local y = y0 + math.max(0, (avail_h - total) * 0.45)

  for _, it in ipairs(items) do
    if it.text then
      ImGui.PushFont(ctx, it.font)
      for _, ln in ipairs(it.lines) do
        local w = ImGui.CalcTextSize(ctx, ln)
        ImGui.SetCursorPos(ctx, x0 + math.max(0, (avail_w - w) / 2), y)
        ImGui.TextColored(ctx, it.color, ln)
        y = y + it.lh
      end
      ImGui.PopFont(ctx)
    elseif it.gap then
      y = y + it.gap
    else
      local pw = math.min(avail_w * 0.6, 420)
      ImGui.SetCursorPos(ctx, x0 + (avail_w - pw) / 2, y + 6)
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, COL.progress)
      ImGui.ProgressBar(ctx, it.progress or 0, pw, 3, "")
      ImGui.PopStyleColor(ctx)
      y = y + 18
    end
  end
  ImGui.SetCursorPos(ctx, x0, y)
  ImGui.Dummy(ctx, 1, 1)
end

---------------------------------------------------------------------------
-- Вкладка «Синхро»
---------------------------------------------------------------------------
local function do_tap(song_t)
  local l = S.lines[tap_idx]
  if not l then return end
  l.t = math.max(0, song_t)
  tap_idx = tap_idx + 1
  mark_dirty(); buf_stale = true
end

local function draw_sync()
  local pos = now_pos()
  local song_t = pos - S.offset

  section(T("sec_timing"))
  ImGui.SetNextItemWidth(ctx, 110)
  local rv, v = ImGui.DragDouble(ctx, T("offset") .. "###offset", S.offset, 0.01, -3600, 36000, "%.2f")
  if rv then S.offset = v; mark_dirty() end
  ImGui.SameLine(ctx)
  if ImGui.SmallButton(ctx, T("offset_cursor") .. "###ocur") then S.offset = r.GetCursorPosition(); mark_dirty() end

  ImGui.SetNextItemWidth(ctx, 110)
  rv, v = ImGui.SliderDouble(ctx, T("lead") .. "###lead", S.lead, 0, 1.5, "%.2f")
  if rv then S.lead = v; mark_dirty() end

  if #S.lines == 0 then
    ImGui.Dummy(ctx, 0, 10)
    ImGui.TextColored(ctx, COL.dim, T("sync_need_text"))
    return
  end

  ImGui.Dummy(ctx, 0, 4)
  ImGui.PushFont(ctx, F_TAP)
  local tapped = accent_button(T("tap") .. "###tap", -1, 54)
  ImGui.PopFont(ctx)
  if tapped then do_tap(song_t) end
  local focused = ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows)
  if focused and not ImGui.IsAnyItemActive(ctx) and
     (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter, false) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter, false)
      or ImGui.IsKeyPressed(ctx, ImGui.Key_T, false)) then
    do_tap(song_t)
  end

  local target = S.lines[tap_idx]
  ImGui.PushTextWrapPos(ctx, 0)
  ImGui.TextColored(ctx, COL.dim, target and T("next_tap", tap_idx, target.text ~= "" and target.text or "♪")
                                       or T("all_tapped"))
  ImGui.PopTextWrapPos(ctx)

  if ImGui.Button(ctx, T("tap_restart") .. "###trs") then tap_idx = 1 end
  flow(button_w(T("clear_timing")))
  if ImGui.Button(ctx, T("clear_timing") .. "###clt") then
    if r.MB(T("clear_timing_q"), "Vocal Prompter", 4) == 6 then
      for _, l in ipairs(S.lines) do l.t = nil end
      tap_idx = 1; mark_dirty(); buf_stale = true
    end
  end
  flow(button_w(T("to_markers")))
  if ImGui.Button(ctx, T("to_markers") .. "###mrk") then export_markers() end

  flow(button_w(ImGui.IsWindowDocked(ctx) and T("undock") or T("dock")))
  if ImGui.IsWindowDocked(ctx) then
    if ImGui.Button(ctx, T("undock") .. "###dock") then dock_req = 0 end
  else
    if ImGui.Button(ctx, T("dock") .. "###dock") then dock_req = -1 end
  end

  section(T("sec_lines"))

  local order = timed_order()
  local k = find_current(order, song_t + S.lead)
  local cur_i = k and order[k] or nil

  if ImGui.BeginTable(ctx, "lines", 3, ImGui.TableFlags_RowBg) then
    ImGui.TableSetupColumn(ctx, "t",    ImGui.TableColumnFlags_WidthFixed, 64)
    ImGui.TableSetupColumn(ctx, "go",   ImGui.TableColumnFlags_WidthFixed, 20)
    ImGui.TableSetupColumn(ctx, "text", ImGui.TableColumnFlags_WidthStretch)
    for i, l in ipairs(S.lines) do
      ImGui.PushID(ctx, tostring(i))
      ImGui.TableNextRow(ctx)

      ImGui.TableNextColumn(ctx)
      if l.t then
        ImGui.SetNextItemWidth(ctx, -1)
        local rv2, v2 = ImGui.DragDouble(ctx, "##t", l.t, 0.01, 0, 36000, "%.2f")
        if rv2 then l.t = v2; mark_dirty(); buf_stale = true end
      else
        ImGui.TextColored(ctx, COL.dim, "—")
      end

      ImGui.TableNextColumn(ctx)
      if l.t and ImGui.SmallButton(ctx, ">") then r.SetEditCurPos(S.offset + l.t, true, true) end

      ImGui.TableNextColumn(ctx)
      local hl = (i == cur_i)
      if hl then ImGui.PushStyleColor(ctx, ImGui.Col_Text, COL.cur) end
      if l.text == "" and not hl then ImGui.PushStyleColor(ctx, ImGui.Col_Text, COL.dim) end
      if ImGui.Selectable(ctx, (l.text ~= "" and l.text or T("interlude")) .. "###sel", i == tap_idx) then tap_idx = i end
      if l.text == "" and not hl then ImGui.PopStyleColor(ctx) end
      if hl then ImGui.PopStyleColor(ctx) end

      ImGui.PopID(ctx)
    end
    ImGui.EndTable(ctx)
  end
end

---------------------------------------------------------------------------
-- Вкладка «Текст»
---------------------------------------------------------------------------
local function fmt_dur(d)
  if type(d) ~= "number" then return "" end
  return string.format("%d:%02d", math.floor(d / 60), math.floor(d % 60))
end

-- Строка результата: основной текст, серые детали, цветная пометка
local function result_row(id, main, sub, tag, tag_col, dim_main)
  local x = ImGui.GetCursorPosX(ctx)
  local clicked = ImGui.Selectable(ctx, "###" .. id, false)
  ImGui.SameLine(ctx, x + 4)
  ImGui.TextColored(ctx, dim_main and COL.dim or COL.text, main)
  if sub and sub ~= "" then ImGui.SameLine(ctx); ImGui.TextColored(ctx, COL.faint, sub) end
  if tag and tag ~= "" then ImGui.SameLine(ctx); ImGui.TextColored(ctx, tag_col, tag) end
  return clicked
end

local function draw_text()
  if buf_stale and not ImGui.IsAnyItemActive(ctx) then
    edit_buf = to_lrc(S.lines)
    buf_stale, edit_dirty = false, false
  end

  section(T("song"))
  ImGui.SetNextItemWidth(ctx, -1)
  local rvn, nv = ImGui.InputTextWithHint(ctx, "###songname", T("song_hint"), S.name)
  if rvn then S.name = nv; mark_dirty() end

  section(T("sec_text"))
  ImGui.PushTextWrapPos(ctx, 0)
  ImGui.TextColored(ctx, COL.dim, T("text_hint"))
  ImGui.PopTextWrapPos(ctx)

  local _, h = ImGui.GetContentRegionAvail(ctx)
  local rv
  local eh = SR.view and math.max(110, (h - 190) * 0.4) or math.max(160, h - 270)
  rv, edit_buf = ImGui.InputTextMultiline(ctx, "##lyrics", edit_buf, -1, eh)
  if rv then edit_dirty = true end

  if accent_button(T("apply") .. "###apply") then
    local lines, meta = parse_lyrics(edit_buf)
    local nm = song_name(meta.ar, meta.ti)
    set_lines(lines, nm ~= "" and nm or nil)
  end
  flow(button_w(T("open_file")))
  if ImGui.Button(ctx, T("open_file") .. "###open") then
    local ok, path = r.GetUserFileNameForRead("", T("open_title"), "*.txt;*.lrc")
    if ok then
      local data = read_file(path)
      if data then
        local lines, meta = parse_lyrics(data)
        local nm = song_name(meta.ar, meta.ti)
        if nm == "" then nm = path:match("([^/\\]+)$"):gsub("%.%w+$", "") end
        set_lines(lines, nm)
      end
    end
  end
  flow(button_w(T("clear")))
  if ImGui.Button(ctx, T("clear") .. "###clear") then
    if r.MB(T("clear_q"), "Vocal Prompter", 4) == 6 then set_lines({}, "") end
  end
  if edit_dirty then
    flow(ImGui.CalcTextSize(ctx, T("not_applied")))
    ImGui.TextColored(ctx, COL.warn, T("not_applied"))
  end

  section(T("search_head"))
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, T("search_hint")) end

  ImGui.SetNextItemWidth(ctx, -100)
  -- Без InputTextFlags_EnterReturnsTrue: с ним ReaImGui отдаёт введённый текст
  -- только по Enter, и стёртое название возвращалось обратно. Enter ловим отдельно.
  local function search_field(label, value)
    local _, v = ImGui.InputText(ctx, label, value)
    local enter = ImGui.IsItemDeactivated(ctx) and
      (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter, false) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter, false))
    return enter, v
  end
  local enter1, enter2
  enter1, q_artist = search_field(T("artist") .. "###qa", q_artist)
  ImGui.SetNextItemWidth(ctx, -100)
  enter2, q_title = search_field(T("title") .. "###qt", q_title)

  if busy() then
    ImGui.BeginDisabled(ctx)
    ImGui.Button(ctx, T("searching") .. "###search")
    ImGui.EndDisabled(ctx)
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COL.dim, T("sec_short", r.time_precise() - busy_since()))
  elseif accent_button(T("search") .. "###search") or enter1 or enter2 then
    SR.from_songs = false
    start_search(q_artist, q_title)
  end
  if SR.err then
    ImGui.SameLine(ctx)
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.warn, err_text(SR.err) .. (SR.err.hint and T("err_net_hint") or ""))
    ImGui.PopTextWrapPos(ctx)
  end

  if not SR.view then
    ImGui.TextColored(ctx, COL.faint, T("search_hint"))
    return
  end
  ImGui.Spacing(ctx)

  -- Список песен исполнителя
  if SR.view == "songs" and SR.songs and #SR.songs > 0 then
    local f = ulower(SR.song_filter)
    local shown = {}
    for _, s in ipairs(SR.songs) do
      if f == "" or ulower(s.title):find(f, 1, true) then shown[#shown + 1] = s end
    end
    ImGui.Text(ctx, T("songs_of", SR.artist, #shown))
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, -1)
    _, SR.song_filter = ImGui.InputTextWithHint(ctx, "###sf", T("filter"), SR.song_filter)

    if ImGui.BeginChild(ctx, "songs", 0, 0, ImGui.ChildFlags_Border) then
      for i, s in ipairs(shown) do
        local tag = s.lrc and (s.lrc.syncedLyrics and T("synced") or T("has_lyrics")) or ""
        local sub = (s.album and s.album or "") .. (s.dur and ("  " .. fmt_dur(s.dur)) or "")
        if result_row("song" .. i, s.title, sub, tag, s.lrc and s.lrc.syncedLyrics and COL.synced or COL.next,
                      not s.lrc) and not busy() then
          SR.from_songs = true
          search_track(SR.artist, s.title)
          -- если LRCLIB уже знает песню, показываем её версии сразу, пока идёт уточняющий поиск
          if s.lrc and not SR.versions then SR.versions = { s.lrc } end
        end
      end
      ImGui.EndChild(ctx)
    end

  -- Версии текста конкретной песни
  elseif SR.view == "versions" then
    if SR.from_songs then
      if ImGui.SmallButton(ctx, T("back_songs") .. "###back") then
        SR.view, SR.versions, SR.err = "songs", nil, nil
        return
      end
      ImGui.SameLine(ctx)
    end
    ImGui.Text(ctx, T("versions_of", SR.versions_title))
    if SR.versions and ImGui.BeginChild(ctx, "versions", 0, 0, ImGui.ChildFlags_Border) then
      for i, res in ipairs(SR.versions) do
        local has = res.syncedLyrics or res.plainLyrics
        local main = (res.artistName or "?") .. " — " .. (res.trackName or "?")
        local sub = (res.albumName or "") .. (res.duration and ("  " .. fmt_dur(res.duration)) or "")
        local tag = res.syncedLyrics and T("synced") or (has and T("plain") or T("none"))
        if result_row("res" .. i, main, sub, tag, res.syncedLyrics and COL.synced or COL.dim, not has) and has then
          set_lines((parse_lyrics(res.syncedLyrics or res.plainLyrics)), song_name(res.artistName, res.trackName))
        end
      end
      ImGui.EndChild(ctx)
    end
  end
end

---------------------------------------------------------------------------
-- Главный цикл
---------------------------------------------------------------------------
local cur_file
cur_proj, cur_file = r.EnumProjects(-1)
load_state(cur_proj)

local function loop()
  -- Другой проект: переключилась вкладка (другой указатель) или в той же вкладке
  -- открыли другой файл / создали новый (указатель тот же, имя файла другое)
  local proj, file = r.EnumProjects(-1)
  if proj ~= cur_proj or file ~= cur_file then
    if dirty and proj ~= cur_proj and r.ValidatePtr(cur_proj, "ReaProject*") then save_state(cur_proj) end
    cur_proj, cur_file = proj, file
    load_state(cur_proj)
    SR.view, SR.err = nil, nil
  end

  if next(SR.pending) then poll_search() end

  if dock_req ~= nil then ImGui.SetNextWindowDockID(ctx, dock_req); dock_req = nil end
  ImGui.SetNextWindowSize(ctx, 480, 660, ImGui.Cond_FirstUseEver)
  -- Окно развернули после сворачивания, а оно осталось полоской: возвращаем размер.
  -- Причина в ReaImGui: если пока окно свёрнуто, приходит событие изменения размера
  -- от Windows (PlatformRequestResize), Dear ImGui записывает высоту заголовка в
  -- «полный» размер окна (SizeFull), и разворачивать становится некуда.
  if WIN.restore and WIN.w then
    ImGui.SetNextWindowSize(ctx, WIN.w, WIN.h, ImGui.Cond_Always)
    WIN.restore = false
  end
  ImGui.SetNextWindowBgAlpha(ctx, VIEW.alpha)
  local nc, nv = push_theme()
  ImGui.PushFont(ctx, F_UI)

  local wtitle = S.name ~= "" and ("Vocal Prompter — " .. S.name) or "Vocal Prompter"
  local wflags = VIEW.compact and ImGui.WindowFlags_NoScrollbar or 0
  local visible, open = ImGui.Begin(ctx, wtitle .. "###VocalPrompter", true, wflags)
  if not visible then
    WIN.collapsed = true          -- свёрнуто (или неактивная вкладка дока)
  elseif ImGui.IsWindowDocked(ctx) then
    WIN.collapsed = false         -- в доке размер задаёт REAPER
  else
    local w, h = ImGui.GetWindowSize(ctx)
    if WIN.collapsed then
      WIN.collapsed = false
      if h <= COLLAPSED_MAX_H and WIN.h and WIN.h > h + 20 then WIN.restore = true end
    elseif h > COLLAPSED_MAX_H then
      WIN.w, WIN.h = w, h
    end
  end
  if visible then
    if VIEW.compact then
      draw_prompter()
    elseif ImGui.BeginTabBar(ctx, "tabs") then
      -- ### держит ID вкладки постоянным, чтобы при смене языка она не сбрасывалась
      if ImGui.BeginTabItem(ctx, T("tab_prompter") .. "###tp") then draw_prompter(); ImGui.EndTabItem(ctx) end
      if ImGui.BeginTabItem(ctx, T("tab_sync")     .. "###ts") then draw_sync();     ImGui.EndTabItem(ctx) end
      if ImGui.BeginTabItem(ctx, T("tab_text")     .. "###tt") then draw_text();     ImGui.EndTabItem(ctx) end
      if ImGui.BeginTabItem(ctx, T("tab_settings") .. "###tset") then draw_settings(); ImGui.EndTabItem(ctx) end

      -- переключатель языка справа
      if ImGui.TabItemButton(ctx, (lang == "ru" and "RU · en" or "ru · EN") .. "###lang",
                             ImGui.TabItemFlags_Trailing | ImGui.TabItemFlags_NoTooltip) then
        set_lang(lang == "ru" and "en" or "ru")
      end
      if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, T("lang_tip")) end

      ImGui.EndTabBar(ctx)
    end

    -- правый клик в любом месте окна — настройки вида
    if ImGui.BeginPopupContextWindow(ctx, "vp_ctx", ImGui.PopupFlags_MouseButtonRight | ImGui.PopupFlags_NoOpenOverItems) then
      draw_view_settings()
      ImGui.EndPopup(ctx)
    end
    ImGui.End(ctx)
  end

  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx, nv)
  ImGui.PopStyleColor(ctx, nc)

  if dirty and not ImGui.IsAnyItemActive(ctx) then save_state(cur_proj); dirty = false end

  if open then
    r.defer(loop)
  elseif dirty and r.ValidatePtr(cur_proj, "ReaProject*") then
    save_state(cur_proj)
  end
end

-- Точка входа для автотестов (tests/run_tests.lua). В REAPER VP_TEST не задан.
if VP_TEST then
  return {
    T = T, STR = STR, set_lang = set_lang, get_lang = function() return lang end,
    parse_lyrics = parse_lyrics, to_lrc = to_lrc, song_name = song_name, song_key = song_key,
    ulower = ulower, json_decode = json_decode, urlencode = urlencode, fmt_time = fmt_time,
    timed_order = timed_order, find_current = find_current, wrap_lines = wrap_lines,
    load_state = load_state, save_state = save_state, set_lines = set_lines, do_tap = do_tap,
    export_markers = export_markers, start_job = start_job, poll_job = poll_job,
    start_search = start_search, search_track = search_track, poll_search = poll_search,
    build_song_list = build_song_list, imgui_has = imgui_has, loop = loop,
    S = function() return S end, SR = SR, VIEW = VIEW, jobs = jobs, COL = COL,
    THEMES = THEMES, ACCENTS = ACCENTS, update_colors = update_colors, mix = mix, fit_text = fit_text,
    tap_idx = function() return tap_idx end, dirty = function() return dirty end,
    queries = function() return q_artist, q_title end,
  }
end

r.defer(loop)
