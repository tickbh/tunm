//the class MaJiang info
use std::collections::HashMap;
use std::cmp;
use td_rlua::{self, LuaPush, lua_State};

pub struct MaJiang;

// MJ_NULL                 =0x0000                             ---没有类型 
// MJ_CHI                  =0x0001                             ---吃类型 
// MJ_PENG                 =0x0002                             ---碰牌类型

static MJ_NULL: u8 = 0;
static MJ_CHI: u8 = 1;
static MJ_PENG: u8 = 2;
static MJ_DUI: u8 = 10;

static KING_IDX: u8 = 255;

#[derive(Clone, Debug)]
pub struct KindItem {
    pub card_idx: Vec<u8>, 
    pub kind_type: u8,
    pub use_king_count: i32,
}


impl LuaPush for KindItem {
    fn push_to_lua(self, lua: *mut lua_State) -> i32 {
        unsafe {
            td_rlua::lua_newtable(lua);
            "card_idx".push_to_lua(lua);
            self.card_idx.push_to_lua(lua);
            td_rlua::lua_settable(lua, -3);

            "type".push_to_lua(lua);
            self.kind_type.push_to_lua(lua);
            td_rlua::lua_settable(lua, -3);

            "use_king_count".push_to_lua(lua);
            self.use_king_count.push_to_lua(lua);
            td_rlua::lua_settable(lua, -3);

            1
        }
    }
}


impl KindItem {

    #[inline]
    pub fn new() -> KindItem {
        KindItem {
            card_idx: vec![],
            kind_type: MJ_NULL,
            use_king_count: 0,
        }
    }

    #[inline]
    pub fn new_by_data(card1: u8, card2: u8, card3: u8, kind_type: u8) -> KindItem {
        KindItem {
            card_idx: vec![card1, card2, card3],
            kind_type: kind_type,
            use_king_count: 0,
        }
    }
}

impl MaJiang {
    #[inline]
    pub fn get_sub_poker_idx(all_card_idx: &HashMap<u8, i32>, idx: u8) -> (HashMap<u8, i32>, i32) {
        let mut poker_idx: HashMap<u8, i32> = HashMap::new();
        let mut sum: i32 = 0;
        for i in 1 .. Self::get_poker_num(idx) {
            let card: u8 = idx * 16 + i;
            if !all_card_idx.contains_key(&card) {
                continue;
            }

            sum += all_card_idx[&card];
            poker_idx.insert(card, all_card_idx[&card]);
        }

        (poker_idx, sum)
    }

    #[inline]
    pub fn get_poker_num(idx: u8) -> u8 {
        match idx {
            0 | 1 | 2 => 10,
            3 => 5,
            4 => 4,
            _ => unreachable!("idx in 0-4"),
        }
    }

    #[inline]
    pub fn calc_hu_pokers(list: &Vec<KindItem>) -> Vec<u8> {
        let mut result_list: Vec<u8> = vec![];
        for v in list {
            result_list.extend(v.card_idx.clone());
        }
        return result_list;
    }

    #[inline]
    pub fn sub_num_pokers(card_idx: &HashMap<u8, i32>, list: &Vec<KindItem>) -> HashMap<u8, i32> {
        let poker_list = Self::calc_hu_pokers(list);
        let mut new_card_idx = card_idx.clone();
        for poker in poker_list {
            let left_count = {
                let count = unwrap_or!(new_card_idx.get_mut(&poker), continue);
                if *count >= 1 {
                    *count -= 1;
                }
                *count
            };
            if left_count == 0 {
                new_card_idx.remove(&poker);
            }
        }
        return new_card_idx
    }

    #[inline]
    pub fn check_can_eat(color: u8, idx: u8, is_spec_eat: bool) -> Vec<Vec<u8>> {
        let mut result = vec![];
        if !is_spec_eat && color >= 3 {
            return result;
        }

        if color > 7 {
            return result;
        }

        let first_card = color * 16 + idx;

        if color < 3 {
            result.push(vec![first_card, first_card + 1, first_card + 2]);
        } else if color == 3 {
            if idx == 1 {
                result.push(vec![first_card, first_card + 1, first_card + 2]);
                result.push(vec![first_card, first_card + 1, first_card + 3]);
                result.push(vec![first_card, first_card + 2, first_card + 3]);
            } else if idx == 2 {
                result.push(vec![first_card, first_card + 1, first_card + 2]);
            }
        } else if color == 4 {
            result.push(vec![first_card, first_card + 1, first_card + 2]);
        }
        result
    }

