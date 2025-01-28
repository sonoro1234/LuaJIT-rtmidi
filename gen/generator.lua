package.path = package.path.."../../LuaJIT-ImGui/cimgui/generator/?.lua"
--package.path = package.path.."../../anima/LuaJIT-ImGui/cimgui/generator/?.lua"
local cp2c = require"cpp2ffi"
local parser = cp2c.Parser()

local defines = {}

cp2c.save_data("./outheader.h",[[#include <rtmidi_c.h>]])

defines = parser:take_lines([[gcc -E -dD -I ../rtmidi/ ./outheader.h]],{"rtmidi.-"},"gcc")


os.remove"./outheader.h"

---------------------------
parser:do_parse()


local cdefs = {}
for i,it in ipairs(parser.itemsarr) do
	table.insert(cdefs,it.item)
end


local deftab = {}
---[[
local ffi = require"ffi"
ffi.cdef(table.concat(cdefs,""))
local wanted_strings = {"."}
for i,v in ipairs(defines) do
	local wanted = false
	for _,wan in ipairs(wanted_strings) do
		if (v[1]):match(wan) then wanted=true; break end
	end
	if wanted then
		local lin = "static const int "..v[1].." = " .. v[2] .. ";"
		local ok,msg = pcall(function() return ffi.cdef(lin) end)
		if not ok then
			print("skipping def",lin)
			print(msg)
		else
			table.insert(deftab,lin)
		end
	end
end
--]]

local LUAFUNCS = ""

local function genfun(fun,typef,cast)
	local cname = fun.funcname:gsub("rtmidi_","")
	local code = "\nfunction "..typef..":"..cname.."("
	local codeargs = ""
	for i=2,#fun.argsT do
		codeargs = codeargs..fun.argsT[i].name..", "
	end
	codeargs = codeargs:gsub(", $","") --delete last comma
	code = code..codeargs..")\n"
	local retcode
	if not cast then
		retcode = "lib."..fun.funcname.."(self"
	else
		retcode = "lib."..fun.funcname.."(ffi.cast(\"RtMidiPtr\",self)"
	end
	if #codeargs==0 then
		retcode = retcode ..")"
	else
		retcode = retcode..","..codeargs..")"
	end
	if fun.ret:match("char") then
		retcode = "    local ret = "..retcode
		retcode = retcode.."\n    if ret==nil then return nil else return ffi.string(ret) end"
	else
		retcode = "    return "..retcode
	end
	code = code .. retcode.. "\nend"
	LUAFUNCS = LUAFUNCS..code
end

local skipedfuncs = {
	rtmidi_get_port_name = true,
	rtmidi_in_free = true,
	rtmidi_out_free = true,
}
cp2c.table_do_sorted(parser.defsT, function(k,v)
--for k,v in pairs(parser.defsT) do
	assert(not v[2],"overloadeing in C?")
	local fun = v[1]
	if fun.argsT[1] then
		if (fun.argsT[1].type  =="RtMidiPtr" or fun.argsT[1].type  =="RtMidiInPtr" or fun.argsT[1].type  =="RtMidiOutPtr") and not skipedfuncs[fun.funcname] then
			local type = fun.argsT[1].type
			if type == "RtMidiPtr" then 
				genfun(fun,"RtMidiInPtr")
				genfun(fun,"RtMidiOutPtr",true)
			else
				genfun(fun,type)
			end
		end
	end
--end
end)

local template = cp2c.read_data("./template.lua")
local CDEFS = table.concat(cdefs,"")
CDEFS = CDEFS:gsub("typedef struct RtMidiWrapper%* RtMidiOutPtr;","typedef struct RtMidiWrapperOut* RtMidiOutPtr;")
local DEFINES = "\n"..table.concat(deftab,"\n")

template = template:gsub("CDEFS",CDEFS)
template = template:gsub("DEFINES",DEFINES)
template = template:gsub("LUAFUNCS",LUAFUNCS)


cp2c.save_data("./rtmidi_ffi.lua",template)
cp2c.copyfile("./rtmidi_ffi.lua","../rtmidi_ffi.lua")

