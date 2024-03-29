 -- define.lua
-- Created by wugd
-- 定义全局变量


MSG_TYPE_TD = 0;
MSG_TYPE_JSON = 1;
MSG_TYPE_BIN = 2;
MSG_TYPE_TEXT = 3;

-- 连接类型
CONN_TYPE_CLIENT = 1;
CONN_TYPE_GS     = 2;
CONN_TYPE_YUNYING = 3;

SERVER_GATE = "gate"
SERVER_LOGIC = "logic"
SERVER_CLIENT = "client"

MESSAGE_GATE = "gate"
MESSAGE_LOGIC = "logic"
MESSAGE_SERVER = "server"
MESSAGE_CLIENT = "client"

GLOABL_RID = "000000000000" 
SYSTEM_RID = "111111111111" 

MESSAGE_MANAGE = 1
MESSAGE_FORWARD = 2
MESSAGE_DISCARD = 3

REDIS_CHAT_CHANNEL_WORLD = "tunm:SUBSCRIBE:CHAT:CHANNEL:WORLD"
REDIS_USER_CONNECTION_LOST = "tunm:SUBSCRIBE:REDIS:USER:CONNECTION:LOST"
REDIS_NOTIFY_ACCOUNT_OBJECT_DESTRUCT = "tunm:SUBSCRIBE:NOTIFY:REDIS:ACCOUNT:OBJECT:DESTRUCT"
REDIS_ACCOUNT_WAIT_LOGIN = "tunm:SUBSCRIBE:REDIS:ACCOUNT:WAIT:LOGIN"
REDIS_ACCOUNT_CANCEL_WAIT_LOGIN = "tunm:SUBSCRIBE:REDIS:ACCOUNT:CANCEL:WAIT:LOGIN"
REDIS_ACCOUNT_OBJECT_CONSTRUCT = "tunm:SUBSCRIBE:REDIS:ACCOUNT:OBJECT:CONSTRUCT"
REDIS_ACCOUNT_OBJECT_DESTRUCT = "tunm:SUBSCRIBE:REDIS:ACCOUNT:OBJECT:DESTRUCT"
REDIS_ACCOUNT_START_HIBERNATE = "tunm:SUBSCRIBE:ACCOUNT:START:HIBERNATE"
REDIS_ACCOUNT_END_HIBERNATE = "tunm:SUBSCRIBE:ACCOUNT:END:HIBERNATE"
REDIS_USER_ENTER_WORLD = "tunm:SUBSCRIBE:REDIS:USER:ENTER:WORLD"

REDIS_SUBS_REGISTER = 
{
    REDIS_CHAT_CHANNEL_WORLD,
    REDIS_USER_CONNECTION_LOST,
    REDIS_NOTIFY_ACCOUNT_OBJECT_DESTRUCT,
    REDIS_ACCOUNT_WAIT_LOGIN,
    REDIS_ACCOUNT_CANCEL_WAIT_LOGIN,
    REDIS_ACCOUNT_OBJECT_CONSTRUCT,
    REDIS_ACCOUNT_OBJECT_DESTRUCT,
    REDIS_USER_ENTER_WORLD,
}

--server_id, user_rid, cookie
REDIS_SERVER_MSG_USER = "SUBSCRIBE:SERVER:MSG:%d:*:*"
MATCH_SERVER_MSG_USER = "SUBSCRIBE:SERVER:MSG:(%d+):(%w+):(%d+)"
CREATE_SERVER_MSG_USER = "SUBSCRIBE:SERVER:MSG:%d:%s:%d"

--server_id, cookie
REDIS_RESPONE_SERVER_INFO = "SUBSCRIBE:RESPONE:SERVER:INFO:%d:*"
MATCH_RESPONE_SERVER_INFO = "SUBSCRIBE:RESPONE:SERVER:INFO:(%d+):(%d+)"
CREATE_RESPONE_SERVER_INFO = "SUBSCRIBE:RESPONE:SERVER:INFO:%d:%d"

