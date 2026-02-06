local ConvenientStatusBar = wezterm.plugin.require("https://github.com/aromatibus/ConvenientStatusBar.WezTerm")

ConvenientStatusBar.setup({
  api_key = "88989d7e3460606958812933b3209599",  -- [必須] ：Open Weather Mapから取得したAPIキーを設定します

  -- 以下はすべて省略可能です
  city            = "",        -- [省略可] 指定しない場合は現在のIPアドレスから取得されます
  country         = "",        -- [省略可] Cityを厳密に指定したい場合に指定します
  lang            = "en",      -- [省略可] 取得するデータの言語を指定します
  units           = "metric",  -- [省略可] 以下の2つから指定します
                               -- metric (Celsius),
                               -- imperial (Fahrenheit)
  update_interval = 600,       -- [省略可] Open Weather Mapへの再接続時間を秒で指定します
  colors = {
    background    = "#1A1B26", -- [省略可] 背景の色を指定します
    foreground    = "#7AA2F7", -- [省略可] タブの色を指定します
    text          = "#FFFFFF"  -- [省略可] 文字の色を指定します
  },
  format = " $cal_ic $year.$month.$day $clock_ic $time_24 $loc_ic $location($country) $weather_ic $temp_ic($temp) $batt_ic$batt_num "
})





🗓️ 日付・時刻・場所変数名内容表示例
$year西暦（4桁）2026
$year_short西暦（2桁）26
$month /
$day 月 /  日02 / 06
$time_24 24時間制時刻22:15
$time_12 12時間制時刻10:15 PM
$location 都市名Yokohama
$country 国名（コード）JP

🌡️ 天気・バッテリー変数名内容表示例
$temp気温（00.0形式）08.5℃
$batt_numバッテリー残量85% (非搭載時は空)

🎨 アイコン（末尾に _ic）変数名内容アイコン例
$cal_icカレンダー
$clock_ic時計
$loc_icロケーション
$weather_ic天候󰖨 (晴れ) / 󰅟 (曇り) など
$temp_ic温度計
$batt_icバッテリー / 電源󱊦 (電池) / 󰚥 (プラグ)


      cal_ic     = "",
      clock_ic   = "",
      loc_ic     = "",
      temp_ic    = weather_icons.temp,
      weather_ic = weather_state.icon,
      year       = wezterm.strftime('%Y'),
      year_short = wezterm.strftime('%y'),
      month      = wezterm.strftime('%m'),
      day        = wezterm.strftime('%d'),
      week       = wezterm.strftime('%a'),
      time_24    = wezterm.strftime('%H:%M'),
      time_12    = wezterm.strftime('%I:%M %p'),
      hour_24    = wezterm.strftime('%H'),
      hour_12    = wezterm.strftime('%I'),
      min        = wezterm.strftime('%M'),
      location   = weather_state.location,
      country    = weather_state.country,
      temp       = weather_state.temp,
      batt_ic    = batt_ic,
      batt_num   = batt_num,
      