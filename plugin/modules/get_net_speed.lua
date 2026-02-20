local wezterm = require 'wezterm'
local M       = {}


--- ==========================================
--- 外部モジュール読み込み用のパスを設定
--- ==========================================
-- 自身と同じフォルダを追加
local config_dir = wezterm.config_dir
package.path = config_dir .. "/?.lua;" .. package.path
-- pluginフォルダを追加
local plugin_list = wezterm.plugin.list()
if plugin_list and plugin_list[1] then
  local plugin_path = plugin_list[1].plugin_dir .. "/plugin/?.lua"
  package.path = plugin_path .. ";" .. package.path
end


--- ==========================================
--- 外部モジュール読み込み
--- ==========================================
local run_child_cmd = require('modules.run_child_cmd')


--- ==========================================
--- バイト/秒フォーマット
--- ==========================================
local function format_bps(bps)
  if bps > 1024 * 1024 then
    return string.format(
      "%5.1fMB/s",
      bps / (1024 * 1024)
    )
  elseif bps > 1024 then
    return string.format("%5.1fKB/s", bps / 1024)
  else
    return string.format("%6.1fB/s", bps)
  end
end


--- ==========================================
--- ネットワーク速度計算
--- ==========================================
function M.get_net_speed(state)
  local now = os.time()
  local dt  = now - state.net_state.last_chk_time
  -- 更新間隔内であれば前回の値を返却
  if dt < (state.net_update_interval or 3) or dt <= 0 then
    return
        state.net_state.disp_str,
        state.net_state.avg_str
  end
  -- 現在の受信バイト数を取得
  local curr_rx = 0
  local triple  = wezterm.target_triple
  local is_win  = triple:find("windows")
  local is_mac  = triple:find("darwin")
  -- Windows/macOS/Linux別に受信バイト数を取得
  if is_win then
    local ok, out = run_child_cmd.run({
      "powershell.exe",
      "-NoProfile",
      "-Command",
      "(Get-NetAdapterStatistics | " ..
      "Measure-Object -Property ReceivedBytes -Sum).Sum"
    })
    curr_rx = ok and tonumber(out) or 0
  elseif is_mac then
    local ok, out = run_child_cmd.run({
      "sh",
      "-c",
      "netstat -ib | " ..
      "awk 'NR>1 && $1 != \"lo0\" {sum+=$7} " ..
      "END {print sum}'"
    })
    curr_rx = ok and tonumber(out) or 0
  else
    local ok, out = run_child_cmd.run({
      "sh",
      "-c",
      "cat /proc/net/dev"
    })
    if ok and out then
      local line_no = 0
      for line in out:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if line_no > 2 then
          local iface, data =
              line:match("^%s*(.-):%s*(.+)")
          if iface and not iface:match("lo") then
            local rx = data:match("^(%d+)")
            curr_rx =
                curr_rx + (tonumber(rx) or 0)
          end
        end
      end
    end
  end
  -- 初回は速度計算をスキップ
  if state.net_state.last_rx_bytes == 0 then
    state.net_state.last_rx_bytes = curr_rx
    state.net_state.last_chk_time = now
    return
        state.net_state.disp_str,
        state.net_state.avg_str
  end
  -- 速度計算
  local diff                    = curr_rx - state.net_state.last_rx_bytes
  local speed                   = diff > 0 and diff / dt or 0
  -- 状態更新
  state.net_state.last_rx_bytes = curr_rx
  state.net_state.last_chk_time = now
  -- 表示用文字列
  local speed_str               = format_bps(speed)
  -- 平均速度計算
  table.insert(state.net_state.samples, speed)
  if #state.net_state.samples > state.net_avg_samples then
    table.remove(state.net_state.samples, 1)
  end
  -- 平均速度算出
  local sum = 0
  for _, v in ipairs(state.net_state.samples) do
    sum = sum + v
  end
  -- 平均速度文字列
  local avg                =
      (#state.net_state.samples > 0) and
      (sum / #state.net_state.samples) or 0
  local avg_str            = format_bps(avg)
  -- 状態保存
  state.net_state.disp_str = speed_str
  state.net_state.avg_str  = avg_str
  return speed_str, avg_str
end


return M
