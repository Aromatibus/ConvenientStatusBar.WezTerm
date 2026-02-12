local M       = {}
local wezterm = require 'wezterm'


--- ==========================================
--- 外部モジュール読み込み用のパスを設定
--- ==========================================
local plugin_path =
    wezterm.plugin.list()[1].plugin_dir .. "/plugin/?.lua"
package.path = plugin_path .. ";" .. package.path


--- ==========================================
--- 外部モジュール読み込み
--- ==========================================
local run_child_cmd = require('modules.run_child_cmd')


--- ==========================================
--- システムリソース取得
--- ==========================================
function M.get_system_resource(state)
  local cpu_val   = 0
  local mem_u_val = 0
  local mem_f_val = 0
  -- OS判定
  local triple    = wezterm.target_triple
  local is_win    = triple:find("windows")
  local is_mac    = triple:find("darwin")
  -- Windows
  if is_win then
    local ok, out = run_child_cmd.run({
      "powershell.exe",
      "-NoProfile",
      "-Command",
      "Get-CimInstance Win32_Processor | " ..
      "Measure-Object -Property LoadPercentage -Average | " ..
      "Select-Object -ExpandProperty Average; " ..
      "(Get-CimInstance Win32_OperatingSystem)." ..
      "FreePhysicalMemory; " ..
      "(Get-CimInstance Win32_OperatingSystem)." ..
      "TotalVisibleMemorySize",
    })
    if ok and out then
      local lines = {}
      for line in out:gmatch("[^\r\n]+") do
        table.insert(lines, line)
      end
      -- CPU使用率
      cpu_val = tonumber(lines[1]) or 0
      -- メモリ使用量
      local f_kb = tonumber(lines[2]) or 0
      local t_kb = tonumber(lines[3]) or 0
      mem_f_val = f_kb / 1024 / 1024
      mem_u_val = (t_kb - f_kb) / 1024 / 1024
    end
    -- macOS
  elseif is_mac then
    -- CPU使用率
    local ok, out = run_child_cmd.run({
      "sh",
      "-c",
      "top -l 1 | grep 'CPU usage'",
    })
    if ok and out then
      local user, sys =
          out:match("(%d+%.?%d*)%% user.*(%d+%.?%d*)%% sys")
      cpu_val =
          (tonumber(user) or 0) +
          (tonumber(sys) or 0)
    end
    -- メモリ使用量
    local ok2, out2 = run_child_cmd.run({
      "sh",
      "-c",
      "vm_stat",
    })
    if ok2 and out2 then
      local page_size  =
          out2:match("page size of (%d+) bytes")
      page_size        = tonumber(page_size) or 4096

      local free       = out2:match("Pages free:%s+(%d+)")
      local inactive   =
          out2:match("Pages inactive:%s+(%d+)")
      local active     =
          out2:match("Pages active:%s+(%d+)")
      local wired      =
          out2:match("Pages wired down:%s+(%d+)")
      free             = tonumber(free) or 0
      inactive         = tonumber(inactive) or 0
      active           = tonumber(active) or 0
      wired            = tonumber(wired) or 0
      local free_bytes =
          (free + inactive) * page_size
      local used_bytes =
          (active + wired) * page_size
      mem_f_val        = free_bytes / 1024 ^ 3
      mem_u_val        = used_bytes / 1024 ^ 3
    end
    -- Linux
  else
    -- CPU使用率
    local ok, out = run_child_cmd.run({
      "sh",
      "-c",
      "cat /proc/stat | head -n1",
    })
    if ok and out then
      local user, nice, system, idle, iowait,
      irq, softirq, steal =
          out:match(
            "cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+" ..
            "(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*(%d*)"
          )
      user                = tonumber(user) or 0
      nice                = tonumber(nice) or 0
      system              = tonumber(system) or 0
      idle                = tonumber(idle) or 0
      iowait              = tonumber(iowait) or 0
      irq                 = tonumber(irq) or 0
      softirq             = tonumber(softirq) or 0
      steal               = tonumber(steal) or 0

      local total         =
          user + nice + system + idle +
          iowait + irq + softirq + steal
      local idle_all      = idle + iowait
      -- 前回との差分からCPU使用率を算出
      if state.cpu_state.last_total ~= 0 then
        local dt    =
            total - state.cpu_state.last_total
        local didle =
            idle_all - state.cpu_state.last_idle
        if dt > 0 then
          cpu_val =
              (1 - didle / dt) * 100
        end
      end
      state.cpu_state.last_total = total
      state.cpu_state.last_idle  = idle_all
    end
    -- メモリ使用量
    local ok2, out2 = run_child_cmd.run({
      "sh",
      "-c",
      "free -b | awk '/^Mem:/ {print $3, $4}'",
    })
    if ok2 and out2 then
      local used, free =
          out2:match("(%d+)%s+(%d+)")
      mem_u_val =
          (tonumber(used) or 0) / 1024 ^ 3
      mem_f_val =
          (tonumber(free) or 0) / 1024 ^ 3
    end
  end
  -- 表示用フォーマットに変換して返却
  return
      string.format("%2d%%", cpu_val),
      string.format("%4.1fGB", mem_u_val),
      string.format("%4.1fGB", mem_f_val)
end

return M
