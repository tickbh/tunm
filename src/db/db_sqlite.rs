use std::collections::HashMap;

use super::DbTrait;
use {NetResult, NetMsg, NetConfig, TimeUtils};

use rt_proto::{self, Value, encode_proto};

use rusqlite;
use rusqlite::{Connection, params};
use rusqlite::types::ValueRef;

static DB_RESULT_PROTO: &'static str = "msg_db_result";
static LAST_INSERT_ID: &'static str = "sys_last_insert_id";

pub struct DbSqlite {
    pub conn: Connection,
    pub last_insert_id: u64,
    pub affected_rows: u64,
    pub error: Option<rusqlite::Error>,
    pub is_connect: bool,
    pub last_use_time: u64,
}

impl DbSqlite {
    pub fn new(conn: Connection) -> DbSqlite {
        DbSqlite {
            conn: conn,
            last_insert_id: 0,
            affected_rows: 0,
            error: None,
            is_connect: true,
            last_use_time: TimeUtils::get_time_ms(),
        }
    }


    pub fn check_connect(&mut self) -> NetResult<()> {
        Ok(())
    }
}


impl DbTrait for DbSqlite {
    fn select(&mut self, sql_cmd: &str, msg: &mut NetMsg) -> NetResult<i32> {
        self.check_connect()?;
        let config = NetConfig::instance();
        let mut array = vec![];
        let mut success = 0;
        let mut statement = match self.conn.prepare(sql_cmd) {
            Ok(statement) => statement,
            Err(err) => {
                match &err {
                    &rusqlite::Error::SqliteFailure(err, _) => success = err.extended_code,
                    _ => (),
                }
                println!("err = {:?}", err);
                self.error = Some(err);
                return Ok(success);
            }
        };
        let mut column_names = vec![];
        {
            for v in statement.column_names() {
                column_names.push(v.to_string());
            }
        }
        match statement.query(params![]) {
            Ok(mut rows) => {
                self.error = None;
                while let Some(row) = rows.next().ok() {
                    let row = unwrap_or!(row, break);
                    let mut hash = HashMap::<Value, Value>::new();
                    
                    for i in 0..column_names.len() {
                        let val = match row.get_ref_unwrap(i) {
                            ValueRef::Null => Value::Nil,
                            ValueRef::Integer(sub_val) => Value::from(sub_val as i64),
                            ValueRef::Real(sub_val) => Value::from(sub_val as f64),
                            ValueRef::Text(sub_val) => Value::from(String::from_utf8_lossy(sub_val).to_string()),
                            ValueRef::Blob(sub_val) => Value::from(sub_val.to_vec()),
                        };
                        let column_name = &column_names[i as usize];
                        hash.insert(Value::from(column_name.clone()), val);
                    }
                    array.push(Value::from(hash));
                }
            }
            Err(err) => {
                match &err {
                    &rusqlite::Error::SqliteFailure(err, _) => success = err.extended_code,
                    _ => success = -1,
                }
                self.error = Some(err);
                return Ok(success);
            }
        }
        encode_proto(msg.get_buffer(),
                          &DB_RESULT_PROTO.to_string(),
                          array)?;
        Ok(0)
    }

    fn execute(&mut self, sql_cmd: &str) -> NetResult<i32> {
        self.check_connect()?;
        let mut success = 0;
        match self.conn.execute(sql_cmd, params![]) {
            Err(err) => {
                match &err {
                    &rusqlite::Error::SqliteFailure(err, _) => success = err.extended_code,
                    _ => success = -1,
                }
                self.error = Some(err);
                return Ok(success);
            },
            _ => {
                self.error = None;
            },
        }
        Ok(success)
    }


    fn insert(&mut self, sql_cmd: &str, msg: &mut NetMsg) -> NetResult<i32> {
        self.check_connect()?;
        let value = self.conn.execute(sql_cmd, params![]);
        let mut success: i32 = 0;
        match value {
            Ok(_) => {
                self.last_insert_id = self.conn.last_insert_rowid() as u64;
                let mut array = vec![];
                let mut hash = HashMap::<Value, Value>::new();
                hash.insert(Value::from(LAST_INSERT_ID.to_string()),
                            Value::from(self.last_insert_id as u32));
                array.push(Value::from(hash));
                encode_proto(msg.get_buffer(),
                                  &DB_RESULT_PROTO.to_string(),
                                  array)?;
                self.error = None;
            }
            Err(val) => {
                match &val {
                    &rusqlite::Error::SqliteFailure(err, _) => success = err.extended_code,
                    _ => success = -1,
                }
                self.error = Some(val);

            }
        }
        Ok(success)
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
