local strgsub = string.gsub
local tbinsert = table.insert
local tointeger = math.tointeger
local strfmt     = string.format
local strrep = string.rep
local tsort = table.sort
local tbconcat = table.concat
local console = require("console")
require("Tools")
local TypeTraits = {}
local CustomM = {}
local CustomTypeCommonet = {s = {},c = {}}
local referenceFiles = {s = {},c = {}}
TypeTraits["int"] = {
    luat = "integer",
    decode =  function(v)
        if v then
            return math.floor(tonumber(v))
        end
        return 0
    end
}

TypeTraits["string"] = {
    luat = "string",
    decode = function(v)
        if v then
            v = strgsub(v, '\n', '\r\n')
            return v
        end
        return ""
    end
}

TypeTraits["float"] = {
    luat = "number",
    decode = function(v)
        if v then
            return tonumber(v)
        end
        return 0.0
    end
}

TypeTraits["bool"] = {
    luat = "boolean",
    decode = function(v)
        if v then
            local n = tonumber(v) 
            if n then 
                return n>0
            end 
            if type(v) == "string" then
                return string.lower(v)== 'true'
            elseif type(v) == "boolean" then
                return v
            end
        end
        return false
    end
}

TypeTraits["int[]"] = {
    luat = "integer[]",
    decode = function(data)
        data = Strtrim(tostring(data))
        if #data==0 or data =="nil" then
            return setmetatable({"empty"},CustomM), true
        end
        local tb = {}
        data = strgsub(data, '%-?%d+' ,function ( w )
            tbinsert(tb, assert(tointeger(w)))
        end)
        local res = {'{'}
        for _, v in ipairs(tb) do
            if _ ~=1 then
                res[#res+1] = ","
            end
            res[#res+1] = tostring(v)
        end
        res[#res+1] = "}"
        return setmetatable(res,CustomM)
    end
}

TypeTraits["float[]"] = {
    luat = "number[]",
    decode = function(data)
        data = Strtrim(tostring(data))
        if #data==0 or data =="nil" then
            return setmetatable({"empty"},CustomM), true
        end
        local tb = {}
        data = strgsub(data,'[^;]+',function ( w )
            tbinsert(tb, assert(tonumber(w)))
        end)
        local res = {'{'}
        for _, v in ipairs(tb) do
            if _ ~=1 then
                res[#res+1] = ","
            end
            res[#res+1] = tostring(v)
        end
        res[#res+1] = "}"
        return setmetatable(res,CustomM)
    end
}

TypeTraits["string[]"] = {
    luat = "string[]",
    decode = function(data)
        data = Strtrim(tostring(data))
        if #data==0 or data =="nil" then
            return setmetatable({"empty"},CustomM), true
        end
        local tb = {}
        data = strgsub(data,'[^;]+',function ( w )
            w = strgsub(w, '\n', '\r\n')
            tbinsert(tb, '[=[' .. w .. ']=]')
        end)
        local res = {'{'}
        for _, v in ipairs(tb) do
            if _ ~=1 then
                res[#res+1] = ","
            end
            res[#res+1] = tostring(v)
        end
        res[#res+1] = "}"
        return setmetatable(res,CustomM)
    end
}

TypeTraits["int[][]"] ={
    luat = "integer[][]",
    decode =function(data)
        data = Strtrim(tostring(data))
        if #data==0 or data =="nil" then
            return setmetatable({"empty"},CustomM), true
        end
        local tb = {}
        strgsub(data,'[^|]+',function ( w )
            tbinsert(tb, w)
        end)
        local res = {'{'}
        for _, v in ipairs(tb) do
            if _ ~=1 then
                res[#res+1] = ","
            end
            res[#res+1] = table.concat(TypeTraits["int[]"].decode(v))
        end
        res[#res+1] = "}"
        return setmetatable(res,CustomM)
    end
}


TypeTraits["raw"] ={
    luat = "table",
    decode = function(data)
        data = tostring(data)
        if #data==0 or data =="nil" then
            return setmetatable({"empty"},CustomM), true
        end
        data = strgsub(data, '\n', '\r\n')
        local check = "return {"..data.."}"
        load(check)()
        return setmetatable({"{"..data.."}"},CustomM)
    end
}


TypeTraits["mapi"] ={
    luat = "table",
    decode = function(data)
        data = tostring(data)
        if #data==0 or data =="nil" then
            return setmetatable({"empty"},CustomM), true
        end
        local tb = {}
        strgsub(data,'[^|]+',function ( w )
            local t = {}
            strgsub(w, '[^;,]+', function(r)
                tbinsert(t, tointeger(r))
            end)
            assert(#t==2,"map need key-value")
            tb[t[1]] = t[2]
        end)

        local res = {'{'}
        local idx = 1
        for k, v in pairs(tb) do
            if idx ~=1 then
                res[#res+1] = ","
            end
            res[#res+1] = strfmt("[%s] = %s", tostring(k), tostring(v))
            idx = idx + 1
        end
        res[#res+1] = "}"
        return setmetatable(res,CustomM)
    end
}

TypeTraits["date"] = {
    luat = "table",
    decode = function(data)
        data = tostring(data)
        if #data==0 or data =="nil" then
            return setmetatable({"empty"},CustomM), true
        end
        local rep = "{year=%1,month=%2,day=%3,hour=%4,min=%5,sec=%6}"
        return setmetatable({(string.gsub(data, "(%d+)[/-](%d+)[/-](%d+) (%d+):(%d+):(%d+)", rep))}, CustomM)
    end
}

TypeTraits["const"] = {
    luat = "const",
    decode =  function(v)
        local const_restrict = {number = 1, integer = 1, string = 1, boolean = 1}
        
        local luat = type(v)
        assert(const_restrict[luat], string.format("bad date type: %s", luat))

        if luat == "number" then
            return tonumber(v)
        end

        return v
    end
}

---引用其他表格数据,用来嵌套表格
local function ReferenceTypeTrait(sysName,fileName,keyName,typename)
    local customtypename = sysName..fileName..keyName..typename
    if not TypeTraits[customtypename] then 
        local typenames = {}
        local names = {}
        if not CustomTypeCommonet[sysName][fileName] then 
            CustomTypeCommonet[sysName][fileName] = {}
        end 
        CustomTypeCommonet[sysName][fileName][typename] = {}
        local referenceConfigName = string.match(typename, "<([%w_]+)>")

        

        if not referenceFiles[sysName][referenceConfigName] then 
            referenceFiles[sysName][referenceConfigName] = {}
        end 
        if not referenceFiles[sysName][referenceConfigName][fileName] then 
            referenceFiles[sysName][referenceConfigName][fileName] = {}
        end 
        referenceFiles[sysName][referenceConfigName][fileName][keyName] = true 


        TypeTraits[customtypename] =  {
            luat = fileName..keyName,
            decode = function(data)
                data = tostring(data)
                local index = 0
                local ids= {}
                if string.find(data,"~") then 
                    strgsub(data,'[^~]+',function ( w )
                        tbinsert(ids,tonumber(w))
                    end)
                    local min = ids[1]
                    local max = ids[2]
                    ids = {}
                    for i = min ,max do
                        ids[#ids+1] = i
                    end
                else 
                   
                    string.gsub (data,"[^;]+",function(s1)
                        ids[#ids+1] = tonumber(s1)
                    end )
                    
                end 
                
                ---读取其他表插入进来

                -- strgsub(data, '[^;,]+', function(r)
                --     index  = index + 1
                --     local traits = assert(TypeTraits[typenames[index]],"dont support "..typenames[index].." type ")
                --     t[names[index]] = traits.decode(r)
                -- end)

                -- local res = {'{'}
                -- local idx = 1
                -- for k, v in pairs(t) do
                --     if idx ~=1 then
                --         res[#res+1] = ","
                --     end
                --     local formatStr = "%s = %s"
                --     if type(v)=="string" then 
                --         formatStr = [[%s = "%s"]]
                --     end 
                --     res[#res+1] = strfmt(formatStr, tostring(k), tostring(v))
                --     idx = idx + 1
                -- end
                -- res[#res+1] = "}"
                return setmetatable(ids,CustomM)
            end
        }
    end
    return TypeTraits[customtypename]

end

local function PairsByKeys(t)
    local a = {}
    for key, _ in pairs(t) do
        a[#a + 1] = key
    end
    table.sort(a)
    local i = 0
    return function ()
        i = i + 1
        return a[i], t[a[i]]
    end
end

---struct类型解析
local StructTypeTrait = function(sysName,fileName,keyName,typename)
    local customtypename = sysName..fileName..keyName..typename
    if not TypeTraits[customtypename] then 
        local typenames = {}
        local names = {}
        if not CustomTypeCommonet[sysName][fileName] then 
            CustomTypeCommonet[sysName][fileName] = {}
        end 
        CustomTypeCommonet[sysName][fileName][typename] = {}
        for k, v in string.gmatch(typename, "(%w+)%s*:%s*(%w+)") do
            tbinsert(typenames,v)
            tbinsert(names,k)
            CustomTypeCommonet[sysName][fileName][typename][k] =  v
        end
        TypeTraits[customtypename] =  {
            luat = fileName..keyName,
            decode = function(data)
            
                data = tostring(data)
                if #data==0 or data =="nil" then
                    return setmetatable({"empty"},CustomM), true
                end
                local index = 0
                local t= {}
                strgsub(data, '[^;]+', function(r)
                    index  = index + 1
                    local traits = assert(TypeTraits[typenames[index]],"dont support "..typenames[index].." type ")
                    t[names[index]] = traits.decode(r)
                end)

                local res = {'{'}
                local idx = 1
                for k, v in PairsByKeys(t) do
                    if idx ~=1 then
                        res[#res+1] = ","
                    end
                    local formatStr = "%s = %s"
                    if type(v)=="string" then 
                        formatStr = [[%s = %s]]
                    elseif type(v) == "table" then
                        local tempstr = ""
                        for _,vv in PairsByKeys(v) do
                            tempstr = tempstr..vv
                        end
                        v = tempstr
                   
                    end 
                    res[#res+1] = strfmt(formatStr, tostring(k), tostring(v))
                    idx = idx + 1
                end
                res[#res+1] = "}"
                -- Dump(res)
                return setmetatable(res,CustomM)
            end
        }
    end
    return TypeTraits[customtypename]

end

---structTable类型解析
local StructTableTypeTrait = function(sysName,fileName,keyName,typename)
    local customtypename = sysName..fileName..keyName..typename
    if not TypeTraits[customtypename] then 
        local typenames = {}
        local names = {}
        if not CustomTypeCommonet[sysName][fileName] then 
            CustomTypeCommonet[sysName][fileName] = {}
        end 
        CustomTypeCommonet[sysName][fileName][typename] = {}
        for k, v in string.gmatch(typename, "(%w+)%s*:%s*(%w+%[?%]?%[?%]?)") do
            tbinsert(typenames,v)
            tbinsert(names,k)
            CustomTypeCommonet[sysName][fileName][typename][k] =  v
        end
        TypeTraits[customtypename] =  {
            luat = fileName..keyName,
            decode = function(data)
                -- print(data)
                data = tostring(data)
                if #data==0 or data =="nil" then
                    return setmetatable({"empty"},CustomM), true
                end
                local hasEmptyTable = false 
                local tt = {}
                -- print(data)
                strgsub(data, '[^|]+', function( w )
                    if w ~= nil then
                        local index = 0
                        local t= {}
                        -- print (w)
                        strgsub(w, '[^;]+', function(r)
                            index  = index + 1
                            assert(index<= #typenames,string.format("结构需要%d个参数，实际输入了%d个参数",#typenames,index))
                            -- Dump(typenames)
                            local traits = assert(TypeTraits[typenames[index]],"dont support "..typenames[index].." type ")
                            t[names[index]],hasEmptyTable = traits.decode(r)
                        end)
                        tt[#tt+1] = t
                    end
				end)
                
                local res = {'{'}
				for key, value in pairs(tt) do
					if key ~= nil then
						local idx = 1
						local rest = "{"
						local isEmpty = true
						for k, v in PairsByKeys(value) do
							if idx ~=1 then
								rest = rest .. ","
							end
							local formatStr = "%s = %s"
							if type(v)=="string" then 
								formatStr = [[%s = "%s"]]
							elseif type(v) == "table" then
								local tempstr = ""
								for _,vv in PairsByKeys(v) do
									tempstr = tempstr..vv
								end
								v = tempstr
							end 
							-- if tostring(v) == "" or  tostring(v) == "empty" or tostring(v) == "nil" then
							-- 	break
							-- end
							rest = rest .. strfmt(formatStr, tostring(k), tostring(v))
							idx = idx + 1
							isEmpty = false
						end
						rest = rest .. "},"
						if not isEmpty then
							res[#res+1] = strfmt("[%s] = %s", tostring(key), rest)
						end
					end
				end
                res[#res+1] = "}"
                return setmetatable(res,CustomM),hasEmptyTable
            end
        }
    end
    return TypeTraits[customtypename]

end

local CustomTypeStrFuncs = {
	["structTable"] = StructTableTypeTrait,
    ["struct"] = StructTypeTrait,
    ["reference"] = ReferenceTypeTrait
}

function GetTypeTraits(sysName,filename,keyname,datatype)
    local isCustomType,customTypeTraitFunc
    for str,typeTraitFunc in pairs(CustomTypeStrFuncs) do 
        isCustomType = string.find(datatype,str.."%s*<.+%s*>%s*")
        if isCustomType then

            customTypeTraitFunc = typeTraitFunc
            break
        end
    end
    local trait
    if isCustomType then
        trait =  customTypeTraitFunc(sysName,filename,keyname,datatype)
    else
        trait = TypeTraits[datatype]
    end
    return trait,isCustomType
end

return {TypeTraits,CustomM,CustomTypeCommonet, referenceFiles}