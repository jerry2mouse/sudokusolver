    -- Filling in candidates
-- Finding cells with just one candidate number
-- remove candidate numbers from cells
--   Naked Pairs, Naked Triples, and Naked Quads
--   Hidden Singles
function table.show(t, name, indent)
    local cart_t = {}    -- a container
    local autoref_t = {}    -- for self references

    --[[ counts the number of elements in a table
       local function tablecount(t)
       local n = 0
       for _, _ in pairs(t) do n = n+1 end
       return n
       end
    ]]
    -- (RiciLake) returns true if the table is empty
    local function isemptytable(t) return next(t) == nil end

    local function basicSerialize(o)
        local so = tostring(o)
        if type(o) == "function" then
            local info = debug.getinfo(o, "S")
            -- info.name is nil because o is not a calling level
            if info.what == "C" then
                return string.format("%q", so .. ", C function")
            else
                -- the information is defined through lines
                return string.format("%q", so .. ", defined in (" ..
                info.linedefined .. "-" .. info.lastlinedefined ..
                ")" .. info.source)
            end
        elseif type(o) == "number" or type(o) == "boolean" then
            return so
        else
            return string.format("%q", so)
        end
    end

    local function addtocart(value, name, indent, saved, field)
        indent = indent or ""
        saved = saved or{}
        field = field or name

        table.insert(cart_t, indent .. field)

        if type(value) ~= "table" then
            table.insert(cart_t, " = " .. basicSerialize(value) .. ";\n")
        else
            if saved[value] then
                table.insert(cart_t, " = {}; -- " .. saved[value]
                .. " (self reference)\n")
                table.insert(autoref_t, name .. " = " .. saved[value] .. ";\n")
            else
                saved[value] = name
                if isemptytable(value) then
                    table.insert(cart_t, " = {};\n")
                else
                    table.insert(cart_t, " = {\n")
                    for k, v in pairs(value) do
                        k = basicSerialize(k)
                        local fname = string.format("%s[%s]", name, k)
                        field = string.format("[%s]", k)
                        -- three spaces between levels
                        addtocart(v, fname, indent .. "   ", saved, field)
                    end
                    table.insert(cart_t, indent .. "};\n")
                end
            end
        end
    end

    name = name or "__unnamed__"
    if type(t) ~= "table" then
        return name .. " = " .. basicSerialize(t)
    end

    addtocart(t, name, indent)
    return table.concat(cart_t) .. table.concat(autoref_t)
end

function strsplit(s, split_str, ret)
    if not ret then
        ret = {}
    end

    local offset = {}

    local nn = #split_str

    local start_pos = 1
    local split_start_pos, split_end_pos = string.find(s, split_str, start_pos)
    while split_start_pos ~= nil and (split_start_pos <= split_end_pos) do
        table.insert(ret, string.sub(s, start_pos, split_start_pos - 1))
        table.insert(offset, start_pos)
        start_pos = split_end_pos + 1
        split_start_pos, split_end_pos = string.find(s, split_str, start_pos)
    end
    if start_pos <= #s then
        table.insert(offset, start_pos)
        table.insert(ret, string.sub(s, start_pos))
    end

    return ret, offset
end


-- Trim leading and trailing whitespace, including tabs, spaces, carriage returns, and line feeds.
-- This function takes a string as input and returns the input string with leading and trailing whitespace removed.
function trimstr(s)
    local begin = 1    -- Initialize the starting index for trimming.
    local stop = #s    -- Initialize the ending index for trimming.

    -- Loop to find the new start index where the first non-whitespace character is encountered.
    for i = 1, #s do
        local x = string.byte(s, i)
        if x == 0x09 or x == 0x20 or x == 0x0d or x == 0x0a then
            begin = i + 1    -- Update the start index if the character is whitespace.
        else
            break    -- Exit the loop when a non-whitespace character is found.
        end
    end

    -- Loop to find the new end index where the last non-whitespace character is encountered.
    for i = #s, begin, -1 do
        local x = string.byte(s, i)
        if x == 0x09 or x == 0x20 or x == 0x0d or x == 0x0a then
            stop = i - 1    -- Update the end index if the character is whitespace.
        else
            break    -- Exit the loop when a non-whitespace character is found.
        end
    end

    -- Return the substring of the input string with leading and trailing whitespace removed.
    return s:sub(begin, stop)
