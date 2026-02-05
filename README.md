# ConvenientStatusBar

ステータスバーの右側に便利な情報を表示します。

## もっとも簡単な使い方
local ConvenientStatusBar = wezterm.plugin.require("https://github.com/aromatibus/ConvenientStatusBar.wezterm")

ConvenientStatusBar.setup({
  api_key = "あなたのAPIキー" -- 必須項目のみ
})

## 細かな設定をする場合
local wezterm = require 'wezterm'
local ConvenientStatusBar = wezterm.plugin.require("https://github.com/aromatibus/ConvenientStatusBar.wezterm")

ConvenientStatusBar.setup({
  api_key = "あなたのAPIキー", -- [必須] ：Open Weather Mapから取得したAPIキーを設定

  -- 以下はすべて省略可能です
  city            = "",        -- [省略可能] デフォルト：現在のIPアドレスから取得
  country         = "",        -- [省略可能] デフォルト：なし
  lang            = "en",      -- [省略可能] デフォルト：en
  units           = "metric",  -- [省略可能] デフォルト：metric（摂氏）
  update_interval = 600,       -- [省略可能] デフォルト：Open Weather Mapへの再接続時間を秒で指定
  colors = {
    background    = "#1A1B26", -- [省略可能] デフォルト：
    foreground    = "#7AA2F7", -- [省略可能] デフォルト：
    text          = "#FFFFFF"  -- [省略可能] デフォルト：
  }
})
