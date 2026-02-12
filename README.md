# ⧉WezTermプラグイン「ConvenientStatusBar」

[ConvenientStatusBar][]
![ConvenientStatusBar.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/588934/b95bc8ea-615f-451c-8070-5e5c2f69e979.png)
↑こんな感じで「[WezTerm][]」の右のステータスバーに表示できます。
※すぐに使いたい方は「[◆まずは使ってみよう！](#まずは使ってみよう)」に進んでください。

<!-- markdownlint-disable-next-line MD033 MD045 -->
<img width="350" src="https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/588934/1766b339-ce96-4eb4-8ed8-801ce0e55305.png"><img width="350" src="https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/588934/3a5541fe-3aff-4881-be1a-8812cacec422.png">
我が家の[WezTerm][]さん

## ◆はじめに

「[Windows Terminal][]」がいまいちだったので他には良いターミナルがないものかと
探していたところWezTerm出会えました！！

:::note info
$\color{Blue}{\textbf{WezTerm}}$とは

「[WezTerm][]」はプログラミング言語「[Rust][]」で書かれたGPUアクセラレーションにも対応した高速なターミナルエミュレータです。
$\color{Blue}{\textbf{クロスプラットフォーム}}$$\color{Blue}{\small\textbf{(Windows、macOS、Linux)}}$で動作します。
環境が変わっても同じ見た目と操作感で使用することが可能になります。
主な特徴はプログラミング言語「[Lua][]」による高度なカスタマイズ性と$\color{Blue}{\textbf{画面分割機能}}$$\color{Red}{\small\textbf{(これが重要)}}$、背景透過など自由で先進的な機能の数々です。
「[WezTerm][]」は「[GitHub上にオープンソースで開発][]」されている非常に強力なターミナルエミュレータです。
$\color{Grey}{\tiny\textbf{※GoogleAIの説明から抜粋}}$
:::

でもですね。じつは第一印象はかなり悪かったんです。
ネットで見た評価が高くなかったら初見で使うのやめたかもしれません。
だって起動したらコマンドプロンプトの真っ暗な画面が現れただけ
マウスを右クリックしてもな～んにも反応しなかったんですもの。[^doesnt_respond]

しかしそこからの「$\color{Red}{\huge\textbf{あっこれイイ(≧∇≦)b}}$」に変わるのは
「$\color{Red}{\large\textbf{あっ}}$」と言うまでした♪

このプラグインはその「$\color{Red}{\textbf{熱い}}$」想いから「$\color{Purple}{\textbf{勢い}}$」と「$\color{Orange}{\textbf{情熱}}$」に任せて作成した
ステータスバー（※注 右側限定）に情報を表示する「[プラグイン](https://ja.wikipedia.org/wiki/%E6%84%9B "愛❤")」なのです！

$\color{black}{\tiny  \textsf{※注　似たようなものがあるかもしれないけど勢いって大事だと思います}}$
$\color{black}{\tiny  \textsf{ここまで読んでくれてありがとうございます♪}}$

## ◆表示できる情報は

冒頭にありました↓これです。
![ConvenientStatusBar.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/588934/b95bc8ea-615f-451c-8070-5e5c2f69e979.png)

実際にはこれ以外にも表示できる情報があり色も含めて自由に設定可能です。

- 日付(YYYY/MM/DDc)
- 時間(HH:MM:DD:SS)(12H/24H)
- Open Weather Mapからの天気情報
 　- 情報を取得した都市名
 　- その都市の現在の天気
 　- その都市の現在の温度
 　※天気と温度は現在、およその3、6、9、12時間後、次のお昼時が指定可能
 - ユーザー名(ローカル/SSH接続)
 - CPU使用率
 - メモリ使用量、空き容量
 - ネットワーク速度と平均速度
 - ノートパソコンの場合、バッテリ残量の目安

以上の情報が表示されます。

## ◆まずは使ってみよう

### 1.天気情報表示に必須なAPIキーを取得します

※APIキーはアルファベットと数字からなる32文字の文字列です。

1. 「[Open Weather][]」の会員である必要があります
まだ会員ではない方は[会員登録ページ]から会員登録してください
2. 会員登録の方法については[会員登録方法を検索][]してください（すみません）
3. 登録後、「[ここからAPIキーを取得]」してください

### 2.WezTermの設定ファイルに情報を追記します

1. WezTermの設定ファイルを開きます
:::note info

OS別の基本的な設定ファイルの場所

- Windows
  `C:\Users\ユーザー名\\.wezterm.lua` または `%USERPROFILE%\\.wezterm.lua`
- macOS / Linux (Unix系)
  `~/.wezterm.lua` または `~/.config/wezterm/wezterm.lua`

$\color{Black}{\tiny\textsf{※インストール直後などファィルがない場合は新規で作成してください}}$
:::

2.WezTermの設定ファイル(`wezterm.lua`)にプラグインの情報を追記します。
今回は新規に作成する場合で説明いたします。
「[公式のクイックスタートガイド][]」に記載されている基本構成は次のとおりです。

```wezterm.lua
-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 28

-- or, changing the font size and color scheme.
config.font_size = 10
config.color_scheme = 'AdventureTime'

-- Finally, return the configuration to wezterm:
return config
```

`--`から始まる行はすべてコメントです。
`return config`の前、今回はコメント`-- Finally～`の前にプラグイン情報を追記します。
完成形は次のとおりです。

```wezterm.lua
-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 28

-- or, changing the font size and color scheme.
config.font_size = 10
config.color_scheme = 'AdventureTime'

-- プラグインの設定　※追加
local ConvenientStatusBar = wezterm.plugin.require("https://github.com/aromatibus/ConvenientStatusBar.WezTerm")

ConvenientStatusBar.setup({
  api_key = "あなたのAPIキー",
})

-- Finally, return the configuration to wezterm:
return config
```

このままコピペしてしまうのが楽ですね！
WezTermを再起動すると情報が表示されるはずなんですがどうでしたか？

1. 成功！
![ConvenientStatusBar.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/588934/b95bc8ea-615f-451c-8070-5e5c2f69e979.png)

2. APIキーが正しくないと温度が表示されません。
![IncorrectAPI.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/588934/9586d3d0-0280-4369-8932-33640f098413.png)

3. おめでとうございます！温度も表示されていますね♪
![UnsupportedNERFfont.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/588934/804711b8-9978-4089-a787-7b8a2a33a7e1.png)
おや？よく見ると都市名の横のロケーションマークが表示されていませんね。
もしかするとカレンダーマークなども表示されていない方がいるかもしれません。
これはアイコンデータを収録した「[Nerd FONT][]」がインストールされていないか
使われているアイコンデータが含まれていないフォントで表示しているからなんです。

<!-- markdownlint-disable-next-line MD034 -->
https://www.nerdfonts.com

ここでは「[Nerd Fontのインストール方法]」については説明いたしませんが
「[WezTermのFONT設定]」をわたしが愛用している「[プログラミングフォント 白源]」を
例にして掲載いたします。

<!-- markdownlint-disable-next-line MD034 -->
https://github.com/yuru7/HackGen

わたしの設定では「`HackGen Console NF`」がフォント名です。
各自で使用するフォント名に差し替えてください。

```WezTerm.lua
-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 28

-- or, changing the font size and color scheme.
config.font_size = 10
config.color_scheme = 'AdventureTime'

-- フォントの設定　※追加
config.font = wezterm.font_with_fallback({
  { family = "HackGen Console NF", weight = "Regular" }
})

-- プラグインの設定
local ConvenientStatusBar = wezterm.plugin.require("https://github.com/aromatibus/ConvenientStatusBar.WezTerm")

ConvenientStatusBar.setup({
  api_key = "あなたのAPIキー",
})

-- Finally, return the configuration to wezterm:
return config

```

こんどこそ完成！！
![ConvenientStatusBar.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/588934/b95bc8ea-615f-451c-8070-5e5c2f69e979.png)

## ◆より詳細な設定をしてみよう

指定できる項目（引数）

```ConvenientStatusBar.lua

local ConvenientStatusBar = wezterm.plugin.require("https://github.com/aromatibus/ConvenientStatusBar.WezTerm")

ConvenientStatusBar.setup({
  api_key = "あなたのAPIキー",  -- [必須] ：Open Weather Mapから取得したAPIキーを設定します

  -- 以下はすべて省略可能です
  city            = "",        -- [省略可] 指定しない場合は現在のIPアドレスから取得されます
  country         = "",        -- [省略可] Cityを厳密に指定したい場合に指定します
  lang            = "en",      -- [省略可] 取得するデータの言語を指定します
  units           = "metric",  -- [省略可] 以下の2つから指定します
                                  metric (Celsius),
                                  imperial (Fahrenheit)
  update_interval = 600,       -- [省略可] Open Weather Mapへの再接続時間を秒で指定します
  colors = {
    background    = "#1A1B26", -- [省略可] 背景の色を指定します
    foreground    = "#7AA2F7", -- [省略可] タブの色を指定します
    text          = "#FFFFFF"  -- [省略可] 文字の色を指定します
  }
})
```

「[GitHubで公開][]」しているのでソース([init.lua][])を直接、自分の`Wezterm.lua`に取り込みめばより自由な設定ができますよ♪

## ◆おわりに

USBメモリで数々のソフトをポータブルで持ち歩ける環境を作成中です。
VHDXの仮想ファイル内に環境を作ることを想定しているのでWindowsPRO版をお持ちなら
パスワードによる暗号化もできて安全性もバッチリです。
ここをお読みなられる方ならインストールは非常に簡単になっています。
SCOOPを利用しているため使用できるソフトも多彩になっています。[^NotPortable]
現在、すでにほぼ問題なく動いているのですが興味が別に移ってしまったりすると
お見せできるのはいつになるのかわかりません$\color{Black}{\tiny\textbf{（汗）}}$

このプラグインがお役に立てれば嬉しいなぁ♪

<!-- markdownlint-disable-next-line MD034 -->
https://github.com/Aromatibus/ConvenientStatusBar.WezTerm

[GitHubで公開]: https://github.com/Aromatibus/ConvenientStatusBar.WezTerm

[Windows Terminal]: https://github.com/microsoft/terminal
[WezTerm]: https://wezterm.org/index.html
[GitHub上にオープンソースで開発]: https://github.com/wezterm/wezterm
[init.lua]: https://raw.githubusercontent.com/Aromatibus/ConvenientStatusBar.WezTerm/refs/heads/main/plugin/init.lua

[公式のクイックスタートガイド]: https://wezterm.org/config/files.html#quick-start
[WezTermのFONT設定]: https://wezterm.org/config/fonts.html
[ConvenientStatusBar]: https://github.com/Aromatibus/ConvenientStatusBar.WezTerm
[Open Weather]: https://openweathermap.org/
[会員登録ページ]: https://home.openweathermap.org/users/sign_up
[会員登録方法を検索]: https://www.google.com/search?q=open+weather+会員登録
[ここからAPIキーを取得]: https://home.openweathermap.org/api_keys
[Rust]: https://rust-lang.org/ja/
[Lua]: https://www.lua.org/
[Nerd Font]: https://www.nerdfonts.com/
[Nerd Fontのインストール方法]: https://www.google.com/search?q=Nerd+FONT+%E3%81%8A%E3%81%99%E3%81%99%E3%82%81
[プログラミングフォント 白源]: https://github.com/yuru7/HackGen

[^doesnt_respond]:マウスでターミナルやタブを閉じたりできるのは危険なんですけどね
[^NotPortable]:SCOOPはポータブル環境用だと思われがちですが実態は違います
