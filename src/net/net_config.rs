use rt_proto::StrConfig;
use FileUtils;

static mut EL: *mut StrConfig = 0 as *mut _;

pub struct NetConfig;

impl NetConfig {
    pub fn instance() -> &'static mut StrConfig {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(StrConfig::new()));
            }
            &mut *EL
        }
    }

    // pub fn change_instance(field: &str, proto: &str) -> bool {
    //     let config = unwrap_or!(StrConfig::new(field, proto), return false);
    //     unsafe {
    //         // for memory leak avoid multi thread use
    //         // if EL != 0 as *mut _ {
    //         //     let old = Box::from_raw(EL);
    //         //     drop(old);
    //         // }
    //         EL = Box::into_raw(Box::new(config));
    //     }
    //     true
    // }

    // pub fn change_by_file(file_name: &str) -> bool {
    //     if let Ok(file_data) = FileUtils::get_file_data(file_name) {
    //         let file_data = unwrap_or!(String::from_utf8(file_data).ok(), return false);
    //         let config = unwrap_or!(StrConfig::new_by_full_str(&*file_data), return false);
    //         unsafe {
    //             // for memory leak avoid multi thread use
    //             // if EL != 0 as *mut _ {
    //             //     let old = Box::from_raw(EL);
    //             //     drop(old);
    //             // }
    //             EL = Box::into_raw(Box::new(config));
    //         }
    //         return true;
    //     }
    //     false
    // }
}
