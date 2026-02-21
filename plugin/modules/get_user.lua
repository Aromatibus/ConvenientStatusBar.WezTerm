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

--

function M.get_current_info(pane)
  -- 1. 基本となるローカルOS情報の特定 (target_tripleを使用)
  local target = wezterm.target_triple
  local current_env_icon = ENV_ICONS.LINUX
  if target:find("windows") then
    current_env_icon = ENV_ICONS.WIN
  elseif target:find("apple") then
    current_env_icon = ENV_ICONS.MAC
  end

  local user_name = os.getenv("USER") or os.getenv("USERNAME") or "User"

  if not pane then return current_env_icon, user_name end

  ---------------------------------------------------------
  -- 2. Domain判定 (WezTerm SSH/WSL Domains経由の場合)
  ---------------------------------------------------------
  local domain = pane:get_domain_name()
  if domain then
    local d = domain:lower()
    if d:find("ssh") then
      return ENV_ICONS.REMOTE, user_name
    elseif d:find("wsl") or d:find("docker") or d:find("container") then
      return ENV_ICONS.VIRTUAL, user_name
    end
  end

  ---------------------------------------------------------
  -- 3. プロセスツリー走査 (Git-Bash等の中身を再帰的に確認)
  ---------------------------------------------------------
  local proc = pane:get_foreground_process_info()
  if proc then
    -- 子プロセスまで潜って SSH / WSL / Docker を探す再帰関数
    local function find_context(p)
      local exe = (p.executable or ""):lower()
      local name = (p.name or ""):lower()

      -- REMOTE 判定 (ssh)
      -- Git-Bash内では名前が "ssh" もしくはパスに "ssh.exe" が含まれる
      if name:match("^ssh") or exe:find("ssh") then
        local u = user_name
        -- 引数 (argv) から user@host を抽出試行
        if p.argv then
          for _, arg in ipairs(p.argv) do
            local captured = arg:match("([^@%-]+)@[^@]+")
            if captured then u = captured break end
          end
        end
        return ENV_ICONS.REMOTE, u
      end

      -- VIRTUAL 判定 (wsl, docker, podman)
      if exe:find("wsl%.exe") or exe:find("docker") or exe:find("podman") then
        return ENV_ICONS.VIRTUAL, user_name
      end

      -- 子プロセスがあればさらに深く探索
      if p.children then
        for _, child in ipairs(p.children) do
          local res_icon, res_user = find_context(child)
          if res_icon then return res_icon, res_user end
        end
      end
      return nil, nil
    end

    local found_icon, found_user = find_context(proc)
    if found_icon then return found_icon, found_user end
  end

  -- 何も見つからなければ最初に特定したローカルOSアイコンを返す
  return current_env_icon, user_name
end

return M
