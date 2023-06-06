use libc;
use std::ffi::CString;

use td_rlua::{self, lua_State, Lua, LuaPush, LuaRead, LuaStruct, NewStruct};
use {NetMsg, ProtocolMgr};

impl NewStruct for NetMsg {
    fn new() -> NetMsg {
        NetMsg::new()
    }

    fn name() -> &'static str {
        "NetMsg"
    }
}

impl<'a> LuaRead for &'a mut NetMsg {
    fn lua_read_with_pop_impl(lua: *mut lua_State, index: i32, _pop: i32) -> Option<&'a mut NetMsg> {
        td_rlua::userdata::read_userdata(lua, index)
    }
}

impl LuaPush for NetMsg {
    fn push_to_lua(self, lua: *mut lua_State) -> i32 {
        unsafe {
            let obj = Box::into_raw(Box::new(self));
            td_rlua::userdata::push_lightuserdata(&mut *obj, lua, |_| {});
            let typeid = CString::new(NetMsg::name()).unwrap();
            td_rlua::lua_getglobal(lua, typeid.as_ptr());
            if td_rlua::lua_istable(lua, -1) {
                td_rlua::lua_setmetatable(lua, -2);
            } else {
                td_rlua::lua_pop(lua, 1);
            }
            1
        }
    }
}

extern "C" fn msg_to_table(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let net_msg: &mut NetMsg = unwrap_or!(LuaRead::lua_read_at_position(lua, 1), return 0);
    ProtocolMgr::instance().unpack_protocol(lua, net_msg)
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
    value
        .create()
        .def("end_msg", td_rlua::function1(NetMsg::end_msg));
    value.create().def(
        "read_head",
        td_rlua::function1(|net_msg: &mut NetMsg| {
            let _ = net_msg.read_head();
        }),
    );
    value.create().def(
        "set_from_svr_id",
        td_rlua::function2(|net_msg: &mut NetMsg, from_svr_id: u32| {
            net_msg.set_from_svr_id(from_svr_id);
        }),
    );
    value.create().def(
        "get_from_svr_id",
        td_rlua::function1(|net_msg: &mut NetMsg| -> u32 { net_msg.get_from_svr_id() }),
    );

    value.create().def(
        "set_msg_type",
        td_rlua::function2(|net_msg: &mut NetMsg, msg_type: u8| {
            net_msg.set_msg_type(msg_type);
        }),
    );

    value.create().def(
        "get_msg_type",
        td_rlua::function1(|net_msg: &mut NetMsg| -> u8 { net_msg.get_msg_type() }),
    );

    value.create().def(
        "set_msg_flag",
        td_rlua::function2(|net_msg: &mut NetMsg, msg_flag: u8| {
            net_msg.set_msg_flag(msg_flag);
        }),
    );
    value.create().def(
        "get_msg_flag",
        td_rlua::function1(|net_msg: &mut NetMsg| -> u8 { net_msg.get_msg_flag() }),
    );

    value.create().def(
        "set_from_svr_type",
        td_rlua::function2(|net_msg: &mut NetMsg, from_svr_type: u16| {
            net_msg.set_from_svr_type(from_svr_type);
        }),
    );
    value.create().def(
        "get_from_svr_type",
        td_rlua::function1(|net_msg: &mut NetMsg| -> u16 { net_msg.get_from_svr_type() }),
    );

    value.create().def(
        "set_real_fd",
        td_rlua::function2(|net_msg: &mut NetMsg, real_fd: u32| {
            net_msg.set_real_fd(real_fd);
        }),
    );
    value.create().def(
        "get_real_fd",
        td_rlua::function1(|net_msg: &mut NetMsg| -> u32 { net_msg.get_real_fd() }),
    );

    value.create().def(
        "set_to_svr_type",
        td_rlua::function2(|net_msg: &mut NetMsg, to_svr_type: u16| {
            net_msg.set_to_svr_type(to_svr_type);
        }),
    );
    value.create().def(
        "get_to_svr_type",
        td_rlua::function1(|net_msg: &mut NetMsg| -> u16 { net_msg.get_to_svr_type() }),
    );

    value.create().def(
        "set_to_svr_id",
        td_rlua::function2(|net_msg: &mut NetMsg, to_svr_id: u32| {
            net_msg.set_to_svr_id(to_svr_id);
        }),
    );
    value.create().def(
        "get_to_svr_id",
        td_rlua::function1(|net_msg: &mut NetMsg| -> u32 { net_msg.get_to_svr_id() }),
    );

    value.create().def(
        "set_from_svr_type",
        td_rlua::function2(|net_msg: &mut NetMsg, from_svr_type: u16| {
            net_msg.set_from_svr_type(from_svr_type);
        }),
    );
    value.create().def(
        "get_from_svr_type",
        td_rlua::function1(|net_msg: &mut NetMsg| -> u16 { net_msg.get_from_svr_type() }),
    );

    value.create().def(
        "set_real_fd",
        td_rlua::function2(|net_msg: &mut NetMsg, real_fd: u32| {
            net_msg.set_real_fd(real_fd);
        }),
    );
    value.create().def(
        "get_real_fd",
        td_rlua::function1(|net_msg: &mut NetMsg| -> u32 { net_msg.get_real_fd() }),
    );

    value.create().def(
        "set_cookie",
        td_rlua::function2(|net_msg: &mut NetMsg, cookie: u32| {
            net_msg.set_cookie(cookie);
        }),
    );
    value.create().def(
        "get_cookie",
        td_rlua::function1(|net_msg: &mut NetMsg| -> u32 { net_msg.get_cookie() }),
    );

    value
        .create()
        .def("set_read_data", td_rlua::function1(NetMsg::set_read_data));
    value.create().register("msg_to_table", msg_to_table);
    value.create().register("get_data", get_data);
}

pub fn register_userdata_func(lua: &mut Lua) {
    register_netmsg_func(lua);
}
