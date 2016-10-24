use td_rp;
use td_rp::{Buffer, Value, encode_number, encode_str_raw, decode_number, decode_str_raw};

use std::io::{Read, Write, Result};
use {NetResult, make_extension_error};

pub const MSG_TYPE_TD: u16 = 0;
pub const MSG_TYPE_JSON: u16 = 1;
pub const MSG_TYPE_BIN: u16 = 2;
pub const MSG_TYPE_TEXT: u16 = 3;

static HEAD_FILL_UP: [u8; 12] = [0; 12];

pub struct NetMsg {
    buffer: Buffer,
    seq_fd: u16,
    length: u32,
    cookie: u32,
    msg_type: u16,
    pack_name: String,
}

impl NetMsg {
    pub fn new() -> NetMsg {
        let mut buffer = Buffer::new();
        let _ = buffer.write(&HEAD_FILL_UP);
        NetMsg {
            seq_fd: 0u16,
            length: buffer.len() as u32,
            cookie: 0u32,
            msg_type: 0u16,
            buffer: buffer,
            pack_name: String::new(),
        }
    }

    pub fn new_by_detail(msg_type: u16, msg_name: String, data: &[u8]) -> NetMsg {
        let mut buffer = Buffer::new();
        let _ = buffer.write(&HEAD_FILL_UP);
        let _ = encode_str_raw(&mut buffer, &Value::Str(msg_name.clone()));
        let _ = encode_number(&mut buffer, &Value::U16(data.len() as u16));
        let _ = buffer.write(data);
        let mut net_msg = NetMsg {
            seq_fd: 0u16,
            length: buffer.len() as u32,
            cookie: 0u32,
            msg_type: msg_type,
            buffer: buffer,
            pack_name: msg_name,
        };
        net_msg.end_msg(0);
        net_msg
    }

    pub fn new_by_data(data: &[u8]) -> NetResult<NetMsg> {
        if data.len() < HEAD_FILL_UP.len() {
            return Err(make_extension_error("data len too small", None));
        }
        let mut buffer = Buffer::new();
        let _ = buffer.write(&data);
        let length: u32 = try!(decode_number(&mut buffer, td_rp::TYPE_U32)).into();
        let seq_fd: u16 = try!(decode_number(&mut buffer, td_rp::TYPE_U16)).into();
        let cookie: u32 = try!(decode_number(&mut buffer, td_rp::TYPE_U32)).into();
        let msg_type: u16 = try!(decode_number(&mut buffer, td_rp::TYPE_U16)).into();
        if data.len() != length as usize {
            println!("data.len() = {:?}, length = {:?}", data.len(), length);
            return Err(make_extension_error("data length not match", None));
        }
        buffer.set_rpos(HEAD_FILL_UP.len());
        let pack_name: String = try!(decode_str_raw(&mut buffer, td_rp::TYPE_STR)).into();
        buffer.set_rpos(HEAD_FILL_UP.len());
        Ok(NetMsg {
            seq_fd: seq_fd,
            length: length,
            cookie: cookie,
            msg_type: msg_type,
            buffer: buffer,
            pack_name: pack_name,
        })
    }

    pub fn min_len() -> usize {
        HEAD_FILL_UP.len()
    }

    pub fn end_msg(&mut self, seq_fd: u16) {
        self.seq_fd = seq_fd;
        self.length = self.buffer.len() as u32;
        let wpos = self.buffer.get_wpos();
        self.buffer.set_wpos(0);
        let _ = encode_number(&mut self.buffer, &Value::U32(self.length));
        let _ = encode_number(&mut self.buffer, &Value::U16(self.seq_fd));
        let _ = encode_number(&mut self.buffer, &Value::U32(self.cookie));
        let _ = encode_number(&mut self.buffer, &Value::U16(self.msg_type));
        self.buffer.set_wpos(wpos);
    }

    pub fn get_buffer(&mut self) -> &mut Buffer {
        &mut self.buffer
    }

    pub fn read_head(&mut self) -> NetResult<()> {
        let rpos = self.buffer.get_rpos();
        self.buffer.set_rpos(0);
        self.length = try!(decode_number(&mut self.buffer, td_rp::TYPE_U32)).into();
        self.seq_fd = try!(decode_number(&mut self.buffer, td_rp::TYPE_U16)).into();
        self.cookie = try!(decode_number(&mut self.buffer, td_rp::TYPE_U32)).into();
        self.msg_type = try!(decode_number(&mut self.buffer, td_rp::TYPE_U16)).into();
        self.buffer.set_rpos(HEAD_FILL_UP.len());
        self.pack_name = try!(decode_str_raw(&mut self.buffer, td_rp::TYPE_STR)).into();
        self.buffer.set_rpos(rpos);
        Ok(())
    }

    /// set rpos is HEAD_FILL_UP.len()
    pub fn set_read_data(&mut self) {
        self.buffer.set_rpos(HEAD_FILL_UP.len());
    }

    pub fn set_write_data(&mut self) {
        self.buffer.set_wpos(HEAD_FILL_UP.len());
    }

    pub fn get_pack_len(&self) -> u32 {
        self.length
    }

    pub fn len(&self) -> usize {
        self.buffer.len()
    }

    pub fn set_rpos(&mut self, rpos: usize) {
        self.buffer.set_rpos(rpos);
    }

    pub fn get_rpos(&self) -> usize {
        self.buffer.get_rpos()
    }

    pub fn set_wpos(&mut self, wpos: usize) {
        self.buffer.set_wpos(wpos)
    }

    pub fn get_wpos(&self) -> usize {
        self.buffer.get_wpos()
    }

    pub fn set_msg_type(&mut self, msg_type: u16) {
        self.msg_type = msg_type
    }

    pub fn get_msg_type(&self) -> u16 {
        self.msg_type
    }

    pub fn set_seq_fd(&mut self, seq_fd: u16) {
        self.seq_fd = seq_fd;
        let wpos = self.buffer.get_wpos();
        self.buffer.set_wpos(4);
        let _ = encode_number(&mut self.buffer, &Value::U16(self.seq_fd));
        self.buffer.set_wpos(wpos);
    }

    pub fn get_seq_fd(&self) -> u16 {
        self.seq_fd
    }

    pub fn set_cookie(&mut self, cookie: u32) {
        self.cookie = cookie;
        let wpos = self.buffer.get_wpos();
        self.buffer.set_wpos(6);
        let _ = encode_number(&mut self.buffer, &Value::U32(self.cookie));
        self.buffer.set_wpos(wpos);
    }

    pub fn get_cookie(&self) -> u32 {
        self.cookie
    }

    pub fn get_pack_name(&self) -> &String {
        &self.pack_name
    }
}


impl Read for NetMsg {
    fn read(&mut self, buf: &mut [u8]) -> Result<usize> {
        self.buffer.read(buf)
    }
}

impl Write for NetMsg {
    fn write(&mut self, buf: &[u8]) -> Result<usize> {
        self.buffer.write(buf)
    }
    fn flush(&mut self) -> Result<()> {
        Ok(())
    }
}

impl Drop for NetMsg {
    fn drop(&mut self) {
        // println!("drop net_msg!!!!!!!!!!!!!!!!!");
    }
}
