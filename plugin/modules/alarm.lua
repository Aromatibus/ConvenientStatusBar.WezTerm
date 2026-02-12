local wezterm = require 'wezterm'
local M       = {}


-- ==========================================
-- カラーパレット
-- ==========================================
local color_palettes = require("modules.color_palettes")
local cp = color_palettes.cp


--- ==========================================
--- 初期設定
--- ==========================================
local config = {
  beep        = false,     -- ビープ通知の有無
  flash       = true,      -- 画面フラッシュの有無
  hourly      = false,     -- 毎正時の時報の有無
  flash_color = cp.white, -- フラッシュ時の文字色
  alarms      = {},        -- { "HH:MM", "HH:MM" } 形式のアラーム時刻リスト
}


--- ==========================================
--- 次のアラーム キャッシュ
--- ==========================================
local cached_next_alarm = ""


--- ==========================================
--- フラッシュ用定数
--- ==========================================
local FLASH_FIRST_DELAY  = 0.0  -- 1回目フラッシュまでの遅延
local FLASH_SECOND_DELAY = 0.08 -- 2回目フラッシュまでの遅延
local FLASH_DURATION     = 0.12 -- フラッシュ継続時間


--- ==========================================
--- 時刻文字列正規化（"HH:MM"形式チェック）
--- ==========================================
local function normalize_time(t)
  -- 文字列でない、または空の場合は無効
  if type(t) ~= "string" or t == "" then
    return nil
  end
  --- "HH:MM"形式チェック
  local h, m = t:match("^(%d%d):(%d%d)$")
  if not h or not m then
    return nil
  end
  -- 数値チェック
  h = tonumber(h)
  m = tonumber(m)
  if not h or not m then
    return nil
  end
  -- 範囲チェック
  if h < 0 or h > 23 or m < 0 or m > 59 then
    return nil
  end
  -- 正規化して返却
  return string.format("%02d:%02d", h, m)
end


--- ==========================================
--- タイマー開始（毎分境界に同期）
--- ==========================================
function M.start(window)
  -- ウィンドウチェック
  if not window then
    return
  end
  -- 毎分境界に同期してタイマー開始
  local function tick()
    local now_sec  = os.time()
    local wait_sec = 60 - (now_sec % 60)
    -- 1分後にコールバック実行
    wezterm.time.call_after(wait_sec, function()
      -- 毎分の処理を実行
      M._on_minute_tick(window)
      -- 次の分も同様にスケジューリング
      tick()
    end)
  end
  tick()
end


--- ==========================================
--- 毎分処理（時報・アラーム判定）
--- ==========================================
function M._on_minute_tick(window)
  local now_hm = os.date("%H:%M")
  -- 時報（毎正時）
  if config.hourly and os.date("%M") == "00" then
    M._notify(window)
  end
  -- アラーム判定
  for _, alarm in ipairs(config.alarms) do
    if alarm == now_hm then
      M._notify(window)
      -- アラーム直後に次のアラームを即時更新
      cached_next_alarm = M._calc_next_alarm()
    end
  end
  -- 次のアラームを毎分更新
  cached_next_alarm = M._calc_next_alarm()
end


--- ==========================================
--- アラーム
--- ==========================================
function M._notify(window)
  -- ビープ
  if config.beep then
    M.beep(window)
  end
  -- フラッシュ
  if config.flash then
    M.flash_window(window)
  end
end


--- ==========================================
--- ビープ処理
--- ==========================================
function M.beep(window)
  local target = wezterm.target_triple or ""
  -- Windows
  if target:find("windows") then
    wezterm.run_child_process({
      "powershell",
      "-Command",
      "[console]::beep(900,120)",
    })
    return
  end
  -- macOS
  if target:find("apple") or target:find("darwin") then
    wezterm.run_child_process({
      "osascript",
      "-e",
      "beep 1",
    })
    return
  end
  -- Linux その他（BEL文字送信）
  window:perform_action(
    wezterm.action.SendString("\a"),
    window:active_pane()
  )
end


