extern crate mysql as my;
extern crate log;
extern crate env_logger;
extern crate tunm;

extern crate td_rthreadpool;

extern crate commander;
use commander::Commander;
use std::thread;
use log::{warn};
use tunm::{GlobalConfig, LuaEngine, register_custom_func, MioEventMgr, FileUtils, DbPool, RedisPool, TelnetUtils, LogUtils};

use std::env;

use std::net::UdpSocket;

/// get the local ip address, return an `Option<String>`. when it fail, return `None`.
pub fn get() -> Option<String> {
    let socket = match UdpSocket::bind("0.0.0.0:0") {
        Ok(s) => s,
        Err(_) => return None,
    };

    match socket.connect("8.8.8.8:80") {
        Ok(()) => (),
        Err(_) => return None,
    };

    match socket.local_addr() {
        Ok(addr) => return Some(addr.ip().to_string()),
        Err(_) => return None,
    };
}

fn main() {

    let command = Commander::new()
                .version(&env!("CARGO_PKG_VERSION").to_string())
                .usage("test")
                .usage_desc("tunm server commander.")
                .option_str("-c, --config [value]", "config data ", Some("config/Gate.yaml".to_string()))
                .option_str("-s, --search [value]", "search data ", Some("scripts/".to_string()))
                .option_str("-l, --log [value]", "log4rs file config ", Some("config/log4rs.yml".to_string()))
                .parse_env_or_exit()
                ;

    log4rs::init_file(&*command.get_str("l").unwrap(), Default::default()).unwrap();
    warn!("local address!! {}", get().unwrap());
    let success = GlobalConfig::change_by_file(&*command.get_str("c").unwrap());
    assert_eq!(success, true);

    let global_config = GlobalConfig::instance();
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
        } else if value.trim() == "false" {
            lua.set(&**key, false);  
        } else {
            lua.set(&**key, value.trim_matches('"'));    
        }
    }

    LogUtils::instance().set_log_path("log/".to_string());

    if let Some(path) = command.get_str("s") {
        FileUtils::instance().add_search_path(&*path);
    }

    // FileUtils::instance().add_search_path("scripts/");
    let telnet_addr = global_config.telnet_addr.clone().unwrap_or(String::new());
    if telnet_addr.len() > 2 {
        TelnetUtils::instance().listen(&*telnet_addr);
    }

    register_custom_func(lua);
    let _ : Option<()> = LuaEngine::instance().get_lua().exec_string(format!("require '{:?}'", global_config.start_lua));
    MioEventMgr::instance().add_lua_excute();



    thread::spawn(move || {
        let _ = MioEventMgr::instance().run_server();
    });

    let err = MioEventMgr::instance().run_timer();

    println!("Finish Server! {:?}", err);
}
