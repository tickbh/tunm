use td_rlua::{self, lua_State, LuaRead};
use tunm_proto::*;
use std::collections::HashMap;
use LuaUtils;
pub struct NetUtils;

impl NetUtils {
    pub fn lua_read_value(lua: *mut lua_State,
                          index: i32)
                          -> Option<Value> {
        unsafe {
            let t = td_rlua::lua_type(lua, index);
            let value = match t {
                td_rlua::LUA_TBOOLEAN => {
                    let val: bool = unwrap_or!(LuaRead::lua_read_at_position(lua, index), return None);
                    Some(Value::from(val))
                }
                td_rlua::LUA_TNUMBER => {
                    let val: f64 = unwrap_or!(LuaRead::lua_read_at_position(lua, index), return None);
                    if val - val.floor() < 0.001 {
                        Some(Value::from(val as u32))
                    } else {
                        Some(Value::from(val as f32))
                    }
                }
                td_rlua::LUA_TSTRING => {
                    if let Some(val) = LuaRead::lua_read_at_position(lua, index) {
                        Some(Value::Str(val))
                    } else {
                        let dst = unwrap_or!(LuaUtils::read_str_to_vec(lua, index), return None);
                        Some(Value::from(dst))
                    }
                }
                td_rlua::LUA_TTABLE => {
                    if !td_rlua::lua_istable(lua, index) {
                        return None;
                    }
                    let len = td_rlua::lua_rawlen(lua, index);
                    if len > 0 {
                        let mut val: Vec<Value> = Vec::new();
                        for i in 1..(len + 1) {
                            td_rlua::lua_pushnumber(lua, i as f64);
                            let new_index = if index < 0 {
                                index - 1
                            } else {
                                index
                            };
                            td_rlua::lua_gettable(lua, new_index);
                            let sub_val = NetUtils::lua_read_value(lua,
                                                                    -1);
                            if sub_val.is_none() {
                                return None;
                            }
                            val.push(sub_val.unwrap());
                            td_rlua::lua_pop(lua, 1);
                        }
                        Some(Value::from(val))
                    } else {
                        let mut val: HashMap<Value, Value> = HashMap::new();
                        td_rlua::lua_pushnil(lua);
                        let t = if index < 0 {
                            index - 1
                        } else {
                            index
                        };

                        while td_rlua::lua_istable(lua, t) && td_rlua::lua_next(lua, t) != 0 {
                            let sub_val = unwrap_or!(NetUtils::lua_read_value(lua, -1), return None);
                            let value = if td_rlua::lua_isnumber(lua, -2) != 0 {
                                let idx: u32 = unwrap_or!(LuaRead::lua_read_at_position(lua, -2),
                                return None);
                                Value::from(idx)
                            } else {
                                let key: String = unwrap_or!(LuaRead::lua_read_at_position(lua, -2),
                                return None);
                                Value::from(key)
                            };
                            val.insert(value, sub_val);
                            td_rlua::lua_pop(lua, 1);
                        }
                        Some(Value::from(val))
                    }
                }
                _ => Some(Value::Nil),
            };
            value
        }
    }

    pub fn lua_convert_value(lua: *mut lua_State,
                             index: i32)
                             -> Option<Vec<Value>> {
        let size = unsafe { td_rlua::lua_gettop(lua) - index + 1 };
        let mut val: Vec<Value> = Vec::new();
        for i in 0..size {
            let sub_val = NetUtils::lua_read_value(lua,
                                                   i + index);
            if sub_val.is_none() {
                return None;
            }
            val.push(sub_val.unwrap());
        }
        Some(val)
    }
}
