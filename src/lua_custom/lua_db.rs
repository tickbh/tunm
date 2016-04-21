use td_rlua::{self, LuaPush, Lua, LuaRead};
use td_rp;
use td_rredis::{self, Cmd, Script};
use libc;

use {DbTrait, DbMysql, DbPool, PoolTrait, RedisPool};
use {LuaEngine, NetMsg, NetConfig, LuaWrapperTableValue, RedisWrapperCmd, RedisWrapperResult,
     RedisWrapperMsg, RedisWrapperVecVec};
use {ThreadUtils, LogUtils, log_utils};

static MYSQL_POOL_NAME: &'static str = "mysql";
static REDIS_POOL_NAME: &'static str = "redis";
// ingnore db_type, because support mysql only
fn thread_db_select(db_name: &String, _db_type: u8, sql_cmd: &str, cookie: u32) {
    let pool = DbPool::instance();
    let mysql = DbMysql::get_db_trait(pool, db_name);
    if mysql.is_none() {
        println!("fail to get dbi - dbname : {}, sqlcmd : {}",
                 db_name,
                 sql_cmd);
        return;
    }
    let mut mysql = mysql.unwrap();
    let mut net_msg = NetMsg::new();
    let result = mysql.select(sql_cmd, &mut net_msg);
    let ret = unwrap_or!(result.ok(), mysql.get_error_code());
    net_msg.end_msg(0);
    if cookie != 0 {
        LuaEngine::instance().apply_db_result(cookie, ret, mysql.get_error_str(), Some(net_msg));
    }
    // record sql error
    if ret != 0 {
        LogUtils::instance().append(log_utils::LOG_WARN, &format!(" sql:{:?} --- error:{:?}", sql_cmd, mysql.get_error_str())[..]);
    }
    DbMysql::release_db_trait(pool, db_name, mysql);
}

fn thread_db_execute(db_name: &String, _db_type: u8, sql_cmd: &str, cookie: u32) {
    let pool = DbPool::instance();
    let mysql = DbMysql::get_db_trait(pool, db_name);
    if mysql.is_none() {
        println!("fail to get dbi - dbname : {}, sqlcmd : {}",
                 db_name,
                 sql_cmd);
        return;
    }
    let mut mysql = mysql.unwrap();
    let result = mysql.execute(sql_cmd);
    let ret = unwrap_or!(result.ok(), mysql.get_error_code());
    if cookie != 0 {
        LuaEngine::instance().apply_db_result(cookie, ret, mysql.get_error_str(), None);
    }
    // record sql error
    if ret != 0 {
        LogUtils::instance().append(log_utils::LOG_WARN, &format!(" sql:{:?} --- error:{:?}", sql_cmd, mysql.get_error_str())[..]);
    }
    DbMysql::release_db_trait(pool, db_name, mysql);
}

fn thread_db_insert(db_name: &String, _db_type: u8, sql_cmd: &str, cookie: u32) {
    let pool = DbPool::instance();
    let mysql = DbMysql::get_db_trait(pool, db_name);
    if mysql.is_none() {
        println!("fail to get dbi - dbname : {}, sqlcmd : {}",
                 db_name,
                 sql_cmd);
        return;
    }
    let mut mysql = mysql.unwrap();
    let mut net_msg = NetMsg::new();
    let result = mysql.insert(sql_cmd, &mut net_msg);
    net_msg.end_msg(0);
    let ret = unwrap_or!(result.ok(), mysql.get_error_code());
    if cookie != 0 {
        LuaEngine::instance().apply_db_result(cookie, ret, mysql.get_error_str(), Some(net_msg));
    }
    // record sql error
    if ret != 0 {
        LogUtils::instance().append(log_utils::LOG_WARN, &format!(" sql:{:?} --- error:{:?}", sql_cmd, mysql.get_error_str())[..]);
    }
    DbMysql::release_db_trait(pool, db_name, mysql);
}

