local wezterm = require 'wezterm'


--- ==========================================
--- パレット定義
--- ==========================================
local palette_list = {
    { name = "palevioletred",         source = "css",         hex = "#DB7093" },
    { name = "bara_iro",              source = "japanese",    hex = "#E9546B" },
    { name = "indianred",             source = "css",         hex = "#CD5C5C" },
    { name = "crimson",               source = "css",         hex = "#DC143C" },
    { name = "kurenai_iro",           source = "japanese",    hex = "#D7003A" },
    { name = "shinku_iro",            source = "japanese",    hex = "#A22041" },
    { name = "tobi_iro",              source = "japanese",    hex = "#95483F" },
    { name = "azuki_iro",             source = "japanese",    hex = "#96514D" },
    { name = "dobunezumi_iro",        source = "japanese",    hex = "#595455" },
    { name = "kuri_iro",              source = "japanese",    hex = "#554738" },
    { name = "sabi_iro",              source = "japanese",    hex = "#6C3524" },
    { name = "maroon",                source = "base16",      hex = "#800000" },
    { name = "darkred",               source = "css",         hex = "#8B0000" },
    { name = "brown",                 source = "css",         hex = "#A52A2A" },
    { name = "firebrick",             source = "css",         hex = "#B22222" },
    { name = "akane_iro",             source = "japanese",    hex = "#B7282E" },
    { name = "hi_iro",                source = "japanese",    hex = "#D3381C" },
    { name = "red",                   source = "base16",      hex = "#FF0000" },
    { name = "orangered",             source = "css",         hex = "#FF4500" },
    { name = "shu_iro",               source = "japanese",    hex = "#EB6101" },
    { name = "chocolate",             source = "css",         hex = "#D2691E" },
    { name = "saddlebrown",           source = "css",         hex = "#8B4513" },
    { name = "sienna",                source = "css",         hex = "#A0522D" },
    { name = "kurumi_iro",            source = "japanese",    hex = "#A86F4C" },
    { name = "susu_iro",              source = "japanese",    hex = "#887F7A" },
    { name = "suzu_iro",              source = "japanese",    hex = "#9EA1A3" },
    { name = "rosybrown",             source = "css",         hex = "#BC8F8F" },
    { name = "darksalmon",            source = "css",         hex = "#E9967A" },
    { name = "akebono_iro",           source = "japanese",    hex = "#F19072" },
    { name = "lightsalmon",           source = "css",         hex = "#FFA07A" },
    { name = "coral",                 source = "css",         hex = "#FF7F50" },
    { name = "kaki_iro",              source = "japanese",    hex = "#ED6D3D" },
    { name = "tomato",                source = "css",         hex = "#FF6347" },
    { name = "salmon",                source = "css",         hex = "#FA8072" },
    { name = "lightcoral",            source = "css",         hex = "#F08080" },
    { name = "usubeni_iro",           source = "japanese",    hex = "#F0908D" },
    { name = "peach",                 source = "complement",  hex = "#FF9E9E" },
    { name = "sango_iro",             source = "japanese",    hex = "#F5B1AA" },
    { name = "niji_iro",              source = "japanese",    hex = "#F6BFBC" },
    { name = "lightpink",             source = "css",         hex = "#FFB6C1" },
    { name = "pink",                  source = "css",         hex = "#FFC0CB" },
    { name = "thistle",               source = "css",         hex = "#D8BFD8" },
    { name = "lavender",              source = "css",         hex = "#E6E6FA" },
    { name = "aliceblue",             source = "css",         hex = "#F0F8FF" },
    { name = "ghostwhite",            source = "css",         hex = "#F8F8FF" },
    { name = "snow",                  source = "css",         hex = "#FFFAFA" },
    { name = "lavenderblush",         source = "css",         hex = "#FFF0F5" },
    { name = "mistyrose",             source = "css",         hex = "#FFE4E1" },
    { name = "seashell",              source = "css",         hex = "#FFF5EE" },
    { name = "linen",                 source = "css",         hex = "#FAF0E6" },
    { name = "oldlace",               source = "css",         hex = "#FDF5E6" },
    { name = "floralwhite",           source = "css",         hex = "#FFFAF0" },
    { name = "ivory",                 source = "css",         hex = "#FFFFF0" },
    { name = "honeydew",              source = "css",         hex = "#F0FFF0" },
    { name = "beige",                 source = "css",         hex = "#F5F5DC" },
    { name = "lightyellow",           source = "css",         hex = "#FFFFE0" },
    { name = "lightgoldenrodyellow",  source = "css",         hex = "#FAFAD2" },
    { name = "lemonchiffon",          source = "css",         hex = "#FFFACD" },
    { name = "cornsilk",              source = "css",         hex = "#FFF8DC" },
    { name = "papayawhip",            source = "css",         hex = "#FFEFD5" },
    { name = "antiquewhite",          source = "css",         hex = "#FAEBD7" },
    { name = "blanchedalmond",        source = "css",         hex = "#FFEBCD" },
    { name = "bisque",                source = "css",         hex = "#FFE4C4" },
    { name = "peachpuff",             source = "css",         hex = "#FFDAB9" },
    { name = "navajowhite",           source = "css",         hex = "#FFDEAD" },
    { name = "moccasin",              source = "css",         hex = "#FFE4B5" },
    { name = "wheat",                 source = "css",         hex = "#F5DEB3" },
    { name = "ama_iro",               source = "japanese",    hex = "#D6C6AF" },
    { name = "tan",                   source = "css",         hex = "#D2B48C" },
    { name = "burlywood",             source = "css",         hex = "#DEB887" },
    { name = "anzu_iro",              source = "japanese",    hex = "#F7B977" },
    { name = "sandybrown",            source = "css",         hex = "#F4A460" },
    { name = "ame_iro",               source = "japanese",    hex = "#DEB068" },
    { name = "hashibami_iro",         source = "japanese",    hex = "#BFA46F" },
    { name = "uguisu_iro",            source = "japanese",    hex = "#928C36" },
    { name = "kusa_iro",              source = "japanese",    hex = "#7B8D42" },
    { name = "olivedrab",             source = "css",         hex = "#6B8E23" },
    { name = "koke_iro",              source = "japanese",    hex = "#69821B" },
    { name = "olive",                 source = "base16",      hex = "#808000" },
    { name = "darkgoldenrod",         source = "css",         hex = "#B8860B" },
    { name = "kitsune_iro",           source = "japanese",    hex = "#C38743" },
    { name = "kohaku_iro",            source = "japanese",    hex = "#BF783A" },
    { name = "peru",                  source = "css",         hex = "#CD853F" },
    { name = "mikan_iro",             source = "japanese",    hex = "#F08300" },
    { name = "darkorange",            source = "css",         hex = "#FF8C00" },
    { name = "orange",                source = "css",         hex = "#FFA500" },
    { name = "yamabuki_iro",          source = "japanese",    hex = "#F8B500" },
    { name = "kogane_iro",            source = "japanese",    hex = "#E6B422" },
    { name = "goldenrod",             source = "css",         hex = "#DAA520" },
    { name = "karashi_iro",           source = "japanese",    hex = "#D0AF4C" },
    { name = "tamago_iro",            source = "japanese",    hex = "#FCD575" },
    { name = "gold",                  source = "css",         hex = "#FFD700" },
    { name = "tanpopo_iro",           source = "japanese",    hex = "#FFD900" },
    { name = "yellow",                source = "base16",      hex = "#FFFF00" },
    { name = "khaki",                 source = "css",         hex = "#F0E68C" },
    { name = "palegoldenrod",         source = "css",         hex = "#EEE8AA" },
    { name = "wakame_iro",            source = "japanese",    hex = "#E0EBAF" },
    { name = "wakaba_iro",            source = "japanese",    hex = "#B9D08B" },
    { name = "yanagi_iro",            source = "japanese",    hex = "#A8C97F" },
    { name = "moegi_iro",             source = "japanese",    hex = "#AACF53" },
    { name = "yellowgreen",           source = "css",         hex = "#9ACD32" },
    { name = "wakakusa_iro",          source = "japanese",    hex = "#C3D825" },
    { name = "maccha_iro",            source = "japanese",    hex = "#C5C56A" },
    { name = "darkkhaki",             source = "css",         hex = "#BDB76B" },
    { name = "wasabi_iro",            source = "japanese",    hex = "#A8BF93" },
    { name = "darkseagreen",          source = "css",         hex = "#8FBC8F" },
    { name = "wakatake_iro",          source = "japanese",    hex = "#68BE8D" },
    { name = "hisui_iro",             source = "japanese",    hex = "#38B48B" },
    { name = "mediumseagreen",        source = "css",         hex = "#3CB371" },
    { name = "limegreen",             source = "css",         hex = "#32CD32" },
    { name = "lime",                  source = "base16",      hex = "#00FF00" },
    { name = "lawngreen",             source = "css",         hex = "#7CFC00" },
    { name = "chartreuse",            source = "css",         hex = "#7FFF00" },
    { name = "greenyellow",           source = "css",         hex = "#ADFF2F" },
    { name = "palegreen",             source = "css",         hex = "#98FB98" },
    { name = "lightgreen",            source = "css",         hex = "#90EE90" },
    { name = "springgreen",           source = "css",         hex = "#00FF7F" },
    { name = "mediumspringgreen",     source = "css",         hex = "#00FA9A" },
    { name = "aquamarine",            source = "css",         hex = "#7FFFD4" },
    { name = "mintcream",             source = "css",         hex = "#F5FFFA" },
    { name = "azure",                 source = "css",         hex = "#F0FFFF" },
    { name = "lightcyan",             source = "css",         hex = "#E0FFFF" },
    { name = "paleturquoise",         source = "css",         hex = "#AFEEEE" },
    { name = "cyan",                  source = "base16",      hex = "#00FFFF" },
    { name = "turquoise",             source = "css",         hex = "#40E0D0" },
    { name = "mediumaquamarine",      source = "css",         hex = "#66CDAA" },
    { name = "mediumturquoise",       source = "css",         hex = "#48D1CC" },
    { name = "darkturquoise",         source = "css",         hex = "#00CED1" },
    { name = "lightseagreen",         source = "css",         hex = "#20B2AA" },
    { name = "cadetblue",             source = "css",         hex = "#5F9EA0" },
    { name = "darkcyan",              source = "css",         hex = "#008B8B" },
    { name = "teal",                  source = "base16",      hex = "#008080" },
    { name = "rokusho_iro",           source = "japanese",    hex = "#47885E" },
    { name = "seagreen",              source = "css",         hex = "#2E8B57" },
    { name = "forestgreen",           source = "css",         hex = "#228B22" },
    { name = "green",                 source = "base16",      hex = "#008000" },
    { name = "tokiwa_iro",            source = "japanese",    hex = "#007B43" },
    { name = "darkolivegreen",        source = "css",         hex = "#556B2F" },
    { name = "darkgreen",             source = "css",         hex = "#006400" },
    { name = "tetsu_iro",             source = "japanese",    hex = "#005243" },
    { name = "darkslategray",         source = "css",         hex = "#2F4F4F" },
    { name = "slategray",             source = "css",         hex = "#708090" },
    { name = "lightslategray",        source = "css",         hex = "#778899" },
    { name = "steelblue",             source = "css",         hex = "#4682B4" },
    { name = "dodgerblue",            source = "css",         hex = "#1E90FF" },
    { name = "cornflowerblue",        source = "css",         hex = "#6495ED" },
    { name = "tsuyukusa_iro",         source = "japanese",    hex = "#38A1DB" },
    { name = "deepskyblue",           source = "css",         hex = "#00BFFF" },
    { name = "lightskyblue",          source = "css",         hex = "#87CEFA" },
    { name = "skyblue",               source = "css",         hex = "#87CEEB" },
    { name = "sora_iro",              source = "japanese",    hex = "#A0D8EF" },
    { name = "lightblue",             source = "css",         hex = "#ADD8E6" },
    { name = "powderblue",            source = "css",         hex = "#B0E0E6" },
    { name = "mizu_iro",              source = "japanese",    hex = "#BCE2E8" },
    { name = "lightsteelblue",        source = "css",         hex = "#B0C4DE" },
    { name = "fuji_iro",              source = "japanese",    hex = "#BBBCDE" },
    { name = "plum",                  source = "css",         hex = "#DDA0DD" },
    { name = "violet",                source = "css",         hex = "#EE82EE" },
    { name = "orchid",                source = "css",         hex = "#DA70D6" },
    { name = "magenta",               source = "base16",      hex = "#FF00FF" },
    { name = "mediumorchid",          source = "css",         hex = "#BA55D3" },
    { name = "darkorchid",            source = "css",         hex = "#9932CC" },
    { name = "blueviolet",            source = "css",         hex = "#8A2BE2" },
    { name = "darkviolet",            source = "css",         hex = "#9400D3" },
    { name = "blue",                  source = "base16",      hex = "#0000FF" },
    { name = "mediumblue",            source = "css",         hex = "#0000CD" },
    { name = "deepsea",               source = "complement",  hex = "#2F2888" },
    { name = "abyss",                 source = "complement",  hex = "#252060" },
    { name = "midnightblue",          source = "css",         hex = "#191970" },
    { name = "navy",                  source = "base16",      hex = "#000080" },
    { name = "darkblue",              source = "css",         hex = "#00008B" },
    { name = "indigo",                source = "css",         hex = "#4B0082" },
    { name = "purple",                source = "base16",      hex = "#800080" },
    { name = "darkmagenta",           source = "css",         hex = "#8B008B" },
    { name = "rebeccapurple",         source = "css",         hex = "#663399" },
    { name = "darkslateblue",         source = "css",         hex = "#483D8B" },
    { name = "shobu_iro",             source = "japanese",    hex = "#674196" },
    { name = "sumire_iro",            source = "japanese",    hex = "#7058A3" },
    { name = "slateblue",             source = "css",         hex = "#6A5ACD" },
    { name = "kikyo_iro",             source = "japanese",    hex = "#5654A2" },
    { name = "ruri_iro",              source = "japanese",    hex = "#1E50A2" },
    { name = "kakitsubata_iro",       source = "japanese",    hex = "#3E62AD" },
    { name = "gunjo_iro",             source = "japanese",    hex = "#4C6CB3" },
    { name = "royalblue",             source = "css",         hex = "#4169E1" },
    { name = "mediumslateblue",       source = "css",         hex = "#7B68EE" },
    { name = "mediumpurple",          source = "css",         hex = "#9370DB" },
    { name = "shion_iro",             source = "japanese",    hex = "#867BA9" },
    { name = "rindo_iro",             source = "japanese",    hex = "#9079AD" },
    { name = "kyomurasaki_iro",       source = "japanese",    hex = "#9D5B8B" },
    { name = "mediumvioletred",       source = "css",         hex = "#C71585" },
    { name = "deeppink",              source = "css",         hex = "#FF1493" },
    { name = "tsutsuji_iro",          source = "japanese",    hex = "#E95295" },
    { name = "botan_iro",             source = "japanese",    hex = "#E7609E" },
    { name = "hotpink",               source = "css",         hex = "#FF69B4" },
    { name = "ayame_iro",             source = "japanese",    hex = "#CC7EB1" },
    { name = "white",                 source = "base16",      hex = "#FFFFFF" },
    { name = "whitesmoke",            source = "css",         hex = "#F5F5F5" },
    { name = "gainsboro",             source = "css",         hex = "#DCDCDC" },
    { name = "lightgray",             source = "css",         hex = "#D3D3D3" },
    { name = "silver",                source = "base16",      hex = "#C0C0C0" },
    { name = "darkgray",              source = "css",         hex = "#A9A9A9" },
    { name = "nezumi_iro",            source = "japanese",    hex = "#949495" },
    { name = "gray",                  source = "base16",      hex = "#808080" },
    { name = "dimgray",               source = "css",         hex = "#696969" },
    { name = "sumi_iro",              source = "japanese",    hex = "#595857" },
    { name = "slate",                 source = "complement",  hex = "#3A3A3A" },
    { name = "charcoal",              source = "complement",  hex = "#222222" },
    { name = "onyx",                  source = "complement",  hex = "#1B1B1B" },
    { name = "black",                 source = "css",         hex = "#000000" },
}


