-- Моки REAPER и ReaImGui для автотестов Vocal Prompter.
--
-- ReaImGui-мок «строгий»: знает список имён, доступных скриптам, которые просят
-- API 0.9 (tests/reaimgui_api_0.9.txt, генерируется из исходников ReaImGui), и при
-- обращении к любому другому имени падает той же ошибкой, что и настоящий
-- ReaImGui. Ещё он проверяет парность Begin/End, Push/Pop и т. п. в каждом кадре.

local M = {}

---------------------------------------------------------------------------
-- Виртуальная файловая система (io.open / os.remove для скрипта)
---------------------------------------------------------------------------
function M.new_fs()
  local fs = { files = {} }
  local function handle(path, mode)
    local buf = {}
    local h = {}
    function h:write(...) for _, s in ipairs({ ... }) do buf[#buf + 1] = tostring(s) end return h end
    function h:read(fmt) return fs.files[path] end
    function h:close() if mode:find("w") then fs.files[path] = table.concat(buf) end end
    return h
  end
  fs.io = {
    open = function(path, mode)
      mode = mode or "r"
      if mode:find("r") then
        if fs.files[path] == nil then return nil, path .. ": No such file or directory" end
      end
      return handle(path, mode)
    end,
  }
  fs.os = setmetatable({
    remove = function(path) fs.files[path] = nil return true end,
  }, { __index = os })
  return fs
end

---------------------------------------------------------------------------
-- REAPER
---------------------------------------------------------------------------
function M.new_reaper(opts)
  opts = opts or {}
  local R = {
    os_name   = opts.os or "Win64",
    resource  = opts.resource or "C:\\Users\\Тест\\AppData\\Roaming\\REAPER",
    proj      = { ptr = "P1", file = "C:\\songs\\a.rpp" },
    ext       = {},            -- [proj][key] = value (секция VocalPrompter)
    gext      = {},            -- глобальный ExtState
    valid     = { P1 = true },
    play_state = 0, play_pos = 0, cursor = 0,
    clock     = 0,
    markers   = {},            -- { pos=, name=, idx= }
    exec      = {},            -- вызовы ExecProcess
    mb        = {},            -- показанные MessageBox
    mb_answer = 6,             -- 6 = «Да»
    dirty_marks = 0,
    undo      = {},
  }
  local reaper = {}
  R.api = reaper

  reaper.ImGui_GetBuiltinPath = function() return "/imgui" end
  reaper.GetOS = function() return R.os_name end
  reaper.GetResourcePath = function() return R.resource end
  reaper.RecursiveCreateDirectory = function() return 1 end
  reaper.time_precise = function() return R.clock end
  reaper.defer = function() end

  reaper.GetExtState = function(sec, key) return R.gext[sec .. "/" .. key] or "" end
  reaper.SetExtState = function(sec, key, v) R.gext[sec .. "/" .. key] = v end

  reaper.EnumProjects = function(idx) return R.proj.ptr, R.proj.file end
  reaper.ValidatePtr = function(p) return R.valid[p] == true end
  reaper.GetProjExtState = function(p, sec, key)
    local v = (R.ext[p] or {})[key]
    return v and 1 or 0, v or ""
  end
  reaper.SetProjExtState = function(p, sec, key, v)
    assert(R.valid[p], "SetProjExtState on invalid project pointer " .. tostring(p))
    R.ext[p] = R.ext[p] or {}
    if key == "" then R.ext[p] = {} else R.ext[p][key] = v end
    return 1
  end
  reaper.MarkProjectDirty = function() R.dirty_marks = R.dirty_marks + 1 end

  reaper.GetPlayState = function() return R.play_state end
  reaper.GetPlayPosition = function() return R.play_pos end
  reaper.GetCursorPosition = function() return R.cursor end
  reaper.SetEditCurPos = function(t) R.cursor = t end

  reaper.CountProjectMarkers = function()
    return #R.markers, #R.markers, 0
  end
  reaper.EnumProjectMarkers3 = function(p, i)
    local m = R.markers[i + 1]
    return 1, false, m.pos, 0, m.name, m.idx
  end
  reaper.DeleteProjectMarker = function(p, idx, isrgn)
    for i, m in ipairs(R.markers) do if m.idx == idx then table.remove(R.markers, i) return true end end
    return false
  end
  local next_idx = 100
  reaper.AddProjectMarker2 = function(p, isrgn, pos, rgnend, name, want, color)
    next_idx = next_idx + 1
    R.markers[#R.markers + 1] = { pos = pos, name = name, idx = next_idx }
    return next_idx
  end
  reaper.Undo_BeginBlock = function() end
  reaper.Undo_EndBlock = function(name) R.undo[#R.undo + 1] = name end

  reaper.ExecProcess = function(cmd, timeout)
    R.exec[#R.exec + 1] = { cmd = cmd, timeout = timeout }
    return ""
  end
  reaper.MB = function(msg, title, kind)
    R.mb[#R.mb + 1] = msg
    return R.mb_answer
  end
  reaper.GetUserFileNameForRead = function() return false, "" end

  setmetatable(reaper, { __index = function(_, k)
    error("test mock: reaper." .. tostring(k) .. " is not mocked", 2)
  end })
  return R
end

---------------------------------------------------------------------------
-- ReaImGui (API 0.9, строгий)
---------------------------------------------------------------------------
local function load_api_list(path)
  local set = {}
  local f = assert(io.open(path, "r"), "can't open " .. path)
  for line in f:lines() do if line ~= "" then set[line] = true end end
  f:close()
  return set
end

-- Имена-функции, которые выглядят как константы (Префикс_Имя)
local FUNC_PREFIXES = { "DrawList_", "ListClipper_", "TextFilter_", "Viewport_", "Function_",
                        "Image_", "Font_", "DrawListSplitter_", "ImageSet_" }
local function is_constant(name)
  if not name:match("^%u%a*_[%w_]+$") then return false end
  for _, p in ipairs(FUNC_PREFIXES) do if name:sub(1, #p) == p then return false end end
  return true
end

-- Пары Begin*/End*: tag → закрывающая функция; when_true = End только если Begin вернул true
local PAIRS = {
  Begin                   = { close = "End",          when_true = true },
  BeginChild              = { close = "EndChild",     when_true = true },
  BeginTabBar             = { close = "EndTabBar",    when_true = true },
  BeginTabItem            = { close = "EndTabItem",   when_true = true },
  BeginTable              = { close = "EndTable",     when_true = true },
  BeginPopup              = { close = "EndPopup",     when_true = true },
  BeginPopupContextWindow = { close = "EndPopup",     when_true = true },
  BeginDisabled           = { close = "EndDisabled",  when_true = false },
  PushID                  = { close = "PopID" },
  PushFont                = { close = "PopFont" },
  PushTextWrapPos         = { close = "PopTextWrapPos" },
}
local CLOSERS = {}
for open, p in pairs(PAIRS) do CLOSERS[p.close] = CLOSERS[p.close] or {}; CLOSERS[p.close][open] = true end

function M.new_imgui(api_path)
  local api = load_api_list(api_path)
  local G = {
    api = api,
    used = {},              -- какие имена скрипт трогал
    stack = {},
    colors = 0, vars = 0,
    texts = {},             -- весь текст кадра
    clicks = {},            -- id/label → true: «нажать» в этом кадре
    tab = "tp",             -- какая вкладка открыта (###tp / ###ts / ###tt)
    keys = {},              -- Key_* → нажата
    inputs = {},            -- id → новое значение поля ввода
    avail_w = 420, avail_h = 560,
    begin_visible = true,
    popups = {},            -- открытые попапы
    frame_errors = {},
    ctx = { "ImGui_Context" },
  }

  local function err(msg) error("ImGui mock: " .. msg, 3) end
  local function id_of(label)
    local id = label:match("###(.+)$") or label:match("##(.+)$")
    return id or label
  end
  local function push(tag, label) G.stack[#G.stack + 1] = { tag = tag, label = label } end
  local function pop(closer)
    local top = G.stack[#G.stack]
    if not top or not CLOSERS[closer][top.tag] then
      err(closer .. " without matching opener (top: " .. (top and top.tag or "empty") .. ")")
    end
    G.stack[#G.stack] = nil
  end
  local function check_ctx(name, c)
    if c ~= G.ctx then err(name .. ": first argument must be the context") end
  end
  local function text(s) G.texts[#G.texts + 1] = s end
  local function clicked(label) return G.clicks[id_of(label)] == true end

  local impl = {}
  local cid = 0
  local function const(name) return function() cid = cid + 1; return cid end end

  impl.CreateContext = function() return G.ctx end
  impl.CreateFont = function(family, size) return { "font", size = size } end
  impl.Attach = function(c, obj) check_ctx("Attach", c) end
  impl.GetBuiltinPath = function() return "/imgui" end

  impl.Begin = function(c, name, open, flags)
    check_ctx("Begin", c)
    if not name:find("###", 1, true) then err("Begin: window needs a stable ### id") end
    if G.begin_visible then push("Begin", name) end
    return G.begin_visible, not G.close_window
  end
  impl.End = function(c) check_ctx("End", c); pop("End") end

  for open, p in pairs(PAIRS) do
    if not impl[open] then
      impl[open] = function(c, label, ...)
        check_ctx(open, c)
        local ret = true
        if open == "BeginTabItem" then ret = id_of(label) == G.tab
        elseif open == "BeginPopup" or open == "BeginPopupContextWindow" then ret = G.popups[label] == true end
        if p.when_true == nil or not p.when_true or ret then push(open, label) end
        return ret
      end
    end
    if not impl[p.close] then
      impl[p.close] = function(c) check_ctx(p.close, c); pop(p.close) end
    end
  end

  impl.PushStyleColor = function(c, idx, col)
    check_ctx("PushStyleColor", c)
    if type(idx) ~= "number" or type(col) ~= "number" then err("PushStyleColor: bad args") end
    G.colors = G.colors + 1
  end
  impl.PopStyleColor = function(c, n) check_ctx("PopStyleColor", c); G.colors = G.colors - (n or 1)
    if G.colors < 0 then err("PopStyleColor: too many pops") end end
  impl.PushStyleVar = function(c, idx, a, b) check_ctx("PushStyleVar", c)
    if type(idx) ~= "number" or type(a) ~= "number" then err("PushStyleVar: bad args") end
    G.vars = G.vars + 1 end
  impl.PopStyleVar = function(c, n) check_ctx("PopStyleVar", c); G.vars = G.vars - (n or 1)
    if G.vars < 0 then err("PopStyleVar: too many pops") end end

  -- Виджеты
  local function button(name)
    return function(c, label, ...) check_ctx(name, c); text(label); return clicked(label) end
  end
  impl.Button = button("Button")
  impl.SmallButton = button("SmallButton")
  impl.TabItemButton = button("TabItemButton")
  impl.Selectable = function(c, label, selected) check_ctx("Selectable", c); text(label); return clicked(label) end
  impl.Checkbox = function(c, label, v)
    check_ctx("Checkbox", c); local id = id_of(label)
    if G.inputs[id] ~= nil then return true, G.inputs[id] end
    return false, v
  end
  local function valued(name)
    return function(c, label, v, ...)
      check_ctx(name, c)
      if type(label) ~= "string" then err(name .. ": label must be a string") end
      local id = id_of(label)
      if G.inputs[id] ~= nil then local nv = G.inputs[id]; return true, nv end
      return false, v
    end
  end
  impl.SliderInt = valued("SliderInt")
  impl.SliderDouble = valued("SliderDouble")
  impl.DragDouble = valued("DragDouble")
  impl.InputText = function(c, label, v, flags)
    check_ctx("InputText", c)
    if type(v) ~= "string" then err("InputText: value must be a string") end
    local id = id_of(label)
    if G.inputs[id] ~= nil then return true, G.inputs[id] end
    return clicked(label .. ":enter"), v
  end
  impl.InputTextWithHint = function(c, label, hint, v)
    check_ctx("InputTextWithHint", c)
    if type(v) ~= "string" then err("InputTextWithHint: value must be a string") end
    local id = id_of(label)
    if G.inputs[id] ~= nil then return true, G.inputs[id] end
    return false, v
  end
  impl.InputTextMultiline = function(c, label, v, w, h)
    check_ctx("InputTextMultiline", c)
    if type(v) ~= "string" then err("InputTextMultiline: value must be a string") end
    local id = id_of(label)
    if G.inputs[id] ~= nil then return true, G.inputs[id] end
    return false, v
  end

  local function texty(name)
    return function(c, ...)
      check_ctx(name, c)
      local args = { ... }
      local s = args[#args]
      if name == "TextColored" then
        if type(args[1]) ~= "number" then err("TextColored: color must be a number") end
        s = args[2]
      end
      if type(s) ~= "string" then err(name .. ": text must be a string, got " .. type(s)) end
      text(s)
    end
  end
  impl.Text = texty("Text"); impl.TextColored = texty("TextColored"); impl.TextWrapped = texty("TextWrapped")
  impl.SeparatorText = texty("SeparatorText")
  impl.SetTooltip = texty("SetTooltip")

  impl.CalcTextSize = function(c, s) check_ctx("CalcTextSize", c); return utf8.len(s) * 8, 16 end
  impl.GetContentRegionAvail = function(c) return G.avail_w, G.avail_h end
  impl.GetCursorPosX = function() return 14 end
  impl.GetCursorPosY = function() return 40 end
  impl.SetCursorPos = function(c, x, y)
    if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y then err("SetCursorPos: bad coords") end
  end
  impl.SetCursorPosX = function(c, x) if type(x) ~= "number" or x ~= x then err("SetCursorPosX: bad x") end end
  impl.GetTextLineHeightWithSpacing = function() return 20 end
  impl.ProgressBar = function(c, frac, w, h, overlay)
    check_ctx("ProgressBar", c)
    if type(frac) ~= "number" or frac < 0 or frac > 1 then err("ProgressBar: fraction out of range: " .. tostring(frac)) end
  end
  impl.IsKeyPressed = function(c, key) return G.keys[key] == true end
  impl.IsAnyItemActive = function() return false end
  impl.IsItemHovered = function() return false end
  impl.IsWindowFocused = function() return true end
  impl.IsWindowDocked = function() return G.docked == true end
  impl.OpenPopup = function(c, id) G.popups[id] = true end

  local NOOP = { "SameLine", "Separator", "Spacing", "Dummy", "SetNextItemWidth", "SetNextWindowSize",
    "SetNextWindowBgAlpha", "SetNextWindowDockID", "TableNextRow", "TableNextColumn", "TableSetupColumn" }
  for _, n in ipairs(NOOP) do impl[n] = impl[n] or function(c) check_ctx(n, c) end end

  local ImGui = setmetatable({}, {
    __index = function(_, key)
      if not api[key] then
        -- точь-в-точь сообщение настоящего ReaImGui
        error(("attempt to access a nil value (field '%s')"):format(key), 2)
      end
      G.used[key] = true
      if is_constant(key) then
        G.constants = G.constants or {}
        if not G.constants[key] then cid = cid + 1; G.constants[key] = cid end
        return G.constants[key]
      end
      local f = impl[key]
      if not f then error("ImGui mock: function '" .. key .. "' exists in ReaImGui 0.9 but is not mocked yet", 2) end
      return f
    end,
  })

  function G.begin_frame()
    G.texts, G.stack, G.colors, G.vars = {}, {}, 0, 0
  end
  function G.end_frame()
    if #G.stack > 0 then
      local names = {}
      for _, s in ipairs(G.stack) do names[#names + 1] = s.tag end
      error("ImGui mock: unclosed at end of frame: " .. table.concat(names, ", "), 2)
    end
    if G.colors ~= 0 then error("ImGui mock: unbalanced PushStyleColor (" .. G.colors .. ")", 2) end
    if G.vars ~= 0 then error("ImGui mock: unbalanced PushStyleVar (" .. G.vars .. ")", 2) end
  end
  function G.has_text(pattern, plain)
    for _, s in ipairs(G.texts) do if s:find(pattern, 1, plain ~= false) then return true end end
    return false
  end

  G.module = ImGui
  return G
end

---------------------------------------------------------------------------
-- Загрузка скрипта в песочнице
---------------------------------------------------------------------------
function M.load_script(script_path, api_path, opts)
  opts = opts or {}
  local R = M.new_reaper(opts)
  local G = M.new_imgui(api_path)
  local fs = M.new_fs()
  local env = setmetatable({
    reaper = R.api,
    io = fs.io,
    os = fs.os,
    VP_TEST = true,
    package = { path = "" },
    require = function(name)
      assert(name == "imgui", "unexpected require: " .. tostring(name))
      return function(version)
        assert(version == "0.9", "script must request ImGui API 0.9, got " .. tostring(version))
        return G.module
      end
    end,
  }, { __index = _G })
  if opts.ext then for k, v in pairs(opts.ext) do R.gext[k] = v end end
  if opts.proj_ext then R.ext.P1 = opts.proj_ext end
  local chunk = assert(loadfile(script_path, "t", env))
  local vp = chunk()
  assert(type(vp) == "table", "script did not return the test API (VP_TEST hook missing?)")
  return vp, R, G, fs
end

-- Один кадр главного цикла с проверками парности
function M.frame(vp, G)
  G.begin_frame()
  vp.loop()
  G.end_frame()
end

return M