end

-- x: 1-9
-- y: 1-9
function gen_cell_key(x, y)
    local k = string.format("%s%d", string.char(0x40 + x), y)
    return k
end

-- 
function calc_candidate_by_row(t, row, col, ret)
    for i = 1, 9 do
        local k0 = gen_cell_key(row, i)
        if is_cell_ok(t, k0) == true then
            ret[t[k0]] = "N"
        end
    end
    return ret
end

function calc_candidate_by_col(t, row, col, ret)
    for i = 1, 9 do
        local k0 = gen_cell_key(i, col)
        if is_cell_ok(t, k0) == true then
            ret[t[k0]] = "N"
        end
    end
    return ret
end


-- Define a function to calculate candidate values for a 3x3 block in a Sudoku grid.
function calc_candidate_by_block(t, row, col, ret)
    -- Get the top-left cell coordinates of the block containing the cell at (row, col).
    local i, j = get_left_top_block(row, col)

    -- Create a table 'f' to collect unique values in the 3x3 block.
    local f = {}

    -- Iterate through the cells in the 3x3 block.
    for i0 = i, i + 2 do
        for j0 = j, j + 2 do
            -- Generate a key 'k' for the current cell and check if it exists in the grid 't'.
            local k = gen_cell_key(i0, j0)
            -- t[k] == ""
            local v = t[k]
            if v ~= "" then
                f[t[k]] = 1
            end
        end
    end

    -- Check numbers 1 through 9 and mark them as "N" if they exist in 'f', meaning they are not candidates.
    for i = 1, 9 do
        local k = string.format("%d", i)
        if f[k] then
            ret[k] = "N"
        end
    end

    -- Return the 'ret' table containing candidate values marked as "N".
    return ret
end


function get_left_top_block(row, col)
    local i = ((row - 1) -((row - 1) % 3)) / 3
    local j = ((col - 1) -((col - 1) % 3)) / 3
    i = i * 3 + 1
    j = j * 3 + 1
    return i, j
end

local s11 = 
[[
3421XXXX7
XXXXX79XX
XX7X6XX5X
X8XX124XX
734XXX1XX
XXX67X53X
XXXXXX8XX
9X6XXXXX5
XX1XX972X
]]
local s12 = 
[[
9XX34X8X1
X51XXXXX9
X7389XX56
XXX4XXXXX
X3XX6XXX8
21XX3XXX4
5XX9XXXX7
XX2X87XXX
X9X2XXXXX
]]
local s13 = 
[[
XX25XXX7X
XX416XX8X
X58XXXX4X
XXXX25XX3
XXXX81XX7
16XXXXXXX
8XXXX71XX
XX93X27XX
3XXXXX5XX
]]
local s100 = 
[[
6X25XXXXX
XXX4X7X1X
9X7X1XXXX
12XXX5X3X
XX8XXX1XX
X3X1XXX96
XXXX3X5X8
X5X7X2XXX
XXXXX49X3
]]
local s1 = 
[[
8XXXXXXXX
XX36XXXXX
X7XX9X2XX
X5XXX7XXX
XXXX457XX
XXX1XXX3X
XX1XXXX68
XX85XXX1X
X9XXXX4XX
]]

function read_s(s)
    local value_k = {
        ["1"] = 1, 
        ["2"] = 1, 
        ["3"] = 1, 
        ["4"] = 1, 
        ["5"] = 1, 
        ["6"] = 1, 
        ["7"] = 1, 
        ["8"] = 1, 
        ["9"] = 1, 
    }
    local r = strsplit(s, "\n")
    print(table.show(r))
    if #r ~= 9 then
        error("data format error, must 9 lines")
    end
    local ret = {}
    for i = 1, 9 do
        local x = trimstr(r[i])
        if #x ~= 9 then
            error("data format line:" .. tostring(i) .. " -->" .. x .. " error")
        end
        for j = 1, 9 do
            local k = gen_cell_key(i, j)
            local c = string.sub(x, j, j)
            if c == "X" then
                ret[k] = ""
            elseif value_k[c] == nil then
                error("data format line:" .. tostring(i) .. " -->" .. x .. " invalid char")
            else
                ret[k] = c
            end
        end
    end

    return ret
end


