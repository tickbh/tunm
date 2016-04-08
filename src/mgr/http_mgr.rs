use std::collections::HashMap;
use std::thread;
use std::net::TcpStream;

use std::io::prelude::*;
use time;
use std::sync::Arc;
use td_rthreadpool::ReentrantMutex;
use tiny_http::{Server, Response, Request};
use {ThreadUtils, LuaEngine};

#[allow(dead_code)]
struct ServerRequest {
    request: Request,
    time: u32,
}

impl ServerRequest {
    pub fn new(request: Request) -> ServerRequest {
        ServerRequest {
            request: request,
            time: (time::precise_time_ns() / 1_000_000) as u32,
        }
    }
}

pub struct HttpMgr {
    requests: HashMap<u32, ServerRequest>,
    mutex: Arc<ReentrantMutex<u32>>,
}

static HTTP_POOL_NAME: &'static str = "http";
static mut el: *mut HttpMgr = 0 as *mut _;
impl HttpMgr {
    pub fn instance() -> &'static mut HttpMgr {
        unsafe {
            if el == 0 as *mut _ {
                el = Box::into_raw(Box::new(HttpMgr::new()));
            }
            &mut *el
        }
    }

    pub fn new() -> HttpMgr {
        ThreadUtils::instance().create_pool(HTTP_POOL_NAME.to_string(), 10);
        HttpMgr {
            requests: HashMap::new(),
            mutex: Arc::new(ReentrantMutex::new(0)),
        }
    }

    pub fn new_request_receive(&mut self, mut request: Request) {
        let mut data = self.mutex.lock().unwrap();
        if *data > u32::max_value() - 1000 {
            *data = 0;
        }
        *data += 1;

        let mut body = String::new();
        let _ = request.as_reader().read_to_string(&mut body);
        LuaEngine::instance().apply_args_func("http_server_msg_recv".to_string(),
                                              vec![data.to_string(),
                                                   request.url().to_string(),
                                                   body,
                                                   format!("{}", request.remote_addr())]);
        self.requests.insert(*data, ServerRequest::new(request));

    }

    pub fn http_server_respone(&mut self, cookie: u32, content: String) {
        let _data = self.mutex.lock().unwrap();
        let request = unwrap_or!(self.requests.remove(&cookie), return);
        let pool = ThreadUtils::instance().get_pool(&HTTP_POOL_NAME.to_string());
        pool.execute(move || {
            let _ = request.request.respond(Response::from_string(&*content));
        });
    }

    pub fn http_get_request(&mut self, cookie: u32, addr: String, url: String) {
        let pool = ThreadUtils::instance().get_pool(&HTTP_POOL_NAME.to_string());
        pool.execute(move || {
            let failed_cookie = cookie;
            let failed_fn = move || {
                LuaEngine::instance().apply_args_func(
                    "http_client_msg_respone".to_string(),
                    vec![failed_cookie.to_string(), "false".to_string()]
                    );
            };

            let mut stream = unwrap_or!(TcpStream::connect(&*addr).ok(), {failed_fn(); return} );
            unwrap_or!(stream.write(b"GET / HTTP/1.1\r\nContent-Type: text/plain; charset=utf8\r\n").ok(), return failed_fn());
            let ip_port: Vec<&str> = addr.split(':').collect();
            let host = if ip_port.len() == 0 { &*addr } else { ip_port[0] };
            let content = format!("Host: {}\r\nContent-Length: {}\r\n\r\n{}", host, url.len(), url);
            unwrap_or!(stream.write(content.as_bytes()).ok(), return failed_fn());
            unwrap_or!(stream.flush().ok(), return failed_fn());

            let mut result : Vec<u8> = vec![];
            let mut bytes = [0u8; 1024];
            let mut content_length = 0;
            let mut header_len = 0;
            loop {
                let size = unwrap_or!(stream.read(&mut bytes).ok(), return failed_fn());
                if size == 0 {
                    break;
                }

                if content_length == 0 {
                    let content = String::from_utf8_lossy(&result);
                    if let Some(_) = content.find("\r\n\r\n") {
                        let header_content: Vec<&str> = content.split("\r\n\r\n").collect();
                        header_len = header_content[0].len() + 4;
                        let header_str : Vec<&str> = header_content[0].split("\r\n").collect();
                        for it in header_str {
                            let values: Vec<&str> = it.split(": ").collect();
                            if values.len() > 1 && values[0] == "Content-Length" {
                                content_length = unwrap_or!(values[1].parse::<usize>().ok(), return failed_fn());
                            }
                        }
                        if content_length == 0 {
                            break;
                        }
                    }
                }
                result.extend_from_slice(&bytes[..size]);
                if content_length + header_len >= result.len() {
                    break;
                }
            }
            if content_length == 0 {
                return failed_fn();
            }
            LuaEngine::instance().apply_args_func(
                "http_client_msg_respone".to_string(),
                vec![cookie.to_string(), "true".to_string(), String::from_utf8_lossy(&result).to_string()]);
        });
    }

    pub fn start_listen(&mut self, url: String) -> bool {
        thread::spawn(move || {
            let server = Server::http(&*url).unwrap();

            for request in server.incoming_requests() {
                println!("received request! method: {:?}, url: {:?}, headers: {:?}",
                         request.method(),
                         request.url(),
                         request.headers());

                HttpMgr::instance().new_request_receive(request);
            }
        });
        true
    }
}
