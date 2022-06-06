use std::collections::HashMap;
use std::thread;

use std::io::prelude::*;

use std::sync::Arc;
use td_rthreadpool::ReentrantMutex;
use tiny_http::{Server, Response, Request};
use {ThreadUtils, LuaEngine, TimeUtils};


#[allow(dead_code)]
struct ServerRequest {
    request: Request,
    time: u64,
}

impl ServerRequest {
    pub fn new(request: Request) -> ServerRequest {
        ServerRequest {
            request: request,
            time: TimeUtils::get_time_ms(),
        }
    }
}

pub struct HttpMgr {
    requests: HashMap<u32, ServerRequest>,
    mutex: Arc<ReentrantMutex<u32>>,
}

static HTTP_POOL_NAME: &'static str = "http";
static mut EL: *mut HttpMgr = 0 as *mut _;
impl HttpMgr {
    pub fn instance() -> &'static mut HttpMgr {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(HttpMgr::new()));
            }
            &mut *EL
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
        let mut headers = HashMap::new();
        for it in request.headers() {
            headers.insert(it.field.as_str().to_string(), it.value.as_str().to_string());
        }

        let _ = request.as_reader().read_to_string(&mut body);
        LuaEngine::instance().apply_http_callback_func(request.method().as_str().to_string(), headers, vec![
                        data.to_string(),
                        request.url().to_string(),
                        body,
                        format!("{}", request.remote_addr())
                    ]);
        
        // ("http_server_msg_recv".to_string(),
        //                                       vec![data.to_string(),
        //                                            request.url().to_string(),
        //                                            headers,
        //                                            body,
        //                                            format!("{}", request.remote_addr())]);
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
                    vec![failed_cookie.to_string(), "0".to_string()]
                    );
            };

            let url = format!("http://{}{}", addr, url);
            let mut resp = unwrap_or!(reqwest::blocking::get(url).ok(), return failed_fn());

            let mut body = vec![];
            unwrap_or!(resp.read_to_end(&mut body).ok(), return failed_fn());
            trace!("{}", String::from_utf8_lossy(&body[..]));
            let status_code: u16 = resp.status().as_u16();
            LuaEngine::instance().apply_args_func(
                "http_client_msg_respone".to_string(),
                vec![cookie.to_string(), status_code.to_string(), String::from_utf8_lossy(&body[..]).to_string()]);
        });
    }

    pub fn http_post_request(&mut self, cookie: u32, addr: String, url: String, body: String) {
        let pool = ThreadUtils::instance().get_pool(&HTTP_POOL_NAME.to_string());
        pool.execute(move || {
            let failed_cookie = cookie;
            let failed_fn = move || {
                LuaEngine::instance().apply_args_func(
                    "http_client_msg_respone".to_string(),
                    vec![failed_cookie.to_string(), "0".to_string()]
                    );
            };


            let url = format!("http://{}{}", addr, url);
            let client = reqwest::blocking::Client::new();
            let mut res = unwrap_or!(client.post(url)
                .body(body)
                .send().ok(), return failed_fn());

            let mut body = vec![];
            unwrap_or!(res.read_to_end(&mut body).ok(), return failed_fn());
            trace!("{}", String::from_utf8_lossy(&body[..]));
            let status_code: u16 = res.status().as_u16();
            LuaEngine::instance().apply_args_func(
                "http_client_msg_respone".to_string(),
                vec![cookie.to_string(), status_code.to_string(), String::from_utf8_lossy(&body[..]).to_string()]);
        });
    }

    // pub fn http_get_request(&mut self, cookie: u32, addr: String, url: String) {
    //     let pool = ThreadUtils::instance().get_pool(&HTTP_POOL_NAME.to_string());
    //     pool.execute(move || {
    //         let failed_cookie = cookie;
    //         let failed_fn = move || {
    //             LuaEngine::instance().apply_args_func(
    //                 "http_client_msg_respone".to_string(),
    //                 vec![failed_cookie.to_string(), 0.to_string()]
    //                 );
    //         };

    //         let mut stream = unwrap_or!(TcpStream::connect(&*addr).ok(), {failed_fn(); return} );
    //         let content = format!("GET {} HTTP/1.1\r\nContent-Type: text/plain; charset=utf8\r\n", url);
    //         unwrap_or!(stream.write(content.as_bytes()).ok(), return failed_fn());

    //         let ip_port: Vec<&str> = addr.split(':').collect();
    //         let host = if ip_port.len() == 0 { &*addr } else { ip_port[0] };
    //         let content = format!("Host: {}\r\nContent-Length: {}\r\n\r\n{}", host, url.len(), url);
    //         unwrap_or!(stream.write(content.as_bytes()).ok(), return failed_fn());
    //         unwrap_or!(stream.flush().ok(), return failed_fn());

    //         let mut result : Vec<u8> = vec![];
    //         let mut bytes = [0u8; 1024];
    //         let mut content_length = 0;
    //         let mut header_len = 0;
    //         let mut status_code: u16 = 200;
    //         loop {
    //             let size = unwrap_or!(stream.read(&mut bytes).ok(), return failed_fn());
    //             if size == 0 {
    //                 break;
    //             }

    //             if content_length == 0 {
    //                 let content = String::from_utf8_lossy(&result);
    //                 if let Some(_) = content.find("\r\n\r\n") {
    //                     let header_content: Vec<&str> = content.split("\r\n\r\n").collect();
    //                     header_len = header_content[0].len() + 4;
    //                     let header_str : Vec<&str> = header_content[0].split("\r\n").collect();
    //                     for it in header_str {
    //                         let values: Vec<&str> = it.split(": ").collect();
    //                         if values.len() > 1 && values[0] == "Content-Length" {
    //                             content_length = unwrap_or!(values[1].parse::<usize>().ok(), return failed_fn());
    //                         }
    //                     }
    //                     if content_length == 0 {
    //                         break;
    //                     }
    //                 }
    //             }
    //             result.extend_from_slice(&bytes[..size]);
    //             if content_length + header_len >= result.len() {
    //                 break;
    //             }
    //         }
    //         if content_length == 0 {
    //             return failed_fn();
    //         }
    //         LuaEngine::instance().apply_args_func(
    //             "http_client_msg_respone".to_string(),
    //             vec![cookie.to_string(), status_code.to_string(), String::from_utf8_lossy(&result).to_string()]);
    //     });
    // }

    // pub fn http_post_request(&mut self, cookie: u32, addr: String, url: String, body: String) {
    //     let pool = ThreadUtils::instance().get_pool(&HTTP_POOL_NAME.to_string());
    //     pool.execute(move || {
    //         let failed_cookie = cookie;
    //         let failed_fn = move || {
    //             LuaEngine::instance().apply_args_func(
    //                 "http_client_msg_respone".to_string(),
    //                 vec![failed_cookie.to_string(), "false".to_string()]
    //                 );
    //         };

    //         let mut stream = unwrap_or!(TcpStream::connect(&*addr).ok(), {failed_fn(); return} );
    //         let content = format!("POST {} HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\n", url);
    //         println!("content {:?}", content);
    //         unwrap_or!(stream.write(content.as_bytes()).ok(), return failed_fn());

    //         let ip_port: Vec<&str> = addr.split(':').collect();
    //         let host = if ip_port.len() == 0 { &*addr } else { ip_port[0] };
    //         let content = format!("Host: {}\r\nContent-Length: {}\r\n\r\n", host, body.len());
    //         unwrap_or!(stream.write(content.as_bytes()).ok(), return failed_fn());
    //         unwrap_or!(stream.write(body.as_bytes()).ok(), return failed_fn());
    //         unwrap_or!(stream.write(b"\r\n\r\n").ok(), return failed_fn());
    //         unwrap_or!(stream.flush().ok(), return failed_fn());

    //         let mut result : Vec<u8> = vec![];
    //         let mut bytes = [0u8; 1024];
    //         let mut content_length = 0;
    //         let mut header_len = 0;
    //         let mut status_code: u16 = 200;
    //         loop {
    //             let size = unwrap_or!(stream.read(&mut bytes).ok(), return failed_fn());
    //             println!("read size is {:?}", size);
    //             if size == 0 {
    //                 break;
    //             }

    //             if content_length == 0 {
    //                 let content = String::from_utf8_lossy(&result);
    //                 if let Some(_) = content.find("\r\n\r\n") {
    //                     let header_content: Vec<&str> = content.split("\r\n\r\n").collect();
    //                     header_len = header_content[0].len() + 4;
    //                     let header_str : Vec<&str> = header_content[0].split("\r\n").collect();
    //                     for it in header_str {
    //                         let values: Vec<&str> = it.split(": ").collect();
    //                         if values.len() > 1 && values[0] == "Content-Length" {
    //                             content_length = unwrap_or!(values[1].parse::<usize>().ok(), return failed_fn());
    //                         }
    //                     }
    //                     if content_length == 0 {
    //                         break;
    //                     }
    //                 }
    //             }
    //             result.extend_from_slice(&bytes[..size]);
    //             if content_length + header_len <= result.len() {
    //                 break;
    //             }
    //         }
    //         if content_length == 0 {
    //             return failed_fn();
    //         }
    //         println!("result {:?}", String::from_utf8_lossy(&result));
    //         LuaEngine::instance().apply_args_func(
    //             "http_client_msg_respone".to_string(),
    //             vec![cookie.to_string(), status_code.to_string(), String::from_utf8_lossy(&result).to_string()]);
    //     });
    // }

    pub fn start_listen(&mut self, url: String) -> bool {
        thread::spawn(move || {
            let server = Server::http(&*url).unwrap();

            for request in server.incoming_requests() {
                trace!("received request! method: {:?}, url: {:?}, headers: {:?}",
                         request.method(),
                         request.url(),
                         request.headers());

                HttpMgr::instance().new_request_receive(request);
            }
        });
        true
    }
}
