--load_folder.lua
--Created by wugd
--加载指定文件下的脚本

-- 定义公共接口，按照字母顺序排序

--加载path文件夹下的lua文件，arrange指定加载文件的
--先后关系，如"a:b:c"，将按照a、b、c的顺序加载

function load_folder(path, arrange, ...)
    local table_file = get_floder_files(path, ...)
    if sizeof(table_file) == 0 then
        trace("找不到目录(%s)下的文件\n", path);
        return;
    end

    local linestart = 1
    local e
    local s
    local str = {}

    --先加载具有先后关系的文件
    if arrange then
        repeat
            if string.find(arrange,":",linestart) then
                 _,e = string.find(arrange,":",linestart)
                 s   = string.sub(arrange,linestart,e-1)

                for k,v in pairs(table_file) do
                    if string.find(v,'/'.. s .. ".lua") or string.find(v,'\\'.. s .. ".lua") then
                        update(v)
                        str[v] = true
                        table.remove(table_file,k)
                        break
                    end
                end
                linestart = e+1

            --处理最后一个文件
            else
                s =  string.sub(arrange,linestart,string.len(arrange))

                for k,v in pairs(table_file) do
                    if string.find(v,'/'..s) or string.find(v,'\\'..s) then
                        str[v] = true
                        update(v)
                        table.remove(table_file,k)
                        break
                    end
                end

                linestart = string.len(arrange) + 1
            end
        until linestart > string.len(arrange)
    end
    
    --加载其他未指定先后关系的文件
    for k,v in pairs(table_file) do
        if not str[v] then
            str[v] = true
            update(v)
        end
    end
end
