use std::collections::HashMap;
use super::DbMysql;
use std::sync::Mutex;

use time;
use mysql::{self, Opts};

static mut el: *mut DbPool = 0 as *mut _;

const MAX_KEEP_CONN: f64 = 3600f64;

pub struct DbPool {
    pub db_mysql: HashMap<String, Vec<DbMysql>>,
    pub db_info: HashMap<String, String>,
    pub mutex: Mutex<i32>,
}

pub trait PoolTrait: Sized {
    fn get_db_trait(pool: &mut DbPool, db_name: &String) -> Option<Self>;
    fn release_db_trait(pool: &mut DbPool, db_name: &String, db: Self);
    fn init_db_trait(pool: &mut DbPool, db_name: &String) -> Option<Self>;
}

impl DbPool {
    pub fn new() -> DbPool {
        DbPool {
            db_mysql: HashMap::new(),
            db_info: HashMap::new(),
            mutex: Mutex::new(0),
        }
    }

    pub fn instance() -> &'static mut DbPool {
        unsafe {
            if el == 0 as *mut _ {
                el = Box::into_raw(Box::new(DbPool::new()));
            }
            &mut *el
        }
    }

    pub fn set_db_info(&mut self, db_info: HashMap<String, String>) -> bool {
        self.db_info = db_info;
        true
    }

    pub fn check_connect_timeout(&mut self) {
        let _guard = self.mutex.lock().unwrap();
        let cur_time = time::precise_time_s();
        for (_, list) in self.db_mysql.iter_mut() {
            let val: Vec<DbMysql> = list.drain(..).collect();
            for v in val {
                if cur_time - v.last_use_time < MAX_KEEP_CONN {
                    list.push(v);
                }
            }
        }
    }
}

impl PoolTrait for DbMysql {
    fn get_db_trait(pool: &mut DbPool, db_name: &String) -> Option<DbMysql> {
        let db = {
            let _guard = pool.mutex.lock().unwrap();
            let mut list = match pool.db_mysql.contains_key(db_name) {
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
        db.last_use_time = time::precise_time_s();
        let _guard = pool.mutex.lock().unwrap();
        let mut list = match pool.db_mysql.contains_key(db_name) {
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
        let mut opts: Opts = Opts::from(&**info);
        opts.db_name = Some(db_name.clone());
        let pool = unwrap_or!(mysql::Conn::new(opts).ok(), return None);
        Some(DbMysql::new(pool))
    }
}
