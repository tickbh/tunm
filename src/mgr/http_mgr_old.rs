// use std::collections::HashMap;
// use std::thread;
// use std::net::TcpStream;

// use td_rp::Buffer;

// use std;
// use std::io::prelude::*;
// use time;

// use std::env;
// use std::io;
// use std::sync::mpsc;
// use std::time::Duration;
// use std::sync::Arc;
// use td_rthreadpool::ReentrantMutex;
// use tiny_http::{Server, Response, Request};
// use {ThreadUtils, LuaEngine};

// use hyper;
// use hyper::client::{self, Handler, HttpConnector};
// use hyper::{Url, Method, StatusCode, Next, Encoder, Decoder, Control};
// use hyper::header::Headers;
// use hyper::net::HttpStream;

// #[derive(Debug)]
// struct ClientHandler {
//     opts: Opts,
//     tx: mpsc::Sender<Msg>,
//     body_len: u64,
//     buffer: Buffer,
// }

// impl ClientHandler {
//     fn new(opts: Opts) -> (ClientHandler, mpsc::Receiver<Msg>) {
//         let (tx, rx) = mpsc::channel();
//         (ClientHandler {
//             opts: opts,
//             tx: tx,
//             body_len: 0,
//             buffer: Buffer::new(),
//         }, rx)
//     }
// }

// #[derive(Debug)]
// enum Msg {
//     Head(client::Response),
//     Chunk(Vec<u8>),
//     Error(hyper::Error),
// }

// fn read(opts: &Opts) -> Next {
//     println!("read timeout = {:?}", opts.read_timeout);
//     if let Some(timeout) = opts.read_timeout {
//         Next::read().timeout(timeout)
//     } else {
//         Next::read()
//     }
// }

// fn write(opts: &Opts) -> Next {
//     println!("write timeout = {:?}", opts.read_timeout);
//     if let Some(timeout) = opts.read_timeout {
//         Next::write().timeout(timeout)
//     } else {
//         Next::write()
//     }
// }


// impl Handler<HttpStream> for ClientHandler {
//     fn on_request(&mut self, req: &mut client::Request) -> Next {
//         println!("on_request!!!!!!!!");
//         req.set_method(self.opts.method.clone());
//         req.headers_mut().extend(self.opts.headers.iter());
//         if self.opts.body.is_some() {
//             write(&self.opts)
//         } else {
//             read(&self.opts)
//         }
//     }

//     fn on_request_writable(&mut self, encoder: &mut Encoder<HttpStream>) -> Next {
//         println!("on_request_writable!!!!!!!!");
//         let mut is_write_all = true;
//         if let Some(ref mut body) = self.opts.body {
//             let n = encoder.write(&body[..]).unwrap();
//             body.drain(..n);
//             if !body.is_empty() {
//                 is_write_all = false;
//             }
//         }
//         if !is_write_all {
//             return write(&self.opts)
//         }
//         encoder.close();
//         println!("on write ended!!!!!!!!");
//         read(&self.opts)
//     }

//     fn on_response(&mut self, res: client::Response) -> Next {
//         println!("on_response!!!!!!!!");
//         use hyper::header;
//         // server responses can include a body until eof, if not size is specified
//         let mut has_body = true;
//         if let Some(len) = res.headers().get::<header::ContentLength>() {
//             self.body_len = **len;
//             if **len == 0 {
//                 has_body = false;
//             }
//         }
//         self.tx.send(Msg::Head(res)).unwrap();
//         if has_body {
//             read(&self.opts)
//         } else {
//             self.tx.send(Msg::Chunk(Vec::new())).unwrap();
//             Next::end()
//         }
//     }

//     fn on_response_readable(&mut self, decoder: &mut Decoder<HttpStream>) -> Next {
//         println!("on_response_readable!!!!!!!!");
//         let mut v = vec![0; 512];
//         match decoder.read(&mut v) {
//             Ok(n) => {
//                 if n == 0 {
//                     self.tx.send(Msg::Error(hyper::Error::TooLarge)).unwrap();
//                     return Next::end()
//                 }
//                 v.truncate(n);
//                 self.buffer.write(&v[..]);
//                 if self.buffer.len() > self.body_len as usize {
//                     self.tx.send(Msg::Error(hyper::Error::TooLarge)).unwrap();
//                     Next::end()
//                 } else if self.buffer.len() == self.body_len as usize {
//                     self.tx.send(Msg::Chunk(self.buffer.get_data().clone())).unwrap();
//                     Next::end()
//                 } else {
//                     read(&self.opts)
//                 }
//             },
//             Err(e) => {
//                 match e.kind() {
//                 io::ErrorKind::WouldBlock => read(&self.opts),
//                 _ => {
//                     self.tx.send(Msg::Error(hyper::Error::TooLarge)).unwrap();
//                     Next::end()
//                 }
//             }
//             }
//         }
//     }

