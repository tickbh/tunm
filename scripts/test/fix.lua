local tests = {};

local function test()
    TRACE("test")
end
-- 取得所有的 agent
function get_tests()
    return tests;
end

function insert_test(v)
    table.insert(tests, v)
    test()
end

function sub_test(v)
    local tests = "aa"
    local function test()
        TRACE("tests = %o", tests)
    end
    test()
end

-- function set_port_map(first, second)
--     tests[first] = true
--     tests[second] = true
-- end

-- function get_port_map()
--     return tests
-- end

local port_map = {};
function get_port_map()
    TRACE("1111111111111111")
    return port_map
end

function set_port_map(port_no_server, port_no_client)
    TRACE("22222222222222222")
    port_map[port_no_server] = port_map[port_no_server] or {}
    port_map[port_no_client] = port_map[port_no_client] or {}
    port_map[port_no_server][port_no_client] = true
    port_map[port_no_client][port_no_server] = true
end
