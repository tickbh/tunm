
function msg_login_notify_status( agent, info )
end

--msg_user_list
function msg_user_list(user, list)
end

function msg_create_user(user, info)
end


function msg_enter_game(agent, info)
    ME_D.me_updated(agent, info)
end