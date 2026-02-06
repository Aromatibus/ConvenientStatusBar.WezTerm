# ConvenientStatusBar 導入ガイド

このプラグインは、WezTermの右ステータスバーに「日付・時刻・現在地の天気・バッテリー情報」を美しく、かつコンパクトに表示するためのLuaモジュールです。

---

## 1. インストール

作成したLuaコードを `convenient_status.lua` という名前で保存し、WezTermの設定ディレクトリ（通常は `~/.wezterm.lua` と同じ階層）に配置してください。

## 2. 基本設定

`wezterm.lua` に以下のコードを追加します。

```lua
local wezterm = require 'wezterm'
local status_bar = require 'convenient_status'

-- プラグインのセットアップ
status_bar.setup({
  api_key = "あなたのOPENWEATHERMAP_API_KEY", -- 必須
  lang = "ja",                                -- 言語 (デフォルト "en")
  city = "",                                  -- 空白時は現在地を自動取得
  units = "metric",                           -- 単位 (metric: 摂氏 / imperial: 華氏)
  update_interval = 600,                      -- 更新間隔（秒）
})

return {}