    #[inline]
    pub fn get_combine_list(n: usize, k: usize) -> Vec<Vec<usize>> {
        assert!(k <= n);
        let mut result_list = vec![];
        if k == 0 {
            return result_list;
        }

        let mut ready_list: Vec<usize> = vec![];
        for i in 0 .. n {
            if i <= k - 1 {
                ready_list.push(1);
            } else {
                ready_list.push(0);
            }
        }

        loop {
            let mut cur_list: Vec<usize> = vec![];
            let mut first_idx: usize = usize::max_value();
            for i in 0 .. n {
                if ready_list[i] == 1 {
                    cur_list.push(i);
                    if first_idx == usize::max_value() {
                        if ready_list.len() > (i + 1) && ready_list[i + 1] == 0 {
                            first_idx = i;
                        }
                    }
                }
            }

            result_list.push(cur_list);
            if first_idx == usize::max_value() {
                break;
            }

            ready_list[first_idx] = 0;
            ready_list[first_idx + 1] = 1;

            let mut count = 0;
            for i in 0 .. first_idx {
                if ready_list[i] == 1 {
                    count+=1;
                }
            }

            if count >= 1 {
                for i in 0 .. count {
                    ready_list[i] = 1;
                }
            }

            for i in count .. first_idx {
                ready_list[i] = 0;
            }
        }
        return result_list;
    }

    #[inline]
    pub fn cost_one_items(temp_card_idx: &mut HashMap<u8, i32>, item: &KindItem) -> bool {
        for i in 0..3u8 {
            let card = item.card_idx[i as usize];
            if temp_card_idx.contains_key(&card) && temp_card_idx[&card] != 0 {
                let num = unwrap_or!(temp_card_idx.get_mut(&card), return false);
                if *num <= 0 {
                    return false;
                }
                *num -= 1;
            } else {
                let num = unwrap_or!(temp_card_idx.get_mut(&KING_IDX), return false);
                if *num <= 0 {
                    return false;
                }
                *num -= 1;
            }
        }
        true
    }

    #[inline]
    pub fn get_poker_idx_sum(poker_idx: &HashMap<u8, i32>) -> i32 {
        let mut sum = 0;
        for (_, val) in poker_idx.iter() {
            sum += *val;
        }
        sum
    }

    #[inline]
    pub fn idx_to_list(poker_idx: &HashMap<u8, i32>) -> Vec<u8> {
        let mut poker_list = vec![];
        for (key, val) in poker_idx.iter() {
            for _ in 0 .. *val {
                if *key != KING_IDX {
                    poker_list.push(*key);
                }
            }
        }
        poker_list
    }

    #[inline]
    pub fn check_left_vaild(card_idx: &mut HashMap<u8, i32>, temp_card_idx: &mut HashMap<u8, i32>, cur_list: &mut Vec<KindItem>) -> (bool, i32) {
        let sub_idx = Self::sub_num_pokers(&card_idx, &cur_list);
        let sub_list = Self::idx_to_list(&sub_idx);
        if sub_list.len() >= 3 {
            return (false, 0);
        }

        let mut is_success = false;
        let mut use_king_count = 0;
        if sub_list.len() == 0 {
            is_success = true;
        } else if sub_list.len() == 1 && temp_card_idx[&KING_IDX] > 0 {
            let num = temp_card_idx.get_mut(&KING_IDX).unwrap();
            *num -= 1;
            is_success = true;

            use_king_count = 1;
            let mut item = KindItem::new();
            item.card_idx.extend(vec![sub_list[0], sub_list[0]]);
            item.use_king_count = 1;
            item.kind_type = MJ_DUI;
            cur_list.push(item);
        } else if sub_list.len() == 2 {
            if sub_list[0] == sub_list[1] {
                is_success = true;
                let mut item = KindItem::new();
                item.card_idx.extend(vec![sub_list[0], sub_list[0]]);
                item.use_king_count = 0;
                item.kind_type = MJ_DUI;
                cur_list.push(item);
            }
        }

        (is_success, use_king_count)
    }


