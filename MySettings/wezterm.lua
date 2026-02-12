local wezterm = require 'wezterm'
local config = wezterm.config_builder()


-- ==========================================================
-- [Startup]
-- ==========================================================
wezterm.on('gui-startup', function(cmd)
    local mux = wezterm.mux
    -- 復元タイミングを待ってから最大化・フォーカス
    wezterm.sleep_ms(300)
    local windows = mux.all_windows()
    if #windows > 0 then
        for _, window in ipairs(windows) do
            local gui = window:gui_window()
            if gui then
                gui:maximize()
                gui:focus()
            end
        end
        return
    end
    -- 通常起動時のみ新規作成
    local _, _, window = mux.spawn_window(cmd or {})
    local gui = window:gui_window()
    -- 最大化・フォーカス
    if gui then
        gui:maximize()
        gui:focus()
    end
end)


-- ==========================================================
-- [Shutdown / Termination Behavior]
-- ==========================================================
-- タブがすべて正常終了なら閉じる（エラー終了時は保持）
config.exit_behavior = "CloseOnCleanExit"
-- ウィンドウ閉鎖時の確認なし（すぐ閉じる）
config.window_close_confirmation = "NeverPrompt"
-- ウィンドウをすべて閉じたら WezTerm を終了
config.quit_when_all_windows_are_closed = true


-- ==========================================================
-- [Resurrect Session]
-- ==========================================================
local resurrect = wezterm.plugin.require 'https://github.com/MLFlexer/resurrect.wezterm'
wezterm.log_info('resurrect loaded: ', resurrect ~= nil)
-- GUI起動時に自動復元を実行
wezterm.on("gui-startup", resurrect.state_manager.resurrect_on_gui_startup)
-- 定期的にセッションを自動保存
local SAVE_INTERVAL = (5 * 60)
local last_save = 0
wezterm.on('update-right-status', function()
    local now = os.time()
    if now - last_save >= SAVE_INTERVAL then
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
        last_save = now
        wezterm.log_info('resurrect: auto-saved')
    end
end)
-- GUI終了時にセッションを保存
wezterm.on('gui-shutdown', function()
  resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
end)


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


-- ==========================================
-- キーバインドの設定
-- ==========================================
-- キーバインドを外部ファイルから読み込み
---@diagnostic disable-next-line: different-requires
config.keys = require("keybinds").keys
-- キーテーブルを外部ファイルから読み込み
---@diagnostic disable-next-line: different-requires
config.key_tables = require("keybinds").key_tables
-- Leaderキーの設定
config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }


-- ==========================================================
-- [Colors / Constants]
-- ==========================================================
-- カラースキーム / テーマ
--config.color_scheme = "Dracula (Official)"
--config.color_scheme = "Dracula (Gogh)"
--config.color_scheme = "Dracula+"