function check_contradiction_sovlved(t, r)
    local isok = true
    local iscontra = false
    for i = 1, 9 do
        for j = 1, 9 do
            local k = gen_cell_key(i, j)
            if is_cell_ok(t, k) == false then
                isok = false
                local s = get_candidate_str(r[k])
                if #s == 0 then
                    iscontra = true
                    return iscontra, isok
                end
            end
        end
    end
    return iscontra, isok
end

function print_result(t)
    local ln = {}
    table.insert(ln, "")
    table.insert(ln, " ")
    for i = 1, 9 do
        table.insert(ln, tostring(i))
    end
    print(table.concat(ln, " | "))
    for i = 1, 9 do
        local ln = {}
        local lns = {}
        table.insert(ln, "")
        table.insert(ln, string.format("%s", string.char(0x40 + i)))
        for j = 1, 9 do
            local k = gen_cell_key(i, j)

            if is_cell_ok(t, k) == false then
                table.insert(ln, "-")
            else
                table.insert(ln, t[k])
            end
        end
        for j = 1, 9 do
            table.insert(lns, "-----")
        end
        print(table.concat(lns, ""))
        print(table.concat(ln, " | "))
    end
end
function print_candidate(t, r)
    local ln = {}
    table.insert(ln, "")
    table.insert(ln, " ")
    for i = 1, 9 do
        table.insert(ln, "   " .. tostring(i) .. "   ")
    end
    print(table.concat(ln, " | "))
    for i = 1, 9 do
        local ln = {}
        local lns = {}
        table.insert(ln, "")
        table.insert(ln, string.format("%s", string.char(0x40 + i)))
        for j = 1, 9 do
            local k = gen_cell_key(i, j)

            if is_cell_ok(t, k) == false then
                local s = get_candidate_str(r[k])
                for m = #s, 6 do
                    s = s .. "-"
                end

                table.insert(ln, s)
            else
                table.insert(ln, t[k] .. "      ")
            end
        end
        for j = 1, 9 do
            table.insert(lns, "-----------")
        end
        print(table.concat(lns, ""))
        print(table.concat(ln, " | "))
    end

end


function get_candidate_str(t)
    local n = {}
    for i = 1, 9 do
        local k = string.format("%d", i)
        if t[k] == "Y" then
            table.insert(n, k)
        end
    end
    if #n > 0 then
        table.sort(n)
    end
    local s = table.concat(n)
    return s
end

-- 单元格的数值确定后，更新单元格的值
-- 同步更新相关行列和块的候选数值
function update_cell_value(t, r, v, row, col)
    local k0 = gen_cell_key(row, col)
    --print("set", k0, v)
    -- 更新单元格数值
    t[k0] = v
    r[k0][v] = "N"

    -- 更新行的候选数值
    for i = 1, 9 do
        local k = gen_cell_key(row, i)
        if r[k][v] == "Y" then
            local n = get_candidate_str(r[k])
            local s = string.format("update candidate ROW: set %s = %s, remove %s from '%s' at %s", k0, v, v, n, k)
            print(s)
            r[k][v] = "N"
        end
    end

    -- 更新列的候选数值
    for i = 1, 9 do
        local k = gen_cell_key(i, col)
        if r[k][v] == "Y" then
            local n = get_candidate_str(r[k])
            local s = string.format("update candidate COL: set %s = %s, remove %s from '%s' at %s", k0, v, v, n, k)
            print(s)
            r[k][v] = "N"
        end
    end

    -- 更新块的候选数值
    local left, top = get_left_top_block(row, col)
    for i0 = left, left + 2 do
        for j0 = top, top + 2 do
            local k = gen_cell_key(i0, j0)
            if r[k][v] == "Y" then
                local n = get_candidate_str(r[k])
                local s = string.format("update candidate BLOCK: set %s = %s, remove %s from '%s' at %s", k0, v, v, n, k)
                print(s)
                r[k][v] = "N"
            end
        end
    end
    local iscontra, isok = check_contradiction_sovlved(t, r)
    if iscontra == true then
        return "CONTRA"
    end
    if isok == true then
        return "OK"
    end

    return "GO"
end

