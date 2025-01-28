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

ffi.cdef[[
struct RtMidiWrapper {
    void* ptr;
    void* data;
   _Bool          ok;
    const char* msg;
};
typedef struct RtMidiWrapper* RtMidiPtr;
typedef struct RtMidiWrapper* RtMidiInPtr;
typedef struct RtMidiWrapperOut* RtMidiOutPtr;
enum RtMidiApi {
    RTMIDI_API_UNSPECIFIED,
    RTMIDI_API_MACOSX_CORE,
    RTMIDI_API_LINUX_ALSA,
    RTMIDI_API_UNIX_JACK,
    RTMIDI_API_WINDOWS_MM,
    RTMIDI_API_RTMIDI_DUMMY,
    RTMIDI_API_WEB_MIDI_API,
    RTMIDI_API_WINDOWS_UWP,
    RTMIDI_API_ANDROID,
    RTMIDI_API_NUM
};
enum RtMidiErrorType {
  RTMIDI_ERROR_WARNING,
  RTMIDI_ERROR_DEBUG_WARNING,
  RTMIDI_ERROR_UNSPECIFIED,
  RTMIDI_ERROR_NO_DEVICES_FOUND,
  RTMIDI_ERROR_INVALID_DEVICE,
  RTMIDI_ERROR_MEMORY_ERROR,
  RTMIDI_ERROR_INVALID_PARAMETER,
  RTMIDI_ERROR_INVALID_USE,
  RTMIDI_ERROR_DRIVER_ERROR,
  RTMIDI_ERROR_SYSTEM_ERROR,
  RTMIDI_ERROR_THREAD_ERROR
};
typedef void(* RtMidiCCallback) (double timeStamp, const unsigned char* message,
                                 size_t messageSize, void *userData);
 const char* rtmidi_get_version();
 int rtmidi_get_compiled_api (enum RtMidiApi *apis, unsigned int apis_size);
 const char *rtmidi_api_name(enum RtMidiApi api);
 const char *rtmidi_api_display_name(enum RtMidiApi api);
 enum RtMidiApi rtmidi_compiled_api_by_name(const char *name);
 void rtmidi_error (enum RtMidiErrorType type, const char* errorString);
 void rtmidi_open_port (RtMidiPtr device, unsigned int portNumber, const char *portName);
 void rtmidi_open_virtual_port (RtMidiPtr device, const char *portName);
 void rtmidi_close_port (RtMidiPtr device);
 unsigned int rtmidi_get_port_count (RtMidiPtr device);
 int rtmidi_get_port_name (RtMidiPtr device, unsigned int portNumber, char * bufOut, int * bufLen);
 RtMidiInPtr rtmidi_in_create_default (void);
 RtMidiInPtr rtmidi_in_create (enum RtMidiApi api, const char *clientName, unsigned int queueSizeLimit);
 void rtmidi_in_free (RtMidiInPtr device);
 enum RtMidiApi rtmidi_in_get_current_api (RtMidiPtr device);
 void rtmidi_in_set_callback (RtMidiInPtr device, RtMidiCCallback callback, void *userData);
 void rtmidi_in_cancel_callback (RtMidiInPtr device);
 void rtmidi_in_ignore_types (RtMidiInPtr device,                                                           _Bool                                                                midiSysex,                                                                           _Bool                                                                                midiTime,                                                                                          _Bool                                                                                               midiSense);
 double rtmidi_in_get_message (RtMidiInPtr device, unsigned char *message, size_t *size);
 RtMidiOutPtr rtmidi_out_create_default (void);
 RtMidiOutPtr rtmidi_out_create (enum RtMidiApi api, const char *clientName);
 void rtmidi_out_free (RtMidiOutPtr device);
 enum RtMidiApi rtmidi_out_get_current_api (RtMidiPtr device);
 int rtmidi_out_send_message (RtMidiOutPtr device, const unsigned char *message, int length);]]

ffi.cdef[[
]]

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



function RtMidiInPtr:close_port()
    return lib.rtmidi_close_port(self)
end
function RtMidiOutPtr:close_port()
    return lib.rtmidi_close_port(ffi.cast("RtMidiPtr",self))
end
function RtMidiInPtr:get_port_count()
    return lib.rtmidi_get_port_count(self)
end
function RtMidiOutPtr:get_port_count()
    return lib.rtmidi_get_port_count(ffi.cast("RtMidiPtr",self))
end
function RtMidiInPtr:in_cancel_callback()
    return lib.rtmidi_in_cancel_callback(self)
end
function RtMidiInPtr:in_get_current_api()
    return lib.rtmidi_in_get_current_api(self)
end
function RtMidiOutPtr:in_get_current_api()
    return lib.rtmidi_in_get_current_api(ffi.cast("RtMidiPtr",self))
end
function RtMidiInPtr:in_get_message(message, size)
    return lib.rtmidi_in_get_message(self,message, size)
end
function RtMidiInPtr:in_ignore_types(midiSysex, midiTime, midiSense)
    return lib.rtmidi_in_ignore_types(self,midiSysex, midiTime, midiSense)
end
function RtMidiInPtr:in_set_callback(callback, userData)
    return lib.rtmidi_in_set_callback(self,callback, userData)
end
function RtMidiInPtr:open_port(portNumber, portName)
    return lib.rtmidi_open_port(self,portNumber, portName)
end
function RtMidiOutPtr:open_port(portNumber, portName)
    return lib.rtmidi_open_port(ffi.cast("RtMidiPtr",self),portNumber, portName)
end
function RtMidiInPtr:open_virtual_port(portName)
    return lib.rtmidi_open_virtual_port(self,portName)
end
function RtMidiOutPtr:open_virtual_port(portName)
    return lib.rtmidi_open_virtual_port(ffi.cast("RtMidiPtr",self),portName)
end
function RtMidiInPtr:out_get_current_api()
    return lib.rtmidi_out_get_current_api(self)
end
function RtMidiOutPtr:out_get_current_api()
    return lib.rtmidi_out_get_current_api(ffi.cast("RtMidiPtr",self))
end
function RtMidiOutPtr:out_send_message(message, length)
    return lib.rtmidi_out_send_message(self,message, length)
end

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




