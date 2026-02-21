local M = {}


--- ==========================================
--- アイコン定義（定数）
--- ==========================================
local ICON = {
  docker = "",  -- Docker
  wsl    = "",  -- WSL (Linux)
  ssh    = "󰀑",  -- SSH
  local_ = "",  -- Local user
}


--- ==========================================
--- ユーザー抽出（Local / SSH / WSL / Docker 判定）
--- ==========================================
function M.get_user(pane)
  -- ローカルユーザー名の取得
  local user_name =
      os.getenv("USER") or
      os.getenv("USERNAME") or
      "User"
  local user_icon = ICON.local_
  -- ペインが無効な場合はローカル扱い
  if not pane then
    return user_name, user_icon
  end
  -- Domain 判定（SSH / WSL / Docker）
  local ok_domain, domain = pcall(function()
    return pane:get_domain_name()
  end)
  if ok_domain and domain then
    local d = domain:lower()
    -- Docker
    if d:find("docker") or d:find("container") then
      user_icon = ICON.docker
      return user_name, user_icon
    end
    -- WSL
    if d:find("wsl") then
      user_icon = ICON.wsl
      return user_name, user_icon
    end
    -- SSH（ユーザー名は後続で上書きされる可能性あり）
    if d:find("ssh") then
      user_icon = ICON.ssh
    end
  end
  -- 作業ディレクトリ（URI）から SSH 判定
  local ok_uri, uri = pcall(function()
    return pane:get_current_working_dir()
  end)
  if ok_uri and uri and uri.username and uri.username ~= "" then
    user_name = uri.username
    user_icon = ICON.ssh
    return user_name, user_icon
  end
  -- プロセス情報から判定
  local ok_proc, proc = pcall(function()
    return pane:get_foreground_process_info()
  end)
  if ok_proc and proc and proc.executable then
    local exe = proc.executable:lower()
    -- Docker
    if exe:find("docker") or exe:find("podman") or exe:find("container") then
      user_icon = ICON.docker
      return user_name, user_icon
    end
    -- WSL
    if exe:find("wsl") then
      user_icon = ICON.wsl
      return user_name, user_icon
    end
    -- SSH
    if exe:find("ssh") then
      user_icon = ICON.ssh
      for _, arg in ipairs(proc.argv or {}) do
        local u = arg:match("([^@]+)@[^@]+")
        if u then
          user_name = u
          return user_name, user_icon
        end
      end
      return user_name, user_icon
    end
  end
  -- タイトルから SSH 判定
  local ok_title, title = pcall(function()
    return pane:get_title()
  end)
  if ok_title and title then
    local t_user = title:match("([^@]+)@[^@]+")
    if t_user then
      user_name = t_user
      user_icon = ICON.ssh
      return user_name, user_icon
    end
  end
  -- デフォルト（Local）
  return user_name, user_icon
end


return M
