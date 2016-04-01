-- log_define.lua
-- Created by wugd
-- 定义模块名

LOG_TYPE_LOGIN_FAIL                  = 1;
LOG_TYPE_USER                        = 2;
LOG_TYPE_TASK                        = 3;
LOG_TYPE_EXP                         = 4;
LOG_TYPE_GET_GOLD                    = 5;
LOG_TYPE_COST_GOLD                   = 6;
LOG_TYPE_GET_STONE                   = 7;
LOG_TYPE_COST_STONE                  = 8;
LOG_TYPE_GET_DUEL_COIN               = 9;
LOG_TYPE_COST_DUEL_COIN              = 10;
LOG_TYPE_GET_ARENA_COIN              = 11;
LOG_TYPE_COST_ARENA_COIN             = 12;
LOG_TYPE_GET_DRAGON_COIN             = 13;
LOG_TYPE_COST_DRAGON_COIN            = 14;
LOG_TYPE_GET_POINT                   = 15;
LOG_TYPE_COST_POINT                  = 16;
LOG_TYPE_LEVEL_UP                    = 18;
LOG_TYPE_CREATE_PROPERTY             = 19;
LOG_TYPE_DESTRUCT_PROPERTY           = 20;
LOG_TYPE_LOGOUT                      = 21;
LOG_TYPE_COST_AMOUNT                 = 25;
LOG_TYPE_ADD_AMOUNT                  = 26;
LOG_TYPE_LOGIN_RECORD                = 39;
LOG_TYPE_LOGOUT_RECORD               = 40;
LOG_TYPE_CREATE_NEW_USER             = 41;
LOG_TYPE_ENTER_MAP                   = 42;
LOG_TYPE_WORLD_CHAT                  = 69;


--日志产生的渠道\系统
LOG_CHANNEL_NULL = 0
LOG_CHANNEL_COPY = 1        --副本
LOG_CHANNEL_OPERATION = 2   --运营活动
LOG_CHANNEL_ARENA = 3       --竞技场
LOG_CHANNEL_BAG = 4         --背包
LOG_CHANNEL_HERO = 5        --英雄
LOG_CHANNEL_TEAM = 6        --战队


local _LOG_DESCRIBE_ = {
    [LOG_TYPE_LOGIN_FAIL] = {name = "玩家创建角色失败或则登录失败", p1="玩家账号或rid", p2="失败的原因1", p3="原因2", meno="" },
    [LOG_TYPE_EXP] = {name = "获得经验", p1="角色RID", p2="英雄RID或者角色RID", p3="经验值", meno="" },
    [LOG_TYPE_GET_GOLD] = {name = "获得金币", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_COST_GOLD] = {name = "消耗金币", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_GET_STONE] = {name = "获得钻石", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_COST_STONE] = {name = "消耗钻石", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_GET_DUEL_COIN] = {name = "获得决斗币", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_COST_DUEL_COIN] = {name = "消耗决斗币", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_GET_ARENA_COIN] = {name = "获得竞技币", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_COST_ARENA_COIN] = {name = "消耗竞技币", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_GET_DRAGON_COIN] = {name = "获得龙币", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_COST_DRAGON_COIN] = {name = "消耗龙币", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_GET_POINT] = {name = "获得积分", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_COST_POINT] = {name = "消耗积分", p1="角色RID", p2="数量", p3="最终数量", meno="" },
    [LOG_TYPE_LEVEL_UP] = {name = "玩家升级", p1="角色RID", p2="英雄RID或者角色RID", p3="之前等级->当前等级(1->2)", meno="" },
    [LOG_TYPE_CREATE_PROPERTY] = {name = "创建物件对象并加载到玩家身上", p1="属主rid", p2="物品rid", p3="物品class_id", meno="物品对象中的数量" },
    [LOG_TYPE_DESTRUCT_PROPERTY] = {name = "销毁物件对象并加载到玩家身上", p1="属主rid", p2="物品rid", p3="物品class_id", meno="物品对象中的数量" },
    [LOG_TYPE_COST_AMOUNT] = {name = "删除道具", p1="属主rid", p2="物品rid", p3="物品class_id", meno="删除个数，删除后剩余个数(cost:%d|remain:%d)" },
    [LOG_TYPE_ADD_AMOUNT] = {name = "新增道具", p1="属主rid", p2="物品rid", p3="物品class_id", meno="新增个数，新增后剩余个数(add:%d|remain:%d)" },
    [LOG_TYPE_LOGOUT] = {name = "调用玩家登出操作", p1="玩家rid", p2="port_no的值", p3="调用登出接口的函数名", meno="" },
    [LOG_TYPE_LOGIN_RECORD] = {name = "玩家登录记录", p1="玩家RID", p2="玩家ACCOUNT", p3="", meno="" },
    [LOG_TYPE_LOGOUT_RECORD] = {name = "玩家登出记录", p1="玩家RID", p2="玩家ACCOUNT", p3="", meno="" },
    [LOG_TYPE_CREATE_NEW_USER] = {name = "进入副本", p1="玩家RID", p2="玩家ACCOUNT", p3="", meno="" },
    [LOG_TYPE_ENTER_MAP] = {name = "新角色创建记录", p1="玩家RID", p2="英雄RID和副手RID(%s:%s)", p3="副本rno", meno="" },
    [LOG_TYPE_WORLD_CHAT] = {name = "世界聊天", p1="玩家RID", p2="发送内容长度", p3="", meno="" },
}
