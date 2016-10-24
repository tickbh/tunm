use libc;
use std::mem;

use td_rlua::{self, Lua, LuaPush};
use td_rp;
use super::EngineProtocol;
use {NetMsg, NetConfig, NetUtils};

pub struct ProtoTd;

impl EngineProtocol for ProtoTd {
    fn pack_protocol(lua: *mut td_rlua::lua_State, index: i32) -> Option<NetMsg> {
        let name: String = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, index), return None);
        let config = NetConfig::instance();
        let proto = unwrap_or!(config.get_proto_by_name(&name), return None);
        let value = NetUtils::lua_convert_value(lua, config, index + 1, &proto.args);
        if value.is_none() {
            println!("data convert failed name = {:?}", name);
            return None;
        }
        let value = value.unwrap();
        let mut net_msg = NetMsg::new();
        unwrap_or!(td_rp::encode_proto(net_msg.get_buffer(), config, &name, value).ok(),
                   return None);
        net_msg.end_msg(0);
        if net_msg.len() > 0xFFFFFF {
            println!("pack message({}) size > 0xFFFF fail!", name);
            return None;
        }
        Some(net_msg)
    }

    fn unpack_message(lua: *mut td_rlua::lua_State, index: i32) -> i32 {
        0
    }
}