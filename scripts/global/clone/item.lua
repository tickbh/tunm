-- item.lua
-- Created by wugd, 2011.7.20
-- 道具对象类

-- 创建类模板
ITEM_CLASS = class(DBASE_CLASS, RID_CLASS, PROPERTY_CLASS);
ITEM_CLASS.name = "ITEM_CLASS";

-- 构造函数
function ITEM_CLASS:create(value)
    assert(type(value) == "table", "item::create para not corret");
    assert(is_int(value["class_id"]));

    self:replace_dbase(value);

    if not value["amount"] then
        -- 设置数量为1
        self:set("amount", 1);
    else
        local max_count = CALC_ITEM_MAX_AMOUNT(self);
        if value["amount"] > max_count then
            trace("创建道具(%s/%d)的数量(%d)超过最大可叠加数(%d)，请检查。\n",
                  self:query("rid"), self:query("class_id"), value["amount"], max_count);
        end
    end
end

-- 析构函数
function ITEM_CLASS:destruct()
end

-- 生成对象的唯一ID
function ITEM_CLASS:get_ob_id()
    return (string.format("ITEM_CLASS:%s:%s", save_string(self:query("rid")),
                         save_string(self:query("class_id"))));
end

-- 定义公共接口，按照字母顺序排序

--获取基本类的对象
function ITEM_CLASS:basic_object()
    local class_id = self.dbase["class_id"]
    return (find_basic_object_by_class_id(class_id))
end

-- 道具增加数量
function ITEM_CLASS:add_amount(count)
    if count <= 0 then
        return;
    end

    local amount = self:query("amount");
    amount = amount + count;

    if amount > CALC_ITEM_MAX_AMOUNT(self) then
        trace("增加道具数量(%d)超过该物品的最大可叠加数。\n", amount);
        return;
    end

    -- 更新 amount 字段
    self:set("amount", amount);
end

-- 道具是否可叠加
function ITEM_CLASS:can_combine(ob)
    if not self:query("combine") or
       not ob:query("combine") or
       self:query("combine") <= 1 or
       ob:query("combine") <= 1 then
       return false;
   end

   -- 判断道具是否为同一个道具
   if self == ob or
      self:query("class_id") ~= ob:query("class_id") then
       return false;
   end

   -- 判断道具叠加后总数是否超过最大叠加数
   if self:query("amount") + ob:query("amount") > CALC_ITEM_MAX_AMOUNT(ob) then
       return false;
   end

   return true;
end

-- 道具扣除数量,返回实际扣除个数
function ITEM_CLASS:cost_amount(count)
    local amount = self:query("amount");
    local update_amount = amount - count;

    if update_amount <= 0 then
        -- 析构道具
        destruct_object(self);
        return;
    end

    -- 更新 amount 字段
    self:set("amount", update_amount);

    return count;
end

function ITEM_CLASS:is_item()
    return true;
end
