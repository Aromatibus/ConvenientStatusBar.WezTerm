local wezterm = require 'wezterm'
local M       = {}

-- (中略: weather_icons, state, run_child_cmd, format_bps, calc_net_speed, get_sys_resources, get_pane_info, fetch_wea_data は変更なし)

--- ==========================================
--- メイン
--- ==========================================
function M.setup(opts)
  local def_fmt =
    " $SSH $Cal_ic $Year.$Month.$Day($Week) $Clock_ic $Time24 " ..
    "$Loc_ic $City $Weather_ic $Temp " ..
    "$CPU_ic $CPU $MEM_ic $MEM_USED $MEM_FREE $Net_ic $Net_speed($Net_avg) "

  local config              = {
    startup_delay           = (opts and opts.startup_delay) or 5,
    weather_api_key         = opts and opts.weather_api_key,
    weather_lang            = (opts and opts.weather_lang) or "en",
    weather_city            = (opts and opts.weather_city) or "",
    weather_units           = (opts and opts.weather_units) or "metric",
    weather_update_interval = 600,
    net_update_interval     = 3,
    net_avg_samples         = 10,
    color_text              = (opts and opts.color_text) or "#ffffff",
    color_foreground        = (opts and opts.color_foreground) or "#7aa2f7",
    color_background        = (opts and opts.color_background) or "#1a1b26",
    format                  = (opts and opts.format) or def_fmt,
  }

  wezterm.on('update-right-status', function(window, pane)
    local now        = os.time()
    local is_waiting = (now - state.proc_start) < config.startup_delay

    if config.weather_api_key and not is_waiting and (now - state.last_wea_upd > config.weather_update_interval) then
      fetch_wea_data(config)
    end

    local net_curr, net_avg = calc_net_speed(config, is_waiting)
    local cpu_usage, mem_used, mem_free = get_sys_resources()
    local pane_info = get_pane_info(pane)

    -- フリーメモリのアイコンのテキスト色のみを背景色に変更する
    local mem_free_formatted = wezterm.format({
      -- アイコン部分: 文字色を背景色(#1a1b26)に変更
      { Foreground = { Color = config.color_background } },
      { Text = "  " },
      -- アイコン終了後、即座に元の文字色(白など)に戻す
      { Foreground = { Color = config.color_text } },
      { Text = mem_free },
    })

    local replace_map = {
      cal_ic      = "",
      clock_ic    = "",
      loc_ic      = "",
      net_ic      = "󰓅",
      cpu_ic      = "",
      mem_ic      = "",
      year        = wezterm.strftime('%Y'),
      month       = wezterm.strftime('%m'),
      day         = wezterm.strftime('%d'),
      week        = wezterm.strftime('%a'),
      time24      = wezterm.strftime('%H:%M'),
      city        = state.city_name,
      weather_ic  = state.weather_ic,
      temp        = state.temp_str,
      cpu         = cpu_usage,
      mem_used    = mem_used,
      mem_free    = mem_free_formatted, -- ここでフォーマット済み文字列を適用
      net_speed   = net_curr,
      net_avg     = net_avg,
      ssh         = pane_info.ssh ~= "" and ("󰢩 " .. pane_info.ssh) or "",
    }

    local final_status = config.format:gsub("%$([%a%d_]+)", function(key)
      local val = replace_map[key:lower()]
      return val ~= nil and val or ("$" .. key)
    end)

    window:set_right_status(wezterm.format({
      { Background = { Color = config.color_background } },
      { Foreground = { Color = config.color_foreground } },
      { Text       = "" },
      { Background = { Color = config.color_foreground } },
      { Foreground = { Color = config.color_text } },
      { Text       = final_status },
      { Background = { Color = config.color_background } },
      { Foreground = { Color = config.color_foreground } },
      { Text       = "" },
    }))
  end)
end

return M