//     fn on_error(&mut self, err: hyper::Error) -> Next {
//         println!("on_error!!!!!!!!!!!");
//         self.tx.send(Msg::Error(err)).unwrap();
//         Next::remove()
//     }

//     /// This event occurs when this Handler has requested to remove the Transport.
//     fn on_remove(self, _transport: HttpStream) {
//         println!("default Handler.on_remove");
//     }

//     /// Receive a `Control` to manage waiting for this request.
//     fn on_control(&mut self, control: Control) {
//         println!("default Handler.on_control() {:?}", control);
//     }
// }

// struct Client {
//     pub client: Option<hyper::Client<ClientHandler>>,
// }

// #[derive(Debug)]
// struct Opts {
//     body: Option<Vec<u8>>,
//     method: Method,
//     headers: Headers,
//     read_timeout: Option<Duration>,
// }

// impl Default for Opts {
//     fn default() -> Opts {
//         Opts {
//             body: None,
//             method: Method::Get,
//             headers: Headers::new(),
//             read_timeout: None,
//         }
//     }
// }

// fn opts() -> Opts {
//     Opts::default()
// }

// impl Opts {
//     fn method(mut self, method: Method) -> Opts {
//         self.method = method;
//         self
//     }

//     fn header<H: ::hyper::header::Header>(mut self, header: H) -> Opts {
//         self.headers.set(header);
//         self
//     }

//     fn body(mut self, body: Option<Vec<u8>>) -> Opts {
//         self.body = body;
//         self
//     }

//     fn read_timeout(mut self, timeout: Duration) -> Opts {
//         self.read_timeout = Some(timeout);
//         self
//     }
// }

// impl Client {
//     fn request<U>(&self, url: U, opts: Opts) -> mpsc::Receiver<Msg>
//     where U: AsRef<str> {
//         let (handler, rx) = ClientHandler::new(opts);
//         self.client.as_ref().unwrap()
//             .request(url.as_ref().parse().unwrap(), handler).unwrap();
//         rx
//     }
// }

// impl Drop for Client {
//     fn drop(&mut self) {
//         self.client.take().map(|c| c.close());
//     }
// }

// fn client() -> Client {
//     let c = hyper::Client::<ClientHandler>::configure()
//         .connector(HttpConnector::default())
//         .build().unwrap();
//     Client {
//         client: Some(c),
//     }
// }

// #[allow(dead_code)]
// struct ServerRequest {
//     request: Request,
//     time: u32,
// }

// impl ServerRequest {
//     pub fn new(request: Request) -> ServerRequest {
//         ServerRequest {
//             request: request,
//             time: (time::precise_time_ns() / 1_000_000) as u32,
//         }
//     }
// }

// pub struct HttpMgr {
//     requests: HashMap<u32, ServerRequest>,
//     mutex: Arc<ReentrantMutex<u32>>,
// }

// static HTTP_POOL_NAME: &'static str = "http";
// static mut el: *mut HttpMgr = 0 as *mut _;
// impl HttpMgr {
//     pub fn instance() -> &'static mut HttpMgr {
//         unsafe {
//             if el == 0 as *mut _ {
//                 el = Box::into_raw(Box::new(HttpMgr::new()));
//             }
//             &mut *el
//         }
//     }

//     pub fn new() -> HttpMgr {
//         ThreadUtils::instance().create_pool(HTTP_POOL_NAME.to_string(), 10);
//         HttpMgr {
//             requests: HashMap::new(),
//             mutex: Arc::new(ReentrantMutex::new(0)),
//         }
//     }

//     pub fn new_request_receive(&mut self, mut request: Request) {
//         let mut data = self.mutex.lock().unwrap();
//         if *data > u32::max_value() - 1000 {
//             *data = 0;
//         }
//         *data += 1;

//         let mut body = String::new();
//         let _ = request.as_reader().read_to_string(&mut body);
//         LuaEngine::instance().apply_args_func("http_server_msg_recv".to_string(),
//                                               vec![data.to_string(),
//                                                    request.url().to_string(),
//                                                    body,
//                                                    format!("{}", request.remote_addr())]);
//         self.requests.insert(*data, ServerRequest::new(request));

//     }

//     pub fn http_server_respone(&mut self, cookie: u32, content: String) {
//         let _data = self.mutex.lock().unwrap();
//         let request = unwrap_or!(self.requests.remove(&cookie), return);
//         let pool = ThreadUtils::instance().get_pool(&HTTP_POOL_NAME.to_string());
//         pool.execute(move || {
//             let _ = request.request.respond(Response::from_string(&*content));
//         });
//     }