-- ==========================================================
-- 基本カラー設定
-- ==========================================================
local gradation_palettes = {
    --- ==========================================
    --- Gradation
    --- ==========================================
    ocean           = "#3B82F6",  -- 澄んだ海の青
    horizon         = "#4F9CFF",  -- 遠くの地平線の青
    cerulean        = "#5AA7FF",  -- 透明感のある青
    summer          = "#63B5FF",  -- 夏空の明るい青
    cirrus          = "#77CEFF",  -- 巻雲のような淡い水色
    glacier         = "#8BE7FF",  -- 氷河を思わせる青白さ
    lagoon          = "#9FFFFF",  -- 南国の浅瀬の水色
    mint            = "#B5FFE0",  -- ミントのように涼やかな青緑
    aquamarine      = "#9FEFD3",  -- 透き通る浅瀬の青緑（mint→jade の橋）
    jade            = "#7EE0B0",  -- 翡翠を思わせる青緑
    viridian        = "#66D1A7",  -- 青緑から緑への移ろい
    emerald         = "#40B090",  -- エメラルドの深い緑
    forest          = "#2F8F6F",  -- 木陰のある深い森の緑（最暗）
    moss            = "#4FA87A",  -- 苔むした緑
    leaf            = "#6FC08A",  -- 日差しを受けた葉の緑
    spring          = "#8FD89A",  -- 春の新緑
    meadow          = "#A6E3A0",  -- 草原の明るい緑
    pistachio       = "#C4F0A0",  -- 若葉の黄緑
    sprout          = "#CCFFC0",  -- 芽吹きの淡い黄緑
    chartreuse      = "#E0FF90",  -- 鮮やかな黄緑
    lime            = "#F0FF80",  -- 黄色に近い黄緑
    yellow          = "#FFFF70",  -- 透き通るような黄色
    lemon           = "#FFF97A",  -- レモンのように明るい黄色
    sunshine        = "#FFEF70",  -- 日差しを感じる温かな黄色
    honey           = "#FFE060",  -- 蜂蜜のような黄橙
    amber           = "#FFD04A",  -- 琥珀色
    apricot         = "#FFC050",  -- 熟した杏のオレンジ
    tangerine       = "#FFA040",  -- みかんの橙
    persimmon       = "#FF8038",  -- 柿の実の赤みの橙
    vermilion       = "#FF6030",  -- 朱色がかった赤橙
    red             = "#FF4040",  -- はっきりとした赤
    ember           = "#FF5050",  -- 熾火のような温かい赤
    rose            = "#FF6A6A",  -- 薔薇の花びらの赤
    coral           = "#FF8484",  -- 珊瑚のようなやわらかな赤
    peach           = "#FF9E9E",  -- 桃色がかった淡い赤
    blush           = "#FFB8B8",  -- 頬紅のような淡い赤
    petal           = "#FFB2C9",  -- 花びらのやさしいピンク
    sakura          = "#FFA0D0",  -- 桜の花びらのピンク
    rose_pink       = "#FF7FBF",  -- 華やかなピンク
    mulberry        = "#F06FB2",  -- 桑の実のような赤紫
    magenta         = "#E85BC7",  -- 落ち着いた赤紫
    berry           = "#D96BCB",  -- ベリー系のやわらかな赤紫
    wisteria        = "#E090FF",  -- 藤の花のやさしい紫
    lavender        = "#C080FF",  -- ラベンダーの青みの紫
    iris            = "#A070FF",  -- 菖蒲の青紫
    amethyst        = "#8860FF",  -- 紫水晶のような紫
    heliotrope      = "#7E63FF",  -- 紫から青紫への移ろい
    twilight        = "#7050FF",  -- 夕暮れの青紫
    cobalt          = "#5A40FF",  -- 冷たさを感じる青紫
    blue            = "#3F4DFF",  -- くっきりとした青
    sapphire        = "#3A3CF2",  -- サファイアの深い青
    midnight        = "#352EE0",  -- 深夜の空の濃い青
    starlight       = "#3B30C0",  -- 星明かりのような青紫
    deep_sea        = "#2F2888",  -- 深海の暗い青
    abyss           = "#252060",  -- 深淵のような群青
    --- ==========================================
    --- Neon
    --- ==========================================
    neon_blue       = "#0050FF",  -- 電飾のようなネオンブルー
    neon_cyan       = "#7FFFFF",  -- 発光感のあるネオンシアン
    neon_green      = "#A0FF00",  -- 蛍光感のあるネオン黄緑
    neon_yellow     = "#F7FF00",  -- 目に刺さるネオンイエロー
    neon_orange     = "#FF9020",  -- 発光感のあるネオンオレンジ
    neon_red        = "#FF2040",  -- 強烈なネオンレッド
    neon_magenta    = "#FF00FF",  -- ビビッドなネオンマゼンタ
    --- ==========================================
    --- Neon
    --- ==========================================
    dark_blue       = "#1F3A8A",  -- 深めのブルー（ネオンブルーの暗色）
    dark_cyan       = "#2FB7B7",  -- 彩度を残した暗シアン
    dark_green      = "#5FA800",  -- ネオン黄緑を落ち着かせたグリーン
    dark_yellow     = "#B3B800",  -- 目に刺さらないダークイエロー
    dark_orange     = "#C86A1A",  -- くすませたオレンジ
    dark_red        = "#B02035",  -- 落ち着いたクリムゾン
    dark_magenta    = "#B000B0",  -- 暗めでも分かるマゼンタ
    --- ==========================================
    --- Monochrome
    --- ==========================================
    black           = "#000000",  -- 黒
    onyx            = "#1B1A2C",  -- 黒曜石のような黒紫
    charcoal        = "#222222",  -- 木炭のような濃い灰
    slate           = "#3A3A3A",  -- 石板のような暗い灰
    ash             = "#5A5A5A",  -- 灰色の中間トーン
    smoke           = "#7A7A7A",  -- 煙のような薄い灰
    fog             = "#A0A0A0",  -- 霧のような明るい灰
    silver          = "#BABABA",  -- 金属的な銀色
    grey            = "#E0E0E0",  -- ごく淡い灰色
    white           = "#FFFFFF",  -- 白
}


