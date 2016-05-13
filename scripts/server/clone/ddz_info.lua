-- time.lua
-- Created by wugd
-- 玩家数据ddz_info

DDZ_INFO_TDCLS = tdcls(DBASE_TDCLS, ATTRIB_TDCLS)
DDZ_INFO_TDCLS.name = "DDZ_INFO_TDCLS"

function DDZ_INFO_TDCLS:create(owner, value)
    self:init_with_data(owner, value)
end

function DDZ_INFO_TDCLS:init_with_data(owner, value)
    self.owner = owner
    if not value or is_empty_table(value) then
        value = {
            owner = self.owner,
            pea_amount = 0,
            score = 0,
            win_amount = 0,
            lose_amount = 0,
            escape_amount = 0,
            give_times = 0,
            last_give_time = 0,
        }
        self:replace_dbase(value)
        set_not_in_db(self)
    else
        self:replace_dbase(value)
    end
    self:freeze_dbase()
    self:try_give_pea()
end

function DDZ_INFO_TDCLS:try_give_pea()
    --当豆豆不足1000时尝试进行赠送
    if self:query("pea_amount") < 1000 then
        local ret= is_same_day(self:query("last_give_time"))
        if ret ~= true then
            self:set("give_times", 0)
            self:set("last_give_time", os.time())
        end

        if self:query("give_times") < 4 then
            self:add("give_times", 1)
            self:set("last_give_time", os.time())
            self:add("pea_amount", 1000)

            return true
        end
    end

    return false
end

-- 取得保存数据库的信息
function DDZ_INFO_TDCLS:save_to_mapping()
      -- 道具数据发生变化的字段
    local change_list = self:get_change_list()
    local data = {}
    local fields = DATA_D.get_table_fields("ddz_info") or {}
    for key,_ in pairs(change_list) do
        if fields[key] then
            data[key] = self:query(key)
        end
    end

    return data
end

-- 取得数据库的保存路径
function DDZ_INFO_TDCLS:get_save_path()
    return "ddz_info", { owner = self.owner }
end

function DDZ_INFO_TDCLS:set_change_to_db(callback, arg)
    local table_name, condition = self:get_save_path()
    if is_not_in_db(self) then
        local sql = SQL_D.insert_sql(table_name, self:query())
        arg.sql_count = arg.sql_count + 1
        DB_D.execute_db(table_name, sql, callback, arg)
        del_not_in_db(self)
        self:freeze_dbase()
        return
    end
    local dbase = self:save_to_mapping()
    if is_empty_table(dbase) then
        callback(arg, 0, {})
        return
    end
    local sql = SQL_D.update_sql(table_name, dbase, condition)
    arg.sql_count = arg.sql_count + 1
    DB_D.execute_db(table_name, sql, callback, arg)
    self:freeze_dbase()
end
