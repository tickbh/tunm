-- global_data_boot.lua
-- Created by wugd
-- 全局启动数据加载相关模块，数据加载完毕才启动

--变量定义
local post_data_init_list = {};
local need_load_data_num = 0
-- 定义公共接口，按照字母顺序排序

-- 依次调用初始化函数
local function post_data_init()
    local temp_post_init = dup(post_data_init_list);

    -- 先清空，避免递归调用
    post_data_init_list = {};
    for _, f in ipairs(temp_post_init) do
        f();
    end
end

function register_post_data_init(f)
    post_data_init_list[#post_data_init_list + 1] = f;
end

function set_need_load_data_num(num)
    need_load_data_num = num
end

function finish_one_load_data()
    need_load_data_num = need_load_data_num - 1
    if need_load_data_num <= 0 then
        post_data_init()
    end
end