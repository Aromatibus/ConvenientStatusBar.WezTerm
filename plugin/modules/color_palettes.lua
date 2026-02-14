local wezterm = require 'wezterm'


--- ==========================================
--- パレット定義（順序付き・完全版）
--- ==========================================
local palette_list = {
    -- Gradation
    { name = "ocean",        hex = "#3B82F6" },
    { name = "horizon",      hex = "#4F9CFF" },
    { name = "cerulean",     hex = "#5AA7FF" },
    { name = "summer",       hex = "#63B5FF" },
    { name = "cirrus",       hex = "#77CEFF" },
    { name = "glacier",      hex = "#8BE7FF" },
    { name = "lagoon",       hex = "#9FFFFF" },
    { name = "mint",         hex = "#B5FFE0" },
    { name = "aquamarine",   hex = "#9FEFD3" },
    { name = "jade",         hex = "#7EE0B0" },
    { name = "viridian",     hex = "#66D1A7" },
    { name = "emerald",      hex = "#40B090" },
    { name = "forest",       hex = "#2F8F6F" },
    { name = "moss",         hex = "#4FA87A" },
    { name = "leaf",         hex = "#6FC08A" },
    { name = "spring",       hex = "#8FD89A" },
    { name = "meadow",       hex = "#A6E3A0" },
    { name = "pistachio",    hex = "#C4F0A0" },
    { name = "sprout",       hex = "#CCFFC0" },
    { name = "chartreuse",   hex = "#E0FF90" },
    { name = "lime",         hex = "#F0FF80" },
    { name = "yellow",       hex = "#FFFF70" },
    { name = "lemon",        hex = "#FFF97A" },
    { name = "sunshine",     hex = "#FFEF70" },
    { name = "honey",        hex = "#FFE060" },
    { name = "amber",        hex = "#FFD04A" },
    { name = "apricot",      hex = "#FFC050" },
    { name = "tangerine",    hex = "#FFA040" },
    { name = "persimmon",    hex = "#FF8038" },
    { name = "vermilion",    hex = "#FF6030" },
    { name = "red",          hex = "#FF4040" },
    { name = "ember",        hex = "#FF5050" },
    { name = "rose",         hex = "#FF6A6A" },
    { name = "coral",        hex = "#FF8484" },
    { name = "peach",        hex = "#FF9E9E" },
    { name = "blush",        hex = "#FFB8B8" },
    { name = "petal",        hex = "#FFB2C9" },
    { name = "sakura",       hex = "#FFA0D0" },
    { name = "rose_pink",    hex = "#FF7FBF" },
    { name = "mulberry",     hex = "#F06FB2" },
    { name = "magenta",      hex = "#E85BC7" },
    { name = "berry",        hex = "#D96BCB" },
    { name = "wisteria",     hex = "#E090FF" },
    { name = "lavender",     hex = "#C080FF" },
    { name = "iris",         hex = "#A070FF" },
    { name = "amethyst",     hex = "#8860FF" },
    { name = "heliotrope",   hex = "#7E63FF" },
    { name = "twilight",     hex = "#7050FF" },
    { name = "cobalt",       hex = "#5A40FF" },
    { name = "blue",         hex = "#3F4DFF" },
    { name = "sapphire",     hex = "#3A3CF2" },
    { name = "midnight",     hex = "#352EE0" },
    { name = "starlight",    hex = "#3B30C0" },
    { name = "deep_sea",     hex = "#2F2888" },
    { name = "abyss",        hex = "#252060" },

    -- Neon
    { name = "neon_blue",    hex = "#0050FF" },
    { name = "neon_cyan",    hex = "#7FFFFF" },
    { name = "neon_green",   hex = "#A0FF00" },
    { name = "neon_yellow",  hex = "#F7FF00" },
    { name = "neon_orange",  hex = "#FF9020" },
    { name = "neon_red",     hex = "#FF2040" },
    { name = "neon_magenta", hex = "#FF00FF" },

    -- Dark
    { name = "dark_blue",    hex = "#1F3A8A" },
    { name = "dark_cyan",    hex = "#2FB7B7" },
    { name = "dark_green",   hex = "#5FA800" },
    { name = "dark_yellow",  hex = "#B3B800" },
    { name = "dark_orange",  hex = "#C86A1A" },
    { name = "dark_red",     hex = "#B02035" },
    { name = "dark_magenta", hex = "#B000B0" },

    -- Monochrome
    { name = "black",        hex = "#000000" },
    { name = "onyx",         hex = "#1B1A2C" },
    { name = "charcoal",     hex = "#222222" },
    { name = "slate",        hex = "#3A3A3A" },
    { name = "ash",          hex = "#5A5A5A" },
    { name = "smoke",        hex = "#7A7A7A" },
    { name = "fog",          hex = "#A0A0A0" },
    { name = "silver",       hex = "#BABABA" },
    { name = "grey",         hex = "#E0E0E0" },
    { name = "white",        hex = "#FFFFFF" },
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
    local ESC = "\x1b"
    local lines = {}

    -- 1行目: カラーブロック横並び（色付き）
    local blocks = {}
    for _, p in ipairs(palette_list) do
        local r = tonumber(p.hex:sub(2, 3), 16)
        local g = tonumber(p.hex:sub(4, 5), 16)
        local b = tonumber(p.hex:sub(6, 7), 16)
        table.insert(
            blocks,
            string.format("%s[38;2;%d;%d;%dm■%s[0m", ESC, r, g, b, ESC)
        )
    end
    table.insert(lines, table.concat(blocks, ""))

    -- 2行目以降: ■:name（色付き）
    for _, p in ipairs(palette_list) do
        local r = tonumber(p.hex:sub(2, 3), 16)
        local g = tonumber(p.hex:sub(4, 5), 16)
        local b = tonumber(p.hex:sub(6, 7), 16)
        table.insert(
            lines,
            string.format(
                "%s[38;2;%d;%d;%dm■%s[0m:%-12s %s",
                ESC, r, g, b, ESC, p.name, p.hex
            )
        )
    end

    local content = table.concat(lines, "\n") .. "\n"

    local file, err = io.open(path, "w")
    if not file then
        wezterm.log_error("Failed to write palette file (ANSI): " .. tostring(err))
        return
    end

    file:write(content)
    file:close()

    wezterm.log_info("Palette (ANSI) exported to: " .. path)
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
