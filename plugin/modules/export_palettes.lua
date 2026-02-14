local wezterm = require 'wezterm'
local M       = {}


--- ==========================================
--- 定数（デフォルト出力先）
--- ==========================================
local DEFAULT_OUTPUT_DIR  = wezterm.home_dir .. "/Documents"
local DEFAULT_HTML_NAME  = "ConvenientStatusBarPalettes.html"
local DEFAULT_TEXT_NAME  = "ConvenientStatusBarPalettes.txt"


-- ==========================================
-- カラーパレット読み込み
-- ==========================================
local color_palettes = require('modules.color_palettes')
local palette_list = color_palettes.palette_list


--- ==========================================
--- パレットをHTMLに書き出す
--- ==========================================
function M.export_palettes_to_html(path)
  -- 出力先パスの決定
  local out_path = path
  if not out_path then
    out_path = DEFAULT_OUTPUT_DIR .. "/" .. DEFAULT_HTML_NAME
  end
  -- カラーとモノクロを分割
  local colors = {}
  local monos  = {}
  -- RGBの値を分解する関数
  local function hex_to_rgb(hex)
      local r = tonumber(hex:sub(2, 3), 16)
      local g = tonumber(hex:sub(4, 5), 16)
      local b = tonumber(hex:sub(6, 7), 16)
      return r, g, b
  end
  -- モノクロ判定関数
  local function is_monochrome(hex)
    -- RGBの閾値で判定
    -- RGBの差が小さいほどモノクロに近いとみなす
    -- 0で完全一致
    local threshold = 6
    local r, g, b = hex_to_rgb(hex)
    return math.abs(r - g) <= threshold
      and math.abs(r - b) <= threshold
      and math.abs(g - b) <= threshold
  end
  -- カラーとモノクロを分割
  for _, p in ipairs(palette_list) do
      if is_monochrome(p.hex) then
          table.insert(monos, p)
      else
          table.insert(colors, p)
      end
  end
  -- HTML内容の生成
  local total_count = #colors + #monos
  local color_count = #colors
  local mono_count  = #monos
  local function grad_bar(rows)
    local t = {}
    for _, r in ipairs(rows) do
      table.insert(
        t,
        string.format(
          '<span class="grad" style="background:%s" onclick="copyHex(\'%s\')"></span>',
          r.hex,
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
function showToast(message) {
  const toast = document.createElement("div");
  toast.textContent = "Copied: " + message;

  toast.style.position = "fixed";
  toast.style.left = "50%";
  toast.style.top = "50%";
  toast.style.transform = "translate(-50%, -50%)";

  toast.style.padding = "10px 16px";
  toast.style.background = "#333333";
  toast.style.color = "#FFFFFF";
  toast.style.borderRadius = "8px";
  toast.style.boxShadow = "0 2px 12px rgba(0,0,0,0.5)";
  toast.style.zIndex = 9999;
  toast.style.fontSize = "12px";

  document.body.appendChild(toast);

  setTimeout(() => {
    toast.style.transition = "opacity 0.4s";
    toast.style.opacity = "0";
    setTimeout(() => toast.remove(), 400);
  }, 1200);
}

function copyHex(hex) {
  navigator.clipboard.writeText(hex);
  showToast(hex);
}

function copyName(name) {
  navigator.clipboard.writeText(name);
  showToast(name);
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
