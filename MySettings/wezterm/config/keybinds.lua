--- ==================================================================
--- Keybindings configuration for WezTerm
--- ==================================================================
-- https://wezterm.org/config/keys.html
-- https://wezterm.org/config/default-keys.html
-- https://wezterm.org/config/lua/keyassignment/index.html


--[[
特殊修飾キーの一覧
| mods名     | キー         | 説明                                   |
| ---------- | ------------ | -------------------------------------- |
| `"CTRL"`   | Ctrl         | Controlキー                            |
| `"ALT"`    | Alt / Option | Altキー（macOSでは Option）            |
| `"SHIFT"`  | Shift        | Shiftキー                              |
| `"SUPER"`  | Win / Cmd    | Windowsキー / macOSの⌘               |
| `"LEADER"` | Leaderキー   | `config.leader` で定義した仮想修飾キー |
]]


local wezterm = require("wezterm")
local act = wezterm.action


-- ==========================================================
-- Resurrect プラグインの読み込み
-- ==========================================================
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")


-- ==========================================================
-- キーバインド設定
-- ==========================================================
return {
  keys = {

    -- =========================================================
    -- アプリケーション終了
    -- ==========================================================
    { key = "q", mods = "LEADER", action = wezterm.action.QuitApplication },

    -- ==========================================================
    -- ステータスバー表示切替
    -- ==========================================================
    { key = "o", mods = "LEADER", action = wezterm.action.EmitEvent("toggle-status-format"), },

    -- ==========================================================
    -- Resurrect設定（成功／失敗ログ付き）
    -- ==========================================================
    -- ワークスペース全体の保存
    {
      key = "w",
      mods = "LEADER",
      action = wezterm.action_callback(function(win, pane)
        local ok, err = pcall(function()
          resurrect.state_manager.save_state(
            resurrect.workspace_state.get_workspace_state()
          )
        end)
        if ok then
          wezterm.log_info("[resurrect] workspace save: success")
        else
          wezterm.log_error("[resurrect] workspace save: failed: ", err)
          win:toast_notification("Resurrect", "Workspace save failed (see log)", nil, 3000)
        end
      end),
    },
    -- 現在のウィンドウの保存
    {
      key = "W",
      mods = "LEADER",
      action = wezterm.action_callback(function(win, pane)
        local ok, err = pcall(function()
          resurrect.window_state.save_window_action()
        end)
        if ok then
          wezterm.log_info("[resurrect] window save: success")
        else
          wezterm.log_error("[resurrect] window save: failed: ", err)
          win:toast_notification("Resurrect", "Window save failed (see log)", nil, 3000)
        end
      end),
    },
    -- 現在のタブの保存
    {
      key = "T",
      mods = "LEADER",
      action = wezterm.action_callback(function(win, pane)
        local ok, err = pcall(function()
          resurrect.tab_state.save_tab_action()
        end)
        if ok then
          wezterm.log_info("[resurrect] tab save: success")
        else
          wezterm.log_error("[resurrect] tab save: failed: ", err)
          win:toast_notification("Resurrect", "Tab save failed (see log)", nil, 3000)
        end
      end),
    },
    -- ワークスペース全体の保存（ウィンドウ・タブもまとめて保存）
    {
      key = "s",
      mods = "LEADER",
      action = wezterm.action_callback(function(win, pane)
        local ok, err = pcall(function()
          resurrect.state_manager.save_state(
            resurrect.workspace_state.get_workspace_state()
          )
          resurrect.window_state.save_window_action()
        end)
        if ok then
          wezterm.log_info("[resurrect] workspace+window save: success")
        else
          wezterm.log_error("[resurrect] workspace+window save: failed: ", err)
          win:toast_notification("Resurrect", "Workspace+Window save failed (see log)", nil, 3000)
        end
      end),
    },
    -- セッションの読み込み（ファジー検索で選択）
    {
      key = "l",
      mods = "LEADER",
      action = wezterm.action_callback(function(win, pane)
        wezterm.log_info("[resurrect] restore: start")
        local ok, err = pcall(function()
          resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
            local typ = string.match(id, "^([^/]+)")
            local short_id = string.match(id, "([^/]+)$")
            short_id = string.match(short_id, "(.+)%..+$")
            wezterm.log_info(string.format(
              "[resurrect] restore selected: type=%s id=%s label=%s",
              tostring(typ), tostring(short_id), tostring(label)
            ))
            local opts = {
              relative = true,
              restore_text = true,
              on_pane_restore = resurrect.tab_state.default_on_pane_restore,
            }
            local ok2, err2 = pcall(function()
              if typ == "workspace" then
                local state = resurrect.state_manager.load_state(short_id, "workspace")
                resurrect.workspace_state.restore_workspace(state, opts)
              elseif typ == "window" then
                local state = resurrect.state_manager.load_state(short_id, "window")
                resurrect.window_state.restore_window(pane:window(), state, opts)
              elseif typ == "tab" then
                local state = resurrect.state_manager.load_state(short_id, "tab")
                resurrect.tab_state.restore_tab(pane:tab(), state, opts)
              end
            end)
            if ok2 then
              wezterm.log_info("[resurrect] restore: success")
            else
              wezterm.log_error("[resurrect] restore: failed: ", err2)
              win:toast_notification("Resurrect", "Restore failed (see log)", nil, 4000)
            end
          end)
        end)
        if not ok then
          wezterm.log_error("[resurrect] restore: failed to start: ", err)
          win:toast_notification("Resurrect", "Restore failed to start (see log)", nil, 4000)
        end
      end),
    },

    -- ==========================================================
    -- ペイン分割（tmux風）
    -- ==========================================================
    { key = "d", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "r", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    -- ペインを閉じる
    { key = "x", mods = "LEADER", action = act({ CloseCurrentPane = { confirm = true } }) },
    -- ペインのズーム（最大化/復元）
    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
    -- ==========================================================
    -- コピーモード（Vim 操作）
    -- ==========================================================
    { key = "[", mods = "LEADER", action = act.ActivateCopyMode },
  },


  -- ==========================================================
  -- キーバインド設定
  -- ==========================================================
  key_tables = {

    -- ==========================================================
    -- コピーモード（Vim 風操作）
    -- ==========================================================
    copy_mode = {
      -- カーソル移動
      { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
      { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
      { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
      { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
      -- 単語移動
      { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
      { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
      { key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },
      -- 行頭/行末
      { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
      { key = "$", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
      { key = "^", mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
      -- ジャンプ
      { key = "f", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = false } }) },
      { key = "t", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = true } }) },
      { key = "F", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
      { key = "T", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
      -- スクロール
      { key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
      { key = "G", mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
      { key = "d", mods = "CTRL", action = act.CopyMode({ MoveByPage = 0.5 }) },
      { key = "u", mods = "CTRL", action = act.CopyMode({ MoveByPage = -0.5 }) },
      -- 選択モード
      { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
      { key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
      { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
      -- コピー
      { key = "y", mods = "NONE", action = act.CopyTo("Clipboard") },
      -- コピーモード終了
      {
        key = "Enter",
        mods = "NONE",
        action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }),
      },
      { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
      { key = "q",      mods = "NONE", action = act.CopyMode("Close") },
    },
  },
}
