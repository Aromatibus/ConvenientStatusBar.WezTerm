local wezterm = require 'wezterm'


--- ==========================================
--- パレット定義
--- ==========================================
local palette_list = {
    { name = "cyclamenpink",          source = "western",              hex = "#F7ADC3" },
    { name = "lightpink",             source = "css",                  hex = "#FFB6C1" },
    { name = "koubai-iro",            source = "selected_from_japan",  hex = "#F2A0A1" },
    { name = "shrimppink",            source = "western",              hex = "#F6978F" },
    { name = "lightcoral",            source = "css",                  hex = "#F08080" },
    { name = "oldrose",               source = "western",              hex = "#D5848C" },
    { name = "rosybrown",             source = "css",                  hex = "#BC8F8F" },
    { name = "mountbattenpink",       source = "western",              hex = "#997A8D" },
    { name = "dovegray",              source = "western",              hex = "#8D8790" },
    { name = "mossgray",              source = "western",              hex = "#8F917F" },
    { name = "rosegray",              source = "western",              hex = "#948779" },
    { name = "fawn",                  source = "western",              hex = "#937B69" },
    { name = "biscuit",               source = "western",              hex = "#BC9C78" },
    { name = "abura-iro",             source = "selected_from_japan",  hex = "#A19361" },
    { name = "duckgreen",             source = "western",              hex = "#989E58" },
    { name = "uguisu-iro",            source = "selected_from_japan",  hex = "#928C36" },
    { name = "olive",                 source = "base16",               hex = "#808000" },
    { name = "koke-iro",              source = "selected_from_japan",  hex = "#69821B" },
    { name = "olivedrab",             source = "css",                  hex = "#6B8E23" },
    { name = "forestgreen",           source = "css",                  hex = "#228B22" },
    { name = "green",                 source = "base16",               hex = "#008000" },
    { name = "darkgreen",             source = "css",                  hex = "#006400" },
    { name = "chromegreen",           source = "western",              hex = "#006B3E" },
    { name = "tokiwa-iro",            source = "selected_from_japan",  hex = "#007B43" },
    { name = "ivygreen",              source = "western",              hex = "#487C38" },
    { name = "mossgreen",             source = "western",              hex = "#5B6F3A" },
    { name = "darkolivegreen",        source = "css",                  hex = "#556B2F" },
    { name = "olivegreen",            source = "western",              hex = "#576128" },
    { name = "ebony",                 source = "western",              hex = "#474931" },
    { name = "kawa-iro",              source = "selected_from_japan",  hex = "#475950" },
    { name = "riverblue",             source = "western",              hex = "#375A5F" },
    { name = "darkslategray",         source = "css",                  hex = "#2F4F4F" },
    { name = "birodo-iro",            source = "selected_from_japan",  hex = "#2F5D50" },
    { name = "evergreen",             source = "western",              hex = "#30583B" },
    { name = "spruce",                source = "western",              hex = "#004F2A" },
    { name = "bottlegreen",           source = "western",              hex = "#005739" },
    { name = "tetsu-iro",             source = "selected_from_japan",  hex = "#005243" },
    { name = "tealgreen",             source = "western",              hex = "#006956" },
    { name = "firgreen",              source = "western",              hex = "#356D64" },
    { name = "hookersgreen",          source = "western",              hex = "#49796B" },
    { name = "seiheki-iro",           source = "selected_from_japan",  hex = "#478384" },
    { name = "teal",                  source = "base16",               hex = "#008080" },
    { name = "nileblue",              source = "western",              hex = "#279E91" },
    { name = "lightseagreen",         source = "css",                  hex = "#20B2AA" },
    { name = "peacockgreen",          source = "western",              hex = "#00AE9D" },
    { name = "hisui-iro",             source = "selected_from_japan",  hex = "#38B48B" },
    { name = "emeraldgreen",          source = "western",              hex = "#00B379" },
    { name = "mediumseagreen",        source = "css",                  hex = "#3CB371" },
    { name = "malachitegreen",        source = "western",              hex = "#009D5B" },
    { name = "seagreen",              source = "css",                  hex = "#2E8B57" },
    { name = "viridian",              source = "western",              hex = "#00896B" },
    { name = "jadegreen",             source = "western",              hex = "#3F9877" },
    { name = "almondgreen",           source = "western",              hex = "#5D8165" },
    { name = "grassgreen",            source = "western",              hex = "#6D8346" },
    { name = "kusa-iro",              source = "selected_from_japan",  hex = "#7B8D42" },
    { name = "elmgreen",              source = "western",              hex = "#7A903E" },
    { name = "matsuba-iro",           source = "selected_from_japan",  hex = "#839B5C" },
    { name = "peagreen",              source = "western",              hex = "#89A368" },
    { name = "sagegreen",             source = "western",              hex = "#88A476" },
    { name = "wasabi-iro",            source = "selected_from_japan",  hex = "#A8BF93" },
    { name = "pistachogreen",         source = "western",              hex = "#B4CF9E" },
    { name = "wakaba-iro",            source = "selected_from_japan",  hex = "#B9D08B" },
    { name = "yanagi-iro",            source = "selected_from_japan",  hex = "#A8C97F" },
    { name = "leafgreen",             source = "western",              hex = "#91BA58" },
    { name = "darkkhaki",             source = "css",                  hex = "#BDB76B" },
    { name = "matcha-iro",            source = "selected_from_japan",  hex = "#C5C56A" },
    { name = "sulfuryellow",          source = "western",              hex = "#F1E266" },
    { name = "kanaria-iro",           source = "selected_from_japan",  hex = "#EBD842" },
    { name = "gold",                  source = "css",                  hex = "#FFD700" },
    { name = "lemonyellow",           source = "western",              hex = "#FFF450" },
    { name = "yellow",                source = "base16",               hex = "#FFFF00" },
    { name = "wakakusa-iro",          source = "selected_from_japan",  hex = "#C3D825" },
    { name = "yellowgreen",           source = "css",                  hex = "#9ACD32" },
    { name = "greenyellow",           source = "css",                  hex = "#ADFF2F" },
    { name = "chartreuse",            source = "css",                  hex = "#7FFF00" },
    { name = "lawngreen",             source = "css",                  hex = "#7CFC00" },
    { name = "lime",                  source = "base16",               hex = "#00FF00" },
    { name = "limegreen",             source = "css",                  hex = "#32CD32" },
    { name = "springgreen",           source = "css",                  hex = "#00FF7F" },
    { name = "mediumspringgreen",     source = "css",                  hex = "#00FA9A" },
    { name = "palegreen",             source = "css",                  hex = "#98FB98" },
    { name = "aquamarine",            source = "css",                  hex = "#7FFFD4" },
    { name = "mintgreen",             source = "western",              hex = "#90CE9C" },
    { name = "applegreen",            source = "western",              hex = "#96C78C" },
    { name = "darkseagreen",          source = "css",                  hex = "#8FBC8F" },
    { name = "wakatake-iro",          source = "selected_from_japan",  hex = "#68BE8D" },
    { name = "nilegreen",             source = "western",              hex = "#33CC99" },
    { name = "mediumaquamarine",      source = "css",                  hex = "#66CDAA" },
    { name = "seiji-iro",             source = "selected_from_japan",  hex = "#7EBEA5" },
    { name = "cadetblue",             source = "css",                  hex = "#5F9EA0" },
    { name = "peacockblue",           source = "western",              hex = "#00A2A4" },
    { name = "turquoiseblue",         source = "western",              hex = "#00B7CE" },
    { name = "darkturquoise",         source = "css",                  hex = "#00CED1" },
    { name = "mediumturquoise",       source = "css",                  hex = "#48D1CC" },
    { name = "turquoise",             source = "css",                  hex = "#40E0D0" },
    { name = "aqua",                  source = "css",                  hex = "#00FFFF" },
    { name = "paleturquoise",         source = "css",                  hex = "#AFEEEE" },
    { name = "lightcyan",             source = "css",                  hex = "#E0FFFF" },
    { name = "azure",                 source = "css",                  hex = "#F0FFFF" },
    { name = "ghostwhite",            source = "css",                  hex = "#F8F8FF" },
    { name = "lavender",              source = "css",                  hex = "#E6E6FA" },
    { name = "lightsteelblue",        source = "css",                  hex = "#B0C4DE" },
    { name = "fountainblue",          source = "western",              hex = "#C0CDDC" },
    { name = "skygray",               source = "western",              hex = "#BFC5CA" },
    { name = "kasumi-iro",            source = "selected_from_japan",  hex = "#C8C2C6" },
    { name = "dawnpink",              source = "western",              hex = "#D0B8BB" },
    { name = "pearlgray",             source = "western",              hex = "#BDBDB7" },
    { name = "ama-iro",               source = "selected_from_japan",  hex = "#D6C6AF" },
    { name = "peach",                 source = "western",              hex = "#FDD1B0" },
    { name = "lightsalmon",           source = "css",                  hex = "#FFA07A" },
    { name = "kawarake-iro",          source = "selected_from_japan",  hex = "#C37854" },
    { name = "terracotta",            source = "western",              hex = "#B66655" },
    { name = "kakishibu-iro",         source = "selected_from_japan",  hex = "#9F563A" },
    { name = "russet",                source = "western",              hex = "#974407" },
    { name = "sepia",                 source = "western",              hex = "#6B4A2B" },
    { name = "kuri-iro",              source = "selected_from_japan",  hex = "#762F07" },
    { name = "akasabi-iro",           source = "selected_from_japan",  hex = "#8A3319" },
    { name = "pompeianred",           source = "western",              hex = "#8D3635" },
    { name = "deepred",               source = "western",              hex = "#AF011C" },
    { name = "akane-iro",             source = "selected_from_japan",  hex = "#B7282E" },
    { name = "enji-iro",              source = "selected_from_japan",  hex = "#B94047" },
    { name = "carmine",               source = "western",              hex = "#D11C2C" },
    { name = "crimson",               source = "css",                  hex = "#DC143C" },
    { name = "cherryred",             source = "western",              hex = "#D9394E" },
    { name = "fuchsiared",            source = "western",              hex = "#E8204E" },
    { name = "strawberry",            source = "western",              hex = "#D83861" },
    { name = "azalea",                source = "western",              hex = "#CD4187" },
    { name = "mediumvioletred",       source = "css",                  hex = "#C71585" },
    { name = "fuchsiapurple",         source = "western",              hex = "#B455A0" },
    { name = "kyoumurasaki-iro",      source = "selected_from_japan",  hex = "#9D5B8B" },
    { name = "kodaimurasaki-iro",     source = "selected_from_japan",  hex = "#895B8A" },
    { name = "mauve",                 source = "western",              hex = "#855896" },
    { name = "edomurasaki-iro",       source = "selected_from_japan",  hex = "#745399" },
    { name = "purpleblue",            source = "western",              hex = "#6F51A1" },
    { name = "sumire-iro",            source = "selected_from_japan",  hex = "#7058A3" },
    { name = "bellflower",            source = "western",              hex = "#6658A6" },
    { name = "kikyo",                 source = "western",              hex = "#5654A2" },
    { name = "kikyou-iro",            source = "selected_from_japan",  hex = "#5654A2" },
    { name = "slateblue",             source = "css",                  hex = "#6A5ACD" },
    { name = "mediumslateblue",       source = "css",                  hex = "#7B68EE" },
    { name = "mediumpurple",          source = "css",                  hex = "#9370DB" },
    { name = "mediumorchid",          source = "css",                  hex = "#BA55D3" },
    { name = "darkorchid",            source = "css",                  hex = "#9932CC" },
    { name = "darkviolet",            source = "css",                  hex = "#9400D3" },
    { name = "blueviolet",            source = "css",                  hex = "#8A2BE2" },
    { name = "blue",                  source = "base16",               hex = "#0000FF" },
    { name = "mediumblue",            source = "css",                  hex = "#0000CD" },
    { name = "indigo",                source = "css",                  hex = "#4B0082" },
    { name = "darkblue",              source = "css",                  hex = "#00008B" },
    { name = "navy",                  source = "base16",               hex = "#000080" },
    { name = "midnightblue",          source = "css",                  hex = "#191970" },
    { name = "navyblue",              source = "western",              hex = "#1F2F54" },
    { name = "darkslateblue",         source = "css",                  hex = "#483D8B" },
    { name = "pansy",                 source = "western",              hex = "#583F99" },
    { name = "shoubu-iro",            source = "selected_from_japan",  hex = "#674196" },
    { name = "rebeccapurple",         source = "css",                  hex = "#663399" },
    { name = "darkmagenta",           source = "css",                  hex = "#8B008B" },
    { name = "budou-iro",             source = "selected_from_japan",  hex = "#522F60" },
    { name = "tyrianpurple",          source = "western",              hex = "#8E3F61" },
    { name = "raspberry",             source = "western",              hex = "#8D1A4A" },
    { name = "rosemadder",            source = "western",              hex = "#950042" },
    { name = "shinku-iro",            source = "selected_from_japan",  hex = "#A22041" },
    { name = "winered",               source = "western",              hex = "#8D3043" },
    { name = "garnet",                source = "western",              hex = "#691C23" },
    { name = "burgundy",              source = "western",              hex = "#561B24" },
    { name = "kokutan-iro",           source = "selected_from_japan",  hex = "#250D00" },
    { name = "charcoalgray",          source = "western",              hex = "#4C444D" },
    { name = "gunmetalgray",          source = "western",              hex = "#58535E" },
    { name = "taupe",                 source = "western",              hex = "#565565" },
    { name = "steelgray",             source = "western",              hex = "#6C676E" },
    { name = "slategray",             source = "css",                  hex = "#708090" },
    { name = "steelblue",             source = "css",                  hex = "#4682B4" },
    { name = "ceruleanblue",          source = "western",              hex = "#008CAF" },
    { name = "saxeblue",              source = "western",              hex = "#2E87A1" },
    { name = "duckblue",              source = "western",              hex = "#007394" },
    { name = "marineblue",            source = "western",              hex = "#006881" },
    { name = "ai-iro",                source = "selected_from_japan",  hex = "#165E83" },
    { name = "tealblue",              source = "western",              hex = "#004864" },
    { name = "inkblue",               source = "western",              hex = "#003F8E" },
    { name = "seiran-iro",            source = "selected_from_japan",  hex = "#274A78" },
    { name = "smalt",                 source = "western",              hex = "#28598F" },
    { name = "sapphireblue",          source = "western",              hex = "#0054A6" },
    { name = "seablue",               source = "western",              hex = "#235BC8" },
    { name = "ultramarine",           source = "western",              hex = "#465DAA" },
    { name = "gunjou-iro",            source = "selected_from_japan",  hex = "#4C6CB3" },
    { name = "royalblue",             source = "css",                  hex = "#4169E1" },
    { name = "cobaltblue",            source = "western",              hex = "#0072BC" },
    { name = "dodgerblue",            source = "css",                  hex = "#1E90FF" },
    { name = "cornflowerblue",        source = "css",                  hex = "#6495ED" },
    { name = "hyacinth",              source = "western",              hex = "#659AD2" },
    { name = "mayablue",              source = "western",              hex = "#73C2FB" },
    { name = "deepskyblue",           source = "css",                  hex = "#00BFFF" },
    { name = "forgetmenot",           source = "western",              hex = "#72C6EF" },
    { name = "skyblue",               source = "css",                  hex = "#87CEEB" },
    { name = "waterblue",             source = "western",              hex = "#AFDFE4" },
    { name = "watergreen",            source = "western",              hex = "#A5C9C1" },
    { name = "spraygreen",            source = "western",              hex = "#A4D5BD" },
    { name = "icegreen",              source = "western",              hex = "#CCE7D3" },
    { name = "celadon",               source = "western",              hex = "#C5D6B9" },
    { name = "parchment",             source = "western",              hex = "#E2E3CB" },
    { name = "oysterwhite",           source = "western",              hex = "#EDF0E0" },
    { name = "honeydew",              source = "css",                  hex = "#F0FFF0" },
    { name = "ivory",                 source = "css",                  hex = "#FFFFF0" },
    { name = "beige",                 source = "css",                  hex = "#F5F5DC" },
    { name = "lightyellow",           source = "css",                  hex = "#FFFFE0" },
    { name = "lightgoldenrodyellow",  source = "css",                  hex = "#FAFAD2" },
    { name = "natsumushi-iro",        source = "selected_from_japan",  hex = "#CEE4AE" },
    { name = "palegoldenrod",         source = "css",                  hex = "#EEE8AA" },
    { name = "kare-iro",              source = "selected_from_japan",  hex = "#E0C38C" },
    { name = "blond",                 source = "western",              hex = "#F3D18A" },
    { name = "naplesyellow",          source = "western",              hex = "#FFD167" },
    { name = "saffronyellow",         source = "western",              hex = "#FFCC40" },
    { name = "kogane-iro",            source = "selected_from_japan",  hex = "#E6B422" },
    { name = "honey",                 source = "western",              hex = "#E7BB5E" },
    { name = "indianyellow",          source = "western",              hex = "#E3A857" },
    { name = "mandarinorange",        source = "western",              hex = "#ED9E31" },
    { name = "orange",                source = "css",                  hex = "#FFA500" },
    { name = "mikan-iro",             source = "selected_from_japan",  hex = "#F08300" },
    { name = "topaz",                 source = "western",              hex = "#CD821F" },
    { name = "kitsune-iro",           source = "selected_from_japan",  hex = "#C38743" },
    { name = "darkgoldenrod",         source = "css",                  hex = "#B8860B" },
    { name = "rawumber",              source = "western",              hex = "#89652B" },
    { name = "cinnamon",              source = "western",              hex = "#AD6820" },
    { name = "chocolate",             source = "css",                  hex = "#D2691E" },
    { name = "yellowred",             source = "western",              hex = "#F36C21" },
    { name = "orangered",             source = "css",                  hex = "#FF4500" },
    { name = "cinnabar",              source = "western",              hex = "#E15A28" },
    { name = "kaba-iro",              source = "selected_from_japan",  hex = "#CD5E3C" },
    { name = "hi-iro",                source = "selected_from_japan",  hex = "#D3381C" },
    { name = "red",                   source = "base16",               hex = "#FF0000" },
    { name = "bronzered",             source = "western",              hex = "#EF4123" },
    { name = "tomatored",             source = "western",              hex = "#F15B55" },
    { name = "geraniumred",           source = "western",              hex = "#E45653" },
    { name = "poppyred",              source = "western",              hex = "#F04E58" },
    { name = "rose",                  source = "western",              hex = "#EF4868" },
    { name = "bougainvillaea",        source = "western",              hex = "#F16682" },
    { name = "rosered",               source = "western",              hex = "#F05F8D" },
    { name = "palevioletred",         source = "css",                  hex = "#DB7093" },
    { name = "cherrypink",            source = "western",              hex = "#F172A3" },
    { name = "redpurple",             source = "western",              hex = "#F067A6" },
    { name = "hotpink",               source = "css",                  hex = "#FF69B4" },
    { name = "azaleapink",            source = "western",              hex = "#FF3399" },
    { name = "fuchsia",               source = "css",                  hex = "#FF00FF" },
    { name = "orchid",                source = "css",                  hex = "#DA70D6" },
    { name = "violet",                source = "css",                  hex = "#EE82EE" },
    { name = "plum",                  source = "css",                  hex = "#DDA0DD" },
    { name = "ayame-iro",             source = "selected_from_japan",  hex = "#CC7EB1" },
    { name = "amethyst",              source = "western",              hex = "#9E76B4" },
    { name = "heliotrope",            source = "western",              hex = "#8A77B7" },
    { name = "shion-iro",             source = "selected_from_japan",  hex = "#867BA9" },
    { name = "wisteria",              source = "western",              hex = "#8689C3" },
    { name = "crocus",                source = "western",              hex = "#A5A0CF" },
    { name = "fuji-iro",              source = "selected_from_japan",  hex = "#BBBCDE" },
    { name = "lilac",                 source = "western",              hex = "#C7B2D6" },
    { name = "thistle",               source = "css",                  hex = "#D8BFD8" },
    { name = "nadeshiko-iro",         source = "selected_from_japan",  hex = "#EEBBCB" },
    { name = "white",                 source = "base16",               hex = "#FFFFFF" },
    { name = "gofun-iro",             source = "selected_from_japan",  hex = "#FFFFFC" },
    { name = "unohana-iro",           source = "selected_from_japan",  hex = "#F7FCFE" },
    { name = "hakuji-iro",            source = "selected_from_japan",  hex = "#F8FBF8" },
    { name = "snowwhite",             source = "western",              hex = "#F4FBFE" },
    { name = "gainsboro",             source = "css",                  hex = "#DCDCDC" },
    { name = "silver",                source = "base16",               hex = "#C0C0C0" },
    { name = "darkgray",              source = "css",                  hex = "#A9A9A9" },
    { name = "ashgrey",               source = "western",              hex = "#949593" },
    { name = "gray",                  source = "base16",               hex = "#808080" },
    { name = "dimgray",               source = "css",                  hex = "#696969" },
    { name = "youkan-iro",            source = "selected_from_japan",  hex = "#383C3C" },
    { name = "ivoryblack",            source = "western",              hex = "#333132" },
    { name = "karasuba-iro",          source = "selected_from_japan",  hex = "#180614" },
    { name = "shikkoku-iro",          source = "selected_from_japan",  hex = "#0D0015" },
    { name = "black",                 source = "css",                  hex = "#000000" },
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
