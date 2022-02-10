
local strgsub = string.gsub
local tbinsert = table.insert
local tointeger = math.tointeger
local strfmt     = string.format
local strrep = string.rep
local tsort = table.sort
local tbconcat = table.concat

local args = {...}

local console = require("console")
local excel = require("excel")
local fs = require("fs")
local json = require("json")

require("Tools")
local t = require("TypeTraits")
local TypeTraits,CustomM,CustomTypeCommonet, referenceFiles = t[1],t[2],t[3],t[4]
local ReferenceM = {}
local st = os.clock()
print("Start export server config")

local InputDir = args[2]
local OutputDir = args[3]
local KeepDirectory
print("inputdir = "..args[2],"outputdir="..args[3])


fs.createdirs(OutputDir)

local OutputClientDir = OutputDir.."/lua/client"
local OutputServerDir  = OutputDir.."/lua/server"
fs.createdirs(OutputClientDir)
fs.createdirs(OutputServerDir)

local excelfiles = fs.listdir(InputDir,"*.xlsx")


---原始excel数据,一行为一组数据
local rawDatas = {}

local rawSCDatas = {
    s = {},
    c = {}
}

local formatdatas = {
    s = {},
    c = {}
}

local publishdata = {
    c = {},
    s = {}
}

local rowmt = {}



