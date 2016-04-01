use std::io;
use std::io::prelude::*;
use std::path::{Path};
use std::env;
use std::fs::{self, File};

static mut ins : *mut FileUtils = 0 as *mut _;


pub struct FileUtils {
    search_paths : Vec<String>,
}

impl FileUtils {
    pub fn instance() -> &'static mut FileUtils {
        unsafe {
            if ins == 0 as *mut _ {
                let val = FileUtils {
                    search_paths : vec![::std::env::current_dir().unwrap().to_str().unwrap().to_string() + "/"],
                };
                ins = Box::into_raw(Box::new(val));
            }
            &mut *ins
        }
    }

    pub fn get_file_data(file_name : &str) -> io::Result<Vec<u8>> {
        let mut f = try!(File::open(file_name));
        let mut buffer = Vec::new();
        // read the whole file
        try!(f.read_to_end(&mut buffer));
        Ok(buffer)
    }

    pub fn get_file_str(file_name : &str) -> Option<String> {
        let data = unwrap_or!(FileUtils::get_file_data(file_name).ok(), return None);
        let data = unwrap_or!(String::from_utf8(data).ok(), return None);
        return Some(data);
    }

    pub fn is_absolute_path(path : &str) -> bool {
        Path::new(path).is_absolute()
    }

    pub fn is_file_exists(file_name : &str) -> bool {
        Path::new(file_name).exists()
    }

    pub fn set_work_path(path : &str) -> bool {
        let root = Path::new(path);
        env::set_current_dir(&root).is_ok()
    }

    pub fn get_work_path() -> String {
        let p = env::current_dir().unwrap();
        p.to_str().unwrap().to_string()
    }

    pub fn full_path_for_name(&self, name : &str) -> Option<String> {
        if Path::new(name).exists() {
            return Some(name.to_string());
        }
        for path in &self.search_paths {
            let new_path = path.clone() + name;
            if Path::new(&*new_path).exists() {
                return Some(new_path);
            }
        }
        None
    }

    pub fn add_search_path(&mut self, path : &str) {
        let path = path.trim_matches('\"');
        self.search_paths.push(path.to_string());
    }

    pub fn list_files(dir : &Path, files : &mut Vec<String>, deep : bool) -> io::Result<()> {
        if try!(fs::metadata(dir)).is_dir() {
            for entry in try!(fs::read_dir(dir)) {
                let entry = try!(entry);
                if try!(fs::metadata(entry.path())).is_dir() {
                    if deep {
                        let _ = Self::list_files(&entry.path(), files, deep);
                    }
                } else {
                    files.push(entry.path().to_str().unwrap().to_string());
                }
            }
        }
        Ok(())
    }

}