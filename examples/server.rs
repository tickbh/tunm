extern crate mysql as my;
#[macro_use(raw_to_ref)]
extern crate tdengine;

extern crate td_proto_rust as td_rp;
extern crate td_rthreadpool;

use tdengine::{NetConfig, GlobalConfig, LuaEngine, register_custom_func, EventMgr, FileUtils, DbPool, RedisPool, TelnetUtils};

use std::env;


fn main() {

    let args = env::args();
    for arg in args {
        println!("args {:?}", arg);    
    }

    let success = GlobalConfig::change_by_file("config/Gate_GlobalConfig.conf");
    assert_eq!(success, true);

    let global_config = GlobalConfig::instance();
    let success = NetConfig::change_by_file(&*global_config.net_info);
    assert_eq!(success, true);

    let success = DbPool::instance().set_db_info(global_config.db_info.clone());
    assert_eq!(success, true);

    let success = RedisPool::instance().set_url_list(global_config.get_redis_url_list());
    assert_eq!(success, true);

    let lua = LuaEngine::instance().get_lua();
    for (key, value) in &global_config.lua_macros {
        let value = &**value;
        if let Some(i) = value.trim().parse::<i32>().ok() {
            lua.set(&**key, i);  
        } else if value.trim() == "true" {
            lua.set(&**key, true);  
        } else if value.trim() == "false" {
            lua.set(&**key, false);  
        } else {
            lua.set(&**key, value);    
        }
    }

    FileUtils::instance().add_search_path("scripts/");

    if global_config.telnet_addr.is_some() {
        TelnetUtils::instance().listen(&*global_config.telnet_addr.as_ref().unwrap());
    }

    register_custom_func(lua);
    let _ : Option<()> = LuaEngine::instance().get_lua().exec_string(format!("require '{:?}'", global_config.start_lua));
    EventMgr::instance().add_lua_excute();
    let _ = EventMgr::instance().get_event_loop().run();

    println!("Finish Server!");
}
