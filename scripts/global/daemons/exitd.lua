-- exitd.lua
-- Created by wugd
-- 结束进程

-- 声明模块名
EXIT_D = {}
setmetatable(EXIT_D, {__index = _G})
local _ENV = EXIT_D

local shutdown_status = false

-- 定义公共接口

function exit()
    --TODO 保存数据库，关闭程序

end

--关闭服务器
function shutdown()
    stop_server()
    -- CONNECT_D.closeConnectingInfo()
    --通知其它服务器关闭
    set_shutdown_status(true)
    exit()
end

function set_shutdown_status(flag)
    shutdown_status = flag
end

function is_shutdown()
    return shutdown_status
end

function create()
end
create()
