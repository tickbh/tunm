use std::net::{TcpStream, TcpListener};
use std::collections::HashMap;
use std::mem;
use std::io::{Read, Write};

use net2;
use td_revent::*;

use {EventMgr, LuaEngine};

const BS: u8 = 8u8;
const SP: u8 = 32u8;


#[derive(Debug)]
pub struct ClientInfo {
    pub tcp: TcpStream,
    pub data: Vec<u8>,
    pub ipos: usize,
    pub records: Vec<Vec<u8>>,
    pub blogin: bool,
    pub benterpwd: bool,
    pub binsert: bool,
    pub ircdnum: i32,
}

impl ClientInfo {
    pub fn new(tcp: TcpStream) -> ClientInfo {
        ClientInfo {
            tcp: tcp,
            data: vec![],
            ipos: 0,
            records: vec![],
            blogin: false,
            benterpwd: false,
            binsert: false,
            ircdnum: 0,
        }
    }
}
#[derive(Debug)]
pub struct TelnetUtils {
    clients: HashMap<i32, ClientInfo>,
    tcp_listener: Option<TcpListener>,
    listen_fd: i32,
    prompt: String,
}

static mut el: *mut TelnetUtils = 0 as *mut _;
impl TelnetUtils {
    pub fn instance() -> &'static mut TelnetUtils {
        unsafe {
            if el == 0 as *mut _ {
                el = Box::into_raw(Box::new(TelnetUtils::new()));
            }
            &mut *el
        }
    }

    pub fn new() -> TelnetUtils {
        TelnetUtils {
            clients: HashMap::new(),
            tcp_listener: None,
            listen_fd: 0,
            prompt: "telnet>".to_string(),
        }
    }

    pub fn new_message(&mut self, msg: String) {
        let vbs = vec![BS; self.prompt.len() + 1];
        for (_, client) in self.clients.iter_mut() {
            if client.blogin {
                let _ = client.tcp.write(&vbs);
                let _ = client.tcp.write(b"\r\x1b[K");
                let _ = client.tcp.write(msg.as_bytes());
                let _ = client.tcp.write(b"\r\n");
                let _ = client.tcp.write(self.prompt.as_bytes());
            }
        }
    }

    pub fn remove_client(&mut self, fd: i32) {
        self.clients.remove(&fd);
    }

    pub fn send(&mut self, fd: i32, data: &str) {
        let client = unwrap_or!(self.clients.get_mut(&fd), return);
        if data.len() == 0 {
            return;
        }
        let _ = client.tcp.write(data.as_bytes());
    }

    pub fn check(client: &mut ClientInfo) -> bool {
        if client.records.len() > 1 && String::from_utf8_lossy(&client.records[0]) == "td" &&
           String::from_utf8_lossy(&client.records[1]) == "td" {
            return true;
        }
        return false;
    }

    pub fn login(&mut self, fd: i32, bytes: &[u8]) {
        let client = unwrap_or!(self.clients.get_mut(&fd), return);
        for (i, b) in bytes.iter().enumerate() {
            if b == &255u8 {
                break;
            }
            // 接受到回车键，开始处理消息
            if b == &13 {
                let _ = client.tcp.write(b"\r\n");
                client.records.push(client.data.clone());
                if client.records.len() > 10 {
                    client.records.pop();
                }
                client.data.clear();
                client.ircdnum = -1;
                client.ipos = 0;

                if !client.benterpwd {
                    let _ = client.tcp.write(b"password:");
                    client.benterpwd = true;
                } else {
                    client.benterpwd = false;
                    if Self::check(client) {
                        client.blogin = true;
                        client.records.clear();
                        let _ = client.tcp.write(b"login succeed!\r\n");
                        let _ = client.tcp.write(self.prompt.as_bytes());
                    } else {
                        client.records.clear();
                        let _ = client.tcp.write(b"login failed!\r\nlogin:");
                    }
                }
                // String::from_utf8_lossy(bytes)
            }
            // 接收到退格键消息
            else if b == &8 {
                if client.ipos != 0 {
                    client.ipos -= 1;
                    client.data.pop();
                    if !client.benterpwd {
                        let _ = client.tcp.write(&[BS]);
                        let _ = client.tcp.write(&client.data[client.ipos as usize..]);
                        let _ = client.tcp.write(&[SP]);
                        for _ in 0..(client.data[client.ipos as usize..].len() + 1) {
                            let _ = client.tcp.write(&[BS]);
                        }
                    }
                }
                continue;
            }
            // \R处理完，忽略\N
            else if b == &10 {
                continue;
            }
            // 接收到TAB键消息
            else if b == &9 {
                continue;
            } else if b == &27 && (i + 1 > bytes.len() && bytes[i + 1] == 91) {
                continue;
            } else {
                // 如果当前为插入状态，将该字符插入消息字符串中
                // 并发送光标之后的内容给客户端，然后再将光标移回来
                client.data.push(*b);
                if !client.benterpwd {
                    let _ = client.tcp.write(&client.data[client.ipos as usize..]);
                    for _ in 0..(client.data[client.ipos as usize..].len() - 1) {
                        let _ = client.tcp.write(&[BS]);
                    }
                }
                client.ipos += 1;
            }
        }

    }

    pub fn update_data(&mut self, fd: i32, bytes: &[u8]) -> i32 {
        let blogin = {
            let client = unwrap_or!(self.clients.get_mut(&fd), return 1);
            client.blogin
        };
        if !blogin {
            self.login(fd, bytes);
            return 1;
        }
        let client = unwrap_or!(self.clients.get_mut(&fd), return 1);
        for (i, b) in bytes.iter().enumerate() {
            if b == &255u8 {
                break;
            }

            // 接受到回车键，开始处理消息
            if b == &13 {
                let _ = client.tcp.write(b"\r\n");

                if client.data.len() > 0 {
                    client.records.push(client.data.clone());
                    if client.records.len() > 10 {
                        client.records.pop();
                    }
                }

                let convert =
                    LuaEngine::convert_excute_string(String::from_utf8_lossy(&client.data)
                                                         .to_string());
                LuaEngine::instance().apply_exec_string(convert);
                client.data.clear();
                client.ircdnum = -1;
                client.ipos = 0;
                let _ = client.tcp.write(self.prompt.as_bytes());
                break;
            }
            // 接收到退格键消息
            else if b == &8 {
                if client.ipos != 0 {
                    client.ipos -= 1;
                    client.data.pop();
                    if !client.benterpwd {
                        let _ = client.tcp.write(&[BS]);
                        let _ = client.tcp.write(&client.data[client.ipos as usize..]);
                        let _ = client.tcp.write(&[SP]);
                        for _ in 0..(client.data[client.ipos as usize..].len() + 1) {
                            let _ = client.tcp.write(&[BS]);
                        }
                    }
                }
                continue;
            }
            // 接收到TAB键消息
            else if b == &9 {
                continue;
            }
            // 收到删除键消息
            else if b == &127 {
                if client.ipos as usize != client.data.len() {
                    let _ = client.tcp.write(&[BS]);
                    let _ = client.tcp.write(&client.data[client.ipos as usize..]);
                    let _ = client.tcp.write(&[SP]);
                    for _ in 0..(client.data[client.ipos as usize..].len() + 1) {
                        let _ = client.tcp.write(&[BS]);
                    }
                }

            }
            // 接收到方向键或插入键
            else if b == &27 && i + 1 < bytes.len() && bytes[i + 1] == 91 && i + 2 < bytes.len() {

                // 方向键向上
                if bytes[i + 2] == 65 && client.records.len() != 0 {
                    let num = client.ircdnum + 1;

                    // 先将关标移至改行开始处，然后清空，在发送上一条信息
                    if num < client.records.len() as i32 {
                        for _ in 0..client.data.len() {
                            let _ = client.tcp.write(&[BS]);
                        }
                        client.ircdnum = num;

                        client.data = client.records[client.ircdnum as usize].clone();
                        client.ipos = client.data.len();

                        // 清空光标后的字符串
                        let _ = client.tcp.write(b"\x1b[K");
                        let _ = client.tcp.write(&client.data);
                    }

                }
                // 方向键向下
                else if bytes[i + 2] == 66 && client.records.len() != 0 {
                    if client.ircdnum != -1 {
                        for _ in 0..client.data.len() {
                            let _ = client.tcp.write(&[BS]);
                        }

                        client.ircdnum -= 1;

                        // 若为最新的一行，则发送空消息
                        if client.ircdnum == -1 {
                            client.data = vec![];
                        } else {
                            client.data = client.records[client.ircdnum as usize].clone();
                        }

                        client.ipos = client.data.len();

                        // 清空光标后的字符串
                        let _ = client.tcp.write(b"\x1b[K");
                        let _ = client.tcp.write(&client.data);
                    }

                }
                // 方向键向右
                else if bytes[i + 2] == 67 && client.ipos < client.data.len() {
                    // 发送光标所处位置的字符，让光标向前一格
                    let _ = client.tcp
                                  .write(&client.data[client.ipos as usize..client.ipos as usize +
                                                                            1]);
                    client.ipos += 1;
                }
                // 方向键向左，发送退格键
                else if bytes[i + 2] == 68 && client.ipos != 0 {
                    client.ipos -= 1;
                    let _ = client.tcp.write(&[BS]);
                }
                // 接收到HOME键
                else if bytes[i + 2] == 49 && i + 3 < bytes.len() && bytes[i + 3] == 126 {

                    for _ in 0..client.data.len() {
                        let _ = client.tcp.write(&[BS]);
                    }
                    client.ipos = 0;
                }
                // 接收到插入键信息
                else if bytes[i + 2] == 50 && i + 3 < bytes.len() && bytes[i + 3] == 126 {
                    client.binsert = !client.binsert;
                }
                // 接收到end的键
                else if bytes[i + 2] == 52 && i + 3 < bytes.len() && bytes[i + 3] == 126 {
                    let steps = client.data.len() - client.ipos;
                    if steps != 0 {
                        let movecursor = format!("\x1b[{}C", steps);
                        let _ = client.tcp.write(movecursor.as_bytes());
                        client.ipos = client.data.len();
                    }
                }
                break;
            }
            // 接收到字符信息
            else {
                // 如果当前为插入状态，将该字符插入消息字符串中
                // 并发送光标之后的内容给客户端，然后再将光标移回来
                if !client.binsert {
                    client.data.insert(client.ipos, *b);
                    let _ = client.tcp.write(&client.data[client.ipos as usize..]);
                    for _ in 0..(client.data[client.ipos as usize..].len() - 1) {
                        let _ = client.tcp.write(&[BS]);
                    }
                }
                // 当前为替换状态，只需将该字符插入到消息字符串中即可
                else {
                    if client.ipos < client.data.len() {
                        client.data[client.ipos as usize] = *b;
                    } else {
                        client.data.push(*b);
                    }
                    let _ = client.tcp.write(&[*b]);
                }
                client.ipos += 1;
            }
        }
        0
    }

    fn read_callback(_: &mut EventLoop, fd: u32, _: EventFlags, _: *mut ()) -> i32 {
        let telnet = TelnetUtils::instance();
        let mut tcp = TcpStream::from_fd(fd as i32);
        let mut buffer = [0; 1024];
        let size = match tcp.read(&mut buffer) {
            Ok(size) => {
                if size == 0 {
                    telnet.remove_client(fd as i32);
                    return 0;
                }
                size
            }
            Err(_) => {
                telnet.remove_client(fd as i32);
                return 0;
            }
        };
        telnet.update_data(fd as i32, &buffer[..size]);
        mem::forget(tcp);
        0
    }

    fn accept_callback(ev: &mut EventLoop, fd: u32, _: EventFlags, _: *mut ()) -> i32 {
        println!("accept_callback {:?}", fd);
        let listener = TcpListener::from_fd(fd as i32);
        let (mut stream, _) = unwrap_or!(listener.accept().ok(), return 0);
        net2::TcpStreamExt::set_nonblocking(&stream, false).ok().unwrap();
        ev.add_event(EventEntry::new(stream.as_fd() as u32,
                                     FLAG_READ | FLAG_PERSIST,
                                     Some(Self::read_callback),
                                     None));

        {
            let _ = stream.write(b"                        ** WELCOME TO TDENGINE SERVER! **                         \n");
            let _ = stream.write(b"login:");
            // 开启单字符模式和回显
            let _ = stream.write(&[255, 251, 3]);
            let _ = stream.write(&[255, 251, 1]);
        }

        let telnet = TelnetUtils::instance();
        telnet.clients.insert(stream.as_fd() as i32, ClientInfo::new(stream));
        mem::forget(listener);
        0
    }

    pub fn listen(&mut self, addr: &str) {
        assert!(self.listen_fd == 0, "repeat listen telnet");
        let listener = TcpListener::bind(addr).unwrap();
        let fd = listener.as_fd();
        let event_loop = EventMgr::instance().get_event_loop();
        event_loop.add_event(EventEntry::new(listener.as_fd() as u32,
                                             FLAG_READ | FLAG_PERSIST,
                                             Some(Self::accept_callback),
                                             None));
        self.listen_fd = fd;
        self.tcp_listener = Some(listener);
    }
}
