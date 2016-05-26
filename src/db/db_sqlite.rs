use std::collections::HashMap;

use super::DbTrait;
use {NetResult, NetMsg, NetConfig, ErrorKind};

use td_rp::{self, Value, encode_proto};

use url;
use time::{self, Timespec};
use rusqlite;
use rusqlite::{Connection};


static DB_RESULT_PROTO: &'static str = "msg_db_result";
static LAST_INSERT_ID: &'static str = "sys_last_insert_id";

pub struct DbSqlite {
    pub conn: Connection,
    pub last_insert_id: u64,
    pub affected_rows: u64,
    pub error: Option<rusqlite::Error>,
    pub is_connect: bool,
    pub last_use_time : f64,
}

impl DbSqlite {
    pub fn new(conn: Connection) -> DbSqlite {
        DbSqlite {
            conn: conn,
            last_insert_id: 0,
            affected_rows: 0,
            error: None,
            is_connect: true,
            last_use_time: time::precise_time_s(),
        }
    }


    pub fn check_connect(&mut self) -> NetResult<()> {
        Ok(())
    }

}


impl DbTrait for DbSqlite {
    fn select(&mut self, sql_cmd: &str, msg: &mut NetMsg) -> NetResult<i32> {
        try!(self.check_connect());
        
        Ok(0)
    }

    fn execute(&mut self, sql_cmd: &str) -> NetResult<i32> {
        try!(self.check_connect());
        Ok(0)
    }


    fn insert(&mut self, sql_cmd: &str, msg: &mut NetMsg) -> NetResult<i32> {
        try!(self.check_connect());
        Ok(0)
    }

    fn begin_transaction(&mut self) -> NetResult<i32> {
        self.execute("START TRANSACTION")
    }

    fn commit_transaction(&mut self) -> NetResult<i32> {
        self.execute("COMMIT")
    }

    fn rollback_transaction(&mut self) -> NetResult<i32> {
        self.execute("ROLLBACK")
    }

    fn get_last_insert_id(&mut self) -> u64 {
        self.last_insert_id
    }

    fn get_affected_rows(&mut self) -> u64 {
        self.affected_rows
    }

    fn get_character_set(&mut self) -> u8 {
        0u8
    }

    fn is_connected(&mut self) -> bool {
        false
    }

    fn get_error_code(&mut self) -> i32 {
        0
    }

    fn get_error_str(&mut self) -> Option<String> {
        None
    }
}
