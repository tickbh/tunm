use ThreadPool;
use std::collections::{HashMap};

pub struct ThreadUtils {
    pools : HashMap<String, ThreadPool>
}

static mut el : *mut ThreadUtils = 0 as *mut _;
const DEFAULT_THREADS : usize = 1;

impl ThreadUtils {
    pub fn instance() -> &'static mut ThreadUtils {
        unsafe {
            if el == 0 as *mut _ {
                let config = ThreadUtils {
                    pools     : HashMap::new(),
                };
                el = Box::into_raw(Box::new(config));
            }
            &mut *el
        }
    }

    pub fn create_pool(&mut self, name : String, threads : usize) {
        let pool = ThreadPool::new_with_name(threads, name.clone());
        self.pools.insert(name, pool);
    }

    pub fn get_pool(&mut self, name : &String) -> &mut ThreadPool {
        if !self.pools.contains_key(name) {
            self.pools.insert(name.clone(), ThreadPool::new_with_name(DEFAULT_THREADS, name.clone()));
        }
        self.pools.get_mut(name).unwrap()
    }
}