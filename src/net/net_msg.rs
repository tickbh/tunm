use tunm_proto;
use tunm_proto::{Buffer, Value, encode_number, encode_str_raw, decode_number, decode_str_raw};

use std::io::{Read, Write, Result};
use {NetResult, make_extension_error};

pub const MSG_TYPE_TD: u8 = 0;
pub const MSG_TYPE_JSON: u8 = 1;
pub const MSG_TYPE_BIN: u8 = 2;
pub const MSG_TYPE_TEXT: u8 = 3;

static HEAD_FILL_UP: [u8; 26] = [0; 26];

pub struct NetMsg {
    buffer: Buffer,
    length: u32,
    cookie: u32,
    msg_type: u8, //message type: 0:normal, 1:forward, request, response
    msg_flag: u8, // flag: encode, compress, route, trace, package
    from_svr_type: u16,
    from_svr_id: u32,
    to_svr_type: u16,
    to_svr_id: u32,
    real_fd: u32,
    pack_name: String,
}

impl NetMsg {
    pub fn new() -> NetMsg {
        let mut buffer = Buffer::new();
        let _ = buffer.write(&HEAD_FILL_UP);
        NetMsg {
            length: buffer.len() as u32,
            cookie: 0u32,
            msg_type: 0u8,
            msg_flag: 0u8,
            from_svr_type: 0u16,
            from_svr_id: 0u32,
            to_svr_type: 0u16,
            to_svr_id: 0u32,
            real_fd: 0u32,
            buffer: buffer,
            pack_name: String::new(),
        }
    }

    pub fn new_by_detail(msg_type: u8, msg_name: String, data: &[u8]) -> NetMsg {
        let mut buffer = Buffer::new();
        let _ = buffer.write(&HEAD_FILL_UP);
        let _ = encode_str_raw(&mut buffer, &Value::Str(msg_name.clone()));
        let _ = encode_number(&mut buffer, &Value::U16(data.len() as u16));
        let _ = buffer.write(data);
        let mut net_msg = NetMsg {
            length: buffer.len() as u32,
            cookie: 0u32,
            msg_type: msg_type,
            msg_flag: 0u8,
            from_svr_type: 0u16,
            from_svr_id: 0u32,
            to_svr_type: 0u16,
            to_svr_id: 0u32,
            real_fd: 0u32,
            buffer: buffer,
            pack_name: msg_name,
        };
        net_msg.end_msg();
        net_msg
    }



    pub fn new_by_proto_data(data: &[u8]) -> NetResult<NetMsg> {
        let mut buffer = Buffer::new();
        let _ = buffer.write(&HEAD_FILL_UP);
        let _ = buffer.write(&data);
        buffer.set_rpos(HEAD_FILL_UP.len());
        let pack_name: String = decode_str_raw(&mut buffer, tunm_proto::TYPE_STR)?.into();
        buffer.set_rpos(HEAD_FILL_UP.len());

        let mut net_msg = NetMsg {
            length: buffer.len() as u32,
            cookie: 0u32,
            msg_type: 0,
            msg_flag: 0u8,
            from_svr_type: 0u16,
            from_svr_id: 0u32,
            to_svr_type: 0u16,
            to_svr_id: 0u32,
            real_fd: 0u32,
            buffer: buffer,
            pack_name: pack_name,
        };
        net_msg.end_msg();
        Ok(net_msg)
    }

    pub fn new_by_data(data: &[u8]) -> NetResult<NetMsg> {
        if data.len() < HEAD_FILL_UP.len() {
            return Err(make_extension_error("data len too small", None));
        }
        let mut buffer = Buffer::new();
        let _ = buffer.write(&data);
        let length: u32 = decode_number(&mut buffer, tunm_proto::TYPE_U32)?.into();
        let cookie: u32 = decode_number(&mut buffer, tunm_proto::TYPE_U32)?.into();
        let msg_type: u8 = decode_number(&mut buffer, tunm_proto::TYPE_U8)?.into();
        let msg_flag: u8 = decode_number(&mut buffer, tunm_proto::TYPE_U8)?.into();
        let from_svr_type: u16 = decode_number(&mut buffer, tunm_proto::TYPE_U16)?.into();
        let from_svr_id: u32 = decode_number(&mut buffer, tunm_proto::TYPE_U32)?.into();
        let to_svr_type: u16 = decode_number(&mut buffer, tunm_proto::TYPE_U16)?.into();
        let to_svr_id: u32 = decode_number(&mut buffer, tunm_proto::TYPE_U32)?.into();
        let real_fd: u32 = decode_number(&mut buffer, tunm_proto::TYPE_U32)?.into();
        if data.len() != length as usize {
            trace!("解析消息文件失败, 客户端未按指定的格式发送,字节长度为:{:?}, 解析长度为:{:?}", data.len(), length);
            return Err(make_extension_error("data length not match", None));
        }
        buffer.set_rpos(HEAD_FILL_UP.len());
        let pack_name: String = decode_str_raw(&mut buffer, tunm_proto::TYPE_STR)?.into();
        buffer.set_rpos(HEAD_FILL_UP.len());
        Ok(NetMsg {
            length: length,
            cookie: cookie,
            msg_type: msg_type,
            msg_flag: msg_flag,
            from_svr_type: from_svr_type,
            from_svr_id: from_svr_id,
            to_svr_type: to_svr_type,
            to_svr_id: to_svr_id,
            real_fd: real_fd,
            buffer: buffer,
            pack_name: pack_name,
        })
    }