--- ==========================================================
--- カラーパレット変換
--- ==========================================================
local cp = {}
for name, hex in pairs(gradation_palettes) do
  cp[name] = wezterm.color.parse(hex)
end


--- ==========================================================
--- カラーパレット選択
--- ==========================================================
local palette = 'dark'  -- 'dark' | 'light'


--- ==========================================================
--- 表示色設定
--- ==========================================================
local display_palettes = {
  light = {
  },
  dark = {
    -- ===============================
    -- 基本の前景色・背景色
    -- ===============================
    foreground = cp.white,   -- 通常のテキスト（ターミナル文字）の色
    background = cp.deep_sea,   -- ターミナル全体の背景色
    -- ===============================
    -- カーソル関連
    -- ===============================
    cursor_bg     = cp.blue, -- カーソル自体の背景色
    cursor_fg     = cp.onyx, -- カーソル上に表示される文字の色
    cursor_border = cp.blue, -- ブロックカーソルや枠線の色
    -- ===============================
    -- 選択範囲（マウスドラッグ等）
    -- ===============================
    selection_fg = cp.black, -- 選択された文字の色
    selection_bg = cp.blue, -- 選択範囲の背景色
    -- ===============================
    -- UIパーツ（スクロールバー・分割線）
    -- ===============================
    scrollbar_thumb = cp.deep_sea, -- スクロールバーの「つまみ」の色
    split           = cp.blue,--cp.persimmon, -- 画面分割時の境界線の色
    -- ===============================
    -- タブバー（上部のタブUI）
    -- ===============================
    tab_bar = {
      background = cp.onyx, -- タブバー全体の背景色
      -- アクティブなタブ
      active_tab = {
        bg_color = cp.peach, -- 選択中タブの背景色
        fg_color = cp.onyx, -- 選択中タブの文字色
        intensity = "Normal",  -- 文字の太さ（Bold / Normal）
        italic = false,     -- 斜体にするか
        underline = "None",  -- 下線の有無
        strikethrough = false, -- 取り消し線の有無
      },
      -- 非アクティブなタブ
      inactive_tab = {
        bg_color = cp.grey, -- 非選択タブの背景色
        fg_color = cp.silver, -- 非選択タブの文字色
      },
      -- 非アクティブタブにマウスオーバーした時
      inactive_tab_hover = {
        bg_color = cp.starlight, -- ホバー時の背景色
        fg_color = cp.blue, -- ホバー時の文字色
        italic = true,       -- ホバー時に斜体にする
      },
      -- 新規タブボタン
      new_tab = {
        bg_color = cp.onyx, -- 「＋」ボタンの背景色
        fg_color = cp.blue, -- 「＋」ボタンの文字色
      },
      -- 新規タブボタンのホバー時
      new_tab_hover = {
        bg_color = cp.starlight, -- ホバー時の背景色
        fg_color = cp.blue, -- ホバー時の文字色
        italic = true,       -- ホバー時に斜体にする
      },
    },
  },
  -- ===============================
  -- ANSI 16色
  -- ===============================
  ansi = {
    "#000000", -- black   : 黒
    "#CD0000", -- red     : 赤
    "#00CD00", -- green   : 緑
    "#CDCD00", -- yellow  : 黄
    "#0000EE", -- blue    : 青
    "#CD00CD", -- magenta : マゼンタ
    "#00CDCD", -- cyan    : シアン
    "#E5E5E5", -- white   : 白（ややグレー寄り）
  },
  -- ===============================
  -- ANSI 16色 明るい版
  -- ===============================
  brights = {
    "#7F7F7F", -- bright black   : 明るい黒（グレー）
    "#FF0000", -- bright red     : 明るい赤
    "#00FF00", -- bright green   : 明るい緑
    "#FFFF00", -- bright yellow  : 明るい黄
    "#5C5CFF", -- bright blue    : 明るい青
    "#FF00FF", -- bright magenta : 明るいマゼンタ
    "#00FFFF", -- bright cyan    : 明るいシアン
    "#FFFFFF", -- bright white   : 白
  },
}
config.colors = display_palettes[palette]