--- ==========================================
--- フラッシュ
--- ==========================================
function M.flash_window(window)
  -- ウィンドウチェック
  if not window then
    return
  end
  -- 元の設定を保存（ディープコピー）
  local orig = wezterm.deepcopy(window:get_config_overrides() or {})
  -- フラッシュ用オーバーライド設定
  local flash_overrides = {
    colors = {
      foreground = config.flash_color,
    },
  }

  -- フラッシュ実行処理
  local function flash_once(delay, duration, next_cb)
    wezterm.time.call_after(delay, function()
      -- フラッシュ色に変更
      window:set_config_overrides(flash_overrides)
      -- 一定時間後に元の色へ戻す
      wezterm.time.call_after(duration, function()
        window:set_config_overrides(orig)
        if next_cb then
          next_cb()
        end
      end)
    end)
  end

  -- 2回フラッシュ
  flash_once(FLASH_FIRST_DELAY, FLASH_DURATION, function()
    flash_once(FLASH_SECOND_DELAY, FLASH_DURATION, nil)
  end)
end


--- ==========================================
--- 次のアラーム時刻を計算
--- ==========================================
function M._calc_next_alarm()
  -- アラーム未設定時は空文字
  if not config.alarms or #config.alarms == 0 then
    return ""
  end
  -- 現在時刻（分単位）
  local now_h      = tonumber(os.date("%H"))
  local now_m      = tonumber(os.date("%M"))
  local now_min    = now_h * 60 + now_m
  local next_alarm = nil
  local next_diff  = nil
  -- アラーム時刻を順次チェック
  for _, t in ipairs(config.alarms) do
    local h, m = t:match("^(%d%d):(%d%d)$")
    if h and m then
      local alarm_min = tonumber(h) * 60 + tonumber(m)
      local diff = alarm_min - now_min
      -- 翌日またぎ対応
      if diff < 0 then
        diff = diff + (24 * 60) -- 翌日扱い
      end
      -- 差が最小のアラームを次のアラームとして採用
      if not next_diff or diff < next_diff then
        next_diff  = diff
        next_alarm = t
      end
    end
  end

  return next_alarm or ""
end


--- ==========================================
--- 次のアラーム時刻を取得（外部公開）
--- ==========================================
function M.get_next_alarm()
  return cached_next_alarm or ""
end


--- ==========================================
--- 次のアラームまでの残り分数を取得（外部公開）
--- ==========================================
function M.get_minutes_until_next_alarm()
  -- 次のアラームが無い場合は空文字
  if not cached_next_alarm or cached_next_alarm == "" then
    return ""
  end
  -- 現在時刻（分単位）
  local now_h   = tonumber(os.date("%H"))
  local now_m   = tonumber(os.date("%M"))
  local now_min = now_h * 60 + now_m
  -- 次のアラーム時刻（分単位）
  local h, m    = cached_next_alarm:match("^(%d%d):(%d%d)$")
  if not h or not m then
    return ""
  end
  local alarm_min = tonumber(h) * 60 + tonumber(m)
  -- 差分計算（翌日またぎ対応）
  local diff = alarm_min - now_min
  if diff < 0 then
    diff = diff + (24 * 60)
  end

  return tostring(diff)
end


--- ==========================================
--- セットアップ
--- ==========================================
function M.setup(opts)
  opts               = opts or {}
  local timer        = opts.timer or {}
  -- 設定反映
  config.beep        = timer.beep == true
  config.flash       = timer.flash ~= false
  config.hourly      = timer.hourly == true
  config.flash_color = timer.flash_color or config.flash_color
  -- アラーム時刻設定反映
  config.alarms      = {}
  -- alarm1
  local a1           = normalize_time(timer.alarm1)
  if a1 then
    table.insert(config.alarms, a1)
  end
  -- alarm2
  local a2 = normalize_time(timer.alarm2)
  if a2 then
    table.insert(config.alarms, a2)
  end
  -- 初期化時にも next_alarm を計算
  cached_next_alarm = M._calc_next_alarm()
end


return M
