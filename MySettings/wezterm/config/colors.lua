local wezterm = require 'wezterm'
local M = {}


function M.apply(config)
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


  --- ==========================================================
  --- cpテーブルを返すための設定
  --- ==========================================================
  M.cp = cp
end


return M
