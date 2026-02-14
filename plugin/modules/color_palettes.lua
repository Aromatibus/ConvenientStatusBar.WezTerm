local wezterm = require 'wezterm'


--- ==========================================
--- パレット定義
--- ==========================================
local palette_list = {
    { name = "palevioletred",               hex = "#DB7093" }, -- css
    { name = "ayame_iro",                   hex = "#CC7EB1" }, -- japanese
    { name = "plum",                        hex = "#DDA0DD" }, -- css
    { name = "violet",                      hex = "#EE82EE" }, -- css
    { name = "orchid",                      hex = "#DA70D6" }, -- css
    { name = "magenta",                     hex = "#FF00FF" }, -- base16
    { name = "mediumorchid",                hex = "#BA55D3" }, -- css
    { name = "darkorchid",                  hex = "#9932CC" }, -- css
    { name = "darkviolet",                  hex = "#9400D3" }, -- css
    { name = "blueviolet",                  hex = "#8A2BE2" }, -- css
    { name = "blue",                        hex = "#0000FF" }, -- base16
    { name = "mediumblue",                  hex = "#0000CD" }, -- css
    { name = "indigo",                      hex = "#4B0082" }, -- css
    { name = "darkblue",                    hex = "#00008B" }, -- css
    { name = "navy",                        hex = "#000080" }, -- base16
    { name = "midnightblue",                hex = "#191970" }, -- css
    { name = "abyss",                       hex = "#252060" }, -- complement
    { name = "shikkoku_iro",                hex = "#0D0015" }, -- japanese
    { name = "purple",                      hex = "#800080" }, -- base16
    { name = "darkmagenta",                 hex = "#8B008B" }, -- css
    { name = "mediumvioletred",             hex = "#C71585" }, -- css
    { name = "kyomurasaki_iro",             hex = "#9D5B8B" }, -- japanese
    { name = "rindo_iro",                   hex = "#9079AD" }, -- japanese
    { name = "shion_iro",                   hex = "#867BA9" }, -- japanese
    { name = "mediumpurple",                hex = "#9370DB" }, -- css
    { name = "mediumslateblue",             hex = "#7B68EE" }, -- css
    { name = "slateblue",                   hex = "#6A5ACD" }, -- css
    { name = "kikyo_iro",                   hex = "#5654A2" }, -- japanese
    { name = "sumire_iro",                  hex = "#7058A3" }, -- japanese
    { name = "shobu_iro",                   hex = "#674196" }, -- japanese
    { name = "rebeccapurple",               hex = "#663399" }, -- css
    { name = "darkslateblue",               hex = "#483D8B" }, -- css
    { name = "deepsea",                     hex = "#2F2888" }, -- complement
    { name = "kon_iro",                     hex = "#223A70" }, -- japanese
    { name = "ruri_iro",                    hex = "#1E50A2" }, -- japanese
    { name = "kakitsubata_iro",             hex = "#3E62AD" }, -- japanese
    { name = "gunjo_iro",                   hex = "#4C6CB3" }, -- japanese
    { name = "royalblue",                   hex = "#4169E1" }, -- css
    { name = "slategray",                   hex = "#708090" }, -- css
    { name = "lightslategray",              hex = "#778899" }, -- css
    { name = "steelblue",                   hex = "#4682B4" }, -- css
    { name = "dodgerblue",                  hex = "#1E90FF" }, -- css
    { name = "cornflowerblue",              hex = "#6495ED" }, -- css
    { name = "tsuyukusa_iro",               hex = "#38A1DB" }, -- japanese
    { name = "deepskyblue",                 hex = "#00BFFF" }, -- css
    { name = "lightskyblue",                hex = "#87CEFA" }, -- css
    { name = "skyblue",                     hex = "#87CEEB" }, -- css
    { name = "sora_iro",                    hex = "#A0D8EF" }, -- japanese
    { name = "lightblue",                   hex = "#ADD8E6" }, -- css
    { name = "powderblue",                  hex = "#B0E0E6" }, -- css
    { name = "mizu_iro",                    hex = "#BCE2E8" }, -- japanese
    { name = "lightcyan",                   hex = "#E0FFFF" }, -- css
    { name = "paleturquoise",               hex = "#AFEEEE" }, -- css
    { name = "cyan",                        hex = "#00FFFF" }, -- base16
    { name = "turquoise",                   hex = "#40E0D0" }, -- css
    { name = "mediumturquoise",             hex = "#48D1CC" }, -- css
    { name = "darkturquoise",               hex = "#00CED1" }, -- css
    { name = "lightseagreen",               hex = "#20B2AA" }, -- css
    { name = "cadetblue",                   hex = "#5F9EA0" }, -- css
    { name = "suzu_iro",                    hex = "#9EA1A3" }, -- japanese
    { name = "lightsteelblue",              hex = "#B0C4DE" }, -- css
    { name = "fuji_iro",                    hex = "#BBBCDE" }, -- japanese
    { name = "lavender",                    hex = "#E6E6FA" }, -- css
    { name = "lavenderblush",               hex = "#FFF0F5" }, -- css
    { name = "mistyrose",                   hex = "#FFE4E1" }, -- css
    { name = "niji_iro",                    hex = "#F6BFBC" }, -- japanese
    { name = "sango_iro",                   hex = "#F5B1AA" }, -- japanese
    { name = "lightpink",                   hex = "#FFB6C1" }, -- css
    { name = "pink",                        hex = "#FFC0CB" }, -- css
    { name = "thistle",                     hex = "#D8BFD8" }, -- css
    { name = "rosybrown",                   hex = "#BC8F8F" }, -- css
    { name = "susu_iro",                    hex = "#887F7A" }, -- japanese
    { name = "dobunezumi_iro",              hex = "#595455" }, -- japanese
    { name = "kuri_iro",                    hex = "#554738" }, -- japanese
    { name = "darkslategray",               hex = "#2F4F4F" }, -- css
    { name = "tetsu_iro",                   hex = "#005243" }, -- japanese
    { name = "teal",                        hex = "#008080" }, -- base16
    { name = "darkcyan",                    hex = "#008B8B" }, -- css
    { name = "rokusho_iro",                 hex = "#47885E" }, -- japanese
    { name = "seagreen",                    hex = "#2E8B57" }, -- css
    { name = "tokiwa_iro",                  hex = "#007B43" }, -- japanese
    { name = "forestgreen",                 hex = "#228B22" }, -- css
    { name = "green",                       hex = "#008000" }, -- base16
    { name = "darkgreen",                   hex = "#006400" }, -- css
    { name = "darkolivegreen",              hex = "#556B2F" }, -- css
    { name = "koke_iro",                    hex = "#69821B" }, -- japanese
    { name = "olivedrab",                   hex = "#6B8E23" }, -- css
    { name = "kusa_iro",                    hex = "#7B8D42" }, -- japanese
    { name = "olive",                       hex = "#808000" }, -- base16
    { name = "uguisu_iro",                  hex = "#928C36" }, -- japanese
    { name = "darkkhaki",                   hex = "#BDB76B" }, -- css
    { name = "maccha_iro",                  hex = "#C5C56A" }, -- japanese
    { name = "karashi_iro",                 hex = "#D0AF4C" }, -- japanese
    { name = "kogane_iro",                  hex = "#E6B422" }, -- japanese
    { name = "goldenrod",                   hex = "#DAA520" }, -- css
    { name = "darkgoldenrod",               hex = "#B8860B" }, -- css
    { name = "oudo_iro",                    hex = "#C39143" }, -- japanese
    { name = "kitsune_iro",                 hex = "#C38743" }, -- japanese
    { name = "peru",                        hex = "#CD853F" }, -- css
    { name = "mikan_iro",                   hex = "#F08300" }, -- japanese
    { name = "darkorange",                  hex = "#FF8C00" }, -- css
    { name = "orange",                      hex = "#FFA500" }, -- css
    { name = "yamabuki_iro",                hex = "#F8B500" }, -- japanese
    { name = "gold",                        hex = "#FFD700" }, -- css
    { name = "tanpopo_iro",                 hex = "#FFD900" }, -- japanese
    { name = "yellow",                      hex = "#FFFF00" }, -- base16
    { name = "wakakusa_iro",                hex = "#C3D825" }, -- japanese
    { name = "moegi_iro",                   hex = "#AACF53" }, -- japanese
    { name = "yellowgreen",                 hex = "#9ACD32" }, -- css
    { name = "greenyellow",                 hex = "#ADFF2F" }, -- css
    { name = "chartreuse",                  hex = "#7FFF00" }, -- css
    { name = "lawngreen",                   hex = "#7CFC00" }, -- css
    { name = "lime",                        hex = "#00FF00" }, -- base16
    { name = "springgreen",                 hex = "#00FF7F" }, -- css
    { name = "mediumspringgreen",           hex = "#00FA9A" }, -- css
    { name = "lightgreen",                  hex = "#90EE90" }, -- css
    { name = "palegreen",                   hex = "#98FB98" }, -- css
    { name = "aquamarine",                  hex = "#7FFFD4" }, -- css
    { name = "mediumaquamarine",            hex = "#66CDAA" }, -- css
    { name = "wakatake_iro",                hex = "#68BE8D" }, -- japanese
    { name = "hisui_iro",                   hex = "#38B48B" }, -- japanese
    { name = "mediumseagreen",              hex = "#3CB371" }, -- css
    { name = "limegreen",                   hex = "#32CD32" }, -- css
    { name = "darkseagreen",                hex = "#8FBC8F" }, -- css
    { name = "wasabi_iro",                  hex = "#A8BF93" }, -- japanese
    { name = "yanagi_iro",                  hex = "#A8C97F" }, -- japanese
    { name = "wakaba_iro",                  hex = "#B9D08B" }, -- japanese
    { name = "wakame_iro",                  hex = "#E0EBAF" }, -- japanese
    { name = "palegoldenrod",               hex = "#EEE8AA" }, -- css
    { name = "khaki",                       hex = "#F0E68C" }, -- css
    { name = "tamago_iro",                  hex = "#FCD575" }, -- japanese
    { name = "lemonchiffon",                hex = "#FFFACD" }, -- css
    { name = "lightgoldenrodyellow",        hex = "#FAFAD2" }, -- css
    { name = "lightyellow",                 hex = "#FFFFE0" }, -- css
    { name = "cornsilk",                    hex = "#FFF8DC" }, -- css
    { name = "beige",                       hex = "#F5F5DC" }, -- css
    { name = "ivory",                       hex = "#FFFFF0" }, -- css
    { name = "honeydew",                    hex = "#F0FFF0" }, -- css
    { name = "mintcream",                   hex = "#F5FFFA" }, -- css
    { name = "azure",                       hex = "#F0FFFF" }, -- css
    { name = "aliceblue",                   hex = "#F0F8FF" }, -- css
    { name = "ghostwhite",                  hex = "#F8F8FF" }, -- css
    { name = "snow",                        hex = "#FFFAFA" }, -- css
    { name = "seashell",                    hex = "#FFF5EE" }, -- css
    { name = "floralwhite",                 hex = "#FFFAF0" }, -- css
    { name = "oldlace",                     hex = "#FDF5E6" }, -- css
    { name = "linen",                       hex = "#FAF0E6" }, -- css
    { name = "antiquewhite",                hex = "#FAEBD7" }, -- css
    { name = "papayawhip",                  hex = "#FFEFD5" }, -- css
    { name = "blanchedalmond",              hex = "#FFEBCD" }, -- css
    { name = "bisque",                      hex = "#FFE4C4" }, -- css
    { name = "peachpuff",                   hex = "#FFDAB9" }, -- css
    { name = "navajowhite",                 hex = "#FFDEAD" }, -- css
    { name = "moccasin",                    hex = "#FFE4B5" }, -- css
    { name = "wheat",                       hex = "#F5DEB3" }, -- css
    { name = "ama_iro",                     hex = "#D6C6AF" }, -- japanese
    { name = "tan",                         hex = "#D2B48C" }, -- css
    { name = "burlywood",                   hex = "#DEB887" }, -- css
    { name = "hashibami_iro",               hex = "#BFA46F" }, -- japanese
    { name = "ame_iro",                     hex = "#DEB068" }, -- japanese
    { name = "anzu_iro",                    hex = "#F7B977" }, -- japanese
    { name = "sandybrown",                  hex = "#F4A460" }, -- css
    { name = "lightsalmon",                 hex = "#FFA07A" }, -- css
    { name = "darksalmon",                  hex = "#E9967A" }, -- css
    { name = "akebono_iro",                 hex = "#F19072" }, -- japanese
    { name = "coral",                       hex = "#FF7F50" }, -- css
    { name = "kaki_iro",                    hex = "#ED6D3D" }, -- japanese
    { name = "tomato",                      hex = "#FF6347" }, -- css
    { name = "salmon",                      hex = "#FA8072" }, -- css
    { name = "lightcoral",                  hex = "#F08080" }, -- css
    { name = "usubeni_iro",                 hex = "#F0908D" }, -- japanese
    { name = "peach",                       hex = "#FF9E9E" }, -- complement
    { name = "momo_iro",                    hex = "#F09199" }, -- japanese
    { name = "bara_iro",                    hex = "#E9546B" }, -- japanese
    { name = "indianred",                   hex = "#CD5C5C" }, -- css
    { name = "hi_iro",                      hex = "#D3381C" }, -- japanese
    { name = "red",                         hex = "#FF0000" }, -- base16
    { name = "orangered",                   hex = "#FF4500" }, -- css
    { name = "shu_iro",                     hex = "#EB6101" }, -- japanese
    { name = "chocolate",                   hex = "#D2691E" }, -- css
    { name = "kohaku_iro",                  hex = "#BF783A" }, -- japanese
    { name = "tsuchi_iro",                  hex = "#BC763C" }, -- japanese
    { name = "kurumi_iro",                  hex = "#A86F4C" }, -- japanese
    { name = "sienna",                      hex = "#A0522D" }, -- css
    { name = "saddlebrown",                 hex = "#8B4513" }, -- css
    { name = "tobi_iro",                    hex = "#95483F" }, -- japanese
    { name = "azuki_iro",                   hex = "#96514D" }, -- japanese
    { name = "sabi_iro",                    hex = "#6C3524" }, -- japanese
    { name = "maroon",                      hex = "#800000" }, -- base16
    { name = "darkred",                     hex = "#8B0000" }, -- css
    { name = "firebrick",                   hex = "#B22222" }, -- css
    { name = "akane_iro",                   hex = "#B7282E" }, -- japanese
    { name = "brown",                       hex = "#A52A2A" }, -- css
    { name = "shinku_iro",                  hex = "#A22041" }, -- japanese
    { name = "kurenai_iro",                 hex = "#D7003A" }, -- japanese
    { name = "crimson",                     hex = "#DC143C" }, -- css
    { name = "deeppink",                    hex = "#FF1493" }, -- css
    { name = "tsutsuji_iro",                hex = "#E95295" }, -- japanese
    { name = "botan_iro",                   hex = "#E7609E" }, -- japanese
    { name = "hotpink",                     hex = "#FF69B4" }, -- css
    { name = "white",                       hex = "#FFFFFF" }, -- base16
    { name = "whitesmoke",                  hex = "#F5F5F5" }, -- css
    { name = "gainsboro",                   hex = "#DCDCDC" }, -- css
    { name = "lightgray",                   hex = "#D3D3D3" }, -- css
    { name = "silver",                      hex = "#C0C0C0" }, -- base16
    { name = "darkgray",                    hex = "#A9A9A9" }, -- css
    { name = "nezumi_iro",                  hex = "#949495" }, -- japanese
    { name = "gray",                        hex = "#808080" }, -- base16
    { name = "dimgray",                     hex = "#696969" }, -- css
    { name = "sumi_iro",                    hex = "#595857" }, -- japanese
    { name = "slate",                       hex = "#3A3A3A" }, -- complement
    { name = "charcoal",                    hex = "#222222" }, -- complement
    { name = "onyx",                        hex = "#1B1B1B" }, -- complement
    { name = "black",                       hex = "#000000" }, -- css
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
