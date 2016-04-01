
extern crate td_rlua;
use td_rlua::lua_State;

extern "C" {
    pub fn luaopen_cjson(L : *mut lua_State);
}
