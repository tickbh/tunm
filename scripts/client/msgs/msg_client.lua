
function msg_login_notify_status( agent, info )
    trace("msg_login_notify_status is %o", info)
end

--msg_user_list
function msg_user_list(user, list)
    trace("msg_user_list content is %o", list)
end

function msg_create_user(user, info)
   trace("msg_create_user info %o", info)
end


function msg_enter_game(agent, info)
    trace("---msg_enter_game--- info = %o", info)
end