local wezterm = require 'wezterm'
local M       = {}


--- ==========================================
-- color_palettes.lua から palette_list を直接読み込む
--- ==========================================
local color_palettes = require('modules.color_palettes')
local palette_list = color_palettes.palette_list


--- ==========================================
--- パレットをテキストファイルに書き出す
--- ==========================================
function M.export_palettes_to_file(path)
    local out_path = path
    if not out_path then
        out_path = wezterm.home_dir .. "/ConvenientStatusBarPalettes.txt"
    end

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

    local file, err = io.open(out_path, "w")
    if not file then
        wezterm.log_error("Failed to write palette file: " .. tostring(err))
        return
    end

    file:write(content)
    file:close()

    wezterm.log_info("Palette text exported to: " .. out_path)
end


--- ==========================================
--- パレットをHTMLに書き出す
--- ==========================================
function M.export_palettes_to_html(path)
    local out_path = path
    if not out_path then
        out_path = wezterm.home_dir .. "/ConvenientStatusBarPalettes.html"
    end

    local colors = {}
    local monos  = {}

    local mono_names = {
        black = true,
        onyx = true,
        charcoal = true,
        slate = true,
        ash = true,
        smoke = true,
        fog = true,
        silver = true,
        grey = true,
        white = true,
    }

    for _, p in ipairs(palette_list) do
        if mono_names[p.name] then
            table.insert(monos, p)
        else
            table.insert(colors, p)
        end
    end

    local total_count = #colors + #monos
    local color_count = #colors
    local mono_count  = #monos

    local function grad_bar(rows)
        local t = {}
        for _, r in ipairs(rows) do
            table.insert(
                t,
                string.format(
                    '<span class="grad" style="background:%s"></span>',
                    r.hex
                )
            )
        end
        return table.concat(t, "")
    end

    local function list_block(rows)
        local t = {}
        for _, r in ipairs(rows) do
            table.insert(
                t,
                string.format([[
<div class="copy-row">
    <span class="dot" style="background:%s" onclick="copyHex('%s')"></span>
    <span class="hex" onclick="copyHex('%s')">(%s)</span>
    <span class="sep"> ・・・ </span>
    <span class="name" onclick="copyName('%s')">%s</span>
    <span class="src"> (lua)</span>
</div>
]],
                    r.hex, r.hex, r.hex, r.hex, r.name, r.name
                )
            )
        end
        return table.concat(t, "")
    end

    local html = string.format([[
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>カラースペクトラム / カラーパレット</title>
<style>
body { background:#111111; color:#EEEEEE; font-family: sans-serif; }
h1, h2 { margin-top:24px; }
.note { font-size: 12px; color: #AAAAAA; margin: 4px 0 12px 0; }
.grad { display:inline-block; width:6px; height:24px; }
.copy-row { margin:4px 0; }
.dot {
    width:12px; height:12px; display:inline-block;
    margin-right:6px; cursor:pointer; vertical-align:middle;
}
.hex { cursor:pointer; font-family: monospace; }
.name {
    cursor:pointer;
    color:#FFFFFF;
    text-decoration: underline;
}
.src { color:#AAAAAA; margin-left:4px; }
.sep { margin:0 4px; }
</style>
<script>
function copyHex(hex) {
    navigator.clipboard.writeText(hex);
}
function copyName(name) {
    navigator.clipboard.writeText(name);
}
</script>
</head>
<body>

<h1>◆カラースペクトラム（全%d色）</h1>

<h2>■ カラー（%d色）</h2>
<div>%s</div>

<h2>■ モノクロ（%d色）</h2>
<div>%s</div>

<h1>◆カラーパレット</h1>
<div class="note">※カラー見本、カラー名をクリックするとカラーコードまたはカラー名をコピーできます</div>

<h2>■ カラー（%d色）</h2>
%s

<h2>■ モノクロ（%d色）</h2>
%s

</body>
</html>
]],
        total_count,
        color_count,
        grad_bar(colors),
        mono_count,
        grad_bar(monos),
        color_count,
        list_block(colors),
        mono_count,
        list_block(monos)
    )

    local file, err = io.open(out_path, "w")
    if not file then
        wezterm.log_error("Failed to write HTML palette: " .. tostring(err))
        return
    end

    file:write(html)
    file:close()

    wezterm.log_info("Palette HTML exported to: " .. out_path)
end


return M
