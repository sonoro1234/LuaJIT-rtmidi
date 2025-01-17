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