fn thread_db_transaction(db_name: &String, _db_type: u8, sql_cmd_list: Vec<String>, cookie: u32) {
    let pool = DbPool::instance();
    let mysql = DbMysql::get_db_trait(pool, db_name);
    if mysql.is_none() {
        println!("fail to get dbi - dbname : {}, sql_cmd_list : {:?}",
                 db_name,
                 sql_cmd_list);
        return;
    }
    let mut mysql = mysql.unwrap();
    let mut failed = false;
    let mut ret = 0;
    let _ = mysql.begin_transaction();

    for sql_cmd in &sql_cmd_list {
        ret = unwrap_or!(mysql.execute(&*sql_cmd).ok(), {
            failed = true;
            break;
        });
        if ret < 0 {
            failed = true;
            break;
        }
    }
    if failed {
        let _ = mysql.rollback_transaction();
    } else {
        let _ = mysql.commit_transaction();
    }

    if cookie != 0 {
        LuaEngine::instance().apply_db_result(cookie, ret, mysql.get_error_str(), None);
    }
    // record sql error
    if ret != 0 {
        LogUtils::instance().append(log_utils::LOG_WARN, &format!(" sql_list:{:?} --- error:{:?}", sql_cmd_list, mysql.get_error_str())[..]);
    }
    DbMysql::release_db_trait(pool, db_name, mysql);
}


fn thread_db_batch_execute(db_name: &String,
                           _db_type: u8,
                           sql_cmd_list: Vec<String>,
                           cookie: u32) {
    let pool = DbPool::instance();
    let mysql = DbMysql::get_db_trait(pool, db_name);
    if mysql.is_none() {
        println!("fail to get dbi - dbname : {}, sql_cmd_list : {:?}",
                 db_name,
                 sql_cmd_list);
        return;
    }
    let mut mysql = mysql.unwrap();
    let mut failed = false;
    let mut ret;
    let mut err_msg: String = "".to_string();
    let _ = mysql.begin_transaction();

    for sql_cmd in &sql_cmd_list {
        ret = unwrap_or!(mysql.execute(&*sql_cmd).ok(), -1);
        if ret < 0 {
            err_msg = err_msg + "|" + &*unwrap_or!(mysql.get_error_str(), "".to_string());
            failed = true;
        }
    }
    ret = unwrap_or!(mysql.commit_transaction().ok(), -1);
    if failed {
        ret = -1;
    }
    if cookie != 0 {
        LuaEngine::instance().apply_db_result(cookie, ret, Some(err_msg), None);
    }
    // record sql error
    if ret != 0 {
        LogUtils::instance().append(log_utils::LOG_WARN, &format!(" sql_list:{:?} --- error:{:?}", sql_cmd_list, mysql.get_error_str())[..]);
    }
    DbMysql::release_db_trait(pool, db_name, mysql);
}

fn db_select(db_name: String, db_type: u8, sql_cmd: String, cookie: u32) {
    let pool = ThreadUtils::instance().get_pool(&MYSQL_POOL_NAME.to_string());
    pool.execute(move || thread_db_select(&db_name, db_type, &*sql_cmd, cookie));
}

fn db_execute(db_name: String, db_type: u8, sql_cmd: String, cookie: u32) {
    let pool = ThreadUtils::instance().get_pool(&MYSQL_POOL_NAME.to_string());
    pool.execute(move || thread_db_execute(&db_name, db_type, &*sql_cmd, cookie));
}

fn db_insert(db_name: String, db_type: u8, sql_cmd: String, cookie: u32) {
    let pool = ThreadUtils::instance().get_pool(&MYSQL_POOL_NAME.to_string());
    pool.execute(move || thread_db_insert(&db_name, db_type, &*sql_cmd, cookie));
}

fn db_transaction(db_name: String, db_type: u8, sql_cmd_list: Vec<String>, cookie: u32) {
    let pool = ThreadUtils::instance().get_pool(&MYSQL_POOL_NAME.to_string());
    pool.execute(move || thread_db_transaction(&db_name, db_type, sql_cmd_list, cookie));
}

fn db_batch_execute(db_name: String, db_type: u8, sql_cmd_list: Vec<String>, cookie: u32) {
    let pool = ThreadUtils::instance().get_pool(&MYSQL_POOL_NAME.to_string());
    pool.execute(move || thread_db_batch_execute(&db_name, db_type, sql_cmd_list, cookie));
}

extern "C" fn db_select_sync(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let db_name: String = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, 1), return 0);
    let _n_dbtype: u8 = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, 2), return 0);
    let sql_cmd: String = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, 3), return 0);

    let pool = DbPool::instance();
    let mysql = DbMysql::get_db_trait(pool, &db_name);
    if mysql.is_none() {
        println!("fail to get dbi - dbname : {}, sqlcmd : {}",
                 db_name,
                 sql_cmd);
        return 0;
    }
    let mut mysql = mysql.unwrap();
    let mut net_msg = NetMsg::new();
    let result = mysql.select(&*sql_cmd, &mut net_msg);
    let ret = unwrap_or!(result.ok(), mysql.get_error_code());
    ret.push_to_lua(lua);
    let instance = NetConfig::instance();
    net_msg.set_read_data();
    if let Ok((_, val)) = td_rp::decode_proto(net_msg.get_buffer(), instance) {
        LuaWrapperTableValue(val).push_to_lua(lua);
    } else {
        unwrap_or!(mysql.get_error_str(), "unknown error".to_string()).push_to_lua(lua);
    }
    // record sql error
    if ret != 0 {
        LogUtils::instance().append(log_utils::LOG_WARN, &format!(" sql:{:?} --- error:{:?}", sql_cmd, mysql.get_error_str())[..]);
    }
    DbMysql::release_db_trait(pool, &db_name, mysql);
    2
}

