use libc;
use std::ffi::CString;

use td_rlua::{self, LuaPush, LuaRead, Lua, NewStruct, LuaStruct, lua_State};
use td_rp;
use {NetMsg, LuaWrapperTableValue, NetConfig};


impl NewStruct for NetMsg {
    fn new() -> NetMsg {
        NetMsg::new()
    }

    fn name() -> &'static str {
        "NetMsg"
    }
}

impl<'a> LuaRead for &'a mut NetMsg {
    fn lua_read_with_pop(lua: *mut lua_State, index: i32, _pop: i32) -> Option<&'a mut NetMsg> {
        td_rlua::userdata::read_userdata(lua, index)
    }
}

impl LuaPush for NetMsg {
    fn push_to_lua(self, lua: *mut lua_State) -> i32 {
        let t = Box::into_raw(Box::new(self));
        let stack = td_rlua::userdata::push_lightuserdata(unsafe { &mut *t }, lua, |_| {});
        unsafe {
            let typeid = CString::new(NetMsg::name()).unwrap();
            td_rlua::lua_getglobal(lua, typeid.as_ptr());
            if td_rlua::lua_istable(lua, -1) {
                td_rlua::lua_setmetatable(lua, -2);
            } else {
                td_rlua::lua_pop(lua, 1);
            }
        }
        stack
    }
}

extern "C" fn msg_to_table(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let net_msg: &mut NetMsg = unwrap_or!(LuaRead::lua_read_at_position(lua, 1), return 0);
    net_msg.set_read_data();
    let instance = NetConfig::instance();
    if let Ok((name, val)) = td_rp::decode_proto(net_msg.get_buffer(), instance) {
        name.push_to_lua(lua);
        LuaWrapperTableValue(val).push_to_lua(lua);
        return 2;
    } else {
        return 0;
    }
}

extern "C" fn get_data(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let net_msg: &mut NetMsg = unwrap_or!(LuaRead::lua_read_at_position(lua, 1), return 0);
    unsafe {
        let val = net_msg.get_buffer().get_data();
        td_rlua::lua_pushlstring(lua, val.as_ptr() as *const libc::c_char, val.len());
    }
    return 1;
}


fn register_netmsg_func(lua: &mut Lua) {
    let mut value = LuaStruct::<NetMsg>::new_light(lua.state());
    value.create().def("end_msg", td_rlua::function2(NetMsg::end_msg));
    value.create().def("read_head",
                       td_rlua::function1(|net_msg: &mut NetMsg| {
                           let _ = net_msg.read_head();
                       }));
    value.create().def("set_seq_fd",
                       td_rlua::function2(|net_msg: &mut NetMsg, seq_fd: u16| {
                           net_msg.set_seq_fd(seq_fd);
                       }));
    value.create().def("get_seq_fd",
                       td_rlua::function1(|net_msg: &mut NetMsg| -> u16 { net_msg.get_seq_fd() }));

    value.create().def("set_cookie",
                       td_rlua::function2(|net_msg: &mut NetMsg, cookie: u32| {
                           net_msg.set_cookie(cookie);
                       }));
    value.create().def("get_cookie",
                       td_rlua::function1(|net_msg: &mut NetMsg| -> u32 { net_msg.get_cookie() }));

    value.create().def("set_read_data", td_rlua::function1(NetMsg::set_read_data));
    value.create().register("msg_to_table", msg_to_table);
    value.create().register("get_data", get_data);
}

pub fn register_userdata_func(lua: &mut Lua) {
    register_netmsg_func(lua);
}
