local wezterm = require 'wezterm'
local M       = {}


-- ==========================================================
-- [Right Status]
-- ==========================================================
-- 設定リロード時の多重登録防止フラグ
local registered = false
function M.apply(config)
  -- 多重登録防止
  if registered then
    return
  end
  registered = true

  -- ==========================================
  -- [ConvenientStatusBar]
  -- ==========================================
  -- APIキー取得（環境変数）
  local OPEN_WEATHER_API_KEY = os.getenv("OPEN_WEATHER_API_KEY") or nil

  --local ConvenientStatusBar = wezterm.plugin.require(
  --  "https://github.com/aromatibus/ConvenientStatusBar.WezTerm"
  --)
  local ConvenientStatusBar = wezterm.plugin.require(
    "file:///R:/Source/WezTerm/ConvenientStatusBar.WezTerm"
  )

  -- 取得したカラーパレットをログ出力で可視化
  ConvenientStatusBar.print_log_palettes()
  -- プラグインからカラーパレット取得
  local cp      = ConvenientStatusBar.cp
  local cp_ansi = ConvenientStatusBar.ansi


  -- ==========================================
  -- テスト用
  -- ==========================================
  ConvenientStatusBar.setup({
    formats          = {
      " $user_ic $user " ..
      "$cal_ic $year.$month.$day($week) $clock_ic $time24 " ..
      "$earth_ic $cal_ic $wx_year.$wx_month.$wx_day($wx_week) $clock_ic $wx_time24 " ..
      " $loc_ic $city($code) " ..
      "($weather_ic/$temp_ic$temp) " ..
      "$batt_ic$batt_num ",
      "" },
    weather_api_key  = OPEN_WEATHER_API_KEY,
    weather_lang     = "",
    weather_country  = "",
    weather_city     = "london",
    color_text       = cp.onyx,
    color_foreground = cp.blue,
    color_background = cp.onyx,
    separator        = { "", "" },
  })