    pub fn min_len() -> usize {
        HEAD_FILL_UP.len()
    }

    pub fn end_msg(&mut self) {
        self.length = self.buffer.get_wpos() as u32;
        let wpos = self.buffer.get_wpos();
        self.buffer.set_wpos(0);
        let _ = encode_number(&mut self.buffer, &Value::U32(self.length));
        let _ = encode_number(&mut self.buffer, &Value::U32(self.cookie));
        let _ = encode_number(&mut self.buffer, &Value::U8(self.msg_type));
        let _ = encode_number(&mut self.buffer, &Value::U8(self.msg_flag));
        let _ = encode_number(&mut self.buffer, &Value::U16(self.from_svr_type));
        let _ = encode_number(&mut self.buffer, &Value::U32(self.from_svr_id));
        let _ = encode_number(&mut self.buffer, &Value::U16(self.to_svr_type));
        let _ = encode_number(&mut self.buffer, &Value::U32(self.to_svr_id));
        let _ = encode_number(&mut self.buffer, &Value::U32(self.real_fd));
        self.buffer.set_wpos(wpos);
    }

    pub fn get_buffer(&mut self) -> &mut Buffer {
        &mut self.buffer
    }

    pub fn read_head(&mut self) -> NetResult<()> {
        let rpos = self.buffer.get_rpos();
        self.buffer.set_rpos(0);
        self.length = decode_number(&mut self.buffer, tunm_proto::TYPE_U32)?.into();
        self.cookie = decode_number(&mut self.buffer, tunm_proto::TYPE_U32)?.into();
        self.msg_type = decode_number(&mut self.buffer, tunm_proto::TYPE_U8)?.into();
        self.msg_flag = decode_number(&mut self.buffer, tunm_proto::TYPE_U8)?.into();
        self.from_svr_type = decode_number(&mut self.buffer, tunm_proto::TYPE_U16)?.into();
        self.real_fd = decode_number(&mut self.buffer, tunm_proto::TYPE_U32)?.into();
        self.to_svr_type = decode_number(&mut self.buffer, tunm_proto::TYPE_U16)?.into();
        self.to_svr_id = decode_number(&mut self.buffer, tunm_proto::TYPE_U32)?.into();
        self.real_fd = decode_number(&mut self.buffer, tunm_proto::TYPE_U32)?.into();
        self.buffer.set_rpos(HEAD_FILL_UP.len());
        self.pack_name = decode_str_raw(&mut self.buffer, tunm_proto::TYPE_STR)?.into();
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
        self.buffer.get_wpos()
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

    pub fn set_msg_type(&mut self, msg_type: u8) {
        self.msg_type = msg_type
    }

    pub fn get_msg_type(&self) -> u8 {
        self.msg_type
    }
    
    pub fn set_msg_flag(&mut self, msg_flag: u8) {
        self.msg_flag = msg_flag
    }

    pub fn get_msg_flag(&self) -> u8 {
        self.msg_flag
    }

    pub fn set_from_svr_type(&mut self, from_svr_type: u16) {
        self.from_svr_type = from_svr_type
    }

    pub fn get_from_svr_type(&self) -> u16 {
        self.from_svr_type
    }

    
    pub fn set_from_svr_id(&mut self, from_svr_id: u32) {
        self.from_svr_id = from_svr_id
    }

    pub fn get_from_svr_id(&self) -> u32 {
        self.from_svr_id
    }

    pub fn set_real_fd(&mut self, real_fd: u32) {
        self.real_fd = real_fd
    }

    pub fn get_real_fd(&self) -> u32 {
        self.real_fd
    }

    
    pub fn set_to_svr_type(&mut self, to_svr_type: u16) {
        self.to_svr_type = to_svr_type
    }

    pub fn get_to_svr_type(&self) -> u16 {
        self.to_svr_type
    }

    pub fn set_to_svr_id(&mut self, to_svr_id: u32) {
        self.to_svr_id = to_svr_id
    }

    pub fn get_to_svr_id(&self) -> u32 {
        self.to_svr_id
    }

    pub fn set_cookie(&mut self, cookie: u32) {
        self.cookie = cookie;
        let wpos = self.buffer.get_wpos();
        self.buffer.set_wpos(4);
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

// impl Drop for NetMsg {
//     fn drop(&mut self) {
//         println!("drop net_msg!!!!!!!!!!!!!!!!!");
//     }
// }
