local strgsub = string.gsub
local tbinsert = table.insert
local tointeger = math.tointeger
local strfmt     = string.format
local strrep = string.rep
local tsort = table.sort
local tbconcat = table.concat
local json = require("json")

function CheckOnly2c(only2c)
    return  only2c == 1
end 

 function Strtrim(input, chars)
    chars = chars or " \t\n\r"
    local pattern = "^[" .. chars .. "]+"
    input = strgsub(input, pattern, "")
    pattern = "[" .. chars .. "]+$"
    return strgsub(input, pattern, "")
end

 function TKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        tbinsert(keys, k)
    end
    return keys
end

 function WriteFile(fileName, content)
    local file = io.open(fileName, "w+b")
    if file then
        file:write(content)
        file:close()
        return true
    end
end

function Dump(tb,name)
    local encode = json.pretty_encode(tb)
    local str = encode
    if type(name)=="string" then 
        str = name.."="..str
    end 
    print(str)
end

function Clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local newObject = {}
        lookup_table[object] = newObject
        for key, value in pairs(object) do
            newObject[_copy(key)] = _copy(value)
        end
        return setmetatable(newObject, getmetatable(object))
    end
    return _copy(object)
end