use rustc_serialize::json;
use std::collections::{HashMap};
use FileUtils;
#[derive(RustcDecodable, Debug)]
pub struct GlobalConfig {
    pub lua_macros     : HashMap<String, String>,
    pub start_lua      : String,
    pub db_info        : HashMap<String, String>,
    pub telnet_addr    : Option<String>,
    pub net_info       : String,
}
static mut el : *mut GlobalConfig = 0 as *mut _;

impl GlobalConfig {
    pub fn instance() -> &'static GlobalConfig {
        unsafe {
            if el == 0 as *mut _ {
                let config = GlobalConfig {
                    lua_macros     : HashMap::new(),
                    db_info        : HashMap::new(),
                    start_lua      : "main.lua".to_string(),
                    telnet_addr    : None,
                    net_info       : "protocol.txt".to_string(),
                };
                el = Box::into_raw(Box::new(config));
            }
            &*el
        }
    }

    pub fn change_instance(file_data : &str) -> bool {
        let field : Result<GlobalConfig, _> = json::decode(file_data);
        let config = unwrap_or!(field.ok(), return false);
        unsafe {
            if el != 0 as *mut _ {
                let old = Box::from_raw(el);
                drop(old);
            }
            el = Box::into_raw(Box::new(config));
        }
        true
    }

    pub fn change_by_file(file_name : &str) -> bool {
        if let Ok(file_data) = FileUtils::get_file_data(file_name) {
            let file_data = unwrap_or!(String::from_utf8(file_data).ok(), return false);
            return GlobalConfig::change_instance(&*file_data);
        }
        false
    }

    pub fn get_redis_url_list(&self) -> Vec<String> {
        let mut result = vec![];
        for i in 0 .. 10 {
            let key = if i == 0 { "redis".to_string() } else { format!("redis{}", i) };
            if self.db_info.contains_key(&key) {
                result.push(self.db_info.get(&key).unwrap().clone());
            } 
        }
        result
    }
}

