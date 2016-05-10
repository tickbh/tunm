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

    self.down_poker = {}
    --存储叫地主信息
    self.lord_list = {}

    --存储出牌信息，如果结束一回合，则清空
    self.play_poker_list = {}
end

function DDZ_DESK_TDCLS:time_update()
    get_class_func(DESK_TDCLS, "time_update")(self)
    if self.cur_step == DDZ_STEP_DEAL then
        local pokers, down_poker = DDZ_D.get_new_game_poker()
        for i=1,3 do
            local wheel = self.wheels[i]
            wheel.poker_list = pokers[i]
            self:send_rid_message(wheel.rid, MSG_ROOM_MESSAGE, "poker_init", {poker_list = wheel.poker_list})
        end
        self.down_poker = down_poker
        self.cur_op_idx = -1
        self.lord_list = {}
        self:change_cur_step(DDZ_STEP_LORD)
    elseif self.cur_step == DDZ_STEP_LORD then
        if self.cur_op_idx == -1 then
            self:change_cur_opidx(math.random(1, 3))
            self:broadcast_message(MSG_ROOM_MESSAGE, "start_deal", {idx = self.cur_op_idx})
        else
            local op_time = self.wheels[self.cur_op_idx].last_op_time
            if os.time() - op_time > 10 then
                self:cur_lord_choose(0)
            end
        end
    elseif self.cur_step == DDZ_STEP_PLAY then
        local op_time = self.wheels[self.cur_op_idx].last_op_time
        if os.time() - op_time > 6 then
            self:deal_poker()
        end
    end
end

function DDZ_DESK_TDCLS:change_cur_step(new_step)
    self.cur_step = new_step
    if self.cur_step == DDZ_STEP_NONE then
        for _,v in pairs(self.wheels) do
            v.is_ready = 0
        end
        
        self.cur_op_idx = -1
        self.lord_idx = -1
        self.play_poker_list = {}
        self.down_poker = {}
        self.lord_list = {}
    end
    self:broadcast_message(MSG_ROOM_MESSAGE, "step_change", {cur_step = self.cur_step})
end

function DDZ_DESK_TDCLS:change_cur_opidx(new_op_idx)
    self.cur_op_idx = new_op_idx
    self.wheels[self.cur_op_idx].last_op_time = os.time()
    self:broadcast_message(MSG_ROOM_MESSAGE, "op_idx", {cur_op_idx = self.cur_op_idx, poker_list = self:get_last_poker_list()})
end

function DDZ_DESK_TDCLS:get_next_op_idx()
    local new_op_idx = (self.cur_op_idx + 1) % 3
    if new_op_idx == 0 then
        new_op_idx = 3
    end
    return new_op_idx
end

function DDZ_DESK_TDCLS:finish_lord(lord_idx)
    self:change_cur_step(DDZ_STEP_PLAY)
    self.lord_idx = lord_idx
    local wheel = self.wheels[self.lord_idx]
    append_to_array(wheel.poker_list, self.down_poker)
    DDZ_D.resort_poker(wheel.poker_list)
    trace("finish_lord wheels is %o", self.wheels)
    for i,v in ipairs(self.wheels) do
        local desk_info = self:pack_desk_info(v.rid)
        desk_info.lord_idx = self.lord_idx
        trace("send_rid_message is = %o", {v.rid, MSG_ROOM_MESSAGE, "start_play", desk_info})
        self:send_rid_message(v.rid, MSG_ROOM_MESSAGE, "start_play", desk_info)
    end
    self:change_cur_opidx(self.lord_idx)
end

function DDZ_DESK_TDCLS:cur_lord_choose(is_choose)
    local info = {idx = self.cur_op_idx, is_choose = is_choose}
    table.insert(self.lord_list, info)
    self:broadcast_message(MSG_ROOM_MESSAGE, "deal_info", info)
    if #self.lord_list < 3 then
        self:change_cur_opidx(self:get_next_op_idx())
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
                self:finish_lord(last_choose)
            else
                self:change_cur_opidx(first_choose)
                self.wheels[self.cur_op_idx].last_op_time = os.time()
            end
        else
            for i = #self.lord_list,1,-1 do
                if self.lord_list[i].is_choose == 1 then
                    self:finish_lord(self.lord_list[i].idx)
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

function DDZ_DESK_TDCLS:pack_desk_info(user_rid)
    local result = {cur_step = self.cur_step, cur_op_idx = self.cur_op_idx, lord_idx = self.lord_idx}
    local user_data = self.users[user_rid]
    if not user_data then
        return result
    end
    
    local wheels = {}
    for i,v in ipairs(self.wheels) do
        if i == user_data.idx then
            table.insert(wheels, v)
        else
            local value = { is_ready = v.is_ready, rid = v.rid, }
            if v.is_light == 1 then
                value.poker_list = v.poker_list
            else
                value.poker_num = #(v.poker_list or {})
            end
            table.insert(wheels, value)
        end
    end
    result.wheels = wheels

    if self.cur_step == DDZ_STEP_PLAY then
        result.down_poker = self.down_poker
    end
    return result
