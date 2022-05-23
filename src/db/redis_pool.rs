use std::net::TcpStream;

use td_rredis::{Cluster, PubSub, Msg};
use std::sync::mpsc::{channel, Receiver};

#[cfg(unix)]
use std::os::unix::io::{FromRawFd, RawFd};
#[cfg(windows)]
use std::os::windows::io::{FromRawSocket, RawSocket};

use std::sync::{Arc, Mutex};
use ThreadUtils;
static REDIS_SUB_POOL_NAME: &'static str = "redis_sub";
/// redis pool store redis info and redis connection and a subscribe redis connection
pub struct RedisPool {
    pub db_redis: Vec<Cluster>,
    pub url_list: Vec<String>,
    pub mutex: Mutex<i32>,

    pub sub_fd: i32,
    pub sub_connect: Option<PubSub>,
    pub sub_receiver: Option<Mutex<Receiver<Msg>>>,
    pub sub_thread_run: Option<Arc<Mutex<bool>>>,
}

static mut EL: *mut RedisPool = 0 as *mut _;

impl RedisPool {
    pub fn new() -> RedisPool {
        RedisPool {
            db_redis: Vec::new(),
            url_list: Vec::new(),
            mutex: Mutex::new(0),

            sub_fd: 0,
            sub_connect: None,
            sub_receiver: None,
            sub_thread_run: None,
        }
    }

    pub fn instance() -> &'static mut RedisPool {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(RedisPool::new()));
            }
            &mut *EL
        }
    }

    fn init_connection(&self) -> Cluster {
        let mut cluster = Cluster::new();
        for url in &self.url_list {
            let _ = cluster.add(&*url);
        }
        cluster
    }

    pub fn set_url_list(&mut self, url_list: Vec<String>) -> bool {
        self.url_list = url_list;
        true
    }

    pub fn get_redis_connection(&mut self) -> Option<Cluster> {
        let _guard = self.mutex.lock().unwrap();
        if self.db_redis.is_empty() {
            return Some(self.init_connection());
        }
        self.db_redis.pop()
    }

    pub fn release_redis_connection(&mut self, cluster: Cluster) {
        let _guard = self.mutex.lock().unwrap();
        self.db_redis.push(cluster);
    }

    pub fn is_sub_work(&self) -> bool {
        if self.sub_thread_run.is_some() && *self.sub_thread_run.as_ref().unwrap().lock().unwrap() {
            return true;
        }
        false
    }

    #[cfg(unix)]
    fn drop_fd(fd: i32) {
        unsafe {
            drop(TcpStream::from_raw_fd(fd as RawFd));
        }
    }

    
    #[cfg(windows)]
    fn drop_fd(fd: i32) {
        unsafe {
            drop(TcpStream::from_raw_socket(fd as RawSocket));
        }

    }

    pub fn get_sub_connection(&mut self) -> Option<&mut PubSub> {
        // if self.is_sub_work() {
        //     return self.sub_connect.as_mut();
        // }
        // becuase no support noblock recv msg
        // so if start recv thread, the connect is move to thread
        // so we can't change in other thread
        self.stop_recv_sub_msg();
        let mut new_fd = 0;
        loop {
            if self.sub_connect.is_none() || !self.sub_connect.as_ref().unwrap().is_work() {
                let cluster = self.init_connection();
                let pubsub = unwrap_or!(cluster.get_pubsub().ok(), break);
                new_fd = pubsub.get_connection_fd();
                self.sub_connect = Some(pubsub);
            }
            break;
        }
        if new_fd != 0 {
            if self.sub_fd != 0 {
                if cfg!(unix) {
                    Self::drop_fd(self.sub_fd);
                } else {
                    Self::drop_fd(self.sub_fd);
                }
            }
            self.sub_fd = new_fd;
        }
        self.sub_connect.as_mut()
    }

    pub fn get_sub_receiver(&mut self) -> Option<&mut Mutex<Receiver<Msg>>> {
        self.sub_receiver.as_mut()
    }

    pub fn stop_recv_sub_msg(&mut self) -> bool {
        // already run sub thread
        if self.sub_thread_run.is_some() {
            *self.sub_thread_run.as_mut().unwrap().lock().unwrap() = false;
            self.sub_connect = None;
            self.sub_receiver = None;
            self.sub_thread_run = None;
            return true;
        }
        false
    }

    pub fn ensure_subconnectioin(&mut self) -> bool {
        if self.is_sub_work() {
            return true;
        }
        self.stop_recv_sub_msg();
        self.get_sub_connection();
        self.start_recv_sub_msg();
        true
    }

    // run in thread
    pub fn start_recv_sub_msg(&mut self) {
        if self.is_sub_work() {
            return;
        }

        if self.sub_connect.is_none() {
            return;
        }

        let sub_connect = self.sub_connect.take().unwrap();
        let (sub_sender, sub_receiver) = channel();
        let thread_run = Arc::new(Mutex::new(true));

        self.sub_receiver = Some(Mutex::new(sub_receiver));
        self.sub_thread_run = Some(thread_run.clone());

        let pool = ThreadUtils::instance().get_pool(&REDIS_SUB_POOL_NAME.to_string());
        pool.execute(move || {
            loop {
                
                let result = unwrap_or!(sub_connect.get_message().ok(), {
                    *thread_run.lock().unwrap() = false;
                    println!("Recv Message Error, Lose Redis Sub Connection");
                    break;
                });
                let _ = sub_sender.send(result);
                if *thread_run.lock().unwrap() == false {
                    break;
                }
            }
        });
    }
}