--[[

  -- ==========================================
  -- シンプル
  -- ==========================================
  ConvenientStatusBar.setup({ formats = { " $user_ic $user $cal_ic $year.$month.$day($week) $clock_ic $time24 $batt_ic$batt_num ", "" } })

  -- ==========================================
  -- シンプル・アラーム付き
  -- ==========================================
  ConvenientStatusBar.setup({
    formats = { " $user_ic $user $cal_ic $year.$month.$day($week) $clock_ic $time24 (Alarm:$next_alarm) $batt_ic$batt_num ", "" },
    timer = {
      alarm1      = "12:00",
      alarm2      = "18:00",
      hourly      = true,
      beep        = true,
      flash       = true,
      flash_color = cp.white,
    },
  })

  -- ==========================================
  -- 天気情報付き
  -- ==========================================
  ConvenientStatusBar.setup({
    weather_api_key = OPEN_WEATHER_API_KEY,
    formats         = {


      -- フォーマット1
      " $user_ic $user " ..
      "$earth_ic $cal_ic $wx_year.$wx_month.$wx_day($wx_week) $clock_ic $wx_time24 " ..
      "$cal_ic $year.$month.$day($week) $clock_ic $time12 (alarm:$next_alarm) " ..
      " $loc_ic $city($code) " ..
      "($weather_ic/$temp_ic$temp) " ..
      "$batt_ic$batt_num ",
      -- フォーマット2
      " Now($weather_ic/$temp_ic$temp) " ..
      "+3h($weather_ic_3h/$temp_ic$temp_3h) " ..
      "+6h($weather_ic_6h/$temp_ic$temp_6h) " ..
      "+9h($weather_ic_9h/$temp_ic$temp_9h) " ..
      "+12h($weather_ic_12h/$temp_ic$temp_12h) " ..
      "NextAfty:$weather_nd_afty_time($weather_nd_afty_ic/$temp_ic$weather_nd_afty_temp) ",
    }
  })

  -- ==========================================
  -- だいたい全部入り
  -- ==========================================

  ConvenientStatusBar.setup({
    formats                 = {
      -- フォーマット1
      " $user_ic $user " ..
      "$cal_ic $year.$month.$day($week) $clock_ic $time12 Alarm:$next_alarm ($time_until_alarm min) " ..
      " $loc_ic $city($code) " ..
      "($weather_ic/$temp_ic$temp) " ..
      "$cpu_ic $cpu $mem_ic $mem_free " ..
      "$net_ic $net_speed($net_avg) " ..
      "$batt_ic$batt_num ",
      -- フォーマット2
      " Now:($weather_ic/$temp_ic$temp) " ..
      "+3h:($weather_ic_3h/$temp_ic$temp_3h) " ..
      "+6h:($weather_ic_6h/$temp_ic$temp_6h) " ..
      "+9h:($weather_ic_9h/$temp_ic$temp_9h) " ..
      "+12h:($weather_ic_12h/$temp_ic$temp_12h) " ..
      "NextAfterNoon $weather_nd_afty_time:($weather_nd_afty_ic/$temp_ic$weather_nd_afty_temp) ",
    },
    timer                   = {
      alarm1      = "12:00",
      alarm2      = "18:00",
      hourly      = true,
      beep        = true,
      flash       = true,
      flash_color = cp.neon_blue,
    },
    --weather_api_key         = "",
    --weather_api_key         = "あなたのAPIキー",
    weather_api_key         = OPEN_WEATHER_API_KEY,
    weather_lang            = "",
    weather_country         = "jp",
    weather_city            = "Marunouchi",
    weather_units           = "metric",
    weather_update_interval = 600,
    weather_retry_interval  = 30,
    net_update_interval     = 3,
    net_avg_samples         = 20,
    startup_delay           = 5,
    color_text              = cp.onyx,
    color_foreground        = cp.blue,
    color_background        = cp.onyx,
    status_position         = "right",     -- "right" or "left"
    separator               = { "", "" },
    --separator = { "", ""},
    --separator = { "", ""},
    --separator = { "", ""},
    --separator = { "", ""},
    --separator = { "", ""},
    --separator = { "|", "|"},
    --separator = { "⟦", "⟧"},
    --separator = { "[", "]"},
    --separator = { "", ""},
    --separator = { "", ""},
    --separator = { "", ""},
    --separator = { " ", " "},
    --separator = { " ", " "},
    --separator = { " ", " "},
    --separator = { " ", " "},
    --separator = { " ", " "},
    --separator = { " ", " "},
    --separator = { " ", " "},
    --separator = { " ", " "},
    --separator = { " ", " "},
    --week_str = {"日","一","二","三","四","五","六"}, -- Chinese
    --week_str = {"Dom","Lun","Mar","Mié","Jue","Vie","Sáb"}, -- Spanish
    --week_str = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"}, -- English
    --week_str = {"रवि","सोम","मंगल","बुध","गुरु","शुक्र","शनि"}, -- Hindi
    --week_str = {"রবি","সোম","मंगल","বুধ","বৃহ","শুক্র","শনি"}, -- Bengali
    --week_str = {"Dom","2ª","3ª","4ª","5ª","6ª","Sáb"}, -- Portuguese
    --week_str = {"ح","اث","ث","أر","خ","ج","س"}, -- Arabic
    --week_str = {"Вс","Пн","Вт","Ср","Чт","Пт","Сб"}, -- Russian
    week_str                = { "日", "月", "火", "水", "木", "金", "土" }, -- Japanese
    --week_str = {"ਐਤ","ਸੋਮ","ਮੰਗਲ","ਬੁੱਧ","ਵੀਰ","ਸ਼ੁੱਕਰ","ਸ਼ਨੀ"}, -- Punjabi
    --week_str = {"रवि","सोम","मंग","बुध","गुरू","शुक्र","शनि"}, -- Marathi
    --week_str = {"ఆది","సోమ","మంగళ","బుధ","గురు","శుక్ర","శని"}, -- Telugu
    --week_str = {"Ngah","Sen","Sel","Reb","Kem","Jum","Set"}, -- Javanese
    --week_str = {"CN","T2","T3","T4","T5","T6","T7"}, -- Vietnamese
    --week_str = {"So","Mo","Di","Mi","Do","Fr","Sa"}, -- German
    --week_str = {"일","월","화","수","목","금","토"}, -- Korean
    --week_str = {"Dim","Lun","Mar","Mer","Jeu","Ven","Sam"}, -- French
    --week_str = {"Dom","Lun","Mar","Mer","Gio","Ven","Sab"}, -- Italian
    --week_str = {"อา.","จ.","อ.","พ.","พฤ.","ศ.","ส."}, -- Thai
    --week_str = {"Jpili","Jtt","Jnn","Jta","Alham","Jma","Jmos"}, -- Swahili
    --week_str = {"Min","Sen","Sel","Rab","Kam","Jum","Sab"}, -- Indonesian
    --week_str = {"nd","pn","wt","śr","cz","pt","sb"}, -- Polish
    --week_str = {"Нд","Пн","Вт","Ср","Чт","Пт","Сб"}, -- Ukrainian
    --week_str = {"sön","mån","tis","ons","tors","fre","lör"}, -- Swedish
    --week_str = {"su","ma","ti","ke","to","pe","la"}, -- Finnish
  })

]]

end


return M
