local wezterm = require "wezterm"
local M       = {}

local ENV = {
  WIN   = " ",
  MAC   = " ",
  LINUX = " ",
  REMOTE = "󰀑 ",
  VIRTUAL = " ",
}

function M.get_current_info(pane)
  -- 1. 基本となるローカルOS情報の特定
  local target = wezterm.target_triple
  local current_env = ENV.LINUX
  if target:find("windows") then current_env = ENV.WIN
  elseif target:find("apple") then current_env = ENV.MAC end

  local user_name = os.getenv("USER") or os.getenv("USERNAME") or "User"

  if not pane then return current_env, user_name end

  ---------------------------------------------------------
  -- 2. Domain判定 (WezTermが接続を管理している場合)
  ---------------------------------------------------------
  local domain = pane:get_domain_name()
  if domain then
    local d = domain:lower()
    if d:find("ssh") then
      return ENV.REMOTE, user_name
    elseif d:find("wsl") or d:find("docker") or d:find("container") then
      return ENV.VIRTUAL, user_name
    end
  end

  ---------------------------------------------------------
  -- 3. プロセスツリー走査 (Git-Bash等の中身を覗く)
  ---------------------------------------------------------
  local proc = pane:get_foreground_process_info()
  if proc then
    -- 子プロセスまで潜って SSH / WSL / Docker を探す再帰関数
    local function find_context(p)
      local exe = (p.executable or ""):lower()
      local name = (p.name or ""):lower()

      -- SSH判定: プロセス名にsshが含まれるかチェック
      if name:match("^ssh") or exe:find("ssh") then
        local u = user_name
        -- 引数から user@host を探す (例: ssh admin@192.168...)
        if p.argv then
          for _, arg in ipairs(p.argv) do
            local captured = arg:match("([^@%-]+)@[^@]+")
            if captured then u = captured break end
          end
        end
        return ENV.REMOTE, u
      end

      -- Virtual判定: wsl, docker, podmanが含まれるか
      if exe:find("wsl%.exe") or exe:find("docker") or exe:find("podman") then
        return ENV.VIRTUAL, user_name
      end

      -- 子プロセスを再帰探索
      if p.children then
        for _, child in ipairs(p.children) do
          local res_env, res_user = find_context(child)
          if res_env then return res_env, res_user end
        end
      end
      return nil, nil
    end

    local found_env, found_user = find_context(proc)
    if found_env then return found_env, found_user end
  end

  -- 何も見つからなければ最初に判定したローカルOSを返す
  return current_env, user_name
end

return M
