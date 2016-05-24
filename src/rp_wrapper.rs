use std::collections::HashMap;
use libc;

use td_rp::Value;
use td_rlua::{self, LuaPush, lua_State};
/// the wrapper for push to lua
pub struct LuaWrapperValue(pub Value);

impl LuaPush for LuaWrapperValue {
    fn push_to_lua(self, lua: *mut lua_State) -> i32 {
        match self.0 {
            Value::Nil => ().push_to_lua(lua),
            Value::U8(val) => val.push_to_lua(lua),
            Value::I8(val) => val.push_to_lua(lua),
            Value::U16(val) => val.push_to_lua(lua),
            Value::I16(val) => val.push_to_lua(lua),
            Value::U32(val) => val.push_to_lua(lua),
            Value::I32(val) => val.push_to_lua(lua),
            Value::Float(val) => val.push_to_lua(lua),
            Value::Str(val) => val.push_to_lua(lua),
            Value::Raw(val) => {
                unsafe {
                    td_rlua::lua_pushlstring(lua, val.as_ptr() as *const libc::c_char, val.len())
                };
                1
            }
            Value::Map(mut val) => {
                let mut wrapper_val: HashMap<String, LuaWrapperValue> = HashMap::new();
                for (k, v) in val.drain() {
                    wrapper_val.insert(k, LuaWrapperValue(v));
                }
                wrapper_val.push_to_lua(lua)
            }
            Value::AU8(mut val) |
            Value::AI8(mut val) |
            Value::AU16(mut val) |
            Value::AI16(mut val) |
            Value::AU32(mut val) |
            Value::AI32(mut val) |
            Value::AFloat(mut val) |
            Value::AStr(mut val) |
            Value::ARaw(mut val) |
            Value::AMap(mut val) => {
                let mut wrapper_val: Vec<LuaWrapperValue> = vec![];
                for v in val.drain(..) {
                    wrapper_val.push(LuaWrapperValue(v));
                }
                wrapper_val.push_to_lua(lua)
            }
        }
    }
}

pub struct LuaWrapperVecValue(pub Vec<Value>);
impl LuaPush for LuaWrapperVecValue {
    fn push_to_lua(mut self, lua: *mut lua_State) -> i32 {
        let mut index = 0;
        for v in self.0.drain(..) {
            index = LuaWrapperValue(v).push_to_lua(lua);
        }
        index
    }
}


pub struct LuaWrapperTableValue(pub Vec<Value>);
impl LuaPush for LuaWrapperTableValue {
    fn push_to_lua(mut self, lua: *mut lua_State) -> i32 {
        unsafe {
            td_rlua::lua_newtable(lua);
            for (i, v) in self.0.drain(..).enumerate() {
                td_rlua::lua_pushnumber(lua, (i + 1) as f64);
                LuaWrapperValue(v).push_to_lua(lua);
                td_rlua::lua_settable(lua, -3);
            }
        }
        1
    }
}
