# ⧉準備中　WezTermプラグイン「ConvenientStatusBar」
![ConvenientStatusBar.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/588934/b95bc8ea-615f-451c-8070-5e5c2f69e979.png)



↑こんなのを[WezTerm][]の右側のステータスバーに表示します。
※すぐに使いたい方は[◆まずは使ってみよう！](#まずは使ってみよう)に進んでください。

## ◆閑話
「[Windows Terminal][]」のあまりの融通の利かなさに~~嫌気が差して~~良いターミナルを
探していたら出会えました。その名も$\color{Purple}{\textbf{WezTerm}}$です！！


:::note info
[WezTerm][]とは

WezTermはプログラム言語「[Rust][]」で書かれた、高速でGPUアクセラレーションにも対応した現代的なクロスプラットフォーム対応のターミナルエミュレータです。主な特徴は「[Lua][]言語」による高度なカスタマイズ性、画面分割機能、背景透過などの機能性です。GitHub上にオープンソースで開発されており、Windows、macOS、Linuxで動作するtmuxのような機能を内蔵した非常に強力なターミナルです。
:::

でもですね。第一印象はかなり悪かったんです。
ネットで見た評価が高くなかったら初見で使うのやめたと思います。
だって起動したら真っ暗でマウス操作もできなかったんですもの。
しかしそこからの「$\color{Red}{\huge\textbf{すっご～い、ス・テ・キ❤}}$」に変わるまでは
「$\color{Red}{\large\textbf{あっ}}$」と言うまでした（笑）

このプラグインはその熱い想いから勢いと情熱に任せて作成した
超優秀ターミナルソフト「[WezTerm][]」のステータスバー（右側限定）に
コンビニエンスな情報を表示する[プラグイン](https://ja.wikipedia.org/wiki/%E6%84%9B "❤❤❤❤❤")なのです！

$\color{black}{\tiny  \textsf{※注　似たようなものがあるかもしれないけど勢いって大事だと思います}}$
$\color{black}{\tiny  \textsf{ここまで読んでくれてありがとうございます♪}}$

## ◆表示できる情報は
冒頭にもありましたこれです。いつ作ったかバレバレ（笑）
![ConvenientStatusBar.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/588934/b95bc8ea-615f-451c-8070-5e5c2f69e979.png)
- 日付
- 時間
- Open Weather Mapからの天気情報
 　- 情報を取得した都市名
 　- その都市の現在の天気
 　- その都市の現在の温度
- ノートパソコンの場合、バッテリ残量の目安

以上の情報が表示されます。

## ◆まずは使ってみよう！

### ◯もっとも簡単な使い方

天気情報を表示するために必須となるAPIキー[Open Weather][]から取得します

1. Open Weatherの[会員登録ページ]から会員登録してください
2. 登録方法については[会員登録方法を検索][]してください（すみません）
3. 登録後、「[ここからAPIキーを取得]」してください

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


![ConvenientStatusBarImage](https://github.com/Aromatibus/ConvenientStatusBar.WezTerm/blob/main/img/ConvenientStatusBar.png)



<!-- markdownlint-disable-next-line MD033 -->
<details><summary>※※※　WezTermとは　※※※</summary>

:::note info
[WezTerm][]は、Rustで書かれた高速でGPUアクセラレーションに対応した、現代的なクロスプラットフォーム対応のターミナルエミュレータです。主な特徴はLua言語による高度なカスタマイズ性、画面分割機能、背景透過・ボカシなどの機能性です。GitHubで開発されており、Windows、macOS、Linuxで動作する、tmuxのような機能を内蔵した強力なターミナルです。
※GoogleAIの回答より抜粋
:::
</details>



[Windows Terminal]: https://github.com/microsoft/terminal
[WezTerm]: https://wezterm.org/index.html
[ConvenientStatusBar]: https://github.com/Aromatibus/ConvenientStatusBar.WezTerm
[Open Weather]: https://openweathermap.org/
[会員登録ページ]: https://home.openweathermap.org/users/sign_up
[会員登録方法を検索]: https://www.google.com/search?q=open+weather+会員登録
[ここからAPIキーを取得]: https://home.openweathermap.org/api_keys
[Rust]: https://rust-lang.org/ja/
[Lua]: https://www.lua.org/
