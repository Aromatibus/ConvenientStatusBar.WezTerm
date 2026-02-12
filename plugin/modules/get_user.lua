local M = {}


--- ==========================================
--- ユーザー抽出
--- ==========================================
function M.get_user(pane)
    -- ローカルユーザー名の取得
    local user_name =
        os.getenv("USER") or
        os.getenv("USERNAME") or
        "User"
    local user_icon = ""
    -- 選択中のペインが無効な場合はローカルユーザーを返す
    if not pane then
        return user_name, user_icon
    end
    -- 作業ディレクトリからの抽出
    local ok_uri, uri = pcall(function()
        return pane:get_current_working_dir()
    end)
    if ok_uri and uri and uri.username and uri.username ~= "" then
        user_name = uri.username
        user_icon = "󰀑"
        return user_name, user_icon
    end
    -- プロセス情報からの抽出
    local ok_proc, proc = pcall(function()
        return pane:get_foreground_process_info()
    end)
    if ok_proc and proc and proc.executable
        and proc.executable:find("ssh")
    then
        for _, arg in ipairs(proc.argv or {}) do
            local u = arg:match("([^@]+)@[^@]+")
            if u then
                user_name = u
                user_icon = "󰀑"
                return user_name, user_icon
            end
        end
    end
    -- タイトルバーからの抽出
    local ok_title, title = pcall(function()
        return pane:get_title()
    end)
    if ok_title and title then
        local t_user = title:match("([^@]+)@[^@]+")
        if t_user then
            user_name = t_user
            user_icon = "󰀑"
            return user_name, user_icon
        end
    end
    return user_name, user_icon
end


return M
