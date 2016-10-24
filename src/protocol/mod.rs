
use NetMsg;
use td_rlua::{self, Lua, LuaPush};


pub trait EngineProtocol: Sized {
    fn pack_protocol(lua: *mut td_rlua::lua_State, index: i32) -> Option<NetMsg>;
    fn unpack_message(lua: *mut td_rlua::lua_State, index: i32) -> i32;
}

mod proto_td;
mod proto_json;
mod proto_bin;
mod proto_text;

pub use self::proto_td::ProtoTd;
pub use self::proto_json::ProtoJson;
pub use self::proto_bin::ProtoBin;
// pub use self::proto_text::ProtoText;
