local cqueues = require "cqueues"

local cqtype = {"cqueues", "cqueues.socket", "cqueues.signal", "cqueues.thread", "cqueues.notify", "cqueues.dns.record", "cqueues.dns.packet", "cqueues.dns.config", "cqueues.dns.hosts", "cqueues.dns.hints",  "cqueues.dns.resolver", "cqueues.dns.resolvers", "cqueues.condition", "cqueues.promise"}
for k, v in ipairs(cqtype) do
  cqtype[k] = require(v).type
end

local function userdata_type(val)
  local val_type
  for _, typer in ipairs(cqtype) do
    val_type = typer(val)
    if val_type ~= nil then
      return val_type
    end
  end
  return "userdata"
end

local Util = {}

local trace = debug.traceback

function Util.wrap(controller, func, opt)
  assert(type(func) == "function", "function expected")
  local silent = type(opt) == "table" and opt.silent
  controller:wrap(function()
    local ok, err = xpcall(func, trace)
    if not ok and not silent then
      io.stderr:write(err)
    end
  end)
  return true
end

local timer_mt = {__index = {
  cancel = function(self)
    self.halt = true
  end
}}

function Util.timer(controller, timeout_sec, func, opt)
  assert(type(timeout_sec)=="number" and timeout_sec > 0, "timeout should be a number of seconds")
  local self = setmetatable({
    timeout = timeout_sec,
    starttime = nil
  }, timer_mt)
  Util.wrap(controller, function()
    local timeout = timeout_sec
    local ret
    while not rawget(self, "halt") do
      rawset(self, "starttime", os.time())
      cqueues.sleep(timeout)
      ret = func(self)
      if type(ret) == "number" then
        --new, changed timeout
        if ret <= 0 then
          error("invalid negative number returned from timer function")
        elseif ret ~= timeout then
          timeout = ret
          rawset(self, "timeout", timeout)
        end
      elseif not ret then
        self.halt = true
      elseif ret ~= true then
        error("invalid return from timer function, expected nil, boolean, or number, got ".. Util.type(ret))
      end
    end
  end, opt)
  return self
end

function Util.type(val)
  local t = type(val)
  if t == "userdata" then
    return userdata_type(val)
  elseif t == "table" then
    local mt = getmetatable(val)
    if mt == timer_mt then
      return "timer"
    else
      return t
    end
  else
    return t
  end
end

return Util
