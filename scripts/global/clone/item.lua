-- item.lua
-- Created by wugd
-- 道具对象类

-- 创建类模板
ITEM_TDCLS = tdcls(DBASE_TDCLS, RID_TDCLS, PROPERTY_TDCLS)
ITEM_TDCLS.name = "ITEM_TDCLS"

-- 构造函数
function ITEM_TDCLS:create(value)
    assert(type(value) == "table", "item::create para not corret")
    assert(is_int(value["class_id"]))

    self:replace_dbase(value)

    if not value["amount"] then
        -- 设置数量为1
        self:set("amount", 1)
    else
        local max_count = CALC_ITEM_MAX_AMOUNT(self)
        if value["amount"] > max_count then
            trace("创建道具(%s/%d)的数量(%d)超过最大可叠加数(%d)，请检查。\n",
                  self:query("rid"), self:query("class_id"), value["amount"], max_count)
        end
    end
end

-- 析构函数
function ITEM_TDCLS:destruct()
end

-- 生成对象的唯一ID
function ITEM_TDCLS:get_ob_id()
    return (string.format("ITEM_TDCLS:%s:%s", save_string(self:query("rid")),
                         save_string(self:query("class_id"))))
end

-- 定义公共接口，按照字母顺序排序

--获取基本类的对象
function ITEM_TDCLS:basic_object()
    local class_id = self.dbase["class_id"]
    return (find_basic_object_by_class_id(class_id))
end

-- 道具增加数量
function ITEM_TDCLS:add_amount(count)
    trace("ITEM_TDCLS:add_amount amount is %o", count)
    if count <= 0 then
        return
    end

    local amount = self:query("amount")
    amount = amount + count

    if amount > CALC_ITEM_MAX_AMOUNT(self) then
        trace("增加道具数量(%d)超过该物品的最大可叠加数。\n", amount)
        return
    end

    -- 更新 amount 字段
    self:set("amount", amount)
    self:notify_fields_updated({"amount"})

    local memo = string.format("add:%d|remain:%d", count, self:query("amount"))
    LOG_D.to_log(LOG_TYPE_ADD_AMOUNT, self:query("owner"), self:get_rid(),
                 tostring(self:query("class_id")), memo, find_object_by_rid(self:query("owner")):query_log_channel())
end

-- 道具是否可叠加
function ITEM_TDCLS:can_combine(ob)
    if not self:query("over_lap") or
       not ob:query("over_lap") or
       self:query("over_lap") <= 1 or
       ob:query("over_lap") <= 1 then
       return false
   end

   -- 判断道具是否为同一个道具
   if self == ob or
      self:query("class_id") ~= ob:query("class_id") then
       return false
   end

   -- 判断道具叠加后总数是否超过最大叠加数
   if self:query("amount") + ob:query("amount") > CALC_ITEM_MAX_AMOUNT(ob) then
       return false
   end

   return true
end

-- 道具扣除数量,返回实际扣除个数
function ITEM_TDCLS:cost_amount(count)
    local owner = get_owner(self)
    local amount = self:query("amount")
    local update_amount = amount - count

    if update_amount <= 0 then
        owner:get_container():drop(self)
        return 0
    end

    -- 更新 amount 字段
    self:set("amount", update_amount)
    self:notify_fields_updated({"amount"})

    local memo = string.format("cost:%d|remain:%d", count, self:query("amount"))
    LOG_D.to_log(LOG_TYPE_COST_AMOUNT, self:query("owner"), self:get_rid(),
                 tostring(self:query("class_id")), memo, owner:query_log_channel() )
    return count
end

-- 通知字段变更
function ITEM_TDCLS:notify_fields_updated(field_names)
    local owner = get_owner(self)
    if not owner then
        return
    end

    owner:notify_property_updated(get_ob_rid(self), field_names)
end

function ITEM_TDCLS:is_item()
    return true
end

-- 取得数据库的保存操作
function ITEM_TDCLS:get_save_oper()
    local oper = self:query_temp("not_in_db") and "insert" or "update"
    return "item", self:query("rid"), oper
end

-- 取得保存数据库的信息
function ITEM_TDCLS:save_to_mapping()
    --insert操作,返回全部数据
    if self:quermy_temp("not_in_db") then
        return (self:query())
    end

    -- 道具数据发生变化的字段
    local change_list = self:get_change_list()
    local data = {}

    for key,_ in pairs(change_list) do
        if DATA_D.is_field_exist("item", key) then
            data[key] = self:query(key)
        else
            return (self:query())
        end 
    end

    if sizeof(data) == 0 then
        return
    end

    return data, 1
end
