local wezterm = require 'wezterm'
local M       = {}


--- ==========================================
--- 外部モジュール読み込み用のパスを設定
--- ==========================================
local plugin_list = wezterm.plugin.list()
if plugin_list and plugin_list[1] then
  local plugin_path = plugin_list[1].plugin_dir .. "/plugin/?.lua"
  package.path = plugin_path .. ";" .. package.path
end


--- ==========================================
--- 定数（デフォルト出力先）
--- ==========================================
local DEFAULT_OUTPUT_DIR = wezterm.home_dir .. "/Documents"
local DEFAULT_HTML_NAME = "Color_Palettes.html"
local DEFAULT_TOML_NAME = "ConvenientStatusBarPalettes.toml"

-- テンプレHTMLは「このLuaファイルと同じフォルダ」
local TEMPLATE_HTML_NAME = DEFAULT_HTML_NAME


-- ==========================================
-- カラーパレット読み込み
-- ==========================================
local color_palettes = require('modules.color_palettes')
local palette_list   = color_palettes.palette_list


--- ==========================================
--- HEX → RGB
--- ==========================================
local function hex_to_rgb(hex)
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)
  return r, g, b
end


--- ==========================================
--- モノクロ判定（RGB近似）
--- ==========================================
local function is_monochrome(hex)
  local threshold = 6
  local r, g, b = hex_to_rgb(hex)
  return math.abs(r - g) <= threshold
    and  math.abs(r - b) <= threshold
    and  math.abs(g - b) <= threshold
end


--- ==========================================
--- パレットをTOMLに出力
--- ==========================================
local function export_palettes_to_toml(path)
  local file, err = io.open(path, "w")
  if not file then
    wezterm.log_error("Failed to write TOML palette: " .. tostring(err))
    return
  end

  file:write("[palettes]\n")

  local max_len = 0
  for _, p in ipairs(palette_list) do
    if #p.name > max_len then
      max_len = #p.name
    end
  end

  for _, p in ipairs(palette_list) do
    local name_pad = p.name .. string.rep(" ", max_len - #p.name)
    file:write(string.format(
      '%s = "%s" # %s\n',
      name_pad,
      p.hex,
      p.source
    ))
  end

  file:close()
  wezterm.log_info("Palette TOML exported to: " .. path)
end


--- ==========================================
--- パレットをHTMLに出力（テンプレHTML使用）
--- ==========================================
function M.export_palettes_to_html(path)
  local out_path = path
  if not out_path then
    out_path = DEFAULT_OUTPUT_DIR .. "/" .. DEFAULT_HTML_NAME
  end

  local toml_path = DEFAULT_OUTPUT_DIR .. "/" .. DEFAULT_TOML_NAME

  local plugin_list = wezterm.plugin.list()
  local plugin_dir = plugin_list and plugin_list[1] and plugin_list[1].plugin_dir
  local tpl_path = plugin_dir .. "/plugin/modules/" .. TEMPLATE_HTML_NAME

  local colors = {}
  local monos  = {}

  for _, p in ipairs(palette_list) do
    if is_monochrome(p.hex) then
      table.insert(monos, p)
    else
      table.insert(colors, p)
    end
  end

  table.sort(monos, function(a, b)
    return a.hex < b.hex
  end)

  local total_count = #colors + #monos
  local color_count = #colors
  local mono_count  = #monos

  local function grad_bar(rows)
    local t = {}
    for _, r in ipairs(rows) do
      table.insert(
        t,
        string.format(
          '<span class="grad" style="background:%s" ' ..
          'title="%s (%s) : %s" ' ..
          'onmousedown="onGradClick(event, \'%s\', \'%s\')"></span>',
          r.hex,
          r.name,
          r.source,
          r.hex,
          r.name,
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
        string.format(
          [[
<div class="copy-row">
  <span class="dot" style="background:%s"
        onclick="copyHex('%s')"></span>
  <span class="hex" onclick="copyHex('%s')">(%s)</span>
  <span class="sep"> ・・・ </span>
  <span class="name" onclick="copyName('%s')">%s</span>
  <span class="src"> (%s)</span>
</div>
]],
          r.hex,
          r.hex,
          r.hex,
          r.hex,
          r.name,
          r.name,
          r.source
        )
      )
    end
    return table.concat(t, "")
  end

  -- テンプレHTML読み込み
  local file, err = io.open(tpl_path, "r")
  if not file then
    wezterm.log_error("Failed to read HTML template: " .. tostring(err))
    wezterm.log_error("Template path: " .. tpl_path)
    return
  end

  local template = file:read("*a")
  file:close()

  -- プレースホルダ置換
  local html = template
  html = html:gsub("{{TOTAL_COUNT}}", tostring(total_count))
  html = html:gsub("{{COLOR_COUNT}}", tostring(color_count))
  html = html:gsub("{{MONO_COUNT}}",  tostring(mono_count))
  html = html:gsub("{{GRAD_COLORS}}", grad_bar(colors))
  html = html:gsub("{{GRAD_MONOS}}",  grad_bar(monos))
  html = html:gsub("{{LIST_COLORS}}", list_block(colors))
  html = html:gsub("{{LIST_MONOS}}",  list_block(monos))

  -- HTML書き出し
  local out_file, werr = io.open(out_path, "w")
  if not out_file then
    wezterm.log_error("Failed to write HTML palette: " .. tostring(werr))
    return
  end

  out_file:write(html)
  out_file:close()

  wezterm.log_info("Palette HTML exported to: " .. out_path)

  export_palettes_to_toml(toml_path)
end


return M
