local wezterm = require 'wezterm'
local config = wezterm.config_builder()


-- ==========================================================
-- [Startup]
-- ==========================================================
-- 最前面にフォーカス
wezterm.on('gui-startup', function(cmd)
  local _, _, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():focus()
end)


-- ==========================================================
-- [Colors / Constants]
-- ==========================================================
-- config.color_scheme = "Catppuccin Latte"
-- config.color_scheme = "Dracula (Official)"
-- config.color_scheme = "Dracula (Gogh)"
config.color_scheme = "Dracula+"

local palette = 'dark'  -- 'dark' | 'light'
local all_palettes = {
  light = {
    red          = "#FF8070",
    peach        = "#FfB090",
    yellow       = "#F0E0A0",
    green        = "#A6E3A0",
    sapphire     = "#80C8E0",
    blue         = "#70B0FF",
    text         = "#F0F0F0",
    tab_text     = "#606070",
    tab_inactive = "#E0E0E0",
    log_success  = "#787878",
    log_failure  = "#FF8800",
    base_bg      = "#FDFFCD",
  },
  dark = {
    text         = "#1A1B00",
    input_text   = "#F0F0F0",
    base_bg      = "#1A1B00",
    tab_text     = "#1A1B00",
    tab_active   = "#FF8070",
    tab_inactive = "#A0A0A0",
    tab_bg       = "#1A1B00",
    log_success  = "#787878",
    log_failure  = "#FF8800",
    red          = "#FF8070",
    peach        = "#FFB090",
    yellow       = "#F0E0A0",
    green        = "#A6E3A0",
    sapphire     = "#80C8E0",
    blue         = "#70B0FF",
  },
}
local colors = all_palettes[palette]

config.colors = {
  background = colors.base_bg,
  foreground = colors.log_success,
  cursor_bg  = colors.text,
  cursor_fg  = colors.input_text,
  selection_bg = colors.sapphire,
  selection_fg = colors.input_text,
  tab_bar = {
    background = colors.tab_bg,
    new_tab = { bg_color = colors.tab_inactive, fg_color = colors.tab_text },
  },
}


-- ==========================================================
-- [Shell]
-- ==========================================================
local function get_default_prog()
  if wezterm.target_triple:find("windows") then
    local current_drive = wezterm.executable_dir:match("(%a:)") or "C:"
    local profile_path =
      current_drive .. "\\DevTools\\PowerShell\\.pwsh\\Documents\\PowerShell\\Microsoft.PowerShell_profile.ps1"
    local pwsh_path = current_drive .. "\\DevTools\\PowerShell\\bin\\pwsh.exe"
    return {
      pwsh_path, "-ExecutionPolicy", "RemoteSigned",
      "-NoExit", "-Command", string.format(". '%s'", profile_path)
    }
  elseif wezterm.target_triple:find("apple") then
    return { "/bin/zsh", "-l" }
  else
    return { "/bin/bash", "-l" }
  end
end

config.default_prog = get_default_prog()


-- ==========================================================
-- [Window / Display / Appearance]
-- ==========================================================
config.automatically_reload_config = true
config.tab_bar_at_bottom = false
config.window_close_confirmation = "NeverPrompt"
config.window_decorations = "RESIZE" -- "TITLE | RESIZE"
config.max_fps = 120
config.use_ime = true

-- [Visual]
config.window_background_opacity = 0.90
config.window_padding = {
  left = '0.5cell', right = '0.5cell', top = '0.5cell', bottom = '0.5cell',
}

local FRAME_COLOR = colors.peach
local FRAME_SIZE  = '5px'
config.window_frame = {
  border_top_height    = FRAME_SIZE,
  border_bottom_height = FRAME_SIZE,
  border_left_width    = FRAME_SIZE,
  border_right_width   = FRAME_SIZE,
  border_top_color     = FRAME_COLOR,
  border_bottom_color  = FRAME_COLOR,
  border_left_color    = FRAME_COLOR,
  border_right_color   = FRAME_COLOR,
}

-- [Brightness inactive pane]
config.inactive_pane_hsb = {
  saturation = 0.3,
  brightness = 1.0,
  hue        = 1.8,
}

-- [Cursor]
config.default_cursor_style = "BlinkingBar"
config.cursor_thickness = '0.1cell'

-- [Characters]
config.initial_cols = 160
config.initial_rows = 31
config.line_height  = 1.1

-- [Font]
config.font_shaper = 'Harfbuzz'
config.freetype_load_flags = 'NO_HINTING'
config.font_size = 12.0
config.font = wezterm.font_with_fallback({
  { family = "HackGen Console NF", weight = "Regular" },
  { family = "Consolas", weight = "Regular" },
  "monospace",
})


-- ==========================================================
-- [Tab]
-- ==========================================================
config.use_fancy_tab_bar = false

-- New Tabボタンを非表示
config.show_new_tab_button_in_tab_bar = false

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local TAB_STYLE = {
    size_min = 8,
    size_max = 20,
  }

  -- アクティブ、非アクティブで色を変える
  local current_tab_color = tab.is_active and colors.tab_active or colors.tab_inactive
  local current_fg_color = colors.tab_text

  -- プロセス名（シェル名）を取得して.exeを削除
  local title = tab.active_pane.title:gsub("%.[eE][xX][eE]$", "")

  -- 番号を付与
  local index = tab.tab_index + 1
  local display_text = string.format("%d: %s", index, title)

  -- タブの長さの調整
  display_text = wezterm.truncate_right(display_text, TAB_STYLE.size_max)
  if #display_text < TAB_STYLE.size_min then
    display_text = display_text .. string.rep(" ", TAB_STYLE.size_min - #display_text)
  end

  -- 描画
  return {
    { Background = { Color = colors.tab_bg } },
    { Foreground = { Color = current_tab_color } },
    { Text = "" },
    { Background = { Color = current_tab_color } },
    { Foreground = { Color = current_fg_color } },
    { Text = " " .. display_text .. " " },
    { Background = { Color = colors.tab_bg } },
    { Foreground = { Color = current_tab_color } },
    { Text = "" },
  }
end)


