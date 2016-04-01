use td_rlua::Lua;
use td_clua_ext;

mod lua_db;
mod lua_network;
mod lua_userdata;
mod lua_timer;
mod lua_util;

pub use self::lua_db::register_db_func;
pub use self::lua_network::register_network_func;
pub use self::lua_userdata::register_userdata_func;
pub use self::lua_timer::register_timer_func;
pub use self::lua_util::register_util_func;


pub fn register_custom_func(lua : &mut Lua) {
    register_db_func(lua);
    register_network_func(lua);
    register_userdata_func(lua);
    register_timer_func(lua);
    register_util_func(lua);
    unsafe {
        td_clua_ext::luaopen_cjson(lua.state());    
    }
}