-- ==========================================================
-- [Window / Display / Appearance]
-- ==========================================================
config.automatically_reload_config = true
config.tab_bar_at_bottom = false
config.window_decorations = "RESIZE" -- "TITLE | RESIZE"
config.max_fps = 120
config.use_ime = true

-- [Visual]
config.window_background_opacity = 0.96
local PAD_CELL = '0.5cell'
config.window_padding = {
  left = PAD_CELL, right = PAD_CELL, top = PAD_CELL, bottom = PAD_CELL,
}
local FRAME_COLOR = config.colors.split
local FRAME_SIZE  = '3px'
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
  brightness = 0.5,
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


-- [Gradient background]
config.window_background_gradient = {
  orientation = 'Vertical',
  --orientation = { Linear = { angle = -45.0 } },
  interpolation = 'Linear',
  colors = {
    cp.onyx,
    cp.onyx,
    cp.abyss,
    cp.abyss,
    cp.abyss,
    cp.abyss,
    cp.abyss,
    cp.abyss,
    cp.abyss,
    cp.abyss,
    cp.abyss,
    cp.abyss,
    cp.abyss,
    cp.deep_sea,
  },
  blend = 'Rgb',
  noise = 40,
  segment_size = 30,
  segment_smoothness = 10.0,
}


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

    -- アクティブ、非アクティブで色を変える
  local current_tab_color = tab.is_active
    and config.colors.tab_bar.active_tab.bg_color
    or  config.colors.tab_bar.inactive_tab.bg_color

    -- タブの文字色をアクティブタブの文字色に合わせる
  local current_fg_color = config.colors.tab_bar.active_tab.fg_color

  -- 描画
  return {
    { Background = { Color = config.colors.tab_bar.background } },
    { Foreground = { Color = current_tab_color } },
    { Text = "" },
    { Background = { Color = current_tab_color } },
    { Foreground = { Color = current_fg_color } },
    { Text = " " .. display_text .. " " },
    { Background = { Color = config.colors.tab_bar.background } },
    { Foreground = { Color = current_tab_color } },
    { Text = "" },
  }
end)


-- ==========================================================
-- [Right Status]
-- ==========================================================

-- ==========================================
-- ステータスバープラグイン読み込み
-- ==========================================
local ConvenientStatusBar = wezterm.plugin.require("https://github.com/aromatibus/ConvenientStatusBar.WezTerm")

-- ==========================================
-- シンプルバージョン
-- ==========================================
ConvenientStatusBar.setup({formats = {" $user_ic $user $cal_ic $year.$month.$day($week) $clock_ic $time24 $batt_ic$batt_num ",""}})

-- ==========================================
-- 天気情報バージョン
-- ==========================================
--[[
ConvenientStatusBar.setup({
  weather_api_key         = "88989d7e3460606958812933b3209599",
  formats = {
    -- フォーマット1
    " $user_ic $user " ..
    "$cal_ic $year.$month.$day($week) $clock_ic $time12 (alarm:$next_alarm) " ..
    " $loc_ic $city($code) " ..
    "($weather_ic/$temp_ic$temp) " ..
    "$batt_ic$batt_num ",
    " Now($weather_ic/$temp_ic$temp) "  ..
    "+3h($weather_ic_3h/$temp_ic$temp_3h) " ..
    "+6h($weather_ic_6h/$temp_ic$temp_6h) " ..
    "+9h($weather_ic_9h/$temp_ic$temp_9h) " ..
    "+12h($weather_ic_12h/$temp_ic$temp_12h) " ..
    "NextAfty:$weather_nd_afty_time($weather_nd_afty_ic/$temp_ic$weather_nd_afty_temp) ",
  }
})
config.keys = {
  {
    key = "o",
    mods = "CTRL|SHIFT",
    action = wezterm.action.EmitEvent("toggle-status-format"),
  },
}
]]

