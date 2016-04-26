-- systemd.lua
-- Created by wud
-- 负责机器当前情况

-- 声明模块名
SYSTEM_D = {}
setmetatable(SYSTEM_D, {__index = _G})
local _ENV = SYSTEM_D

local cpu_num = 0
-- Such as 2500, that is 2500 MHz.
local cpu_speed = 0
local os_type = ""
local os_release = ""
--{ "one", "five", "fifteen" }
local load_avg = {}
local proc_total = 0
--{ "total", "free", "avail", "buffers", "cached", "swap_total", "swap_free" }
local mem_info = {}
--{ "total", "free" }
local disk_info = {}

function get_cpu_ratio_avg()
    return (load_avg["one"] or 0.1) * 100
end

function get_memory_use_ratio()
    mem_info["total"] = mem_info["total"] or 1
    mem_info["free"] = mem_info["free"] or 1
    if mem_info["total"] == 0 then
        trace("memory get error")
        return 0
    end
    return mem_info["free"] / mem_info["total"] * 100
end

function reload_mem_loadavg()
    load_avg = system_loadavg()
    proc_total = system_proc_total()
    mem_info = system_mem_info()
end

local function create()
    cpu_num = system_cpu_num()
    cpu_speed = system_cpu_speed()
    os_type = system_os_type()
    os_release = system_os_release()
    disk_info = system_disk_info()

    reload_mem_loadavg()
    set_timer(1000 * 60, reload_mem_loadavg, nil, true)
end

create()