-- ==========================================================
-- [Right Status]
-- ==========================================================

-- ステータスバープラグイン読み込み
local ConvenientStatusBar = wezterm.plugin.require("https://github.com/aromatibus/ConvenientStatusBar.WezTerm")

-- セットアップの実行
ConvenientStatusBar.setup({
  --weather_api_key         = "",
  --weather_api_key         = "あなたのAPIキー",
  weather_api_key         = "88989d7e3460606958812933b3209599",


--[[
  formats = {
    -- フォーマット1
    " $user_ic $user " ..
    "$cal_ic $year.$month.$day($week) $clock_ic $time24 " ..
    "$loc_ic $city($code) " ..
    "$weather_ic($temp) "  ..
    "$batt_ic$batt_num ",

    -- フォーマット2
    " Now:$weather_ic($temp) "  ..
    "+3h:$weather_ic_3h($temp_3h) " ..
    "+24h:$weather_ic_24h($temp_24h) " ..
    "$cpu_ic $cpu $mem_ic $mem_free " ..
    "$net_ic $net_speed($net_avg) ",

  },
]]



--[[
  startup_delay           = 5,
  weather_lang            = "en",
  weather_country         = "",
  weather_city            = "",
  weather_units           = "metric",
  weather_update_interval = 600,
  weather_retry_interval  = 30,
  net_update_interval     = 3,
  net_avg_samples         = 20,
  separator_left          = "",
  separator_right         = "",
  color_text              = "#FFFFFF",
  color_foreground        = "#7AA2F7",
  color_background        = "#1A1B26",
]]

--[[
  format                  = 
    " $user_ic $user " ..
    "$cal_ic $year.$month.$day($week) $clock_ic $time24 " ..
    "$loc_ic $city($code) $weather_ic $temp " ..
    "$cpu_ic $cpu $mem_used_ic $mem_used $mem_free_ic $mem_free " ..
    "$net_ic $net_speed($net_avg) " ..
    "$batt_ic$batt_num ",
]]
  --week_str = {"日","一","二","三","四","五","六"}, -- Chinese
  --week_str = {"Dom","Lun","Mar","Mié","Jue","Vie","Sáb"}, -- Spanish
  --week_str = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"}, -- English
  --week_str = {"रवि","सोम","मंगल","बुध","गुरु","शुक्र","शनि"}, -- Hindi
  --week_str = {"রবি","সোম","मंगल","বুধ","বৃহ","শুক্র","শনি"}, -- Bengali
  --week_str = {"Dom","2ª","3ª","4ª","5ª","6ª","Sáb"}, -- Portuguese
  --week_str = {"ح","اث","ث","أر","خ","ج","س"}, -- Arabic
  --week_str = {"Вс","Пн","Вт","Ср","Чт","Пт","Сб"}, -- Russian
  --week_str = {"日","月","火","水","木","金","土"}, -- Japanese
  --week_str = {"ਐਤ","ਸੋਮ","ਮੰਗਲ","ਬੁੱਧ","ਵੀਰ","ਸ਼ੁੱਕਰ","ਸ਼ਨੀ"}, -- Punjabi
  --week_str = {"रवि","सोम","मंग","बुध","गुरू","शुक्र","शनि"}, -- Marathi
  --week_str = {"ఆది","సోమ","మంగళ","బుధ","గురు","శుక్ర","శని"}, -- Telugu
  --week_str = {"Ngah","Sen","Sel","Reb","Kem","Jum","Set"}, -- Javanese
  --week_str = {"CN","T2","T3","T4","T5","T6","T7"}, -- Vietnamese
  --week_str = {"So","Mo","Di","Mi","Do","Fr","Sa"}, -- German
  --week_str = {"일","월","화","수","목","금","토"}, -- Korean
  --week_str = {"Dim","Lun","Mar","Mer","Jeu","Ven","Sam"}, -- French
  --week_str = {"Dom","Lun","Mar","Mer","Gio","Ven","Sab"}, -- Italian
  --week_str = {"อา.","จ.","อ.","พ.","พฤ.","ศ.","ส."}, -- Thai
  --week_str = {"Jpili","Jtt","Jnn","Jta","Alham","Jma","Jmos"}, -- Swahili
  --week_str = {"Min","Sen","Sel","Rab","Kam","Jum","Sab"}, -- Indonesian
  --week_str = {"nd","pn","wt","śr","cz","pt","sb"}, -- Polish
  --week_str = {"Нд","Пн","Вт","Ср","Чт","Пт","Сб"}, -- Ukrainian
  --week_str = {"sön","mån","tis","ons","tors","fre","lör"}, -- Swedish
  --week_str = {"su","ma","ti","ke","to","pe","la"}, -- Finnish
})


--return config
config.keys = {
  {
    key = "o",
    mods = "CTRL|SHIFT",
    action = wezterm.action.EmitEvent("toggle-status-format"),
  },
}

return config
