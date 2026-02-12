local wezterm = require 'wezterm'


--- ==========================================
--- カラーパレット定義（hex）
--- ==========================================
local palettes = {
  --- ==========================================
  --- Gradation
  --- ==========================================
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

  --- ==========================================
  --- Neon
  --- ==========================================
  neon_blue    = "#0050FF",
  neon_cyan    = "#7FFFFF",
  neon_green   = "#A0FF00",
  neon_yellow  = "#F7FF00",
  neon_orange  = "#FF9020",
  neon_red     = "#FF2040",
  neon_magenta = "#FF00FF",

  --- ==========================================
  --- Dark Neon
  --- ==========================================
  dark_blue    = "#1F3A8A",
  dark_cyan    = "#2FB7B7",
  dark_green   = "#5FA800",
  dark_yellow  = "#B3B800",
  dark_orange  = "#C86A1A",
  dark_red     = "#B02035",
  dark_magenta = "#B000B0",

  --- ==========================================
  --- Monochrome
  --- ==========================================
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


--- ==========================================
--- wezterm 用カラーパレット（parse 済み）
--- ==========================================
local cp = {}

for name, hex in pairs(palettes) do
  cp[name] = wezterm.color.parse(hex)
end


--- ==========================================
--- モジュール返却
--- ==========================================
return {
  palettes = palettes, -- hex 生値が欲しい場合用
  cp       = cp,       -- wezterm.color.parse 済み
}