    // is_success, use_king_count, result_list
    #[inline]
    pub fn calc_ttt_combine(mut card_idx: HashMap<u8, i32>, king_count: i32, color: u8, is_spec_eat: bool) -> (bool, i32, Vec<KindItem>) {
        let result_list = vec![];
        let left_sum = Self::get_poker_idx_sum(&card_idx);
        if left_sum == 0 {
            return (true, 0, result_list);
        }

        card_idx.insert(KING_IDX, king_count);
        let max_item_num = (left_sum + king_count) / 3;
        let min_item_num = cmp::max(0, (1.51f32 / 3f32 * ((left_sum as f32 - 2f32) as f32)).floor() as i32);
        if king_count < min_item_num {
            return (false, 0, result_list);
        }

        let mut kind_items: Vec<KindItem> = vec![];

        for j in 1 .. Self::get_poker_num(color) {
            let card: u8 = color * 16 + j;
            //小于3, 无牌可凑, 主动退出
            if left_sum + king_count < 3 {
                break;
            }

            // if !card_idx.contains_key(&card) {
            //     continue;
            // }

            let mut use_king_count = 0;
            let card_count = card_idx.get(&card).map(|v| v.clone()).unwrap_or(0);
            let mut is_create_peng = false;
            if card_count == 2 && king_count >= 1 {
                use_king_count = 1;
                is_create_peng = true;
            } else if card_count == 1 && king_count >= 2 {
                use_king_count = 2;
                is_create_peng = true;
            }

            if is_create_peng {
                let mut item = KindItem::new_by_data(card, card, card, MJ_PENG);
                item.use_king_count = use_king_count;
                kind_items.push(item);
            }

            let eat_list = Self::check_can_eat(color, j, is_spec_eat);
            for eat in eat_list {
                let mut count1 = card_idx.get(&eat[0]).map(|v| v.clone()).unwrap_or(0);
                let mut count2 = card_idx.get(&eat[1]).map(|v| v.clone()).unwrap_or(0);
                let mut count3 = card_idx.get(&eat[2]).map(|v| v.clone()).unwrap_or(0);
                let mut temp_total_count = king_count;
                while count1 + count2 + count3 + temp_total_count >= 3 {
                    if count1 + count2 == 0 || count1 + count3 == 0 || count2 + count3 == 0 {
                        break;
                    }
                    let mut item = KindItem::new_by_data(eat[0], eat[1], eat[2], MJ_CHI);
                    if count1 <= 0 {
                        temp_total_count -= 1;
                        item.use_king_count += 1;
                    } else {
                        count1 -= 1;
                    }

                    if count2 <= 0 {
                        temp_total_count -= 1;
                        item.use_king_count += 1;
                    } else {
                        count2 -= 1;
                    }

                    if count3 <= 0 {
                        temp_total_count -= 1;
                        item.use_king_count += 1;
                    } else {
                        count3 -= 1;
                    }

                    kind_items.push(item);
                }
            }
        }

        let mut pre_result_list = None;
        let mut min_use_king_count = 255;
        let mut max_use_item_num = 0;

        for need_num in min_item_num .. (max_item_num + 1) {
            if need_num > kind_items.len() as i32 {
                break;
            }

            if min_use_king_count < need_num {
                break;
            }

            if need_num == 0 {
                let mut temp_card_idx = card_idx.clone();
                let mut cur_list = vec![];
                let (is_success, use_king_count) = Self::check_left_vaild(&mut card_idx, &mut temp_card_idx, &mut cur_list);
                if is_success {
                    min_use_king_count = use_king_count as i32;
                    pre_result_list = Some(cur_list);
                }
            } else {

                let result_list = Self::get_combine_list(kind_items.len() as usize, need_num as usize);
                for list in result_list {
                    let mut temp_card_idx = card_idx.clone();
                    let mut cur_list = vec![];

                    let mut cur_use_item_num = 0;
                    let mut cost_success = false;
                    for idx in list {
                        cost_success = Self::cost_one_items(&mut temp_card_idx, &kind_items[idx]);
                        if !cost_success {
                            break;
                        }
                        cur_use_item_num += if kind_items[idx].use_king_count > 0 { 1 } else { 0 };
                        cur_list.push(kind_items[idx].clone());
                    }

                    if cost_success {
                        let (is_success, _use_king_count) = Self::check_left_vaild(&mut card_idx, &mut temp_card_idx, &mut cur_list);
                        if is_success {
                            let cur_king_count = king_count - temp_card_idx[&KING_IDX];
                            if cur_king_count < min_use_king_count {
                                min_use_king_count = cur_king_count;
                                max_use_item_num = cur_use_item_num;
                                pre_result_list = Some(cur_list);
                            } else if cur_king_count == min_use_king_count {
                                if max_use_item_num < cur_use_item_num {
                                    max_use_item_num = cur_use_item_num;
                                    pre_result_list = Some(cur_list);
                                }
                            }
                        }
                    }
                }

                if pre_result_list.is_some() {
                    break;
                }
            }
        }

        if pre_result_list.is_some() {
            (true, min_use_king_count, pre_result_list.unwrap())
        } else {
            (false, 0, result_list)
        }
    }

