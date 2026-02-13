local wezterm = require("wezterm")
local act = wezterm.action


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
