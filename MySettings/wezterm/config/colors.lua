local wezterm = require 'wezterm'
local M       = {}


function M.apply(config)
  -- ==========================================================
  -- 基本カラー設定
  -- ==========================================================
  -- プラグインからカラーパレット取得
  local ConvenientStatusBar = wezterm.plugin.require(
    "file:///R:/Source/WezTerm/ConvenientStatusBar.WezTerm"
  )
  local cp       = ConvenientStatusBar.cp

  --- ==========================================================
  --- カラーパレット選択
  --- ==========================================================
  local palette = 'dark' -- 'dark' | 'light'


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
      foreground      = cp.white, -- 通常のテキスト（ターミナル文字）の色
      background      = cp.deepsea, -- ターミナル全体の背景色
      -- ===============================
      -- カーソル関連
      -- ===============================
      cursor_bg       = cp.blue, -- カーソル自体の背景色
      cursor_fg       = cp.onyx, -- カーソル上に表示される文字の色
      cursor_border   = cp.blue, -- ブロックカーソルや枠線の色
      -- ===============================
      -- 選択範囲（マウスドラッグ等）
      -- ===============================
      selection_fg    = cp.black, -- 選択された文字の色
      selection_bg    = cp.blue, -- 選択範囲の背景色
      -- ===============================
      -- UIパーツ（スクロールバー・分割線）
      -- ===============================
      scrollbar_thumb = cp.deepsea,  -- スクロールバーの「つまみ」の色
      split           = cp.blue,     -- 画面分割時の境界線の色
      -- ===============================
      -- タブバー（上部のタブUI）
      -- ===============================
      tab_bar         = {
        background = cp.charcoal, -- タブバー全体の背景色
        -- アクティブなタブ
        active_tab = {
          bg_color = cp.white,   -- 選択中タブの背景色
          fg_color = cp.onyx,    -- 選択中タブの文字色
          intensity = "Normal",  -- 文字の太さ（Bold / Normal）
          italic = false,        -- 斜体にするか
          underline = "None",    -- 下線の有無
          strikethrough = false, -- 取り消し線の有無
        },
        -- 非アクティブなタブ
        inactive_tab = {
          bg_color = cp.gray,   -- 非選択タブの背景色
          fg_color = cp.silver, -- 非選択タブの文字色
        },
        -- 非アクティブタブにマウスオーバーした時
        inactive_tab_hover = {
          bg_color = cp.mediumblue, -- ホバー時の背景色
          fg_color = cp.blue,      -- ホバー時の文字色
          italic = true,           -- ホバー時に斜体にする
        },
        -- 新規タブボタン
        new_tab = {
          bg_color = cp.onyx, -- 「＋」ボタンの背景色
          fg_color = cp.blue, -- 「＋」ボタンの文字色
        },
        -- 新規タブボタンのホバー時
        new_tab_hover = {
          bg_color = cp.mediumblue, -- ホバー時の背景色
          fg_color = cp.blue,      -- ホバー時の文字色
          italic = true,           -- ホバー時に斜体にする
        },
      },
    },
    -- ===============================
    -- ANSI 16色
    -- ===============================
    ansi    = {
      cp.ansi.base.black,
      cp.ansi.base.red,
      cp.ansi.base.green,
      cp.ansi.base.yellow,
      cp.ansi.base.blue,
      cp.ansi.base.magenta,
      cp.ansi.base.cyan,
      cp.ansi.base.white,
    },
    brights = {
      cp.ansi.brights.black,
      cp.ansi.brights.red,
      cp.ansi.brights.green,
      cp.ansi.brights.yellow,
      cp.ansi.brights.blue,
      cp.ansi.brights.magenta,
      cp.ansi.brights.cyan,
      cp.ansi.brights.white,
    },
  }
  config.colors = display_palettes[palette]

end


return M
