use std::collections::HashMap;
use std::str::FromStr;

use super::DbTrait;
use {NetResult, NetMsg, ErrorKind, TimeUtils};

use tunm_proto::{self, Value, encode_proto};
use chrono::prelude::*;
use url;
use mysql;
use mysql::{Conn, Result as MyResult, QueryResult, Opts};
use mysql::prelude::*;


static DB_RESULT_PROTO: &'static str = "msg_db_result";
static LAST_INSERT_ID: &'static str = "sys_last_insert_id";

pub struct DbMysql {
    pub conn: Conn,
    pub last_insert_id: u64,
    pub affected_rows: u64,
    pub error: Option<mysql::Error>,
    pub is_connect: bool,
    pub last_use_time : u64,
}

impl DbMysql {
    pub fn new(conn: Conn) -> DbMysql {
        DbMysql {
            conn: conn,
            last_insert_id: 0,
            affected_rows: 0,
            error: None,
            is_connect: true,
            last_use_time: TimeUtils::get_time_ms(),
        }
    }

    // pub fn is_io_error<'a, 't, 'tc>(value: &MyResult<QueryResult<'a, 't, 'tc>>) -> bool {
    //     match value {
    //         &Err(ref val) => {
    //             match val {
    //                 &mysql::Error::IoError(_) => return true,
    //                 _ => (),
    //             }
    //         }
    //         _ => (),
    //     }
    //     false
    // }

    pub fn check_connect(&mut self) -> NetResult<()> {
        if !self.conn.ping() {
            self.is_connect = false;
            unwrap_or!(self.conn.reset().ok(),
                       fail!((ErrorKind::IoError, "reconnect db error")));
            self.is_connect = true;
        }
        Ok(())
    }


    pub fn from_url_basic(url: &str) -> Option<Opts> {
        Opts::from_url(url).ok()
    }

}


impl DbTrait for DbMysql {
    fn select(&mut self, sql_cmd: &str, msg: &mut NetMsg) -> NetResult<i32> {
        self.check_connect()?;
        let mut value = self.conn.query_iter(sql_cmd)?;
        let mut success: i32 = 0;

        while let Some(val) = value.iter() {
            
            self.last_insert_id = unwrap_or!(val.last_insert_id(), 0u64) ;
            self.affected_rows = val.affected_rows();
            let mut array = vec![];
            for (_, row) in val.enumerate() {
                // row.ok().unwrap().columns()
                let mut hash = HashMap::<Value, Value>::new();
                let mut row = row.unwrap();
                
                for column in row.columns_ref() {
                    let name = column.name_str().to_string();
                    let fix_value = 
                        match row[&*name].clone() {
                            mysql::Value::NULL => continue,
                            mysql::Value::Bytes(sub_val) => {
                                if let Some(val) = String::from_utf8(sub_val.clone()).ok() {
                                    Value::from(val)
                                } else {
                                    Value::from(sub_val)
                                }
                            }
                            mysql::Value::Int(sub_val) => {
                                Value::from(sub_val as i64)
                            }
                            mysql::Value::UInt(sub_val) => {
                                Value::from(sub_val as u64)
                            }
                            mysql::Value::Float(sub_val) => {
                                Value::from(sub_val as f32)
                            }
                            mysql::Value::Double(sub_val) => {
                                Value::from(sub_val as f64)
                            }
                            mysql::Value::Date(year, month, day, hour, minutes, seconds, micro) => {
                                let dt = Utc.ymd((year + 1970) as i32, month as u32, day as u32).and_hms(hour as u32, minutes as u32, seconds as u32); // `2014-07-08T09:10:11Z`
                                Value::from(dt.timestamp() as u32)
                            }
                            _ => continue,
                        };
                    hash.insert(Value::from(name.to_string()), fix_value);
                }
                array.push(Value::from(hash));
            }
            
            msg.set_write_data();
            encode_proto(msg.get_buffer(),
                                &DB_RESULT_PROTO.to_string(),
                                array)?;
            self.error = None;
        }
        
        Ok(success)
    }

    fn execute(&mut self, sql_cmd: &str) -> NetResult<i32> {
        self.check_connect()?;
        let mut value = self.conn.query_iter(sql_cmd)?;
        let success: i32 = 0;
        
        if let Some(val) = value.iter() {
            self.last_insert_id = unwrap_or!(val.last_insert_id(), 0u64) ;
            self.affected_rows = val.affected_rows();
            self.error = None;
        }
        Ok(success)
    }


    fn insert(&mut self, sql_cmd: &str, msg: &mut NetMsg) -> NetResult<i32> {
        self.check_connect()?;
        let value = self.conn.query_iter(sql_cmd);
        let mut success: i32 = 0;
        match value {
            Ok(val) => {
                self.last_insert_id = unwrap_or!(val.last_insert_id(), 0u64);
                self.affected_rows = val.affected_rows();
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
                match val {
                    mysql::Error::MySqlError(ref val) => success = val.code as i32,
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
        match self.error {
            Some(ref err) => {
                match *err {
                    mysql::Error::MySqlError(ref val) => val.code as i32,
                    _ => -1,
                }
            }
            None => 0,
        }
    }

    fn get_error_str(&mut self) -> Option<String> {
        match self.error {
            Some(ref err) => {
                match *err {
                    mysql::Error::MySqlError(ref val) => Some(val.message.clone()),
                    _ => Some(format!("{}", err)),
                }
            }
            None => None,
        }
    }
}
