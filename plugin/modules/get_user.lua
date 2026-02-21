local wezterm = require 'wezterm'
local M = {}

local ENV_ICONS = {
  WIN     = " ",
  MAC     = " ",
  LINUX   = " ",
  REMOTE  = "󰀑 ",
  VIRTUAL = " ",
}

function M.get_user(pane)
  -- 1. 基盤OSの特定
  local target = wezterm.target_triple
  local current_env_icon = ENV_ICONS.LINUX
  if target:find("windows") then current_env_icon = ENV_ICONS.WIN
  elseif target:find("apple") then current_env_icon = ENV_ICONS.MAC end

  local user_name = os.getenv("USER") or os.getenv("USERNAME") or "User"
  if not pane then return user_name, current_env_icon end

  -- 2. WezTerm Domain判定（SSH Domain等を使用している場合）
  local domain = pane:get_domain_name()
  if domain and domain:lower() ~= "local" then
    local d = domain:lower()
    if d:find("ssh") then return user_name, ENV_ICONS.REMOTE
    elseif d:find("wsl") or d:find("docker") then return user_name, ENV_ICONS.VIRTUAL end
  end

  -- 3. プロセスツリー走査の強化
  local proc = pane:get_foreground_process_info()
  if proc then
    local function find_context(p)
      -- 判定対象を拡張: executable(フルパス) だけでなく name(短い名前) も重視
      local exe = (p.executable or ""):lower()
      local name = (p.name or ""):lower()

      -- SSH判定の条件を緩和（git-bashのsshは 'ssh' という名前で動くことが多いため）
      if name == "ssh" or name == "ssh.exe" or exe:find("ssh") then
        local u = user_name
        -- 引数からユーザー名を抽出
        if p.argv then
          for _, arg in ipairs(p.argv) do
            local captured = arg:match("([^@%-]+)@[^@]+")
            if captured then u = captured break end
          end
        end
        return ENV_ICONS.REMOTE, u
      end

      -- Virtual(WSL/Docker)判定
      if name:find("wsl") or exe:find("wsl%.exe") or name:find("docker") or exe:find("docker") then
        return ENV_ICONS.VIRTUAL, user_name
      end

      -- 子プロセスを再帰的にチェック
      if p.children then
        for _, child in ipairs(p.children) do
          local res_icon, res_user = find_context(child)
          if res_icon then return res_icon, res_user end
        end
      end
      return nil, nil
    end

    local found_icon, found_user = find_context(proc)
    if found_icon then return found_user, found_icon end
  end

  -- 4. 最終手段: タイトルからSSHの user@host 形式を探す
  -- Git-BashはSSH接続時にウィンドウタイトルを書き換えることが多いため有効
  local title = pane:get_title()
  if title then
    local t_user = title:match("([^@%s]+)@[^@%s]+")
    if t_user then return t_user, ENV_ICONS.REMOTE end
  end

  return user_name, current_env_icon
end

return M
