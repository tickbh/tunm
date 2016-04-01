-- global_boot.lua
-- Created by wugd
-- 全局启动相关工具函数

--变量定义
local post_init_list = {};
local server_list_callback_list = {};
setmetatable(server_list_callback_list, { __mode = "v" });

-- 定义公共接口，按照字母顺序排序

-- 依次调用初始化函数
function post_init()
    local temp_post_init = dup(post_init_list);

    -- 先清空，避免递归调用
    post_init_list = {};
    for _, f in ipairs(temp_post_init) do
        f();
    end
end

function register_post_init(f)
    post_init_list[#post_init_list + 1] = f;
end

function register_server_list_done(f)
    server_list_callback_list[#server_list_callback_list + 1] = f;
end

function post_server_list_done()
    clean_array(server_list_callback_list);
    for _, f in ipairs(server_list_callback_list) do
        if type(f) == "function" then
            xpcall(f, error_handle);
        end
    end
end
