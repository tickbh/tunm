-- redis_scriptd.lua
-- Created by wugd
-- 负责竞技场相关的功能模块

-- 声明模块名
REDIS_SCRIPTD = {}
setmetatable(REDIS_SCRIPTD, {__index = _G})
local _ENV = REDIS_SCRIPTD

script_folder = "server/redis_scripts/"
cache_hashs = {}
cache_full_path = {}
script_slot = {}

function load_script(name, slot)
    local hash_value = load_redis_script(get_full_path(script_folder .. name .. ".lua"), "")
    if not hash_value or hash_value == "" then
        return
    end
    cache_full_path[name] = get_full_path(script_folder .. name .. ".lua")
    cache_hashs[name] = hash_value
    script_slot[name] = slot
    return true
end

function reload_redis_scripts()
    local files = get_floder_files(script_folder)
    for _,v in pairs(files) do
        local name = string.sub(v, string.len(script_folder) + 2)
        load_script(name)
    end
end

local function callback_eval_script(data, result_list)
    data.callback(data.callback_arg, result_list)
end

function eval_script_by_name(name, ext_data, callback, callback_arg)
    if not cache_hashs[name] then
        LOG.err("warning: in main thread load script %o", name)
        load_script(name)
        if not cache_hashs[name] then
            LOG.err("error: in main thread load script %o and failed!!!", name)
            callback({success = 0}, callback_arg)
            return
        end
    end

    REDIS_D.run_script_with_call(callback_eval_script, {callback = callback, callback_arg = callback_arg}, cache_full_path[name], cache_hashs[name], script_slot[name] or "", unpack(ext_data))
end

local function create()
    -- reload_redis_scripts()
end

create()