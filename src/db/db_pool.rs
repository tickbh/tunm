use std::collections::HashMap;
use crate::TimeUtils;

use super::DbMysql;
use super::DbSqlite;
use super::DbTrait;
use std::sync::Mutex;
use std::path::Path;
use std::fs;

use {NetResult, NetMsg};

use mysql::{self, Opts, OptsBuilder};

use rusqlite::{Connection};

static mut EL: *mut DbPool = 0 as *mut _;

const MAX_KEEP_CONN: u64 = 3600u64;

/// it store the db connection,  and the base db info
pub struct DbPool {
    pub db_mysql: HashMap<String, Vec<DbMysql>>,
    pub db_sqlite: HashMap<String, Vec<DbSqlite>>,
    pub db_info: HashMap<String, String>,
    pub mutex: Mutex<i32>,
}

pub enum DbStruct {
    MySql(DbMysql),
    Sqlite(DbSqlite),
}

pub trait PoolTrait : Sized {
    /// get the db connection from pool, it not exist it will call init_db_trait init connection
    fn get_db_trait(pool: &mut DbPool, db_name: &String) -> Option<Self>;
    /// finish use the connection, it will push into pool
    fn release_db_trait(pool: &mut DbPool, db_name: &String, db: Self);
    /// init db connection 
    fn init_db_trait(pool: &mut DbPool, db_name: &String) -> Option<Self>;
}

impl DbPool {
    pub fn new() -> DbPool {
        DbPool {
            db_mysql: HashMap::new(),
            db_sqlite: HashMap::new(),
            db_info: HashMap::new(),
            mutex: Mutex::new(0),
        }
    }

    pub fn instance() -> &'static mut DbPool {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(DbPool::new()));
            }
            &mut *EL
        }
    }

    pub fn set_db_info(&mut self, db_info: HashMap<String, String>) -> bool {
        self.db_info = db_info;
        true
    }

    /// try remove the long time unuse connection
    pub fn check_connect_timeout(&mut self) {
        let _guard = self.mutex.lock().unwrap();
        let cur_time = TimeUtils::get_time_ms();
        for (_, list) in self.db_mysql.iter_mut() {
            let val: Vec<DbMysql> = list.drain(..).collect();
            for v in val {
                if cur_time - v.last_use_time < MAX_KEEP_CONN {
                    list.push(v);
                }
            }
        }
    }

    pub fn get_db_trait(&mut self, db_type: u8, db_name: &String) -> Option<DbStruct> {
        if db_type == 1 {
            let mysql = unwrap_or!(DbMysql::get_db_trait(self, db_name), return None);
            return Some(DbStruct::MySql(mysql))
        } else if db_type == 0 {
            let sqlite = unwrap_or!(DbSqlite::get_db_trait(self, db_name), return None);
            return Some(DbStruct::Sqlite(sqlite))
        }
        None
    }

    pub fn release_db_trait(&mut self, db_name: &String, db: DbStruct) {
        match db {
            DbStruct::MySql(db) => DbMysql::release_db_trait(self, db_name, db),
            DbStruct::Sqlite(db) => DbSqlite::release_db_trait(self, db_name, db),
        }
    }
}

impl PoolTrait for DbMysql {
    fn get_db_trait(pool: &mut DbPool, db_name: &String) -> Option<DbMysql> {
        let db = {
            let _guard = pool.mutex.lock().unwrap();
            let list = match pool.db_mysql.contains_key(db_name) {
                true => pool.db_mysql.get_mut(db_name).unwrap(),
                false => {
                    pool.db_mysql.entry(db_name.to_string()).or_insert(vec![]);
                    pool.db_mysql.get_mut(db_name).unwrap()
                }
            };
            if list.is_empty() {
                None
            } else {
                list.pop()
            }
        };

        match db {
            Some(_) => db,
            None => PoolTrait::init_db_trait(pool, db_name),
        }
    }

    fn release_db_trait(pool: &mut DbPool, db_name: &String, mut db: DbMysql) {
        // db is lose connection, not need add to pool
        if !db.is_connect {
            return;
        }
        db.last_use_time = TimeUtils::get_time_ms();
        let _guard = pool.mutex.lock().unwrap();
        let list = match pool.db_mysql.contains_key(db_name) {
            true => pool.db_mysql.get_mut(db_name).unwrap(),
            false => {
                pool.db_mysql.entry(db_name.to_string()).or_insert(vec![]);
                pool.db_mysql.get_mut(db_name).unwrap()
            }
        };
        list.push(db);
    }

    fn init_db_trait(pool: &mut DbPool, db_name: &String) -> Option<DbMysql> {
        let mut info = pool.db_info.get(&db_name.to_string());
        if info.is_none() {
            info = pool.db_info.get(&"mysql".to_string());
        }
        let info = unwrap_or!(info, return None);
        let opts: Opts = DbMysql::from_url_basic(&**info).unwrap();
        let opts = OptsBuilder::from_opts(opts).db_name(Some(db_name.clone()));
        // opts.db_name(db_name.clone());
        println!("opts = {:?}", opts);
        let pool = unwrap_or!(mysql::Conn::new(opts).ok(), return None);
        Some(DbMysql::new(pool))
    }
}

