local wezterm = require 'wezterm'
local M = {}

-- ご指定のアイコン定義
local ENV_ICONS = {
  WIN     = " ",
  MAC     = " ",
  LINUX   = " ",
  REMOTE  = "󰀑 ",
  VIRTUAL = " ",
}

--- ==========================================
--- ユーザー名と環境アイコンを取得
--- ==========================================
function M.get_user(pane)
  -- 1. 基本OSの特定 (target_triple)
  local target = wezterm.target_triple
  local current_env_icon = ENV_ICONS.LINUX
  if target:find("windows") then
    current_env_icon = ENV_ICONS.WIN
  elseif target:find("apple") then
    current_env_icon = ENV_ICONS.MAC
  end

  -- デフォルトのユーザー名取得
  local user_name = os.getenv("USER") or os.getenv("USERNAME") or "User"

  -- ペインが無効な場合は初期判定を返す
  if not pane then
    return user_name, current_env_icon
  end

  ---------------------------------------------------------
  -- 2. Domain判定 (WezTerm標準のSSH/WSL接続)
  ---------------------------------------------------------
  local domain = pane:get_domain_name()
  if domain then
    local d = domain:lower()
    if d:find("ssh") then
      return user_name, ENV_ICONS.REMOTE
    elseif d:find("wsl") or d:find("docker") or d:find("container") then
      return user_name, ENV_ICONS.VIRTUAL
    end
  end

  ---------------------------------------------------------
  -- 3. プロセスツリー走査 (Git-Bash内でのSSH判定)
  ---------------------------------------------------------
  local proc = pane:get_foreground_process_info()
  if proc then
    -- 子プロセスまで潜って SSH / WSL / Docker を探す再帰関数
    local function find_context(p)
      local exe = (p.executable or ""):lower()
      local name = (p.name or ""):lower()

      -- SSH 判定
      if name:match("^ssh") or exe:find("ssh") then
        local u = user_name
        -- argvから user@host を探す
        if p.argv then
          for _, arg in ipairs(p.argv) do
            local captured = arg:match("([^@%-]+)@[^@]+")
            if captured then u = captured break end
          end
        end
        return ENV_ICONS.REMOTE, u
      end

      -- VIRTUAL 判定
      if exe:find("wsl%.exe") or exe:find("docker") or exe:find("podman") then
        return ENV_ICONS.VIRTUAL, user_name
      end

      -- 子プロセスがあれば再帰的に探索
      if p.children then
        for _, child in ipairs(p.children) do
          local res_icon, res_user = find_context(child)
          if res_icon then return res_icon, res_user end
        end
      end
      return nil, nil
    end

    local found_icon, found_user = find_context(proc)
    if found_icon then
      return found_user, found_icon
    end
  end

  -- 何も見つからない場合はローカルOSの結果を返す
  return user_name, current_env_icon
end

return M
