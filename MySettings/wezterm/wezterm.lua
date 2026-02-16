local wezterm = require 'wezterm'
local config  = wezterm.config_builder()


-- ==========================================================
-- [Startup]
-- ==========================================================
wezterm.on('gui-startup', function(cmd)
  -- =========================================================
  -- ウィンドウを最大化、フォーカスする内部関数
  -- =========================================================
  local function maximize_and_focus(gui)
    -- guiオブジェクトが無い場合は何もしない
    if not gui then
      return
    end
    local pane = gui:active_pane()
    -- paneが無い場合待機して再取得
    if not pane then
      -- 起動直後などペインが無い場合は少し待って再取得
      wezterm.sleep_ms(100)
      pane = gui:active_pane()
      if not pane then
        return
      end
    end
    -- 最大化とフォーカスを実行
    gui:perform_action(wezterm.action.ToggleFullScreen, pane)
    gui:focus()
  end
  -- =========================================================
  -- スタートアップ処理本体
  -- =========================================================
  -- 既存ウィンドウの検出
  local mux = wezterm.mux
  local windows = mux.all_windows()
  -- 既存ウィンドウがある場合は新規ウィンドウを作らず終了
  if #windows > 0 then
    -- 既存する全ウィンドウに対して最大化とフォーカスを適用する
    for _, window in ipairs(windows) do
      local gui = window:gui_window()
      maximize_and_focus(gui)
    end
    return
  end
  -- 通常起動時（既存ウィンドウが無い場合）の新規ウィンドウ生成
  local _, _, window = mux.spawn_window(cmd or {})
  local gui = window and window:gui_window()
  maximize_and_focus(gui)
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
-- [Keybindings / Key Tables]
-- ==========================================
local keybinds = require("config/keybinds")
config.keys       = keybinds.keys
config.key_tables = keybinds.key_tables
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 2000 }


-- ==========================================================
-- [Colorscheme / Theme]
-- ==========================================================
--config.color_scheme = "Dracula (Official)"
--config.color_scheme = "Dracula (Gogh)"
--config.color_scheme = "Dracula+"


-- ==========================================================
-- [Colors]
-- ==========================================================
-- カラーパレット適用
local colors = require("config/colors")
colors.apply(config)
-- プラグインからカラーパレット取得
local ConvenientStatusBar = wezterm.plugin.require(
  --"https://github.com/aromatibus/ConvenientStatusBar.WezTerm"
  "file:///R:/Source/WezTerm/ConvenientStatusBar.WezTerm"
)
local cp       = ConvenientStatusBar.cp

config.keys = config.keys or {}
table.insert(config.keys, {
    key = "p",
    mods = "LEADER",
    action = wezterm.action_callback(function(window, pane)
        ConvenientStatusBar.export_palettes_to_file("A:/palettes.txt")
    end),
})


-- ==========================================================
-- [Window / Display / Appearance]
-- ==========================================================
config.automatically_reload_config = true
config.tab_bar_at_bottom           = false
config.window_decorations          = "RESIZE" -- "TITLE | RESIZE"
config.max_fps                     = 120
config.use_ime                     = true

-- [Visual]
config.window_background_opacity   = 0.96
local PAD_CELL                     = '0.5cell'
config.window_padding              = {
  left = PAD_CELL, right = PAD_CELL, top = PAD_CELL, bottom = PAD_CELL,
}
local FRAME_COLOR                  = cp.blue
local FRAME_SIZE                   = '3px'
config.window_frame                = {
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
config.inactive_pane_hsb           = {
  saturation = 0.3,
  brightness = 0.5,
  hue        = 1.8,
}

-- [Cursor]
config.default_cursor_style        = "BlinkingBar"
config.cursor_thickness            = '0.1cell'

-- [Characters]
config.initial_cols                = 160
config.initial_rows                = 31
config.line_height                 = 1.1

-- [Font]
config.font_shaper                 = 'Harfbuzz'
config.freetype_load_flags         = 'NO_HINTING'
config.font_size                   = 12.0
config.font                        = wezterm.font_with_fallback({
  { family = "HackGen Console NF", weight = "Regular" },
  { family = "Consolas",           weight = "Regular" },
  "monospace",
})

-- [Gradient background]
config.window_background_gradient  = {
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
    cp.deepsea,
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
      or config.colors.tab_bar.inactive_tab.bg_color

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
-- [StatusBar]
-- ==========================================================
require("config/status").apply(config)


return config