--room, user_rid, cookie
REDIS_ROOM_MSG_CHANNEL_USER = "SUBSCRIBE:ROOM:MSG:CHANNEL:%s:*:*"
MATCH_ROOM_MSG_CHANNEL_USER = "SUBSCRIBE:ROOM:MSG:CHANNEL:(%w+):(%w+):(%d+)"
CREATE_ROOM_MSG_CHANNEL_USER = "SUBSCRIBE:ROOM:MSG:CHANNEL:%s:%s:%d"

--room, cookie
REDIS_RESPONE_ROOM_INFO = "SUBSCRIBE:RESPONE:ROOM:INFO:%s:*"
MATCH_RESPONE_ROOM_INFO = "SUBSCRIBE:RESPONE:ROOM:INFO:(%w+):(%d+)"
CREATE_RESPONE_ROOM_INFO = "SUBSCRIBE:RESPONE:ROOM:INFO:%s:%d"

MATCH_SERVER_MSG = "SUBSCRIBE:SERVER:MSG:(%d+)"
CREATE_SERVER_MSG = "SUBSCRIBE:SERVER:MSG:%d"

REDIS_ROOM_MSG_CHANNEL = "SUBSCRIBE:ROOM:MSG:CHANNEL:*"
MATCH_ROOM_MSG_CHANNEL = "SUBSCRIBE:ROOM:MSG:CHANNEL:(%w+)"
CREATE_ROOM_MSG_CHANNEL = "SUBSCRIBE:ROOM:MSG:CHANNEL:%s"


SUBSCRIBE_ROOM_DETAIL_RECEIVE = "SUBSCRIBE:ROOM:DETAIL:RECEIVE"


CACHE_EXPIRE_TIME_MEMORY = 1
CACHE_EXPIRE_TIME_REDIS = 300

OB_TYPE_USER        = 1;
OB_TYPE_ITEM        = 2;
OB_TYPE_EQUIP       = 3;
OB_TYPE_ACCOUNT     = 4;

CHAT_CHANNEL_WORLD = 1
CHAT_CHANNEL_UNION = 2
CHAT_CHANNEL_PRIVATE = 3

-- 定义包裹分组位置
PAGE_ITEM           = 2;             -- 道具仓库
PAGE_EQUIP          = 3;             -- 装备

-- 各分页的最大道具数量
MAX_PAGE_SIZE  = {
    [PAGE_EQUIP]      = 400,
    [PAGE_ITEM]       = 250,
};


BONUS_TYPE_NOSHOW = 0;
BONUS_TYPE_SHOW = 1;

NO_OPERATION_TIME = 600
USER_STEP_SAVE_TIME = 120

EVENT_EXP_CHANGE = "EVENT_EXP_CHANGE"
EVENT_LOGIN_OK   = "EVENT_LOGIN_OK"
EVENT_ACCOUNT_START_HIBERNATE = "EVENT_ACCOUNT_START_HIBERNATE"
EVENT_ACCOUNT_END_HIBERNATE = "EVENT_ACCOUNT_END_HIBERNATE"
EVENT_ACCOUNT_WAIT_LOGIN = "EVENT_ACCOUNT_WAIT_LOGIN"
EVENT_ACCOUNT_CANCEL_WAIT_LOGIN = "EVENT_ACCOUNT_CANCEL_WAIT_LOGIN"
EVENT_ACCOUNT_OBJECT_CONSTRUCT = "EVENT_ACCOUNT_OBJECT_CONSTRUCT"
EVENT_ACCOUNT_OBJECT_DESTRUCT = "EVENT_ACCOUNT_OBJECT_DESTRUCT"
EVENT_SUCCESS_ACCOUNT_OBJECT_DESTRUCT = "EVENT_SUCCESS_ACCOUNT_OBJECT_DESTRUCT"
EVENT_SUCCESS_ACCOUNT_END_HIBERNATE = "EVENT_SUCCESS_ACCOUNT_END_HIBERNATE"
EVENT_NOTIFY_ACCOUNT_OBJECT_DESTRUCT = "EVENT_NOTIFY_ACCOUNT_OBJECT_DESTRUCT"
EVENT_USER_OBJECT_CONSTRUCT = "EVENT_USER_OBJECT_CONSTRUCT"
EVENT_USER_CONNECTION_LOST = "EVENT_USER_CONNECTION_LOST"
