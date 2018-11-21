

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

function Util.type(val)
  local t = type(val)
  if t == "userdata" then
    return userdata_type(val)
  else
    return t
  end
end

function Util.wrap(controller, func)
  controller:wrap(function()
    local ok, err = xpcall(func, trace)
    if not ok then
      io.stderr:write(err)
    end
  end)
  return true  
end

return Util
