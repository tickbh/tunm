extern crate mysql as my;
extern crate log;
extern crate env_logger;
#[macro_use(raw_to_ref)]
extern crate tunm;

extern crate td_rthreadpool;
extern crate td_revent;

extern crate commander;
use commander::Commander;

use env_logger::{Builder, Target};
use log::{warn, info};
use td_revent::{EventLoop, EventEntry, EventFlags, CellAny, RetValue};
use tunm::{GlobalConfig, LuaEngine, register_custom_func, EventMgr, FileUtils, DbPool, RedisPool, TelnetUtils, LogUtils};

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
                .option_str("-c, --config [value]", "config data ", Some("config/Gate_GlobalConfig.conf".to_string()))
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
        } else {
            lua.set(&**key, value);    
        }
    }

    LogUtils::instance().set_log_path("log/".to_string());

    FileUtils::instance().add_search_path("scripts/");
    let telnet_addr = global_config.telnet_addr.clone().unwrap_or(String::new());
    if telnet_addr.len() > 2 {
        TelnetUtils::instance().listen(&*telnet_addr);
    }

    register_custom_func(lua);
    let _ : Option<()> = LuaEngine::instance().get_lua().exec_string(format!("require '{:?}'", global_config.start_lua));
    EventMgr::instance().add_lua_excute();


    //timer check server status, example db connect is idle 
    fn check_server_status(
        ev: &mut EventLoop,
        _timer: u32, _ : Option<&mut CellAny>) -> (RetValue, u64) {
        DbPool::instance().check_connect_timeout();
        (RetValue::OK, 0)
    }
    EventMgr::instance().get_event_loop().add_timer(EventEntry::new_timer(5 * 60 * 1000, true, Some(check_server_status), None)); 

    let _ = EventMgr::instance().get_event_loop().run();

    println!("Finish Server!");
}