end

function DDZ_DESK_TDCLS:send_desk_info(user_rid)
    self:send_rid_message(user_rid, MSG_ROOM_MESSAGE, "desk_info", self:pack_desk_info(user_rid))
end

function DDZ_DESK_TDCLS:user_enter(user_rid)
    get_class_func(DESK_TDCLS, "user_enter")(self, user_rid)
    local user_data = self.users[user_rid]
    if not user_data then
        return -1
    end
    user_data.last_logout_time = nil
    return 0
end

function DDZ_DESK_TDCLS:user_leave(user_rid)
    local user_data = self.users[user_rid]
    if not user_data then
        return -1
    end

    user_data.last_logout_time = os.time()

    self:broadcast_message(MSG_ROOM_MESSAGE, "success_leave_desk", {rid = user_rid, idx = idx})
    --中途掉线，保存当前进度数据
    if self.cur_step ~= DDZ_STEP_NONE then
        return -1
    end
    self.users[user_rid] = nil
    self.wheels[user_data.idx] = {}
    return 0
end

function DDZ_DESK_TDCLS:win_by_idx(idx)
    self:broadcast_message(MSG_ROOM_MESSAGE, "team_win", {idx = idx})
    --TODO win
    trace("op_info 赢得了比赛 %o", op_info)
    self:change_cur_step(DDZ_STEP_NONE)
    self.retry_deal_times = 0
    for _,wheel in ipairs(self.wheels) do
        local user_data = self.users[wheel.rid]
        if user_data and user_data.last_logout_time then
            self:user_leave(wheel.rid)
        end
    end
end

function DDZ_DESK_TDCLS:get_last_poker_list()
    for i=#self.play_poker_list,1,-1 do
        local data = self.play_poker_list[i]
        if data.is_play == 1 then
            return data.poker_list
        end
    end
    return nil
end

function DDZ_DESK_TDCLS:check_round_end()
    local len = #self.play_poker_list
    if len < 3 then
        return false
    end
    if self.play_poker_list[len].is_play == 0 and self.play_poker_list[len - 1].is_play == 0 then
        return true, self.play_poker_list[len - 2].idx
    end
    return false
end

function DDZ_DESK_TDCLS:deal_poker(poker_list)
    local op_info = self.wheels[self.cur_op_idx]
    trace("DDZ_DESK_TDCLS:deal_poker!!!!! op_info is %o", op_info)
    local last_poker_list = self:get_last_poker_list()
    --做为出牌方，无牌时则系统默认超时处理，取最小的一张牌
    if not last_poker_list and not poker_list then
        poker_list = {op_info.poker_list[#op_info.poker_list]}
    end

    if not last_poker_list and #poker_list == 0 then
        return false, "第一个出牌，必须出牌"
    end

    if not poker_list or #poker_list == 0 then
        table.insert(self.play_poker_list, {idx = self.cur_op_idx, is_play = 0})
        --非出牌方，则默认不出牌，换下一家
        self:broadcast_message(MSG_ROOM_MESSAGE, "deal_poker", {idx = self.cur_op_idx, is_play = 0, poker_list = {}})
        local is_end, win_idx = self:check_round_end()
        if is_end then
            self.play_poker_list = {}
            self:change_cur_opidx(win_idx)
        else
            self:change_cur_opidx(self:get_next_op_idx())
        end
        return
    end

    local success, new_poker_list = DDZ_D.sub_poker(op_info.poker_list, poker_list)
    trace("poker_list is = %o", poker_list)
    trace("new_poker_list is = %o", new_poker_list)
    if not success then
        return false, "您未包含有当前的牌组"
    end

    if last_poker_list and not DDZ_D.compare_card(last_poker_list, poker_list) then
        return false, "所选牌必须要大过上家"
    end


    table.insert(self.play_poker_list, {idx = self.cur_op_idx, is_play = 1, poker_list = poker_list })

    op_info.poker_list = new_poker_list
    if #op_info.poker_list == 0 then
        self:win_by_idx(self.cur_op_idx)
        return
    end

    self:broadcast_message(MSG_ROOM_MESSAGE, "deal_poker", {idx = self.cur_op_idx, is_play = 1, poker_list = poker_list})
    self:change_cur_opidx(self:get_next_op_idx())
    return true
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
        if self.cur_step ~= DDZ_STEP_PLAY then
            return
        end
        if idx ~= self.cur_op_idx then
            return
        end
        local success, err_msg = self:deal_poker(info.poker_list)
        if not success then
            self:send_rid_message(user_rid, MSG_ROOM_MESSAGE, "error_op", {ret = -1, err_msg = err_msg})
        end
        return true
    end
    return false
end
