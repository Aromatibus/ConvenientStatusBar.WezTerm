local M       = {}
local wezterm = require 'wezterm'


--- ==========================================
--- 子プロセス実行
--- ==========================================
function M.run(args)
  local success, stdout, _ = wezterm.run_child_process(args)
  return success, stdout
end

return M