-- 遍历所有单元格，找到只有一个候选值的单元格（找到答案）
-- 然后更新相关行列块候选值
-- 返回值是空值的个数，空值个数0表示已经计算完毕
function check_update_candidate(t, r, rv)
    local empty_cell = 0
    for i = 1, 9 do
        for j = 1, 9 do
            local k = gen_cell_key(i, j)
            if is_cell_ok(t, k) == false then
                local n = get_candidate_str(r[k])
                if #n == 1 then
                    local isok = update_cell_value(t, r, n, i, j)
                    if isok == "CONTRA" then
                        return "CONTRA", 100
                    end
                    if isok == "OK" then
                        local s = string.format("[%s]=%s", k, n)
                        table.insert(rv, s)
                        return "FINISH", 100
                    end
                    local s = string.format("[%s]=%s", k, n)
                    table.insert(rv, s)
                    return "GOT"
                else
                    empty_cell = empty_cell + 1
                end
            end
        end
    end
    return "GO", empty_cell
end

-- 按行或列去除相同的候选数字
-- 如：某行的两个单元格候选值都是23，则该行其他的23可以清除
-- Naked Pairs, Naked Triples, and Naked Quads:
-- Look for rows, columns, or boxes where a specific set of two, three, 
-- or four numbers appears as candidates in the same cells. 
-- When you identify such sets, you can eliminate those numbers as 
-- candidates from other cells in the same unit.
function proc_samecell_set(t, r, tp)
    local is_change = false
    for i = 1, 9 do
        local candidate_cnt = {}
        local pos = {}
        for j = 1, 9 do
            local k = ""
            if tp == "ROW" then
                k = gen_cell_key(i, j)
            elseif tp == "COL" then
                k = gen_cell_key(j, i)
            else
            end
            if is_cell_ok(t, k) == false then
                local s = get_candidate_str(r[k])
                if #s > 0 then
                    if candidate_cnt[s] == nil then
                        candidate_cnt[s] = 1
                        pos[s] = {}
                        pos[s][k] = 1
                    else
                        candidate_cnt[s] = candidate_cnt[s] + 1
                        pos[s][k] = 1
                    end
                end
            end
        end
        -- candidate_cnt["34"] = 2
        for k, v in pairs(candidate_cnt) do
            -- v是候选值个数，如果候选值个数为1，会在后续的计算中成功获得答案，这里不处理候选值为1的情况
            if v > 1 and #k == v then
                for j = 1, 9 do
                    local kz = ""
                    if tp == "ROW" then
                        kz = gen_cell_key(i, j)
                    elseif tp == "COL" then
                        kz = gen_cell_key(j, i)
                    else
                    end
                    if pos[k][kz] == nil then
                        for m = 1, #k do
                            local m1 = string.sub(k, m, m)
                            if r[kz][m1] == "Y" then
                                local s = get_candidate_str(r[kz])
                                if tp == "ROW" then
                                    print(string.format("row remove %s from %s by %s at %s", m1, s, k, kz))
                                elseif tp == "COL" then
                                    print(string.format("col remove %s from %s by %s at %s", m1, s, k, kz))
                                else
                                end
                                r[kz][m1] = "N"
                                is_change = true
                            end
                        end
                    end
                end
            end
            if is_change == true then
                return is_change
            end
        end
    end
    return is_change
end

function is_cell_ok(t, k)
    if t[k] == "" then
        return false
    end
    return true
end

-- check number just in one cell
-- 按行和列检查
-- 检查，候选值只在一个单元格中出现
-- Hidden Singles
-- Locked Candidates
function proc_row_same_cell(t, r, tp)
    local is_change = false
    for i = 1, 9 do
        local candidate_cnt = {}
        local pos = {}
        for j = 1, 9 do
            local k = ""
            if tp == "ROW" then
                k = gen_cell_key(i, j)
            elseif tp == "COL" then
                k = gen_cell_key(j, i)
            else
            end
            if is_cell_ok(t, k) == false then
                for m = 1, 9 do
                    local s = string.format("%d", m)
                    if r[k][s] == "Y" then
                        if candidate_cnt[s] == nil then
                            candidate_cnt[s] = 1
                            pos[s] = {}
                            pos[s][k] = j
                        else
                            candidate_cnt[s] = candidate_cnt[s] + 1
                            pos[s][k] = j
                        end
                    end
                end
            end
        end
        local s = ""
        for j = 1, 9 do
            s = string.format("%d", j)
            if candidate_cnt[s] == 1 then
                break
            end
            s = ""
        end

        if s ~= "" then

            local k = ""
            if tp == "ROW" then
                k = next(pos[s])

            elseif tp == "COL" then
                k = next(pos[s])
            else
            end
            for m = 1, 9 do
                local m0 = string.format("%d", m)
                if r[k][m0] == "Y" then
                    if m0 == s then
                    else
                        if tp == "ROW" then
                            print(string.format("XXXrow remove %s, just one at %s", m0, k))
                        elseif tp == "COL" then
                            print(string.format("XXXcol remove %s, just one at %s", m0, k))
                        else
                        end
                        r[k][m0] = "N"
                        is_change = true
                    end
                end
            end

        end
    end
    return is_change
