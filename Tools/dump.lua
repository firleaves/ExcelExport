---@diagnostic disable: lowercase-global
local function dump_value_(v)
    if type(v) == "string" then
        v = '"' .. v .. '"'
    end
    return tostring(v)
end

function dump(value, desciption, nesting)
    if type(nesting) ~= "number" then
        nesting = 3
    end
    local lookupTable = {}
    local result = {}
    local function dump_(value, desciption, indent, nest, keylen)
        desciption = desciption or "<var>"
        local spc = ""
        if type(keylen) == "number" then
            spc = string.rep(" ", keylen - string.len(dump_value_(desciption)))
        end
        if type(value) ~= "table" then
            result[#result + 1] = string.format("%s%s%s = %s", indent, dump_value_(desciption), spc, dump_value_(value))
        elseif lookupTable[tostring(value)] then
            result[#result + 1] = string.format("%s%s%s = *REF*", indent, dump_value_(desciption), spc)
        else
            lookupTable[tostring(value)] = true
            if nest > nesting then
                result[#result + 1] = string.format("%s%s = *MAX NESTING*", indent, dump_value_(desciption))
            else
                result[#result + 1] = string.format("%s%s = {", indent, dump_value_(desciption))
                local indent2 = indent .. "    "
                local keys = {}
                local keylen = 0
                local values = {}
                for k, v in pairs(value) do
                    keys[#keys + 1] = k
                    local vk = dump_value_(k)
                    local vkl = string.len(vk)
                    if vkl > keylen then
                        keylen = vkl
                    end
                    values[k] = v
                end
                table.sort(
                    keys,
                    function(a, b)
                        if type(a) == "number" and type(b) == "number" then
                            return a < b
                        else
                            return tostring(a) < tostring(b)
                        end
                    end
                )
                for i, k in ipairs(keys) do
                    dump_(values[k], k, indent2, nest + 1, keylen)
                end
                result[#result + 1] = string.format("%s}", indent)
            end
        end
    end
    dump_(value, desciption, "- ", 1)
    for i, line in ipairs(result) do
        print(line)
    end
end

function dump_byte(pack)
	print(".................dump_byte start.................")
    for i = 1, string.len(pack) do 
        print(string.byte(pack, i))
    end
    print(".................dump_byte end.................")
end