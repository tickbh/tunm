DDZ_DESK_CLASS = class(DESK_CLASS)
DDZ_DESK_CLASS.name = "DDZ_DESK_CLASS"

--构造函数
function DDZ_DESK_CLASS:create()

end

function DDZ_DESK_CLASS:time_update()

end

function DDZ_DESK_CLASS:is_full_user()
    trace("is_full_user %o", self:get_user_count() >= 3)
    return self:get_user_count() >= 3
end

function DDZ_DESK_CLASS:get_play_num()
    return 3
end