    pub fn check_can_hu(poker_list: Vec<u8>, king_num: i32, king_poker:u8, is_spec_eat: bool) -> Option<(bool, Vec<KindItem>, Vec<i32>)> {
        let mut all_card_idx: HashMap<u8, i32> = HashMap::new();
        let mut combine_type_table: HashMap<u8, Vec<KindItem>> = HashMap::new();
        let mut left_king_count = king_num;
        let left = (poker_list.len() + king_num as usize) % 3;
        if left != 0 && left != 2 {
            return None;
        }
        let check_can_full = left == 0;

        for poker in poker_list {
            let counter = all_card_idx.entry(poker).or_insert(0);
            *counter += 1;
        }

        for color in 0 .. 5 {
            let mut kind_items: Vec<KindItem> = vec![];
            let (card_idx, all_num) = Self::get_sub_poker_idx(&all_card_idx, color);


            for j in 1 .. Self::get_poker_num(color) {
                //小于3, 无牌可凑, 主动退出
                if all_num < 3 {
                    break;
                }
                let card: u8 = color * 16 + j;
                if !all_card_idx.contains_key(&card) {
                    continue;
                }

                let card_count = all_card_idx[&card];
                let mut is_create_peng = false;
                if card_count >= 3 {
                    is_create_peng = true;
                }

                if is_create_peng {
                    kind_items.push(KindItem::new_by_data(card, card, card, MJ_PENG));
                }

                let eat_list = Self::check_can_eat(color, j, is_spec_eat);
                for eat in eat_list {
                    let mut count1 = *unwrap_or!(all_card_idx.get(&eat[0]), continue);
                    let mut count2 = *unwrap_or!(all_card_idx.get(&eat[1]), continue);
                    let mut count3 = *unwrap_or!(all_card_idx.get(&eat[2]), continue);
                    while count1 > 0 && count2 > 0 && count3 > 0 {
                        kind_items.push(KindItem::new_by_data(eat[0], eat[1], eat[2], MJ_CHI));
                        count1-=1;
                        count2-=1;
                        count3-=1;
                    }
                }
            }

            let mut cur_type_list: Vec<Vec<KindItem>> = vec![];
            let max_combine = cmp::min(kind_items.len(), (all_num / 3) as usize);

            for i in (0 .. max_combine + 1).rev() {
                //剩余牌数不能组成胡牌, 跳出判断, 几个刻子*3 + 每张金牌带走2张 + 一对子
                if (i as i32) * 3 + (left_king_count as i32) * 2 + 2 < all_num {
                    break;
                }
                let mut hu_list: Vec<Vec<KindItem>> = vec![];
                let mut cost_success: bool = true;
                let result_list = Self::get_combine_list(kind_items.len() as usize, i);
                for list in result_list {
                    let mut temp_card_idx = card_idx.clone();
                    let mut cur_list = vec![];

                    for idx in list {
                        cost_success = Self::cost_one_items(&mut temp_card_idx, &kind_items[idx]);
                        if !cost_success {
                            break;
                        }
                        cur_list.push(kind_items[idx].clone());
                    }

                    if cost_success {
                        hu_list.push(cur_list);
                    }
                }

                if cost_success && hu_list.len() == 0 {
                    hu_list.push(vec![]);
                }

                if hu_list.len() > 0 {
                    cur_type_list = hu_list;
                    break;
                }
            }

            let mut final_list: Option<Vec<KindItem>> = None;
            let mut min_use_king_count = 255;

            for list in cur_type_list.drain(..) {
                let left_idx = Self::sub_num_pokers(&card_idx, &list);
                let (is_success, use_king_count, result_list) = Self::calc_ttt_combine(left_idx, left_king_count, color, is_spec_eat);
                if is_success {
                    if use_king_count < min_use_king_count {
                        min_use_king_count = use_king_count;
                        let mut new_list = vec![];
                        new_list.extend(list);
                        new_list.extend(result_list);
                        final_list = Some(new_list);
                    }

                }
            }

            if final_list.is_none() {
                return None;
            }

            left_king_count = left_king_count.overflowing_sub(min_use_king_count).0;
            combine_type_table.insert(color, final_list.unwrap());
        }

        let mut left_dui_list = vec![];
        let mut hu_list = vec![];
        for i in 0 .. 5 {
            for v in combine_type_table.get_mut(&i).unwrap().drain(..) {
                if v.kind_type != MJ_DUI {
                    hu_list.push(v)
                } else {
                    left_dui_list.push(v)
                }
            }
        }

        if check_can_full {
            if left_king_count >= left_dui_list.len() as i32 {
                left_king_count -= left_dui_list.len() as i32;
                for mut v in left_dui_list.drain(..) {
                    let card = v.card_idx[0];
                    v.card_idx.push(card);
                    v.use_king_count = v.use_king_count + 1;
                    v.kind_type = MJ_PENG;
                    hu_list.push(v);
                }

                loop {
                    if left_king_count <= 0 {
                        break;
                    }
                    let mut item = KindItem::new_by_data(king_poker, king_poker, king_poker, MJ_PENG);
                    item.use_king_count = 3;
                    hu_list.push(item);
                    left_king_count = left_king_count.overflowing_sub(3).0;
                }
                return Some((true, hu_list, vec![]));
            }
        } else {
            if left_king_count + 1 >= left_dui_list.len() as i32 {
                let mut use_king_dui = vec![];
                let is_big = (left_king_count + 1) > left_dui_list.len() as i32;

                let sum = left_dui_list.len() as i32;
                let mut add_num = 0;
                if is_big {
                    left_king_count -= left_dui_list.len() as i32;
                } else {
                    left_king_count -= left_dui_list.len() as i32 - 1;
                }

                for mut v in left_dui_list.drain(..) {
                    if !is_big && add_num >= sum - 1 {
                        hu_list.push(v);
                        break;
                    }
                    if v.use_king_count > 0 {
                        use_king_dui.push(v);
                    } else {
                        let card = v.card_idx[0];
                        v.card_idx.push(card);
                        v.use_king_count = v.use_king_count + 1;
                        v.kind_type = MJ_PENG;
                        hu_list.push(v);
                        add_num += 1;
                    }
                }

                for mut v in use_king_dui.drain(..) {
                    if !is_big && add_num >= sum - 1 {
                        hu_list.push(v);
                        break;
                    }
                    let card = v.card_idx[0];
                    v.card_idx.push(card);
                    v.use_king_count = v.use_king_count + 1;
                    v.kind_type = MJ_PENG;
                    hu_list.push(v);
                    add_num += 1;
                }

                if is_big {
                    let mut item = KindItem::new();
                    item.card_idx.extend(vec![king_poker, king_poker]);
                    item.kind_type = MJ_DUI;
                    item.use_king_count = 2;
                    hu_list.push(item);
                    left_king_count = left_king_count.overflowing_sub(2).0;
                }


                loop {
                    if left_king_count <= 0 {
                        break;
                    }
                    let mut item = KindItem::new_by_data(king_poker, king_poker, king_poker, MJ_PENG);
                    item.use_king_count = 3;
                    hu_list.push(item);
                    left_king_count = left_king_count.overflowing_sub(3).0;
                }
                return Some((true, hu_list, vec![]));
            }
        }
        None
    }

}