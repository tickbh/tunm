
use std::time::{SystemTime, UNIX_EPOCH};


pub struct TimeUtils {
}

impl TimeUtils {
    pub fn get_time_s() -> u64 {
        let start = SystemTime::now();
        let since_the_epoch = start
            .duration_since(UNIX_EPOCH)
            .expect("Time went backwards");
        since_the_epoch.as_secs() as u64
    }

    
    pub fn get_time_ms() -> u64 {
        let start = SystemTime::now();
        let since_the_epoch = start
            .duration_since(UNIX_EPOCH)
            .expect("Time went backwards");
        let ms = since_the_epoch.as_secs() as u64 * 1000u64 + (since_the_epoch.subsec_nanos() as f64 / 1_000_000.0) as u64;
        ms
    }
}
