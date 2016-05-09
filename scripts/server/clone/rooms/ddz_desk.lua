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
    self.retry_deal_times = 0
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
        self:change_cur_step(DDZ_STEP_LORD)
    elseif self.cur_step == DDZ_STEP_LORD then
        if self.cur_op_idx == -1 then
            self:change_cur_opidx(math.random(1, 3))
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

function DDZ_DESK_TDCLS:change_cur_step(new_step)
    self.cur_step = new_step
    self:broadcast_message(MSG_ROOM_MESSAGE, "step_change", {cur_step = self.cur_step})
end

function DDZ_DESK_TDCLS:change_cur_opidx(new_op_idx)
    self.cur_op_idx = new_op_idx
    self:broadcast_message(MSG_ROOM_MESSAGE, "op_idx", {cur_op_idx = self.cur_op_idx})
end

function DDZ_DESK_TDCLS:cur_lord_choose(is_choose)
    local info = {idx = self.cur_op_idx, is_choose = is_choose}
    table.insert(self.lord_list, info)
    self:broadcast_message(MSG_ROOM_MESSAGE, "deal_info", info)
    if #self.lord_list < 3 then
        local new_op_idx = (self.cur_op_idx + 1) % 3
        if new_op_idx == 0 then
            new_op_idx = 3
        end
        self:change_cur_opidx(new_op_idx)
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
                self:try_restart_game()
            elseif choose_num == 1 then
                self:change_cur_step(DDZ_STEP_PLAY)
                self.lord_idx = last_choose
                self:broadcast_message(MSG_ROOM_MESSAGE, "start_play", {lord_idx = self.lord_idx})
                self:change_cur_opidx(self.lord_idx)
            else
                self:change_cur_opidx(first_choose)
                self.wheels[self.cur_op_idx].last_op_time = os.time()
            end
        else
            for i = #self.lord_list,1,-1 do
                if self.lord_list[i].is_choose == 1 then
                    self.lord_idx = self.lord_list[i].idx
                    self:change_cur_step(DDZ_STEP_PLAY)
                    self:broadcast_message(MSG_ROOM_MESSAGE, "start_play", {lord_idx = self.lord_idx})
                    self:change_cur_opidx(self.lord_idx)
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

function DDZ_DESK_TDCLS:clear_all_status()
    for idx,info in ipairs(self.wheels) do
        info.is_ready = 0
        info.poker_list = nil
        if info.rid and self.users[info.rid] then
            if self.users[info.rid].offline_time then
                self.users[info.rid] = nil
                self.wheels[idx] = {}
            end
        end
    end
    self:change_cur_step(DDZ_STEP_NONE)
    self.retry_deal_times = 0
end

function DDZ_DESK_TDCLS:is_someone_offline()
    for _,info in ipairs(self.wheels) do
        if info.rid and self.users[info.rid] then
            if self.users[info.rid].offline_time then
                return true
            end
        end
    end
    return false
end

--无人叫地主，重来，如有人断线，或者重试超过2次，则重新开始
function DDZ_DESK_TDCLS:try_restart_game()
    if self.retry_deal_times > 1 or self:is_someone_offline() then
        self:clear_all_status()
        trace("重置次数超限或者有人掉线")
        return
    end
    self.retry_deal_times = self.retry_deal_times + 1

    self:change_cur_step(DDZ_STEP_DEAL)
    self:broadcast_message(MSG_ROOM_MESSAGE, "restart_game", {})
end

function DDZ_DESK_TDCLS:start_game()
    get_class_func(DESK_TDCLS, "start_game")(self)
    self:change_cur_step(DDZ_STEP_DEAL)
    trace("DDZ_DESK_TDCLS:start_game!@!!!")
end

function DDZ_DESK_TDCLS:is_playing()
    return self.cur_step ~= DDZ_STEP_NONE
end

function DDZ_DESK_TDCLS:send_desk_info(user_rid)
    self:send_message(user_rid, MSG_ROOM_MESSAGE, "desk_info", {wheels = self.wheels, cur_step = self.cur_step, cur_op_idx = self.cur_op_idx, lord_idx = self.lord_idx})
end

function DDZ_DESK_TDCLS:user_enter(user_rid)
    get_class_func(DESK_TDCLS, "user_enter")(self, user_rid)
    return 0
end

function DDZ_DESK_TDCLS:user_leave(user_rid)
    local user_data = self.users[user_rid]
    if not user_data then
        return -1
    end

    user_data.offline_time = os.time()

    self:broadcast_message(MSG_ROOM_MESSAGE, "success_leave_desk", {rid = user_rid, idx = idx})
    --中途掉线，保存当前进度数据
    if self.cur_step ~= DDZ_STEP_NONE then
        return -1
    end
    self.users[user_rid] = nil
    self.wheels[user_data.idx] = {}
    return 0
end

function DDZ_DESK_TDCLS:op_info(user_rid, info)
    local is_oper = get_class_func(DESK_TDCLS, "op_info")(self, user_rid, info)
    if is_oper then
        return is_oper
    end

    local idx = self.users[user_rid].idx
    if info.oper == "ready" then
        if self:is_playing() or self.wheels[idx].is_ready == 1 then
            return true
        end
        self.wheels[idx].is_ready = 1
        trace("玩家%s在位置%d已准备", user_rid, idx)
        self:broadcast_message(MSG_ROOM_MESSAGE, "success_user_ready", {rid = user_rid, idx = idx})
        self:check_all_ready()
        return true
    elseif info.oper == "choose" then
        if idx ~= self.cur_op_idx then
            return true
        end
        self:cur_lord_choose(info.is_choose)
        return true
    elseif info.oper == "deal_poker" then
        trace("poker_list is %o", info.poker_list)
        return true
    end
    return false
end
