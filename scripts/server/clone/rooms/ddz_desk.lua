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
    --当前阶段
    self.cur_step = "none"
    --当前操作者
    self.cur_op_idx = -1
    --地主拥有者
    self.lord_idx = -1
    --当前局倍数
    self.multi_num = 15
    --所有人没叫地主的次数
    self.retry_deal_times = 0
    --底牌
    self.down_poker = {}
    --存储叫地主信息
    self.lord_list = {}
    --存储出牌信息，如果结束一回合，则清空
    self.play_poker_list = {}
end

--定时器操作
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
        if os.time() - op_time > 30 then
            self:deal_poker()
        end
    end
end

--当前阶段变更
function DDZ_DESK_TDCLS:change_cur_step(new_step)
    self.cur_step = new_step
    if self.cur_step == DDZ_STEP_NONE then
        for _,v in pairs(self.wheels) do
            v.is_ready = 0
        end
        
        self.cur_op_idx = -1
        self.lord_idx = -1
        self.multi_num = 15
        self.play_poker_list = {}
        self.down_poker = {}
        self.lord_list = {}
    end
    self:broadcast_message(MSG_ROOM_MESSAGE, "step_change", {cur_step = self.cur_step})
end

--当前操作者变更
function DDZ_DESK_TDCLS:change_cur_opidx(new_op_idx)
    self.cur_op_idx = new_op_idx
    self.wheels[self.cur_op_idx].last_op_time = os.time()
    self:broadcast_message(MSG_ROOM_MESSAGE, "op_idx", {cur_op_idx = self.cur_op_idx, poker_list = self:get_last_poker_list()})
end

--得出下一次操作的对象
function DDZ_DESK_TDCLS:get_next_op_idx()
    local new_op_idx = (self.cur_op_idx + 1) % 3
    if new_op_idx == 0 then
        new_op_idx = 3
    end
    return new_op_idx
end

--确定最后谁为地主，并把底牌分给地主
function DDZ_DESK_TDCLS:finish_lord(lord_idx)
    self:change_cur_step(DDZ_STEP_PLAY)
    self.lord_idx = lord_idx
    local wheel = self.wheels[self.lord_idx]
    append_to_array(wheel.poker_list, self.down_poker)
    DDZ_D.resort_poker(wheel.poker_list)
    -- if true then
    --     wheel.poker_list = {0x01}
    -- end
    for i,v in ipairs(self.wheels) do
        local desk_info = self:pack_desk_info(v.rid)
        desk_info.lord_idx = self.lord_idx
        self:send_rid_message(v.rid, MSG_ROOM_MESSAGE, "start_play", desk_info)
    end
    self:change_cur_opidx(self.lord_idx)
end

--当前对象是否叫地主
function DDZ_DESK_TDCLS:cur_lord_choose(is_choose)
    local info = {idx = self.cur_op_idx, is_choose = is_choose}
    if is_choose == 1 then
        self:do_double_multi_num()
    end
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

--角色是否已满员
function DDZ_DESK_TDCLS:is_full_user()
    return self:get_user_count() >= 3
end

--玩游戏需要的人数
function DDZ_DESK_TDCLS:get_play_num()
    return 3
end

--游戏结束清除所有的状态
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

--是否有掉线的人
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
        TRACE("重置次数超限或者有人掉线")
        return
    end
    self.retry_deal_times = self.retry_deal_times + 1

    self:change_cur_step(DDZ_STEP_DEAL)
    self:broadcast_message(MSG_ROOM_MESSAGE, "restart_game", {})
end

--所有的人准备完毕，开始游戏
function DDZ_DESK_TDCLS:start_game()
    get_class_func(DESK_TDCLS, "start_game")(self)
    self:change_cur_step(DDZ_STEP_DEAL)
    TRACE("DDZ_DESK_TDCLS:start_game!@!!!")
end

--是否正在玩游戏
function DDZ_DESK_TDCLS:is_playing(user_rid)
    return self.cur_step ~= DDZ_STEP_NONE
end

--获取该玩家能获取的桌子信息
function DDZ_DESK_TDCLS:pack_desk_info(user_rid)
    local result = {cur_step = self.cur_step, cur_op_idx = self.cur_op_idx, lord_idx = self.lord_idx, multi_num = self.multi_num}
    local user_data = self.users[user_rid]
    if not user_data then
        return result
    end
    
    local wheels = {}
    local details = {}
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
        table.insert(details, self.room:get_base_info_by_rid(v.rid) or {})
    end
    result.wheels = wheels
    result.details = details

    if self.cur_step == DDZ_STEP_PLAY then
        result.down_poker = self.down_poker
    end
    return result