//     // pub fn http_get_request(&mut self, cookie: u32, addr: String, url: String) {
//     //     let pool = ThreadUtils::instance().get_pool(&HTTP_POOL_NAME.to_string());
//     //     pool.execute(move || {
//     //         let failed_cookie = cookie;
//     //         let failed_fn = move || {
//     //             LuaEngine::instance().apply_args_func(
//     //                 "http_client_msg_respone".to_string(),
//     //                 vec![failed_cookie.to_string(), "0".to_string()]
//     //                 );
//     //         };

//     //         let client = client();
//     //         let opts = opts().method(Method::Get).read_timeout(Duration::from_secs(10));
//     //         let url : Url = unwrap_or!(format!("http://{}{}", addr, url).parse().ok(), {failed_fn(); return});
//     //         let (handler, res) = ClientHandler::new(opts);
//     //         unwrap_or!(client.client.as_ref().unwrap().request(url, handler).ok(), {failed_fn(); return});

//     //         let mut status_code: u16 = 200;
//     //         if let Msg::Head(head) = res.recv().unwrap() {
//     //             status_code = head.status().to_u16();
//     //         } else {
//     //             failed_fn(); 
//     //             return;
//     //         }

//     //         let msg_body = if let Msg::Chunk(body) = res.recv().unwrap() {
//     //             body
//     //         } else {
//     //             failed_fn(); 
//     //             return;
//     //         };

//     //         LuaEngine::instance().apply_args_func(
//     //             "http_client_msg_respone".to_string(),
//     //             vec![cookie.to_string(), status_code.to_string(), String::from_utf8_lossy(&msg_body[..]).to_string()]);
//     //     });
//     // }

//     // pub fn http_post_request(&mut self, cookie: u32, addr: String, url: String, body: String) {
//     //     use hyper::header::ContentType;
//     //     let pool = ThreadUtils::instance().get_pool(&HTTP_POOL_NAME.to_string());
//     //     pool.execute(move || {
//     //         let failed_cookie = cookie;
//     //         let failed_fn = move || {
//     //             LuaEngine::instance().apply_args_func(
//     //                 "http_client_msg_respone".to_string(),
//     //                 vec![failed_cookie.to_string(), "0".to_string()]
//     //                 );
//     //         };

//     //         let client = client();
//     //         let opts = opts().method(Method::Post).body(Some(body.into_bytes())).header(ContentType::form_url_encoded()).read_timeout(Duration::from_secs(10));;
//     //         let url : Url = unwrap_or!(format!("http://{}{}", addr, url).parse().ok(), {failed_fn(); return});
//     //         let (handler, res) = ClientHandler::new(opts);
//     //         unwrap_or!(client.client.as_ref().unwrap().request(url, handler).ok(), {failed_fn(); return});

//     //         let mut status_code: u16 = 200;
//     //         if let Msg::Head(head) = res.recv().unwrap() {
//     //             status_code = head.status().to_u16();
//     //         } else {
//     //             failed_fn(); 
//     //             return;
//     //         }

//     //         let msg_body = if let Msg::Chunk(body) = res.recv().unwrap() {
//     //             body
//     //         } else {
//     //             failed_fn(); 
//     //             return;
//     //         };

//     //         LuaEngine::instance().apply_args_func(
//     //             "http_client_msg_respone".to_string(),
//     //             vec![cookie.to_string(), status_code.to_string(), String::from_utf8_lossy(&msg_body[..]).to_string()]);
//     //     });
//     // }

//     pub fn http_get_request(&mut self, cookie: u32, addr: String, url: String) {
//         let pool = ThreadUtils::instance().get_pool(&HTTP_POOL_NAME.to_string());
//         pool.execute(move || {
//             let failed_cookie = cookie;
//             let failed_fn = move || {
//                 LuaEngine::instance().apply_args_func(
//                     "http_client_msg_respone".to_string(),
//                     vec![failed_cookie.to_string(), 0.to_string()]
//                     );
//             };

//             let mut stream = unwrap_or!(TcpStream::connect(&*addr).ok(), {failed_fn(); return} );
//             let content = format!("GET {} HTTP/1.1\r\nContent-Type: text/plain; charset=utf8\r\n", url);
//             unwrap_or!(stream.write(content.as_bytes()).ok(), return failed_fn());

//             let ip_port: Vec<&str> = addr.split(':').collect();
//             let host = if ip_port.len() == 0 { &*addr } else { ip_port[0] };
//             let content = format!("Host: {}\r\nContent-Length: {}\r\n\r\n{}", host, url.len(), url);
//             unwrap_or!(stream.write(content.as_bytes()).ok(), return failed_fn());
//             unwrap_or!(stream.flush().ok(), return failed_fn());

//             let mut result : Vec<u8> = vec![];
//             let mut bytes = [0u8; 1024];
//             let mut content_length = 0;
//             let mut header_len = 0;
//             let mut status_code: u16 = 200;
//             loop {
//                 let size = unwrap_or!(stream.read(&mut bytes).ok(), return failed_fn());
//                 if size == 0 {
//                     break;
//                 }