impl PoolTrait for DbSqlite {
    fn get_db_trait(pool: &mut DbPool, db_name: &String) -> Option<DbSqlite> {
        let db = {
            let _guard = pool.mutex.lock().unwrap();
            let list = match pool.db_sqlite.contains_key(db_name) {
                true => pool.db_sqlite.get_mut(db_name).unwrap(),
                false => {
                    pool.db_sqlite.entry(db_name.to_string()).or_insert(vec![]);
                    pool.db_sqlite.get_mut(db_name).unwrap()
                }
            };
            if list.is_empty() {
                None
            } else {
                list.pop()
            }
        };

        match db {
            Some(_) => db,
            None => Self::init_db_trait(pool, db_name),
        }
    }

    fn release_db_trait(pool: &mut DbPool, db_name: &String, mut db: DbSqlite) {
        // db is lose connection, not need add to pool
        if !db.is_connect {
            return;
        }
        db.last_use_time = TimeUtils::get_time_ms();
        let _guard = pool.mutex.lock().unwrap();
        let list = match pool.db_sqlite.contains_key(db_name) {
            true => pool.db_sqlite.get_mut(db_name).unwrap(),
            false => {
                pool.db_sqlite.entry(db_name.to_string()).or_insert(vec![]);
                pool.db_sqlite.get_mut(db_name).unwrap()
            }
        };
        list.push(db);
    }

    fn init_db_trait(pool: &mut DbPool, db_name: &String) -> Option<DbSqlite> {
        let mut info = pool.db_info.get(&db_name.to_string());
        if info.is_none() {
            info = pool.db_info.get(&"sqlite".to_string());
        }
        let info = unwrap_or!(info, return None);
        let _ = fs::create_dir_all(Path::new("db"));

        let db_dir = Path::new("db");
        let path = db_dir.join(&*info);
        let db =  unwrap_or!(Connection::open(&path).ok(), return None);
        Some(DbSqlite::new(db))
    }
}

impl DbTrait for DbStruct {
    fn select(&mut self, sql_cmd: &str, msg: &mut NetMsg) -> NetResult<i32> {
        match *self {
            DbStruct::MySql(ref mut db) => db.select(sql_cmd, msg),
            DbStruct::Sqlite(ref mut db) => db.select(sql_cmd, msg),
        }
    }

    fn execute(&mut self, sql_cmd: &str) -> NetResult<i32> {
        match *self {
            DbStruct::MySql(ref mut db) => db.execute(sql_cmd),
            DbStruct::Sqlite(ref mut db) => db.execute(sql_cmd),
        }
    }


    fn insert(&mut self, sql_cmd: &str, msg: &mut NetMsg) -> NetResult<i32> {
        match *self {
            DbStruct::MySql(ref mut db) => db.insert(sql_cmd, msg),
            DbStruct::Sqlite(ref mut db) => db.insert(sql_cmd, msg),
        }
    }

    fn begin_transaction(&mut self) -> NetResult<i32> {
        match *self {
            DbStruct::MySql(ref mut db) => db.begin_transaction(),
            DbStruct::Sqlite(ref mut db) => db.begin_transaction(),
        }
    }

    fn commit_transaction(&mut self) -> NetResult<i32> {
        match *self {
            DbStruct::MySql(ref mut db) => db.commit_transaction(),
            DbStruct::Sqlite(ref mut db) => db.commit_transaction(),
        }
    }

    fn rollback_transaction(&mut self) -> NetResult<i32> {
        match *self {
            DbStruct::MySql(ref mut db) => db.rollback_transaction(),
            DbStruct::Sqlite(ref mut db) => db.rollback_transaction(),
        }
    }

    fn get_last_insert_id(&mut self) -> u64 {
        match *self {
            DbStruct::MySql(ref mut db) => db.get_last_insert_id(),
            DbStruct::Sqlite(ref mut db) => db.get_last_insert_id(),
        }
    }

    fn get_affected_rows(&mut self) -> u64 {
        match *self {
            DbStruct::MySql(ref mut db) => db.get_affected_rows(),
            DbStruct::Sqlite(ref mut db) => db.get_affected_rows(),
        }
    }

    fn get_character_set(&mut self) -> u8 {
        match *self {
            DbStruct::MySql(ref mut db) => db.get_character_set(),
            DbStruct::Sqlite(ref mut db) => db.get_character_set(),
        }
    }

    fn is_connected(&mut self) -> bool {
        match *self {
            DbStruct::MySql(ref mut db) => db.is_connected(),
            DbStruct::Sqlite(ref mut db) => db.is_connected(),
        }
    }

    fn get_error_code(&mut self) -> i32 {
        match *self {
            DbStruct::MySql(ref mut db) => db.get_error_code(),
            DbStruct::Sqlite(ref mut db) => db.get_error_code(),
        }
    }

    fn get_error_str(&mut self) -> Option<String> {
        match *self {
            DbStruct::MySql(ref mut db) => db.get_error_str(),
            DbStruct::Sqlite(ref mut db) => db.get_error_str(),
        }
    }
}