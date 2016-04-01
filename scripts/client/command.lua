
function connect(account, password)
    LOGIN_D.login(account, password)
end

function c()
    connect("aa", "bb")
end

function get_attrib(field, amount)
    local user = ME_D.get_user()
    if not is_object(user) then
        trace("请先登陆游戏")
        return
    end
    user:send_message(CMD_COMMON_OP, {oper = "get", field = field, amount = amount})
end

function use_attrib(field, amount)
    local user = ME_D.get_user()
    if not is_object(user) then
        trace("请先登陆游戏")
        return
    end
    user:send_message(CMD_COMMON_OP, {oper = "use", field = field, amount = amount})
end