//                 if content_length == 0 {
//                     let content = String::from_utf8_lossy(&result);
//                     if let Some(_) = content.find("\r\n\r\n") {
//                         let header_content: Vec<&str> = content.split("\r\n\r\n").collect();
//                         header_len = header_content[0].len() + 4;
//                         let header_str : Vec<&str> = header_content[0].split("\r\n").collect();
//                         for it in header_str {
//                             let values: Vec<&str> = it.split(": ").collect();
//                             if values.len() > 1 && values[0] == "Content-Length" {
//                                 content_length = unwrap_or!(values[1].parse::<usize>().ok(), return failed_fn());
//                             }
//                         }
//                         if content_length == 0 {
//                             break;
//                         }
//                     }
//                 }
//                 result.extend_from_slice(&bytes[..size]);
//                 if content_length + header_len >= result.len() {
//                     break;
//                 }
//             }
//             if content_length == 0 {
//                 return failed_fn();
//             }
//             LuaEngine::instance().apply_args_func(
//                 "http_client_msg_respone".to_string(),
//                 vec![cookie.to_string(), status_code.to_string(), String::from_utf8_lossy(&result).to_string()]);
//         });
//     }

//     pub fn http_post_request(&mut self, cookie: u32, addr: String, url: String, body: String) {
//         let pool = ThreadUtils::instance().get_pool(&HTTP_POOL_NAME.to_string());
//         pool.execute(move || {
//             let failed_cookie = cookie;
//             let failed_fn = move || {
//                 LuaEngine::instance().apply_args_func(
//                     "http_client_msg_respone".to_string(),
//                     vec![failed_cookie.to_string(), "false".to_string()]
//                     );
//             };

//             let mut stream = unwrap_or!(TcpStream::connect(&*addr).ok(), {failed_fn(); return} );
//             let content = format!("POST {} HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\n", url);
//             println!("content {:?}", content);
//             unwrap_or!(stream.write(content.as_bytes()).ok(), return failed_fn());

//             let ip_port: Vec<&str> = addr.split(':').collect();
//             let host = if ip_port.len() == 0 { &*addr } else { ip_port[0] };
//             let content = format!("Host: {}\r\nContent-Length: {}\r\n\r\n", host, body.len());
//             unwrap_or!(stream.write(content.as_bytes()).ok(), return failed_fn());
//             unwrap_or!(stream.write(body.as_bytes()).ok(), return failed_fn());
//             unwrap_or!(stream.write(b"\r\n\r\n").ok(), return failed_fn());
//             unwrap_or!(stream.flush().ok(), return failed_fn());

//             let mut result : Vec<u8> = vec![];
//             let mut bytes = [0u8; 1024];
//             let mut content_length = 0;
//             let mut header_len = 0;
//             let mut status_code: u16 = 200;
//             loop {
//                 let size = unwrap_or!(stream.read(&mut bytes).ok(), return failed_fn());
//                 println!("read size is {:?}", size);
//                 if size == 0 {
//                     break;
//                 }

//                 if content_length == 0 {
//                     let content = String::from_utf8_lossy(&result);
//                     if let Some(_) = content.find("\r\n\r\n") {
//                         let header_content: Vec<&str> = content.split("\r\n\r\n").collect();
//                         header_len = header_content[0].len() + 4;
//                         let header_str : Vec<&str> = header_content[0].split("\r\n").collect();
//                         for it in header_str {
//                             let values: Vec<&str> = it.split(": ").collect();
//                             if values.len() > 1 && values[0] == "Content-Length" {
//                                 content_length = unwrap_or!(values[1].parse::<usize>().ok(), return failed_fn());
//                             }
//                         }
//                         if content_length == 0 {
//                             break;
//                         }
//                     }
//                 }
//                 result.extend_from_slice(&bytes[..size]);
//                 if content_length + header_len <= result.len() {
//                     break;
//                 }
//             }
//             if content_length == 0 {
//                 return failed_fn();
//             }
//             println!("result {:?}", String::from_utf8_lossy(&result));
//             LuaEngine::instance().apply_args_func(
//                 "http_client_msg_respone".to_string(),
//                 vec![cookie.to_string(), status_code.to_string(), String::from_utf8_lossy(&result).to_string()]);
//         });
//     }

//     pub fn start_listen(&mut self, url: String, port: u16) -> bool {
//         thread::spawn(move || {
//             let server = Server::http(&*url).unwrap();

//             for request in server.incoming_requests() {
//                 println!("received request! method: {:?}, url: {:?}, headers: {:?}",
//                          request.method(),
//                          request.url(),
//                          request.headers());

//                 HttpMgr::instance().new_request_receive(request);
//             }
//         });
//         true
//     }
// }
