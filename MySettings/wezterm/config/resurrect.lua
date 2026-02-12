local wezterm = require 'wezterm'
local M       = {}


-- 設定リロード時の多重登録防止フラグ
local registered = false


function M.apply(config)
  -- 多重登録防止
  if registered then
    return
  end
  registered = true
  -- Resurrectプラグイン読み込み
  local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
  -- 起動時に自動復元
  wezterm.on("gui-startup", function(cmd)
    if resurrect
        and resurrect.state_manager
        and resurrect.state_manager.resurrect_on_gui_startup
    then
      resurrect.state_manager.resurrect_on_gui_startup(cmd)
    end
  end)
  -- 定期自動保存
  local SAVE_INTERVAL = (5 * 60)
  local last_save = 0
  wezterm.on('update-right-status', function()
    local now = os.time()
    if now - last_save < SAVE_INTERVAL then
      return
    end
    if not (
          resurrect
          and resurrect.state_manager
          and resurrect.workspace_state
          and resurrect.workspace_state.get_workspace_state
        ) then
      return
    end
    local ok, err = pcall(function()
      resurrect.state_manager.save_state(
        resurrect.workspace_state.get_workspace_state()
      )
    end)
    if ok then
      last_save = now
      -- wezterm.log_info('resurrect: auto-saved')
    else
      wezterm.log_error('resurrect: auto-save failed: ', err)
    end
  end)
  -- GUI終了時に保存
  wezterm.on('gui-shutdown', function()
    if not (
          resurrect
          and resurrect.state_manager
          and resurrect.workspace_state
          and resurrect.workspace_state.get_workspace_state
        ) then
      return
    end
    local ok, err = pcall(function()
      resurrect.state_manager.save_state(
        resurrect.workspace_state.get_workspace_state()
      )
    end)
    if not ok then
      wezterm.log_error('resurrect: shutdown save failed: ', err)
    end
  end)
end


return M