extern "C" fn db_insert_sync(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let db_name: String = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, 1), return 0);
    let _n_dbtype: u8 = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, 2), return 0);
    let sql_cmd: String = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, 3), return 0);

    let pool = DbPool::instance();
    let mysql = DbMysql::get_db_trait(pool, &db_name);
    if mysql.is_none() {
        println!("fail to get dbi - dbname : {}, sqlcmd : {}",
                 db_name,
                 sql_cmd);
        return 0;
    }
    let mut mysql = mysql.unwrap();
    let mut net_msg = NetMsg::new();
    let result = mysql.insert(&*sql_cmd, &mut net_msg);
    let ret = unwrap_or!(result.ok(), mysql.get_error_code());
    ret.push_to_lua(lua);
    if ret == 0 {
        (mysql.get_last_insert_id() as u32).push_to_lua(lua);
    } else {
        unwrap_or!(mysql.get_error_str(), "unknown error".to_string()).push_to_lua(lua);
    }
    // record sql error
    if ret != 0 {
        LogUtils::instance().append(log_utils::LOG_WARN, &format!(" sql:{:?} --- error:{:?}", sql_cmd, mysql.get_error_str())[..]);
    }
    DbMysql::release_db_trait(pool, &db_name, mysql);
    2
}

fn thread_redis_run_command(cookie: u32, cmd: Cmd) {
    let cluster = RedisPool::instance().get_redis_connection();
    if cluster.is_none() {
        println!("get redis connection failed !");
        if cookie != 0 {
            LuaEngine::instance()
                .apply_redis_result(cookie, Some(Err(td_rredis::no_connection_error())));
        }
        return;
    }
    let mut cluster = cluster.unwrap();
    let value: td_rredis::RedisResult<td_rredis::Value> = cmd.query_cluster(&mut cluster);
    if cookie != 0 {
        LuaEngine::instance().apply_redis_result(cookie, Some(value));
    }
    RedisPool::instance().release_redis_connection(cluster);
}


extern "C" fn redis_run_command(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let cookie: u32 = unwrap_or!(LuaRead::lua_read_at_position(lua, 1), return 0);
    let cmd: RedisWrapperCmd = unwrap_or!(LuaRead::lua_read_at_position(lua, 2), return 0);
    let pool = ThreadUtils::instance().get_pool(&REDIS_POOL_NAME.to_string());
    pool.execute(move || {
        thread_redis_run_command(cookie, cmd.0);
    });
    1.push_to_lua(lua);
    return 1;
}

extern "C" fn redis_run_command_sync(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let cmd: RedisWrapperCmd = unwrap_or!(LuaRead::lua_read_at_position(lua, 1), return 0);
    let cluster = RedisPool::instance().get_redis_connection();
    if cluster.is_none() {
        println!("get redis connection failed !");
        RedisWrapperResult(Err(td_rredis::no_connection_error())).push_to_lua(lua);
        return 1;
    }
    let mut cluster = cluster.unwrap();
    let value: td_rredis::RedisResult<td_rredis::Value> = cmd.0.query_cluster(&mut cluster);
    RedisPool::instance().release_redis_connection(cluster);
    RedisWrapperResult(value).push_to_lua(lua);
    1
}

fn thread_redis_subs_command(cookie: u32, op: String, channels: Vec<String>) {
    let connect = RedisPool::instance().get_sub_connection();
    if connect.is_none() {
        println!("get redis connection failed !");
        if cookie != 0 {
            LuaEngine::instance()
                .apply_redis_result(cookie, Some(Err(td_rredis::no_connection_error())));
        }
        return;
    }
    let connect = connect.unwrap();
    let result = match &*op.to_uppercase() {
        "SUBSCRIBE" => connect.subscribes(channels),
        "PSUBSCRIBE" => connect.psubscribes(channels),
        "UNSUBSCRIBE" => connect.unsubscribes(channels),
        "PUNSUBSCRIBE" => connect.punsubscribes(channels),
        _ => Err(td_rredis::make_extension_error("unknown sub command", None)),
    };
    if cookie != 0 {
        if result.is_err() {
            LuaEngine::instance().apply_redis_result(cookie, Some(Err(result.err().unwrap())));
        } else {
            LuaEngine::instance().apply_redis_result(cookie, Some(Ok(td_rredis::Value::Okay)));
        }
    }

    if op == "SUBSCRIBE" || op == "PSUBSCRIBE" {
        RedisPool::instance().start_recv_sub_msg();
    }

}

