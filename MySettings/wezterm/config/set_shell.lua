local wezterm = require 'wezterm'
local M       = {}


-- =========================
-- ファイルの存在チェック
-- =========================

-- 指定パスのファイルが存在するかチェック
local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end


-- =========================
-- Windows 用シェル選択
-- =========================
local function get_windows_shell()
  local home_drive  = os.getenv("HOMEDRIVE") or "C:"
  local userprofile = os.getenv("USERPROFILE")

  -- シェルの優先順位リスト
  local candidates = {
    {
      name = "WSL2",
      prog = { "C:/Windows/System32/wsl.exe" },
    },
    {
      name = "Git Bash (Scoop)",
      prog = { home_drive .. "/Scoop/apps/git/current/bin/bash.exe", "-l" },
    },
    {
      name = "Git Bash",
      prog = { "C:/Program Files/Git/bin/bash.exe", "-l" },
    },
    {
      name = "Git Bash (x86)",
      prog = { "C:/Program Files (x86)/Git/bin/bash.exe", "-l" },
    },
    {
      name = "PowerShell 7 (Scoop)",
      prog = {
        home_drive .. "/Scoop/apps/pwsh/current/pwsh.exe",
        "-NoExit",
        "-File",
        userprofile .. "\\Documents\\PowerShell\\Microsoft.PowerShell_profile.ps1",
      },
    },
    {
      name = "PowerShell 7",
      prog = { "C:/Program Files/PowerShell/7/pwsh.exe" },
    },
    {
      name = "Windows PowerShell",
      prog = { "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" },
    },
    {
      name = "cmd",
      prog = { "cmd.exe" },
      always = true,
    },
  }

  -- 優先順位順にprog[1] の存在チェック
  -- always が true のものは無条件でOK
  for _, c in ipairs(candidates) do
    if c.always or file_exists(c.prog[1]) then
      wezterm.log_info("Selected Windows shell: " .. c.name)
      return c.prog
    end
  end
end


-- =========================
-- macOS 用シェル選択
-- =========================
local function get_macos_shell()
  return { "zsh" }
end


-- =========================
-- Linux 用シェル選択
-- =========================
local function get_linux_shell()
  return { "bash" }
end


-- =========================
-- 結果を返却
-- =========================
function M.apply(config)
  local target = wezterm.target_triple

  if target:find("windows") then
    config.default_prog = get_windows_shell()
    config.default_cwd  = os.getenv("USERPROFILE")

  elseif target:find("apple") or target:find("darwin") then
    config.default_prog = get_macos_shell()
    config.default_cwd  = os.getenv("HOME")

  else
    config.default_prog = get_linux_shell()
    config.default_cwd  = os.getenv("HOME")
  end
end


return M
