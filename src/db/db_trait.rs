use NetResult;
use NetMsg;

pub trait DbTrait
    where Self: Sized
{
    fn select(&mut self, sql_cmd: &str, msg: &mut NetMsg) -> NetResult<i32>;
    fn execute(&mut self, sql_cmd: &str) -> NetResult<i32>;
    fn insert(&mut self, sql_cmd: &str, msg: &mut NetMsg) -> NetResult<i32>;
    fn begin_transaction(&mut self) -> NetResult<i32>;
    fn commit_transaction(&mut self) -> NetResult<i32>;
    fn rollback_transaction(&mut self) -> NetResult<i32>;
    fn get_last_insert_id(&mut self) -> u64;
    fn get_affected_rows(&mut self) -> u64;
    fn get_character_set(&mut self) -> u8;
    fn is_connected(&mut self) -> bool;
    fn get_error_code(&mut self) -> i32;
    fn get_error_str(&mut self) -> Option<String>;
}