end

-- Hidden Singles
-- Locked Candidates
function proc_same_block(t, r, tp)
    local is_change = false
    for ii = 0, 2 do
        for jj = 0, 2 do
            local candidate_cnt = {}
            local pos = {}
            -- pos[candidate][cell] = xx
            -- pos["3"]["A1"] = 1
            -- pos["3"]["A2"] = 1
            for i = 1, 3 do
                for j = 1, 3 do
                    local xx = ii * 3 + i
                    local yy = jj * 3 + j
                    local k = gen_cell_key(xx, yy)

                    if is_cell_ok(t, k) == false then
                        for m = 1, 9 do
                            local s = string.format("%d", m)
                            if r[k][s] == "Y" then
                                if candidate_cnt[s] == nil then
                                    candidate_cnt[s] = 1
                                    pos[s] = {}
                                    pos[s][k] = 1
                                else
                                    candidate_cnt[s] = candidate_cnt[s] + 1
                                    pos[s][k] = 2
                                end
                            end
                        end
                    end

                end
            end
            while true do
                local s = ""
                for j = 1, 9 do
                    s = string.format("%d", j)
                    if candidate_cnt[s] == 1 then
                        candidate_cnt[s] = 0
                        break
                    end
                    s = ""
                end

                if s ~= "" then
                    local k = next(pos[s])
                    for m = 1, 9 do
                        local m0 = string.format("%d", m)
                        if r[k][m0] == "Y" then
                            if m0 ~= s then
                                r[k][m0] = "N"
                                print(string.format("BLOCK with %s remove %s, just one at %s", s, m0, k))
                                is_change = true
                            end
                        end
                    end

                    -- 清除唯一候选值的项
                    pos[s] = nil
                    if is_change == true then
                        return is_change
                    end
                else
                    break
                end
            end

            while true do

                local a, b, c = is_block_same_rc(pos)
                if a ~= "" then
                    for i = 1, 9 do
                        local k = ""
                        if c == "ROW" then
                            k = b .. string.format("%d", i)
                        else
                            k = string.format("%s", string.char(0x40 + i)) .. b
                        end
                        if pos[a][k] == nil then
                            if r[k][a] == "Y" then

                                r[k][a] = "N"
                                print(string.format("BLOCK %s with %s remove %s, just one at %s", c, a, a, k))
                                is_change = true
                            end
                        end
                    end
                    pos[a] = nil

                    if is_change == true then
                        return is_change
                    end
                else
                    break
                end
            end
        end
    end
    return is_change
end

-- ["5"] = {
--     ["E9"] = 2;
--     ["E8"] = 1;
--  };
--  ["4"] = {
--     ["E9"] = 2;
--     ["E8"] = 2;
--     ["D7"] = 1;
--     ["F7"] = 2;
--     ["D9"] = 2;
--  };
-- 块内候选数值在同一行列内
function is_block_same_rc(t)
    for k, v in pairs(t) do
        local r = {}
        for k1, v1 in pairs(v) do
            table.insert(r, k1)
        end
        local a, b = check_rc(r)
        if a ~= "" then
            return k, a, "ROW"
        end

        if b ~= "" then
            return k, b, "COL"
        end

    end
    return "", "", ""
end

function check_rc(t)
    if #t <= 1 then
        error("t必须有2项以上")
    end
    local rf = true
    local cf = true
    local r = string.sub(t[1], 1, 1)
    local c = string.sub(t[1], 2, 2)
    for i = 2, #t do
        local x = t[i]
        if rf == true and r ~= string.sub(x, 1, 1) then
            rf = false
            r = ""
        end
        if cf == true and c ~= string.sub(x, 2, 2) then
            cf = false
            c = ""
        end
    end
    return r, c
end

