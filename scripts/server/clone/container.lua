-- container.lua
-- 容器类

-- 创建类模板
CONTAINER_TDCLS = tdcls();
CONTAINER_TDCLS.name = "CONTAINER_TDCLS";

-- 构造函数
function CONTAINER_TDCLS:create(para)
    -- 普通背包
    self.carry = {};
    setmetatable(self.carry, { __mode = "v" });
    self.owner = para.rid
end

-- 析构函数
function CONTAINER_TDCLS:destruct()
    -- 析构玩家容器
    for _, ob in pairs(self.carry) do
        DESTRUCT_OBJECT(ob);
    end
end

-- 定义公共接口，按照字母顺序排序

-- 合并道具
function CONTAINER_TDCLS:combine_to_pos(property, dst_pos)
    local pre_property = dst_pos;
    if not IS_OBJECT(pre_property) then

        -- 取得目前位置对象
        pre_property = self:get_pos_carry(dst_pos);
        if not IS_OBJECT(pre_property) then
            return (self:load_property(property, dst_pos));
        end
    end

    -- 判断是否可以合并
    if not pre_property:can_combine(property) then
        TRACE("原道具(%s/%d)无法与道具(%s/%d)进行合并。", pre_property:query("rid"),
              pre_property:query("class_id"), property:query("rid"), property:query("class_id"));
        return false;
    end

    -- 判断合并数量是否溢出
    if pre_property:query("amount") + property:query("amount") >
        CALC_ITEM_MAX_AMOUNT(property) then
        TRACE("原道具(%s/%d)与道具(%s/%d)进行合并后数量超过最大叠加数。", pre_property:query("rid"),
              pre_property:query("class_id"), property:query("rid"), property:query("class_id"));
        return false;
    end

    -- 合并道具

    -- 原道具增加个数
    pre_property:add_amount(property:query("amount"));

    -- 析构道具
    self:drop(property);

    return true;
end

function CONTAINER_TDCLS:drop(property)
    --判断道具对象是否存在
    if not property or not IS_OBJECT(property) then
       TRACE("drop的道具对象不存在");
       return;
    end

    if string.len(property:query("pos") or "") > 0 then
        self:get_owner():notify_property_delete(get_ob_rid(property))
    end
        
    if is_not_in_db(property) then        
        -- 该道具未在数据库中，不需要执行删除数据库记录的操作
        self:unload_property(property, not_auto_notify);
        DESTRUCT_OBJECT(property);        
        return;
    end

    check_rid_vaild(get_ob_rid(property))

    -- 取得道具所在的数据库表
    local table_name = property:get_save_oper();
    local sql = SQL_D.delete_sql(table_name, {rid = property:query("rid")})
    DB_D.execute_db(table_name, sql)

    LOG_D.to_log(LOG_TYPE_DESTRUCT_PROPERTY, self.owner, property:GET_RID(), tostring(property:query("class_id")), tostring(property:query("amount")), self:get_owner():query_log_channel());
    self:unload_property(property, not_auto_notify);
    DESTRUCT_OBJECT(property);
end

-- 取得所有下属物件
function CONTAINER_TDCLS:get_carry()
    return (DUP(self.carry));
end

