use td_rp::Config;
use FileUtils;

static mut EL: *mut Config = 0 as *mut _;

pub struct NetConfig;

impl NetConfig {
    pub fn instance() -> &'static mut Config {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(Config::new_empty()));
            }
            &mut *EL
        }
    }

    pub fn change_instance(field: &str, proto: &str) -> bool {
        let config = unwrap_or!(Config::new(field, proto), return false);
        unsafe {
            // for memory leak avoid multi thread use
            // if EL != 0 as *mut _ {
            //     let old = Box::from_raw(EL);
            //     drop(old);
            // }
            EL = Box::into_raw(Box::new(config));
        }
        true
    }

    pub fn change_by_file(file_name: &str) -> bool {
        if let Ok(file_data) = FileUtils::get_file_data(file_name) {
            let file_data = unwrap_or!(String::from_utf8(file_data).ok(), return false);
            let config = unwrap_or!(Config::new_by_full_str(&*file_data), return false);
            unsafe {
                // for memory leak avoid multi thread use
                // if EL != 0 as *mut _ {
                //     let old = Box::from_raw(EL);
                //     drop(old);
                // }
                EL = Box::into_raw(Box::new(config));
            }
            return true;
        }
        false
    }
}
