HEARTBEAT_INTERVAL = 10000

local seq_id = 0;

function get_network_seq_id()
    seq_id = seq_id + 111;
    seq_id = bit32.band(seq_id, 0xFFFF) 
    return seq_id;
end

function set_network_seq_id(seq)
    seq_id = seq
end