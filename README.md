# ⧉WezTermプラグイン「ConvenientStatusBar」

![ConvenientStatusBarImage](https://github.com/Aromatibus/ConvenientStatusBar.WezTerm/blob/main/img/ConvenientStatusBar.png)

「[Windows Terminal][]」の融通の利かなさに~~嫌気が差して~~良いターミナルを探していたら
出会いました！！その名も$\color{Black}{\huge\textbf{WezTerm}}$です！！

</br>
でもですね。第一印象はナニコレなにもないじゃない？！だったんですよね。
からの「$\color{red}{\huge\textbf{すごーいス・テ・キ❤}}$」に変わるまで「$\color{black}{\large\textbf{あっ}}$」と言うまでした（笑）

<!-- markdownlint-disable-next-line MD033 -->
<details><summary>※※※　WezTermとは　※※※</summary>

:::note info
[WezTerm][]は、Rustで書かれた高速でGPUアクセラレーションに対応した、現代的なクロスプラットフォーム対応のターミナルエミュレータです。主な特徴はLua言語による高度なカスタマイズ性、画面分割機能、背景透過・ボカシなどの機能性です。GitHubで開発されており、Windows、macOS、Linuxで動作する、tmuxのような機能を内蔵した強力なターミナルです。
※GoogleAIの回答より抜粋
:::
</details>

このプラグインは超優秀ターミナルソフト[WezTerm][]のステータスバー（右側限定）に
コンビニエンスな情報を表示するプラグインなのです！


## ◆表示できる情報は

- 日付
- 時間
- Open Weather Mapからの天気情報
 - 情報を取得した都市名
 - その都市の天気
 - 温度
- ノートパソコンの場合、バッテリ残量の目安

以上の情報が表示できます。

## ◆まずは使ってみよう！

### ◯もっとも簡単な使い方

#### ・天気情報を表示するためのAPIキーを取得します

1. [Open Weather][]の[会員登録ページ]から会員登録してください。
2. 登録方法については[会員登録方法検索][]で調べてみてください。（すみません）

#### ・[WezTerm][]に[ConvenientStatusBar][]の設定情報を追記します

1.[WezTerm][]の設定ファイルを開きます。

##### 各OS別の設定ファイルの場所

- その後、[APIキーを取得][]します。
- [WezTerm][]の設定ファイルを開きます。


- Windows
  C:\Users\ユーザー名\.wezterm.lua
  または %USERPROFILE%\.wezterm.lua
- macOS / Linux (Unix系)
  ~/.wezterm.lua
  または ~/.config/wezterm/wezterm.lua

注意点
デフォルトではファイルは存在しない: インストール直後は設定ファイルがないため、自分で作成する必要があります。






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

[Windows Terminal]: https://github.com/microsoft/terminal
[WezTerm]: https://wezterm.org/index.html
[ConvenientStatusBar]: https://github.com/Aromatibus/ConvenientStatusBar.WezTerm
[Open Weather]: https://openweathermap.org/
[会員登録ページ]: https://home.openweathermap.org/users/sign_up
[会員登録方法検索]: https://www.google.com/search?q=open+weather+会員登録
[APIキーを取得]: https://home.openweathermap.org/api_keys
