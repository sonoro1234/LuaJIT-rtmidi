local ffi = require"ffi"
--uncomment to debug cdef calls
---[[
local ffi_cdef = function(code)
    local ret,err = pcall(ffi.cdef,code)
    if not ret then
        local lineN = 1
        for line in code:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
            lineN = lineN + 1
        end
        print(err)
        error"bad cdef"
    end
end
--]]

--to get different metatypes
ffi.cdef[[
struct RtMidiWrapperOut {
    void* ptr;
    void* data;
   _Bool          ok;
    const char* msg;
};
]]

ffi.cdef[[CDEFS]]

ffi.cdef[[DEFINES]]

local lib = ffi.load"rtmidi"

local M = {C=lib}

local RtMidiInPtr = {}
RtMidiInPtr.__index = RtMidiInPtr

function RtMidiInPtr:__new(api, clientName, queueSizeLimit)
	local ret
	if not api then
		ret = lib.rtmidi_in_create_default()
	else
		clientName = clientName or "RtMidi Input Client"
		queueSizeLimit = queueSizeLimit or 100
		ret = lib.rtmidi_in_create(api,clientName,queueSizeLimit);
	end
	ffi.gc(ret,lib.rtmidi_in_free)
	return ret
end
function RtMidiInPtr:free()
    ffi.gc(self,nil)
    return lib.rtmidi_in_free(self)
end

local RtMidiOutPtr = {}
RtMidiOutPtr.__index = RtMidiOutPtr

function RtMidiOutPtr:__new(api, clientName)
	local ret
	if not api then
		ret = lib.rtmidi_out_create_default()
	else
		clientName = clientName or "RtMidi Output Client"
		ret = lib.rtmidi_out_create(api,clientName);
	end
	ffi.gc(ret,lib.rtmidi_out_free)
	return ret
end
function RtMidiOutPtr:free()
    ffi.gc(self,nil)
    return lib.rtmidi_out_free(self)
end

function RtMidiInPtr:get_port_name(portNumber)
	local bufLen = ffi.new("int[1]") 
    local ret = lib.rtmidi_get_port_name(self,portNumber, nil, bufLen)
	assert(ret == 0)
	local bufOut = ffi.new("char[?]", bufLen[0])
	ret = lib.rtmidi_get_port_name(self,portNumber, bufOut, bufLen)
	return ffi.string(bufOut)
end
function RtMidiOutPtr:get_port_name(portNumber, bufOut, bufLen)
	return RtMidiInPtr.get_port_name(ffi.cast("RtMidiPtr",self),portNumber)
end


LUAFUNCS

ffi.cdef[[typedef struct RtMidiWrapper rtmidiin_t;]]
M.rtmidi_in = ffi.metatype("rtmidiin_t",RtMidiInPtr)
ffi.cdef[[typedef struct RtMidiWrapperOut rtmidiout_t;]]
M.rtmidi_out = ffi.metatype("rtmidiout_t",RtMidiOutPtr)

local callback_t
local callbacks_anchor = {}
--typedef void(* RtMidiCCallback) (double timeStamp, const unsigned char* message,size_t messageSize, void *userData);
function M.MakeMidiCallback(func, ...)
	if not callback_t then
		local CallbackFactory = require "lj-async.callback"
		callback_t = CallbackFactory("void(*)(double*,const unsigned char*,size_t,void*)") --"RtAudioCallback"
	end
	local cb = callback_t(func, ...)
	table.insert(callbacks_anchor,cb)
	return cb:funcptr() , cb
end

function M.GetAllInfo()
	local rtmidi = M
	local I = {APInames={},APIdisplay_names={},API={},APIbyi={}}
	local api_count = rtmidi.get_compiled_api(nil,0)
	local apis_data = ffi.new("enum RtMidiApi[?]",api_count)
	rtmidi.get_compiled_api(apis_data, api_count);
	for i=1,api_count do
		local api = tonumber(apis_data[i-1])
		I.APInames[i] = ffi.string(rtmidi.api_name(api))
		I.APIdisplay_names[i] = ffi.string(rtmidi.api_display_name(api))
		I.APIbyi[i] = api
		local m_in = rtmidi.rtmidi_in(api)
		local nPorts = m_in:get_port_count();
		I.API[api] = {ins={},outs={}}
		for j=1,nPorts do
			I.API[api].ins[j] = ffi.string(m_in:get_port_name(j-1))
		end
		if nPorts == 0 then I.API[api].ins[1] = "none" end
		m_in:free()
		local m_out = rtmidi.rtmidi_out(api)
		local nPorts = m_out:get_port_count();
		for j=1,nPorts do
			I.API[api].outs[j] = ffi.string(m_out:get_port_name(j-1))
		end
		if nPorts == 0 then I.API[api].outs[1] = "none" end
		m_out:free()
	end
	return I
end


setmetatable(M,{
__index = function(t,k)
	local ok,ptr = pcall(function(str) return lib["rtmidi_"..str] end,k)
	if not ok then ok,ptr = pcall(function(str) return lib["RTMIDI_"..str] end,k) end 
	if not ok then error(k.." not found") end
	rawset(M, k, ptr)
	return ptr
end
})

-- require"anima.utils"
-- prtable(M.GetAllInfo())

return M