-- 找到长度为len的第sn个单元格
function get_guess_cell(r, len, sn)
    local ret = {}
    while true do
        local cnt = 0
        for i = 1, 9 do
            for j = 1, 9 do
                local k = gen_cell_key(i, j)
                local n = get_candidate_str(r[k])
                if #n == len then
                    cnt = cnt + 1
                    if cnt == sn then
                        return len, sn, k
                    end
                end
            end
        end

        len = len + 1
        sn = 1
        if len >= 9 then
            -- 不存在这个候选值个数的单元格
            break
        end
    end
    return nil
end

function copy_t(t, ret)
    if ret == nil then
        ret = {}
    end
    for k, v in pairs(t) do
        ret[k] = v
    end
    return ret
end

local guess_s = {}
function guess_cell(tsrc, k, v)
    local t = copy_t(tsrc)
    t[k] = v
    local f = reslove(t)
    if f == true then
        copy_t(t, tsrc)
        return true
    end

    return false
end

function proc_guess_cell(t)
    local len = 2
    local sn = 1
    local k = ""
    while true do
        local r = calc_candidate(t)
        len, sn, k = get_guess_cell(r, len, sn)
        if k ~= nil then
            if len > 2 then
                return false
            end
            if sn > 1 then
                return false
            end
            local n = get_candidate_str(r[k])
            for i = 1, #n do
                print("guess", k, i, string.sub(n, i, i))
                local sa = string.format("[%02d][%s]=%s in '%s'", #guess_s + 1, k, string.sub(n, i, i), n)
                table.insert(guess_s, sa)
                print(">>XX:" .. table.concat(guess_s, ","))
                isok = guess_cell(t, k, string.sub(n, i, i))
                if isok == true then
                    return true
                end
                table.remove(guess_s, #guess_s)
                print("<<XX:" .. table.concat(guess_s, ","))


            end
            sn = sn + 1

        else
            return false
        end
    end
    error("can not reach here")
    return false
end


function calc_cell_candidate(t, i, j)
    local ret = {}
    for i = 1, 9 do
        local k = string.format("%d", i)
        ret[k] = "Y"
    end

    local k = gen_cell_key(i, j)
    if is_cell_ok(t, k) == true then
        for m = 1, 9 do
            local s = string.format("%d", m)
            ret[s] = "N"
        end
    else
        calc_candidate_by_row(t, i, j, ret)
        calc_candidate_by_col(t, i, j, ret)
        calc_candidate_by_block(t, i, j, ret)
    end
    return ret
end

function calc_candidate(t)
    local r = {}
    for i = 1, 9 do
        for j = 1, 9 do
            local k = gen_cell_key(i, j)
            r[k] = calc_cell_candidate(t, i, j)
        end
    end
    return r
end

function prt(n, t, r)
    --do return end
    local s = string.format("*** %3d *******************", n)
    print(s)
    print_result(t)
    print("")
    print_candidate(t, r)
end
local rsn = {}
function add_to(t, r)
    for i = 1, #r do
        table.insert(t, r[i])
    end
end
function remove_n(t, n)
    local x0 = #t
    for i = x0, n + 1, -1 do
        table.remove(t, i)
    end
end
function reslove(t)
    local r = calc_candidate(t)
    local nc = 0
    prt(nc, t, r)
    local rv = {}
    while true do
        local a, b = check_update_candidate(t, r, rv)
        while a == "GOT" do
            prt(nc, t, r)
            a, b = check_update_candidate(t, r, rv)
        end
        nc = nc + 1
        if a == "FINISH" then
            prt(nc, t, r)
            print_result(t)
            print_candidate(t, r)

            return true
        end
        if a == "CONTRA" then
            return false
        end

        if a == "GO" then
            b = proc_samecell_set(t, r, "ROW")
            if b == false then
                b = proc_samecell_set(t, r, "COL")
            end
            if b == false then
                b = proc_row_same_cell(t, r, "ROW")
            end
            if b == false then
                b = proc_row_same_cell(t, r, "COL")
            end
            if b == false then
                b = proc_same_block(t, r)
            end
            if b == false then
                b = proc_guess_cell(t)
                if b == false then
                    return false
                else
                    return true
                end
            end

        else
            error("ret value not processed:" .. a)
        end

    end
    error("not reach here")
    return true
end

local t = read_s(s1)
reslove(t)