--- ==========================================
--- palettes（互換用マップ）
--- ==========================================
local palettes = {}
for _, p in ipairs(palette_list) do
  palettes[p.name] = p.hex
end


--- ==========================================
--- ANSI
--- ==========================================
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
  },
}


--- ==========================================
--- wezterm用 cp（lazy parse）
--- ==========================================
local cp = setmetatable({
  ansi = { base = {}, brights = {} },
}, {
  __index = function(t, k)
    local hex = palettes[k]
    if hex then
      local c = wezterm.color.parse(hex)
      rawset(t, k, c)
      return c
    end
  end,
})

for name, hex in pairs(ansi.base) do
  cp.ansi.base[name] = wezterm.color.parse(hex)
end
for name, hex in pairs(ansi.brights) do
  cp.ansi.brights[name] = wezterm.color.parse(hex)
end


--- ==========================================
--- パレットをテキストファイルに書き出す
--- ==========================================
local function export_palettes_to_file(path)
  local lines = {}
  local blocks = {}
  for _ in ipairs(palette_list) do
    table.insert(blocks, "■")
  end
  table.insert(lines, table.concat(blocks, ""))
  for _, p in ipairs(palette_list) do
    table.insert(lines, string.format("■:%-12s %s", p.name, p.hex))
  end
  local content = table.concat(lines, "\n") .. "\n"
  local file, err = io.open(path, "w")
  if not file then
    wezterm.log_error("Failed to write palette file: " .. tostring(err))
    return
  end
  file:write(content)
  file:close()
  wezterm.log_info("Palette exported to: " .. path)
end


--- ==========================================
--- モジュール返却
--- ==========================================
return {
  cp                       = cp,
  ansi                     = ansi,
  palettes                 = palettes,
  palette_list             = palette_list,
  export_palettes_to_file  = export_palettes_to_file,
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