end

--发送桌子的信息
function DDZ_DESK_TDCLS:send_desk_info(user_rid)
    self:send_rid_message(user_rid, MSG_ROOM_MESSAGE, "desk_info", self:pack_desk_info(user_rid))
end

--玩家进入桌子
function DDZ_DESK_TDCLS:user_enter(user_rid)
    get_class_func(DESK_TDCLS, "user_enter")(self, user_rid)
    local user_data = self.users[user_rid]
    if not user_data then
        return -1
    end
    user_data.last_logout_time = nil
    return 0
end

--玩家离开桌子 
function DDZ_DESK_TDCLS:user_leave(user_rid)
    local user_data = self.users[user_rid]
    if not user_data then
        return -1
    end

    user_data.last_logout_time = os.time()

    self:broadcast_message(MSG_ROOM_MESSAGE, "success_leave_desk", {rid = user_rid, wheel_idx = user_data.idx})
    --中途掉线，保存当前进度数据
    if self:is_playing() then
        return -1
    end
    self.users[user_rid] = nil
    self.wheels[user_data.idx] = {}
    return 0
end

--获取所有人豆豆的数量情况
function DDZ_DESK_TDCLS:get_all_pea_amount()
    local pea_amount_list = {}
    for i=1,3 do
        local wheel = self.wheels[i]
        local info = self.room:get_base_info_by_rid(wheel.rid)
        info.ddz_info = info.ddz_info or {}
        table.insert(pea_amount_list, info.ddz_info.pea_amount or 0)
    end
    return pea_amount_list
end

--位置xx赢得了比赛
function DDZ_DESK_TDCLS:win_by_idx(idx)
    local pea_amount_list = self:get_all_pea_amount()
    self:broadcast_message(MSG_ROOM_MESSAGE, "team_win", {idx = idx})
    for i,wheel in ipairs(self.wheels) do
        local user_data = self.users[wheel.rid]
        if user_data then
            self:send_rid_message(wheel.rid, RESPONE_ROOM_MESSAGE, "calc_score", {
                is_win = (i == idx and 1 or 0),
                idx = i,
                lord_idx = self.lord_idx,
                room_name = self.room:get_room_name(),
                game_type = self.room:get_game_type(), 
                is_escape = (IS_INT(user_data.last_logout_time) and 1 or 0),
                multi_num = self.multi_num,
                pea_amount_list = pea_amount_list,
            })
            if user_data.last_logout_time then
                self:user_leave(wheel.rid)
                --掉线的则为桌号通知房间已掉线
                self.room:entity_leave(wheel.rid)
            end
        end
    end
    self:change_cur_step(DDZ_STEP_NONE)
end

--最后一个出的牌，如果是第一个出牌则为空，如果碰到不出的往前遍历
function DDZ_DESK_TDCLS:get_last_poker_list()
    for i=#self.play_poker_list,1,-1 do
        local data = self.play_poker_list[i]
        if data.is_play == 1 then
            return data.poker_list
        end
    end
    return nil
end

--是否当前回合结束，如果是，那确定新的回合是哪个位置开始
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

--叫地主倍数增加
function DDZ_DESK_TDCLS:do_double_multi_num()
    self.multi_num = self.multi_num * 2
    self:broadcast_message(MSG_ROOM_MESSAGE, "multi_num_change", {multi_num = self.multi_num})
end

--是否牌为双倍的牌
function DDZ_DESK_TDCLS:try_double_multi_num(poker_list)
    local card_type = DDZ_D.get_card_type(poker_list)
    if card_type == DDZ_D.TYPE_BOMB_CARD or card_type == DDZ_D.TYPE_MISSILE_CARD then
        self:do_double_multi_num()
    end
end

--处理当前玩家出牌
function DDZ_DESK_TDCLS:deal_poker(poker_list)
    local op_info = self.wheels[self.cur_op_idx]
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
            self:broadcast_message(MSG_ROOM_MESSAGE, "next_round", {idx = win_idx})
            self:change_cur_opidx(win_idx)
        else
            self:change_cur_opidx(self:get_next_op_idx())
        end
        return
    end

    local success, new_poker_list = DDZ_D.sub_poker(op_info.poker_list, poker_list)
    if not success then
        return false, "您未包含有当前的牌组"
    end

    if last_poker_list and not DDZ_D.compare_card(last_poker_list, poker_list) then
        return false, "所选牌必须要大过上家"
    end

    self:try_double_multi_num(poker_list)

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

--操作信息
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
        TRACE("玩家%s在位置%d已准备", user_rid, idx)
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
