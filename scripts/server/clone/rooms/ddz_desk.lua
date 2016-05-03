--未开始
DDZ_STEP_NONE = "none"
--发牌
DDZ_STEP_DEAL = "deal"
--叫地主
DDZ_STEP_LORD = "lord"
--玩游戏
DDZ_STEP_PLAY = "play"

DDZ_DESK_TDCLS = tdcls(DESK_TDCLS)
DDZ_DESK_TDCLS.name = "DDZ_DESK_TDCLS"

--构造函数
function DDZ_DESK_TDCLS:create()
    self.cur_step = "none"
    self.cur_op_idx = -1
    self.lord_idx = -1
    --存储叫地主信息
    self.lord_list = {}
end

function DDZ_DESK_TDCLS:time_update()
    get_class_func(DESK_TDCLS, "time_update")(self)
    if self.cur_step == DDZ_STEP_DEAL then
        local pokers, down_poker = DDZ_D.get_new_game_poker()
        for i=1,3 do
            local wheel = self.wheels[i]
            wheel.poker_list = pokers[i]
            self:send_message(wheel.rid, MSG_ROOM_MESSAGE, "poker_init", {poker_list = wheel.poker_list})
        end
        self.down_poker = down_poker
        self.cur_op_idx = -1
        self.lord_list = {}
        self.cur_step = DDZ_STEP_LORD
    elseif self.cur_step == DDZ_STEP_LORD then
        if self.cur_op_idx == -1 then
            self.cur_op_idx = math.random(1, 3)
            self.wheels[self.cur_op_idx].last_op_time = os.time()
            self:broadcast_message(MSG_ROOM_MESSAGE, "start_deal", {idx = self.cur_op_idx})
        else
            local op_time = self.wheels[self.cur_op_idx].last_op_time
            if os.time() - op_time > 10 then
                self:cur_lord_choose(0)
            end
        end
    elseif self.cur_step == DDZ_STEP_PLAY then

    end
end

function DDZ_DESK_TDCLS:cur_lord_choose(is_choose)
    local info = {idx = self.cur_op_idx, is_choose = is_choose}
    table.insert(self.lord_list, info)
    self:broadcast_message(MSG_ROOM_MESSAGE, "deal_info", info)
    if #self.lord_list < 3 then
        self.cur_op_idx = (self.cur_op_idx + 1) % 3
        if self.cur_op_idx == 0 then
            self.cur_op_idx = 3
        end
        self.wheels[self.cur_op_idx].last_op_time = os.time()
    else
        if #self.lord_list == 3 then
            local choose_num = 0
            local last_choose = nil
            local first_choose = nil
            for _,v in ipairs(self.lord_list) do
                if v.is_choose == 1 then
                    choose_num = choose_num + 1
                    last_choose = v.idx
                    first_choose = first_choose or v.idx
                end
            end
            if choose_num == 0 then
                self.cur_step = DDZ_STEP_DEAL
                self:broadcast_message(MSG_ROOM_MESSAGE, "restart_game", {})
            elseif choose_num == 1 then
                self.cur_step = DDZ_STEP_PLAY
                self.lord_idx = last_choose
                self:broadcast_message(MSG_ROOM_MESSAGE, "start_play", {lord_idx = self.lord_idx})
            else
                self.cur_op_idx = first_choose
                self.wheels[self.cur_op_idx].last_op_time = os.time()
            end
        else
            for i = #self.lord_list,1,-1 do
                if self.lord_list[i].is_choose == 1 then
                    self.lord_idx = self.lord_list[i].idx
                    self.cur_step = DDZ_STEP_PLAY
                    self:broadcast_message(MSG_ROOM_MESSAGE, "start_play", {lord_idx = self.lord_idx})
                    break
                end
            end
        end
    end
end

function DDZ_DESK_TDCLS:is_full_user()
    trace("is_full_user %o", self:get_user_count() >= 3)
    return self:get_user_count() >= 3
end

function DDZ_DESK_TDCLS:get_play_num()
    return 3
end

function DDZ_DESK_TDCLS:start_game()
    get_class_func(DESK_TDCLS, "entity_update")(self)

    self.cur_step = DDZ_STEP_DEAL
    trace("DDZ_DESK_TDCLS:start_game!@!!!")


end