for _, file in ipairs(excelfiles) do

    
    local relativePath = string.sub(file,#InputDir+2)
    print(relativePath)
    local filename = fs.name(relativePath)

    local directory = string.sub(relativePath,1,-#filename-1)
    if directory ~= "" then
        fs.createdirs(OutputClientDir.."/"..directory)
        fs.createdirs(OutputServerDir.."/"..directory)
    end 

    -- local dir = 
    local filename = string.sub(relativePath,1,-6)
    local name = fs.stem(relativePath)
    -- GetFileDirectory(file)
    -- print(relativePath,filename,name)
    if string.sub(name,1,2)~="~$" then
        local res, err = excel.read(file)
        if not res then
            console.error(err)
            return
        end
        rawDatas[filename] = res
        
    end
end




---筛选s和c数据
local function FilterSCData(fileName,rawData)

    local comments = rawData[1]
    local colname = rawData[2]
    local datatype = rawData[3]
    local only2c =  rawData[4]
    if only2c ==nil then
        return
    end

    table.remove(rawData,4)
    local c = rawData
    local s = Clone(c)

    local deleteIdxs = TKeys(only2c)
    table.sort(deleteIdxs,function(a,b)
        return a>b 
    end)
    for _,deleteIdx in ipairs(deleteIdxs) do
        for _,data in ipairs(s) do 
            data[deleteIdx] = nil
        end 
    end 

    return s,c
end 

for fileName,data in pairs(rawDatas) do 
    local s,c = FilterSCData(fileName,data[1])
    rawSCDatas.s[fileName] = s
    rawSCDatas.c[fileName] = c
end
rawDatas = nil 

--[[
    data row:
    1. comments
    2. colname
    3. datatype
    4. only2c
]]
local function FormatOne(sysName,fileName,rawData)
    -- Dump(rawData)
    local comments = rawData[1]
    local colname = rawData[2]
    local datatype = rawData[3]
   
    if datatype[1] ==nil then
        return
    end

    local hasEmptyTable = false
    local customTypeIdxs = nil
    local resTb = {}
    for i=4,#rawData do
        local row = rawData[i]
        local key
        local onerow = {}
        if row[1] then
            for idx=1, #colname do
                local name = colname[idx]
                if name then
                    local value = row[idx]
                    if datatype[idx] then 
                        local trait,isCustomType = GetTypeTraits(sysName,fileName,name,datatype[idx])
                        if isCustomType then
                            if not customTypeIdxs then 
                                customTypeIdxs = {}
                            end 
                            customTypeIdxs[idx] = true
                        end

                        if trait and trait.decode then
                            local ok, res, empty = xpcall(trait.decode, debug.traceback, value, fileName, name)
                            if not ok then
                                console.error(strfmt("Excel file '%s' col '%s'[%d] rawData %s format error: %s", fileName, name,i+1, tostring(value), res))
                            else
                                if not hasEmptyTable then
                                    hasEmptyTable = empty
                                end
                                value = res
                                onerow[name] = value
                                --- col 1 is key
                                if idx == 1 then
                                    key = value
                                end
                            end
                        else
                            colname[idx] = tostring(idx)
                        end
                    end
                else
                    colname[idx] = tostring(idx)
                end
            end
            if key then
                if resTb[key] then
                    console.error(strfmt("Excel file '%s' row %d key 已经有相同的key(%d),检查表格", fileName, i+1,key))
                else
                    -- XXX：tianyun 特殊处理，对于只有两列，且其中一列#const的情况，onerow合并为#const值
                    if onerow["#const"] ~= nil then
                        resTb[key] = onerow["#const"]
                    else
                        resTb[key] = setmetatable(onerow, rowmt)
                    end
                end
            end
        end
    end
    -- tsort(resTb)
    return {
        comments = comments,
        datatype = datatype,
        colname = colname,
        data = resTb,
        customTypeIdxs =customTypeIdxs,
        hasEmptyTable = hasEmptyTable
    }
end



for sysname, data in pairs(rawSCDatas) do
    for fileName ,excelData in pairs(data) do 
        local res = FormatOne(sysname,fileName,excelData)
        -- Dump(res.data,name)
        if res then
            formatdatas[sysname][fileName] = res
        else
            console.warn(strfmt("Excel file '%s' main key is null, will skipped!", fileName))
        end
    end 
end
rawSCDatas = nil 



---合并引用文件到每个表格数据中,并且删除formatdatas里面被引用的表格

local referenceDatas = {s = {},c = {}}
for sysName,data in pairs(referenceFiles) do 
    for referenceName,data2 in pairs(data) do
        referenceDatas[sysName][referenceName] = formatdatas[sysName][referenceName]
        formatdatas[sysName][referenceName] = nil
    end
end 
---合并引用数据
for sysName,data in pairs(referenceFiles) do 
    for referenceName,data2 in pairs(data) do
        for fileName,filedata in pairs(data2) do
            for keyname,_ in pairs(filedata) do
                local formatData = formatdatas[sysName][fileName].data
                for id,colData in pairs(formatData) do 
                    local keyData = colData[keyname]
                    local t = {}
                    local referenceData = referenceDatas[sysName][referenceName].data
                    
                    for _,referenceId in ipairs(keyData) do 
                        assert(referenceData[referenceId],string.format("表[%s]key(%s)第(%d)行引用表[%s]中找不到 id = %d数据",fileName,keyname,id,referenceName,referenceId))
                        setmetatable(referenceData[referenceId],nil)
                        tbinsert(t,referenceData[referenceId])
                    end 
               
                    setmetatable(t,ReferenceM)
                    colData[keyname] = t
                end 
            end
        end 
    end
end

-- Dump(formatdatas.s)
local SpaceFindTable = {}
for i=1,32 do
    SpaceFindTable[i]= strrep("\t", i)
end

local function FormatCustomTypeCommonet(fileName,keyname,typename)
    local result = {}
    local t = assert(CustomTypeCommonet[fileName][typename])
    result[#result+1] =  strfmt("---@class %s",  fileName..keyname)
    for name,childTypeName in pairs(t) do
        local trait = assert(TypeTraits[childTypeName],childTypeName)
        result[#result+1]  = strfmt("---@field public %s %s", name, trait.luat)
    end
    result[#result+1] = "\r\n"
    return result
end

local function write(fileName, formatdata, direct)
    local order = formatdata.colname
    local datatype = formatdata.datatype
    local comments = formatdata.comments
    local customTypeIdxs = formatdata.customTypeIdxs
    local function write_value(v)
        if type(v) == "string" then
            if string.find(v, "%c") then
                v = "[[" .. v .. "]]"
            else
                v = "\'" .. v .. "\'"
            end
        end
        return tostring(v)
    end

    local function write_key(v)
        if type(v) == "number" then
            v = "[" .. v .. "]"
        elseif type(v) == "string" and string.find(v," ") then 
            v = "[\""..v.."\"]"
        end
        return tostring(v)
    end

    local result = {}


    local function AppendResult(str)
        result[#result+1] = str

    end 
    local function AppendResults(strt)
        for _,str in ipairs(strt) do 
            AppendResult(str)
        end 
    end
    -- if not direct then
    --     ---emmylua comments
    --     if customTypeIdxs  then
    --         for idx,_ in pairs(customTypeIdxs) do
    --             local typename = datatype[idx]
    --             local keyname = order[idx]
    --             AppendResults(checkonly2c(only2c[idx]),FormatCustomTypeCommonet(fileName,keyname,typename))
    --         end
    --     end

    --     AppendResult(false,strfmt("---@class %s_cfg", fileName))
    --     for k, v in ipairs(order) do
    --         if not v or not datatype[k] then
    --             console.warn(strfmt("Excel file '%s' col '%s' has unsupport datatype '%s' ,skipped!", fileName, v, datatype[k]))
    --         else
    --             if comments[k] then
    --                 assert(datatype[k], tostring(k))
    --                 assert(comments[k], tostring(k))
    --                 local trait = GetTypeTraits(fileName,v,datatype[k])
    --                 assert(trait, datatype[k])

    --                 local str = strfmt("---@field public %s %s @%s", v, trait.luat, strgsub(comments[k],"%c",""))
    --                 AppendResult(checkonly2c(only2c[k]),str)
    --             else
    --                 console.warn(strfmt("Excel file '%s' col '%s' has no comments.", fileName, v, datatype[k]))
    --                 local str = strfmt("---@field public %s %s", v, TypeTraits[datatype[k]].luat)
    --                 AppendResult(checkonly2c(only2c[k]),str)
    --             end
    --         end
    --     end
    -- end

    if formatdata.hasEmptyTable then
        AppendResult("\r\nlocal empty = {}\r\n")
    else
        AppendResult( "")
    end

    AppendResult("local M = {")

   

    local function write_one(k, v, nspace, depth)
        local tp = type(v)

        local needprint = false 


        if tp ~= "table" then
            AppendResult(strfmt("%s%s = %s,",SpaceFindTable[nspace], write_key(k), write_value(v)))
            
        elseif not direct and getmetatable(v) == CustomM then
             AppendResult(strfmt("%s%s = %s,",SpaceFindTable[nspace], write_key(k), table.concat(v)))
        else
            if depth~=1 then
                 AppendResult(strfmt("%s%s = {",SpaceFindTable[nspace], write_key(k)))
            end
            local keys
            if getmetatable(v) == rowmt then
                keys = order
            else
                keys = TKeys(v)
                tsort(keys, function(a, b)
                    if type(a) == "number" and type(b) == "number" then
                        return a < b
                    else
                        return tostring(a) < tostring(b)
                    end
                end)
            end

            for _, _k in ipairs(keys) do
                local _v = v[_k]
        
                if _v~=nil then
                    write_one(_k, _v, nspace+1,depth+1)
                end
                
            end
            if depth~=1 then
                 AppendResult(strfmt("%s},",SpaceFindTable[nspace]))
            end
        end
        
    end

    write_one("", formatdata.data, 0, 1)

    AppendResult("}\r\nreturn M\r\n")
    return tbconcat(result,"\r\n")
end

for sysName, sysFormatData in pairs(formatdatas) do
    for fileName, formatdata in pairs(sysFormatData) do
        local content = write(fileName, formatdata)
        -- print(content)
        if #content >0 then
            local ret,errinfo = load(content, fileName..".lua")
            if ret == nil then 
                -- WriteFile(fs.join(OutputClientDir,fileName..".lua"), content)
                error(errinfo)
            end 
            local fn = ret
            publishdata[sysName][fileName] = {data = fn(), content = content}
        end
    end
end

local filter = {}

for systemname, data in pairs(publishdata) do
    for name,v in pairs(data) do 
        local fn = filter[name]
        if fn then
            print("prepare", name)
            fn(v)
        end
        if systemname == "c" then
            print("write",fs.join(OutputClientDir,name..".lua"))
            WriteFile(fs.join(OutputClientDir,name..".lua"), v.content)
        else
            print("write",fs.join(OutputServerDir,name..".lua"))
            WriteFile(fs.join(OutputServerDir,name..".lua"), v.content)
        end
    end
end

-- for name, v in pairs(publishdata) do
--     local fn = filter[name]
--     if fn then
--         print("prepare", name)
--         fn(v)
--     end
--     writefile(fs.join(OutputDir,name..".lua"), v.content)
--     -- writefile(fs.join(OutputClientDir,name..".lua"), v.content)
-- end
print("Export server config cost", (os.clock() - st).."s")
