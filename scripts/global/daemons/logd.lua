-- logd.lua
-- Created by wugd
-- 日志记录

-- 声明模块名
LOG_D = {}
setmetatable(LOG_D, {__index = _G})
local _ENV = LOG_D

local table_name = "log"

function to_log(log_id, p1, p2, p3, memo, log_channel)
    local sql = SQL_D.insert_sql(table_name, {
        time = os.time(),
        log_id = log_id,        
        p1 = p1,
        p2 = p2 or "",
        p3 = p3 or "",
        memo = memo or "",
        log_channel= log_channel or LOG_CHANNEL_NULL,
        })
    DB_D.execute_db(table_name, sql)
end

-- 模块的入口执行
local function create()
end

create()
IMPORT_D = {}
setmetatable(IMPORT_D, {__index = _G})
local _ENV = IMPORT_D