fn redis_subs_command(cookie: u32, op: String, channels: Vec<String>) {
    let pool = ThreadUtils::instance().get_pool(&REDIS_POOL_NAME.to_string());
    pool.execute(move || {
        thread_redis_subs_command(cookie, op, channels);
    });
}

extern "C" fn redis_subs_get_reply(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let receiver = RedisPool::instance().get_sub_receiver();
    if receiver.is_none() {
        return 0;
    }
    let receiver = receiver.unwrap().lock().unwrap();
    let mut list = vec![];
    loop {
        let result = unwrap_or!(receiver.try_recv().ok(), break);
        list.push(RedisWrapperMsg(result));
    }
    list.push_to_lua(lua);
    1
}

fn load_redis_script(path: String, hash: String) -> String {
    let script = unwrap_or!(Script::new_path_hash(&*path, &*hash).ok(),
                            return String::new());
    script.get_hash().to_string()
}

extern "C" fn redis_run_script(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let cookie: u32 = unwrap_or!(LuaRead::lua_read_at_position(lua, 1), return 0);
    let path: String = unwrap_or!(LuaRead::lua_read_at_position(lua, 2), return 0);
    let hash: String = unwrap_or!(LuaRead::lua_read_at_position(lua, 3), return 0);
    let slot: String = unwrap_or!(LuaRead::lua_read_at_position(lua, 4), return 0);
    let strings: RedisWrapperVecVec = unwrap_or!(LuaRead::lua_read_at_position(lua, 5),
                                                    return 0);
    let pool = ThreadUtils::instance().get_pool(&REDIS_POOL_NAME.to_string());
    pool.execute(move || {
        let script = unwrap_or!(Script::new_path_hash(&*path, &*hash).ok(), return);
        let cluster = RedisPool::instance().get_redis_connection();
        if cluster.is_none() {
            if cookie != 0 {
                LuaEngine::instance()
                    .apply_redis_result(cookie, Some(Err(td_rredis::no_connection_error())));
            }
            return;
        }
        let mut cluster = cluster.unwrap();
        {
            let connection = cluster.get_connection_by_name(slot).ok();
            if connection.is_none() {
                if cookie != 0 {
                    LuaEngine::instance()
                        .apply_redis_result(cookie, Some(Err(td_rredis::no_connection_error())));
                }
                return;
            }

            let value: td_rredis::RedisResult<td_rredis::Value> = {
                let half = strings.0.len() / 2;
                if half > 0 {
                    script.key(&strings.0[..half])
                          .arg(&strings.0[half..])
                          .invoke(connection.unwrap())
                } else {
                    script.invoke(connection.unwrap())
                }
            };
            if cookie != 0 {
                LuaEngine::instance().apply_redis_result(cookie, Some(value));
            }
        }
        RedisPool::instance().release_redis_connection(cluster);
    });
    1.push_to_lua(lua);
    return 1;
}


pub fn register_db_func(lua: &mut Lua) {
    ThreadUtils::instance().create_pool(MYSQL_POOL_NAME.to_string(), 10);
    ThreadUtils::instance().create_pool(REDIS_POOL_NAME.to_string(), 1);
    lua.set("db_select", td_rlua::function4(db_select));
    lua.set("db_execute", td_rlua::function4(db_execute));
    lua.set("db_insert", td_rlua::function4(db_insert));
    lua.set("db_transaction", td_rlua::function4(db_transaction));
    lua.set("db_batch_execute", td_rlua::function4(db_batch_execute));
    lua.register("db_select_sync", db_select_sync);
    lua.register("db_insert_sync", db_insert_sync);

    lua.register("redis_run_command", redis_run_command);
    lua.register("redis_run_command_sync", redis_run_command_sync);
    lua.set("redis_subs_command", td_rlua::function3(redis_subs_command));
    lua.register("redis_subs_get_reply", redis_subs_get_reply);
    lua.set("load_redis_script", td_rlua::function2(load_redis_script));
    lua.register("redis_run_script", redis_run_script);
}
