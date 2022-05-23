use td_rlua::{self, Lua};
use crate::{MioEventMgr};

fn timer_event_del(time: u32) -> u32 {
    MioEventMgr::instance().delete_timer(time as u64);
    0
}

fn timer_event_set(time: u32, repeat: bool, at_once: bool) -> u32 {
    MioEventMgr::instance().add_timer_step("lua_set".to_string(), time as u64, repeat, at_once) as u32
}

pub fn register_timer_func(lua: &mut Lua) {
    lua.set("timer_event_del", td_rlua::function1(timer_event_del));
    lua.set("timer_event_set", td_rlua::function3(timer_event_set));
}
