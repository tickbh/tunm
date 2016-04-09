HEARTBEAT_INTERVAL = 10000

local seq_ids = {}

local seq_id = 0;

function get_network_seq_id(port_no)
    seq_ids[port_no] = (seq_ids[port_no] or 0) + 111
    seq_ids[port_no] = bit32.band(seq_ids[port_no], 0xFFFF) 
    return seq_ids[port_no];
end

function set_network_seq_id(port_no, seq)
    seq_ids[port_no] = seq
end

-- local seq_id = 0;

-- function get_network_seq_id()
--     seq_id = seq_id + 111;
--     seq_id = bit32.band(seq_id, 0xFFFF) 
--     return seq_id;
-- end

-- function set_network_seq_id(seq)
--     seq_id = seq
-- end