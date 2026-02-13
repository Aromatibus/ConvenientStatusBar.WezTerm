local wezterm = require 'wezterm'


--- ==========================================
--- カラーパレット定義（hex）
--- ==========================================
local palettes = {
  --- Gradation
  ocean        = "#3B82F6",
  horizon      = "#4F9CFF",
  cerulean     = "#5AA7FF",
  summer       = "#63B5FF",
  cirrus       = "#77CEFF",
  glacier      = "#8BE7FF",
  lagoon       = "#9FFFFF",
  mint         = "#B5FFE0",
  aquamarine   = "#9FEFD3",
  jade         = "#7EE0B0",
  viridian     = "#66D1A7",
  emerald      = "#40B090",
  forest       = "#2F8F6F",
  moss         = "#4FA87A",
  leaf         = "#6FC08A",
  spring       = "#8FD89A",
  meadow       = "#A6E3A0",
  pistachio    = "#C4F0A0",
  sprout       = "#CCFFC0",
  chartreuse   = "#E0FF90",
  lime         = "#F0FF80",
  yellow       = "#FFFF70",
  lemon        = "#FFF97A",
  sunshine     = "#FFEF70",
  honey        = "#FFE060",
  amber        = "#FFD04A",
  apricot      = "#FFC050",
  tangerine    = "#FFA040",
  persimmon    = "#FF8038",
  vermilion    = "#FF6030",
  red          = "#FF4040",
  ember        = "#FF5050",
  rose         = "#FF6A6A",
  coral        = "#FF8484",
  peach        = "#FF9E9E",
  blush        = "#FFB8B8",
  petal        = "#FFB2C9",
  sakura       = "#FFA0D0",
  rose_pink    = "#FF7FBF",
  mulberry     = "#F06FB2",
  magenta      = "#E85BC7",
  berry        = "#D96BCB",
  wisteria     = "#E090FF",
  lavender     = "#C080FF",
  iris         = "#A070FF",
  amethyst     = "#8860FF",
  heliotrope   = "#7E63FF",
  twilight     = "#7050FF",
  cobalt       = "#5A40FF",
  blue         = "#3F4DFF",
  sapphire     = "#3A3CF2",
  midnight     = "#352EE0",
  starlight    = "#3B30C0",
  deep_sea     = "#2F2888",
  abyss        = "#252060",

  --- Neon
  neon_blue    = "#0050FF",
  neon_cyan    = "#7FFFFF",
  neon_green   = "#A0FF00",
  neon_yellow  = "#F7FF00",
  neon_orange  = "#FF9020",
  neon_red     = "#FF2040",
  neon_magenta = "#FF00FF",

  --- Dark
  dark_blue    = "#1F3A8A",
  dark_cyan    = "#2FB7B7",
  dark_green   = "#5FA800",
  dark_yellow  = "#B3B800",
  dark_orange  = "#C86A1A",
  dark_red     = "#B02035",
  dark_magenta = "#B000B0",

  --- Monochrome
  black        = "#000000",
  onyx         = "#1B1A2C",
  charcoal     = "#222222",
  slate        = "#3A3A3A",
  ash          = "#5A5A5A",
  smoke        = "#7A7A7A",
  fog          = "#A0A0A0",
  silver       = "#BABABA",
  grey         = "#E0E0E0",
  white        = "#FFFFFF",
}


-- ===============================
-- ANSI Colors
-- ===============================
local ansi = {
  base = {
    black   = "#000000",
    red     = "#CD0000",
    green   = "#00CD00",
    yellow  = "#CDCD00",
    blue    = "#0000EE",
    magenta = "#CD00CD",
    cyan    = "#00CDCD",
    white   = "#E5E5E5",
  },
  brights = {
    black   = "#7F7F7F",
    red     = "#FF0000",
    green   = "#00FF00",
    yellow  = "#FFFF00",
    blue    = "#5C5CFF",
    magenta = "#FF00FF",
    cyan    = "#00FFFF",
    white   = "#FFFFFF",
  }
}


--- ==========================================
--- wezterm 用カラーパレット（parse処理）
--- ==========================================
-- wezterm.color.parse 用テーブル
local cp = {}
cp.ansi = {
  base    = {},
  brights = {},
}

-- Parse 処理
for name, hex in pairs(palettes) do
  cp[name] = wezterm.color.parse(hex)
end
for name, hex in pairs(ansi.base) do
  cp.ansi.base[name] = wezterm.color.parse(hex)
end
for name, hex in pairs(ansi.brights) do
  cp.ansi.brights[name] = wezterm.color.parse(hex)
end


--- ==========================================
--- パレット可視化関数
--- ==========================================
local function display_palettes()
    local line_blocks = {}
    local lines_named = {}

    -- 1行目: ■だけを横並び
    for _, _ in pairs(palettes) do
        table.insert(line_blocks, "■")
    end

    -- 2行目以降: ■:カラー名 を1色ずつ縦に表示
    for name, _ in pairs(palettes) do
        table.insert(lines_named, "■:" .. name)
    end

    local message =
        table.concat(line_blocks, " ")
        .. "\n"
        .. table.concat(lines_named, "\n")

    wezterm.log_info(message)
end


--- ==========================================
--- Color Palettes モジュール返却
--- ==========================================
return {
  cp       = cp,
  ansi     = ansi,
  display_palettes = display_palettes,
}


--[[
こんな感じで使える

-- ==========================================
-- カラーパレット
-- ==========================================
-- カラーパレットモジュールからカラーデータ取得
local color_palettes = require("color_palettes")
-- パレットデータ
local cp = color_palettes.cp
local ansi = color_palettes.ansi

-- パレット可視化（ログ出力）
color_palettes.display_palettes()

-- ANSI 16色
config.colors = {
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
]]
