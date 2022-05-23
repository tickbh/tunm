use std::collections::HashMap;
use std::io::{Write};
use std::any::Any;
use std::io::Result;

use mio::{Poll, Token};

use td_revent::*;

use crate::net::SocketEvent;
use {MioEventMgr, LuaEngine};

const BS: u8 = 8u8;
const SP: u8 = 32u8;


#[derive(Debug)]
pub struct ClientInfo {
    pub unique: String,
    pub data: Vec<u8>,
    pub ipos: usize,
    pub records: Vec<Vec<u8>>,
    pub blogin: bool,
    pub benterpwd: bool,
    pub binsert: bool,
    pub ircdnum: i32,
}

impl ClientInfo {
    pub fn new(unique: String) -> ClientInfo {
        ClientInfo {
            unique: unique,
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
    clients: HashMap<String, ClientInfo>,
    listen_fd: usize,
    prompt: String,
}

static mut EL: *mut TelnetUtils = 0 as *mut _;
impl TelnetUtils {
    pub fn instance() -> &'static mut TelnetUtils {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(TelnetUtils::new()));
            }
            &mut *EL
        }
    }

    pub fn new() -> TelnetUtils {
        TelnetUtils {
            clients: HashMap::new(),
            listen_fd: 0,
            prompt: "telnet>".to_string(),
        }
    }

    fn send_client_msg(unique: &String, bytes: &[u8]) {
        let _  = MioEventMgr::instance().write_to_socket(unique, bytes);
    }

    pub fn new_message(&mut self, msg: String) {
        let vbs = vec![BS; self.prompt.len() + 1];
        for (_, client) in self.clients.iter_mut() {
            if client.blogin {
                let _ = Self::send_client_msg(&client.unique, &vbs);
                let _ = Self::send_client_msg(&client.unique, b"\r\x1b[K");
                let _ = Self::send_client_msg(&client.unique, msg.as_bytes());
                let _ = Self::send_client_msg(&client.unique, b"\r\n");
                let _ = Self::send_client_msg(&client.unique, self.prompt.as_bytes());
            }
        }
    }

    pub fn remove_client(&mut self, unique: &String) {
        self.clients.remove(unique);
    }

    pub fn send(&mut self, unique: &String, data: &str) {
        let client = unwrap_or!(self.clients.get_mut(unique), return);
        if data.len() == 0 {
            return;
        }
        let _ = Self::send_client_msg(&client.unique, data.as_bytes());
    }

    pub fn check(client: &mut ClientInfo) -> bool {
        if client.records.len() > 1 && String::from_utf8_lossy(&client.records[0]) == "tunm" &&
           String::from_utf8_lossy(&client.records[1]) == "tunm" {
            return true;
        }
        return false;
    }

    pub fn login(&mut self, unique: &String, bytes: &[u8]) {
        let client = unwrap_or!(self.clients.get_mut(unique), return);
        for (i, b) in bytes.iter().enumerate() {
            if b == &255u8 {
                break;
            }
            if b == &0u8 {
                continue;
            }
            // 接受到回车键，开始处理消息
            if b == &13 {
                let _ = Self::send_client_msg(&client.unique, b"\r\n");
                client.records.push(client.data.clone());
                if client.records.len() > 10 {
                    client.records.pop();
                }
                client.data.clear();
                client.ircdnum = -1;
                client.ipos = 0;

                if !client.benterpwd {
                    let _ = Self::send_client_msg(&client.unique, b"password:");
                    client.benterpwd = true;
                } else {
                    client.benterpwd = false;
                    if Self::check(client) {
                        client.blogin = true;
                        client.records.clear();
                        let _ = Self::send_client_msg(&client.unique, b"login succeed!\r\n");
                        let _ = Self::send_client_msg(&client.unique, self.prompt.as_bytes());
                    } else {
                        client.records.clear();
                        let _ = Self::send_client_msg(&client.unique, b"login failed!\r\nlogin:");
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
                        let _ = Self::send_client_msg(&client.unique, &[BS]);
                        let _ = Self::send_client_msg(&client.unique, &client.data[client.ipos as usize..]);
                        let _ = Self::send_client_msg(&client.unique, &[SP]);
                        for _ in 0..(client.data[client.ipos as usize..].len() + 1) {
                            let _ = Self::send_client_msg(&client.unique, &[BS]);
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
                    let _ = Self::send_client_msg(&client.unique, &client.data[client.ipos as usize..]);
                    for _ in 0..(client.data[client.ipos as usize..].len() - 1) {
                        let _ = Self::send_client_msg(&client.unique, &[BS]);
                    }
                }
                client.ipos += 1;
            }
        }

    }

    pub fn update_data(&mut self, unique: &String, bytes: &[u8]) -> i32 {
        let blogin = {
            let client = unwrap_or!(self.clients.get_mut(unique), return 1);
            client.blogin
        };
        if !blogin {
            self.login(unique, bytes);
            return 1;
        }
        let client = unwrap_or!(self.clients.get_mut(unique), return 1);
        for (i, b) in bytes.iter().enumerate() {
            if b == &255u8 {
                break;
            }

            // 接受到回车键，开始处理消息
            if b == &13 {
                let _ = Self::send_client_msg(&client.unique, b"\r\n");

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
                let _ = Self::send_client_msg(&client.unique, self.prompt.as_bytes());
                break;
            }
            // 接收到退格键消息
            else if b == &8 {
                if client.ipos != 0 {
                    client.ipos -= 1;
                    client.data.pop();
                    if !client.benterpwd {
                        let _ = Self::send_client_msg(&client.unique, &[BS]);
                        let _ = Self::send_client_msg(&client.unique, &client.data[client.ipos as usize..]);
                        let _ = Self::send_client_msg(&client.unique, &[SP]);
                        for _ in 0..(client.data[client.ipos as usize..].len() + 1) {
                            let _ = Self::send_client_msg(&client.unique, &[BS]);
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
                client.ipos -= 1;
                client.data.pop();
                if !client.benterpwd {
                    let _ = Self::send_client_msg(&client.unique, &[BS]);
                    let _ = Self::send_client_msg(&client.unique, &client.data[client.ipos as usize..]);
                    let _ = Self::send_client_msg(&client.unique, &[SP]);
                    for _ in 0..(client.data[client.ipos as usize..].len() + 1) {
                        let _ = Self::send_client_msg(&client.unique, &[BS]);
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
                            let _ = Self::send_client_msg(&client.unique, &[BS]);
                        }
                        client.ircdnum = num;

                        client.data = client.records[client.ircdnum as usize].clone();
                        client.ipos = client.data.len();

                        // 清空光标后的字符串
                        let _ = Self::send_client_msg(&client.unique, b"\x1b[K");
                        let _ = Self::send_client_msg(&client.unique, &client.data);
                    }

                }
                // 方向键向下
                else if bytes[i + 2] == 66 && client.records.len() != 0 {
                    if client.ircdnum != -1 {
                        for _ in 0..client.data.len() {
                            let _ = Self::send_client_msg(&client.unique, &[BS]);
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
                        let _ = Self::send_client_msg(&client.unique, b"\x1b[K");
                        let _ = Self::send_client_msg(&client.unique, &client.data);
                    }

                }
                // 方向键向右
                else if bytes[i + 2] == 67 && client.ipos < client.data.len() {
                    // 发送光标所处位置的字符，让光标向前一格
                    let _ = Self::send_client_msg(&client.unique, &client.data[client.ipos as usize..client.ipos as usize +
                                                                            1]);
                    client.ipos += 1;
                }
                // 方向键向左，发送退格键
                else if bytes[i + 2] == 68 && client.ipos != 0 {
                    client.ipos -= 1;
                    let _ = Self::send_client_msg(&client.unique, &[BS]);
                }
                // 接收到HOME键
                else if bytes[i + 2] == 49 && i + 3 < bytes.len() && bytes[i + 3] == 126 {

                    for _ in 0..client.data.len() {
                        let _ = Self::send_client_msg(&client.unique, &[BS]);
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
                        let _ = Self::send_client_msg(&client.unique, movecursor.as_bytes());
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
                    let _ = Self::send_client_msg(&client.unique, &client.data[client.ipos as usize..]);
                    for _ in 0..(client.data[client.ipos as usize..].len() - 1) {
                        let _ = Self::send_client_msg(&client.unique, &[BS]);
                    }
                }
                // 当前为替换状态，只需将该字符插入到消息字符串中即可
                else {
                    if client.ipos < client.data.len() {
                        client.data[client.ipos as usize] = *b;
                    } else {
                        client.data.push(*b);
                    }
                    let _ = Self::send_client_msg(&client.unique, &[*b]);
                }
                client.ipos += 1;
            }
        }
        0
    }

    fn read_callback(
        socket: &mut SocketEvent,
    ) -> usize {
        let telnet = TelnetUtils::instance();
        let data = socket.in_buffer.drain_collect(socket.in_buffer.get_wpos());
        telnet.update_data(socket.get_unique(), &data[..]);
        0
    }

    fn read_end_callback(
        socket: &mut SocketEvent) {
        let telnet = TelnetUtils::instance();
        telnet.remove_client(socket.get_unique());
    }

    fn accept_callback(
        socket: &mut SocketEvent,
    ) -> usize {
        let telnet = TelnetUtils::instance();
        let mio = MioEventMgr::instance();
        let _ = mio.write_by_socket_event(socket, b"                        ** WELCOME TO tunm SERVER! **                         \r\n");
        let _ = mio.write_by_socket_event(socket, b"login:");
        // 开启单字符模式和回显
        let _ = mio.write_by_socket_event(socket, &[255, 251, 3]);
        let _ = mio.write_by_socket_event(socket, &[255, 251, 1]);
        telnet.clients.insert(socket.get_unique().clone(), ClientInfo::new(socket.get_unique().clone()));
        return 1;
    }
    

    pub fn listen(&mut self, addr: &str) {
        assert!(self.listen_fd == 0, "repeat listen telnet");
        match MioEventMgr::instance().listen_server(addr.to_string(), 0, Some(Self::accept_callback), Some(Self::read_callback), Some(Self::read_end_callback)) {
            Ok(fd) => self.listen_fd = fd,
            _ => ()
        };
    }
}
