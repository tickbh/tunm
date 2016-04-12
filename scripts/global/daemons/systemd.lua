-- systemd.lua
-- Created by wud
-- 负责机器当前情况

-- 声明模块名
module("SYSTEM_D", package.seeall);

local cpu_num = 0
-- Such as 2500, that is 2500 MHz.
local cpu_speed = 0
local os_type = ""
local os_release = ""
local load_avg = {}
local proc_total = 0
local mem_info = {}
local disk_info = {}

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

    trace("SYSTEM_D !!!! %o", {cpu_num, cpu_speed, os_type, os_release, load_avg, proc_total, mem_info, disk_info})
end

create()