-- 根据class_id取得所有class_id对象
function CONTAINER_TDCLS:get_carry_by_class_id(class_id)

    local arr = {};
    local x, y;
    local read_pos = READ_POS;

    for pos, ob in pairs(self.carry) do
        x, y = read_pos(pos);
        if ob:query("class_id") == class_id then
            arr[#arr + 1] = ob;
        end
    end

    return arr;
end

-- 取得某一页面的所有物件
function CONTAINER_TDCLS:get_page_carry(page)

    local arr = {};
    local x, y;
    local read_pos = READ_POS;

    for pos, ob in pairs(self.carry) do
        x, y = read_pos(pos);
        if x == page then
            arr[#arr + 1] = ob;
        end
    end

    return arr;
end

function CONTAINER_TDCLS:get_range_page_carry(ps, pe, pages)
    local arr = {};
    local x, y;
    local read_pos = READ_POS;
    local page_table = {}
    for _,v in ipairs(pages or {}) do
        page_table[v] = true
    end

    for pos, ob in pairs(self.carry) do
        x, y = read_pos(pos);
        if (x >= ps and x <= pe) or (page_table[x]) then
            arr[#arr + 1] = ob;
        end
    end

    return arr;
end

-- 根据道具类型id获得所属页的所有物件
function CONTAINER_TDCLS:get_page_carry_by_class_id(class_id)

    -- 根据道具类型ID获得道具所在的page
    local page = PROPERTY_D.get_property_info(class_id)["item_type"];

    return (self:get_page_carry(page));
end

-- 根据道具类型ID获得背包中数量
function CONTAINER_TDCLS:get_property_amount(class_id)

    local amount = 0;
    for _, ob in pairs(self.carry) do
        if ob:query("class_id") == class_id then
            amount = amount + ob:query("amount");
        end
    end

    return amount;
end


-- 扣除指定rid 和 数量的道具
function CONTAINER_TDCLS:cost_property_by_rid(rid, amount, bonus_type)
    local ob = find_object_by_rid(rid)
    if not ob then
        return false
    end

    if not amount and ob:query("ob_type") and  ob:query("ob_type") ==  OB_TYPE_EQUIP then
        amount= 1
    end

    -- 先判断玩家背包是否有足够的物品,没有不做处理
    local num = ob:query("amount");
    if num < amount then
        return false;
    end
    
    -- 扣除背包道具
    local deduct_amount = ob:cost_amount(amount, bonus_type);
    amount = amount - deduct_amount;
    if amount <= 0 then
        return true;
    end
end

-- 扣除指定数量的道具
function CONTAINER_TDCLS:cost_property(class_id, amount, bonus_type)
    if not amount or amount <= 0 then
        return true
    end
    -- 先判断玩家背包是否有足够的物品,没有不做处理
    local num = self:get_property_amount(class_id);
    if num < amount then
        return false;
    end

    -- 扣除背包道具
    local deduct_amount, ob_rid;
    for _, ob in pairs(self.carry) do
        if ob:query("class_id") == class_id then

            ob_rid = ob:GET_RID();
            deduct_amount = ob:cost_amount(amount, bonus_type);
            amount = amount - deduct_amount;
            if amount <= 0 then
                return true;
            end
        end
    end
end

-- 根据page , (pos begin->end) 获得物件集合
function  CONTAINER_TDCLS:get_page_range_carry(page, b, e)
    local arr = self:get_page_carry(page);
    if not arr then
        return;
    end

    local arr2 = {};
    local x, y;
    local read_pos = READ_POS;
    for _, ob in ipairs(arr) do
        x, y = read_pos(ob:query("pos"));
        if y >= b and y <= e then
            arr2[#arr2 + 1] = ob;
        end
    end

    return arr2;
end

-- 取得某物件的所在的位置
function CONTAINER_TDCLS:get_property_pos(property)
    return (property:query("pos"));
end

-- 取得某一位置上的物件
function CONTAINER_TDCLS:get_pos_carry(pos)
    return self.carry[pos];
end

-- 取得空闲位置
function CONTAINER_TDCLS:get_free_pos(property, can_combine)
    local page = CONTAINER_D.get_page(property, self);
    local x, y;
    local size = self:get_container_size(page);
    if not size then
        return;
    end

    local pos, ob;
    -- 若 property 为可叠加道具，则优先取得已存在的可叠加的道具位置
    if can_combine and property:query("combine") and
        property:query("combine") > 0 then

        -- 从第一个位置开始遍历
        for i = 0, size - 1 do
            pos = MAKE_POS(page, i);

            -- 取得该位置的对象
            ob = self:get_pos_carry(pos);
            if IS_OBJECT(ob) then
                -- 只对位置上存在的可叠加对象，进行判断
                if ob:can_combine(property) then
                    return pos;
                end
            end
        end
    end

    -- 从第一个位置开始遍历该页面的 pos，找到第一个空位
    for i = 0, size - 1 do
        pos = MAKE_POS(page, i);

        -- 取得该位置的对象
        ob = self:get_pos_carry(pos);
        if not ob then
            return pos;
        end
    end

    return nil;
end

-- 根据指定的page找到该page空格子的数量
function CONTAINER_TDCLS:get_free_amount_by_page(page)
    local size = self:get_container_size(page);

    if not size then
        return;
    end

    local number = 0;
    -- 从第一个位置开始遍历该页面的 pos
    for i = 0, size - 1 do
        pos = MAKE_POS(page, i);
        if not self:get_pos_carry(pos) then
            number = number + 1;
        end
    end

    return number;
end

-- 判断是否为可用的POS
function CONTAINER_TDCLS:is_available_pos(pos)
    local x,y = READ_POS(pos);

    local size = self:get_container_size(x);
    if not size then
        return;
    end

    return (y <= size - 1);
end

-- 根据class_id找到空闲位置的数量
-- can_combine: 是否考虑可叠加
function CONTAINER_TDCLS:get_free_amount_by_class_id(class_id, can_combine)

    -- 取得item_info
    local item_info = PROPERTY_D.get_property_info(class_id);
    if not item_info then
        return 0;
    end

    -- 取得所在的page
    local page = item_info["item_type"];

    -- 取得空格子数量
    local free_amount = self:get_free_amount_by_page(page);

    -- 不考虑可叠加
    if not can_combine then
        return free_amount;

    -- 考虑可叠加
    else
        -- 取得可叠加最大值
        local combine_amount = CALC_ITEM_MAX_AMOUNT(class_id);

        -- 本身就不可叠加
        if combine_amount <= 1 then
            return free_amount;
        end

        -- 开始计算可叠加数量
        free_amount = free_amount * combine_amount;

        -- 取得指定class_id的对象数组
        local properties = self:get_carry_by_class_id(class_id);
        for i, property in ipairs(properties) do
            free_amount = free_amount + (combine_amount - property:query("amount"));
        end

        return free_amount;
    end
end

-- 根据page和number判断空闲位置是否足够
function CONTAINER_TDCLS:check_free_amount_by_page(page, number)
    -- 空闲数量
    local free_amount = 0;
    local pos;

    -- 遍历该页面的空pos
    local size = self:get_container_size(page);
    if not size then
        return false;
    end
    for i = 0, size - 1 do
        pos = MAKE_POS(page, i);
        if not self:get_pos_carry(pos) then
            free_amount = free_amount + 1;
            if free_amount >= number then
                -- 空格子足够则返回
                return true;
            end
        end
    end

    return false;
end

-- 根据class_id和number判断空闲位置是否足够
function CONTAINER_TDCLS:check_free_amount_by_class_id(class_id, number)

    -- 空闲数量
    local free_amount = 0;

    -- 取得可叠加最大值
    local combine_amount = CALC_ITEM_MAX_AMOUNT(class_id);
    if combine_amount < 1 then
        return false;
    end

    -- 遍历该页面的空pos
    local page = PROPERTY_D.get_property_info(class_id)["item_type"];
    local size = self:get_container_size(page);
    if not size then
        return false;
    end
    for i = 0, size - 1 do
        pos = MAKE_POS(page, i);
        if not self:get_pos_carry(pos) then
            free_amount = free_amount + combine_amount;
            if free_amount >= number then
                -- 空格子足够则返回
                return true;
            end
        end
    end

    -- 如果是不可叠加，直接返回
    if combine_amount <= 1 then
        return false;
    end

    -- 遍历玩家的carry
    for _, property in pairs(self.carry) do
        if property:query("class_id") == class_id then
            free_amount = free_amount + (combine_amount - property:query("amount"));
            if free_amount >= number then
                return true;
            end
        end
    end

    return false;
end

-- 根据多个class_id和amount判断空闲位置是否足够
-- (不考虑可叠加，只判断空格数量和所需数量)
-- item_list =
-- {
--    {class_id=*, amount=*},
--    {class_id=*, amount=*},
--    ...
-- }
function CONTAINER_TDCLS:check_free_amount_by_multi_class_id(item_list)

    -- 先按照背包页面分类,每个页面所需空格数量
    local page_amount = {};
    local page;
    for _, info in ipairs(item_list) do
        page = PROPERTY_D.get_property_info(info.class_id)["item_type"];
        -- 认为info.amount>1是可叠加的并且不超过可叠加数
        page_amount[page] = (page_amount[page] or 0) + 1;
    end

    local rest_amount;
    -- 遍历每个页面，看剩余空格够不够
    for page, amount in pairs(page_amount) do
        rest_amount = self:get_free_amount_by_page(page);
        if rest_amount < amount then
            return false;
        end
    end

    return true;
end

-- 增加指定数量的道具、装备
function CONTAINER_TDCLS:add_property(class_id, amount, bonus_type)

    if not amount then
        amount = 1;
    end

    if not bonus_type then
        bonus_type = BONUS_TYPE_GD;
    end

    local combine = 1;
    if PROPERTY_D.get_item_dbase(class_id) then
        combine = CALC_ITEM_MAX_AMOUNT(class_id);
    end

    -- 根据可叠加数来构造bonus_info
    local property_list = {};
    while amount > 0 do
        local info = { ob=self, class_id=class_id };
        if amount > combine then
            info["amount"] = combine;
        else
            info["amount"] = amount;
        end
        property_list[#property_list+1] = info;
        amount = amount - combine;
    end

    -- 执行奖励
    local bonus_info = { property = property_list };
    BONUS_D.do_bonus(bonus_info, bonus_type);
end

-- 根据指定的page找到该page空闲位置
function CONTAINER_TDCLS:get_free_pos_by_page(page)
    local size = self:get_container_size(page);

    if not size then
        return;
    end

    local pos;
    -- 从第一个位置开始遍历该页面的 pos
    for i = 0, size - 1 do
        pos = MAKE_POS(page, i);
        if not self:get_pos_carry(pos) then
            return pos;
        end
    end

    return nil;
end

-- 取得某一页面指定范围的物件
function CONTAINER_TDCLS:get_page_carry_by_region(page, range, idx)

    local size = self:get_container_size(page);
    if not size then
        return;
    end

    -- 取得指定区间开始和结束索引
    local b = math.floor(size/range)*(idx-1);
    local e = b + range - 1;

    return (self:get_page_range_carry(page, b, e));
end

-- 根据指定的page找到该page和指定区间的空闲位置
function CONTAINER_TDCLS:get_free_pos_by_region(page, range, idx)
    local size = self:get_container_size(page);
    if not size then
        return;
    end

    -- 取得指定区间开始和结束索引
    local b = math.floor(size/range)*(idx-1);
    local e = b + range - 1;

    local pos;
    -- 从第一个位置开始遍历该页面的pos
    for i = b, e - 1 do
        pos = MAKE_POS(page, i);
        if not self:get_pos_carry(pos) then
            return pos, b;
        end
    end

    return nil;
end

function CONTAINER_TDCLS:init_property(property)
    ASSERT(property["pos"] and property["class_id"] and property["rid"], "pos class_id rid must be exist")
    ASSERT(self.carry[property["pos"]] == nil, "carry pos must nil")
    property = PROPERTY_D.clone_object_from(property["class_id"], property, true)
    if not property then
        return false
    end
    -- 将物件放入窗口中
    property:set("owner", self.owner);
    property:set_temp("container", self.owner);

    -- 记录物件的位置索引
    self.carry[property:query("pos")] = property;

    return true;
end

function CONTAINER_TDCLS:recieve_property(info, check_enough)

    ASSERT(info["class_id"] ~= nil, "class_id must no empty")
    local item_info = PROPERTY_D.get_item_or_equip_info(info["class_id"])
    if not item_info then
        return false;
    end

    local page = CONTAINER_D.get_page_by_data(item_info);
    local size = self:get_container_size(page);
    if not size then
        return false;
    end
    info["amount"] = info["amount"] or 1
    local max_amount = CALC_ITEM_MAX_AMOUNT(item_info)
    local pos, left_amount = nil, info["amount"]

    local gain_list = {}
    local empty_slot = {}
    for i = 1, size - 1 do
        pos = MAKE_POS(page, i)
        local property = self:get_pos_carry(pos)
        if not property then
            empty_slot[#empty_slot+1] = pos
        elseif property:query("class_id") == info["class_id"] then
            local get_amount = math.max(0, max_amount - property:query("amount"))
            if get_amount > 0 then
                local real_get = math.min(get_amount, left_amount)
                table.insert(gain_list, { pos = pos, amount = real_get })
                left_amount = left_amount - real_get
            end
            if left_amount <= 0 then
                break
            end
        end
    end

    if left_amount > 0 and #empty_slot > 0 then 
        for _, pos in ipairs(empty_slot) do 
            local real_get = math.min(max_amount, left_amount)
            table.insert(gain_list, { pos = pos, amount = real_get })
            left_amount = left_amount - real_get
            if left_amount <= 0 then break end
        end
    end

    if check_enough and left_amount > 0 then 
        return false, "背包空间不足"
    end
    local result_list = {}
    for _,v in ipairs(gain_list) do
        local property = PROPERTY_D.clone_object_from(info["class_id"], MERGE(DUP(info), {amount = v.amount}), false)
        self:load_property(property, v.pos)
        local property = self.carry[v.pos]
        table.insert(result_list, {rid = get_ob_rid(property), class_id = info["class_id"], amount = v.amount, pos = v.pos, ob_type = property:query("ob_type")})
    end
    return true, result_list
end

-- 加载道具
function CONTAINER_TDCLS:load_property(property, dst_pos, not_auto_notify, not_auto_arrange)
    if property:query_temp("container") == self.owner then
        -- 道具已在容器中，需要先从容器中移除
        self:unload_property(property, not_auto_notify);
    end

    -- 判断目标位置是否已被占用
    if self:is_pos_occuppied(dst_pos) then
        -- 若该位置为自动获取的，则尝试合并道具
        return (self:combine_to_pos(property, dst_pos));
    end
    local owner_rid = self.owner
    local owner_ob = self:get_owner()
    LOG_D.to_log(LOG_TYPE_CREATE_PROPERTY, self.owner, property:GET_RID(), tostring(property:query("class_id")), tostring(property:query("amount")), self:get_owner():query_log_channel());
    -- 记录物件的位置
    property:set("pos", dst_pos);

    -- 将物件放入窗口中
    property:set("owner", self.owner);
    property:set_temp("container", self.owner);

    -- 记录物件的位置索引
    self.carry[dst_pos] = property;
    -- 通知物件加载
    self:get_owner():notify_property_loaded(property:GET_RID())

    return true;
end

function CONTAINER_TDCLS:get_owner()
    return find_object_by_rid(self.owner)
end

-- 卸载道具
function CONTAINER_TDCLS:unload_property(property, not_auto_notify)
    local pos = property:query("pos");
    local property_rid = property:query("rid");

    -- 删除该物件记录的 container
    property:delete_temp("container");
    if pos then
        -- 背包物品析构，从 carry 中移除该物件
        self.carry[pos] = nil;
    end

    return true;
end

-- 判断位置是否已被占用
function CONTAINER_TDCLS:is_pos_occuppied(pos)
    return (IS_OBJECT(self.carry[pos]));
end

-- 取得容器实际的容量,否则取定义的容量大小
function CONTAINER_TDCLS:get_container_size(page)
    local container_size = self:query("container_size") or {};
    local size = container_size[page] or MAX_PAGE_SIZE[page];
    return size;
end

-- 设置容器大小
function CONTAINER_TDCLS:set_container_size(page, size)
    local container_size = self:query("container_size") or {};
    container_size[page] = size;
    self:set("container_size", container_size);
end

-- 交换位置
function CONTAINER_TDCLS:switch_pos(src_pos, dst_pos)

    local src_ob = self.carry[src_pos];
    local dst_ob = self.carry[dst_pos];

    self.carry[src_pos] = nil;
    self.carry[dst_pos] = nil;

    if IS_OBJECT(src_ob) then
        src_ob:set("pos", dst_pos);
        self.carry[dst_pos] = src_ob;
        src_ob:notify_fields_updated("pos");
    end

    if IS_OBJECT(dst_ob) then
        dst_ob:set("pos", src_pos);
        self.carry[src_pos] = dst_ob;
        dst_ob:notify_fields_updated("pos");
    end
end

-- 交换位置不带通知
function CONTAINER_TDCLS:switch_carry_pos_without_notify(src_pos, dst_pos)

    local src_ob = self.carry[src_pos];
    local dst_ob = self.carry[dst_pos];

    self.carry[src_pos] = nil;
    self.carry[dst_pos] = nil;

    if src_ob and src_ob:is_equip() == true then
        --src_ob:set("pos", dst_pos);
        self.carry[dst_pos] = src_ob;
        --src_ob:notify_fields_updated("pos");
    end

    if dst_ob and dst_ob:is_equip() == true then
        --dst_ob:set("pos", src_pos);
        self.carry[src_pos] = dst_ob;
        --dst_ob:notify_fields_updated("pos");
    end
end