-- ==========================================
-- 全機能入り
-- ==========================================

--[[
ConvenientStatusBar.setup({
  formats = {
    -- フォーマット1
    " $user_ic $user " ..
    "$cal_ic $year.$month.$day($week) $clock_ic $time12 Alarm:$next_alarm ($time_until_alarm min) " ..
    " $loc_ic $city($code) " ..
    "($weather_ic/$temp_ic$temp) " ..
    "$cpu_ic $cpu $mem_ic $mem_free " ..
    "$net_ic $net_speed($net_avg) " ..
    "$batt_ic$batt_num ",
    -- フォーマット2
    " Now:($weather_ic/$temp_ic$temp) "  ..
    "+3h:($weather_ic_3h/$temp_ic$temp_3h) " ..
    "+6h:($weather_ic_6h/$temp_ic$temp_6h) " ..
    "+9h:($weather_ic_9h/$temp_ic$temp_9h) " ..
    "+12h:($weather_ic_12h/$temp_ic$temp_12h) " ..
    "NextAfterNoon $weather_nd_afty_time:($weather_nd_afty_ic/$temp_ic$weather_nd_afty_temp) ",
  },

  timer = {
    alarm1                = "12:00",
    alarm2                = "18:00",
    hourly                = true,
    beep                  = true,
    flash                 = true,
    flash_color          = "#FFFFFF",
  },
  --weather_api_key         = "",
  --weather_api_key         = "あなたのAPIキー",
  weather_api_key         = "88989d7e3460606958812933b3209599",
  weather_lang            = "",
  weather_country         = "jp",
  weather_city            = "Marunouchi",
  weather_units           = "metric",
  weather_update_interval = 600,
  weather_retry_interval  = 30,
  net_update_interval     = 3,
  net_avg_samples         = 20,
  startup_delay           = 5,

  color_text              = "#1A1B00",
  color_foreground        = "#70B0FF",
  color_background        = "#1A1B00",
  status_position         = "right", -- "right" or "left"
  separator = { "", ""},
  --separator = { "", ""},
  --separator = { "", ""},
  --separator = { "", ""},
  --separator = { "", ""},
  --separator = { "", ""},
  --separator = { "|", "|"},
  --separator = { "⟦", "⟧"},
  --separator = { "[", "]"},
  --separator = { "", ""},
  --separator = { "", ""},
  --separator = { "", ""},
  --separator = { " ", " "},
  --separator = { " ", " "},
  --separator = { " ", " "},
  --separator = { " ", " "},
  --separator = { " ", " "},
  --separator = { " ", " "},
  --separator = { " ", " "},
  --separator = { " ", " "},
  --separator = { " ", " "},
  --week_str = {"日","一","二","三","四","五","六"}, -- Chinese
  --week_str = {"Dom","Lun","Mar","Mié","Jue","Vie","Sáb"}, -- Spanish
  --week_str = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"}, -- English
  --week_str = {"रवि","सोम","मंगल","बुध","गुरु","शुक्र","शनि"}, -- Hindi
  --week_str = {"রবি","সোম","मंगल","বুধ","বৃহ","শুক্র","শনি"}, -- Bengali
  --week_str = {"Dom","2ª","3ª","4ª","5ª","6ª","Sáb"}, -- Portuguese
  --week_str = {"ح","اث","ث","أر","خ","ج","س"}, -- Arabic
  --week_str = {"Вс","Пн","Вт","Ср","Чт","Пт","Сб"}, -- Russian
  week_str = {"日","月","火","水","木","金","土"}, -- Japanese
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
]]


return config
