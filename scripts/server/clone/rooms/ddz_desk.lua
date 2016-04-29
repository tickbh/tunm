DDZ_DESK_CLASS = class(DESK_CLASS)
DDZ_DESK_CLASS.name = "DDZ_DESK_CLASS"

--构造函数
function DDZ_DESK_CLASS:create()

end

function DDZ_DESK_CLASS:time_update()
    get_class_func(DESK_CLASS, "time_update")(self)
end

function DDZ_DESK_CLASS:is_full_user()
    trace("is_full_user %o", self:get_user_count() >= 3)
    return self:get_user_count() >= 3
end

function DDZ_DESK_CLASS:get_play_num()
    return 3
end

function DDZ_DESK_CLASS:start_game()
    get_class_func(DESK_CLASS, "entity_update")(self)

    trace("DDZ_DESK_CLASS:start_game!@!!!")

    local pokers, down_poker = DDZ_D.get_new_game_poker()
    for i=1,3 do
        local wheel = self.wheels[i]
        wheel.poker_list = pokers[i]
        self:send_message(wheel.rid, MSG_ROOM_MESSAGE, "poker_init", {poker_list = wheel.poker_list})
    end
    self.down_poker = down_poker
end