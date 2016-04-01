use td_revent::{EventLoop, EventEntry, EventFlags};
use td_rlua::{self, Lua};
use {EventMgr, LuaEngine};

//timer return no success(0) will no be repeat
fn time_callback(_ev : &mut EventLoop, fd : u32, _ : EventFlags, _ : *mut ()) -> i32 {
    LuaEngine::instance().apply_args_func("timer_event_dispatch".to_string(), vec![fd.to_string()]);
    0
}

fn timer_event_del(time : u32) -> u32 {
    let event_loop = EventMgr::instance().get_event_loop();
    let _ = event_loop.del_timer(time);
    0
}

fn timer_event_set(time : u32, repeat : bool) -> u32 {
    let event_loop = EventMgr::instance().get_event_loop();
    let timer_id = event_loop.add_timer(EventEntry::new_timer((time * 1000) as u64, repeat, Some(time_callback), None));
    timer_id
}

pub fn register_timer_func(lua : &mut Lua) {
    lua.set("timer_event_del", td_rlua::function1(timer_event_del));
    lua.set("timer_event_set", td_rlua::function2(timer_event_set));
}
