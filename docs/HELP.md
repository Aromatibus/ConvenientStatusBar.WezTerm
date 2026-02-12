-- ==========================================================
-- [Right Status]
-- ==========================================================

local ConvenientStatusBar = wezterm.plugin.require("https://github.com/aromatibus/ConvenientStatusBar.WezTerm")

-- セットアップの実行
ConvenientStatusBar.setup({
  startup_delay           = 5,          -- 起動時の通信待機時間
  weather_api_key         = 
    "88989d7e3460606958812933b3209599", -- OpenWeatherMap APIキー
  weather_lang            = "en",       -- 天気情報の言語コード
  weather_country         = "",         -- 国コード、都市名と組み合わせて使用
  weather_city            = "",         -- 都市名、省略された場合はIPアドレスから自動取得
  weather_units           = "metric",   -- "metric(摂氏)" or "imperial(華氏)"
  weather_update_interval = 600,        -- 天気情報の更新時間（秒）
  weather_retry_interval  = 30,         -- 天気情報取得失敗時のリトライ時間（秒）
  net_update_interval     = 3,          -- ネットワーク速度更新時間（秒）
  net_avg_samples         = 20,         -- 平均速度のサンプル数
  separator_left          = "",        -- ステータスバーの始端（左側）
  separator_right         = "",        -- ステータスバーの終端（右側）
  color_text              = "#ffffff",  -- ステータスバーの文字色
  color_foreground        = "#7aa2f7",  -- ステータスバーの前景色
  color_background        = "#1a1b26",  -- ステータスバーの背景色
  format                  =             -- ステータスバーのフォーマット
    " $Cal_ic $Year.$Month.$Day($Week) $Clock_ic $Time24 " ..
    "$Loc_ic $City($Code) $Weather_ic $Temp_ic($Temp) " ..
    "$Net_ic $Net_speed($Net_avg) $Batt_ic$Batt_num ",
})

--[[
      cal_ic      = "",
      clock_ic    = "",
      loc_ic      = "",
      temp_ic     = weather_icons.thermometer,
      weather_ic  = use_weather and state.weather_ic or "",
      year        = wezterm.strftime('%Y'),
      month       = wezterm.strftime('%m'),
      day         = wezterm.strftime('%d'),
      week        = wezterm.strftime('%a'),
      time24      = wezterm.strftime('%H:%M'),
      city        = use_weather and state.city_name or "",
      code        = use_weather and state.city_code or "",
      temp        = use_weather and state.temp_str or "",
      net_ic      = "󰓅",
      net_speed   = net_curr,
      net_avg     = net_avg,
      batt_ic     = batt_ic,
      batt_num    = batt_num,
]]
