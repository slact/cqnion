local Messenger = require "cqnion.messenger"
local Thread = require "cqueues.thread"
local Cqueues = require "cqueues"
local mm = require "mm"
local Master = {
  workers = {}
}

function Master.initialize(cq)--nothing to do
  cq = cq or Cqueues.new()
  assert(Cqueues.type(cq) == "controller", "cqueue controller required")
  Master.controller = cq
  return Master
end

function Master.spawnWorker(name, chunk, ...)
  local err
  if type(name) == "function" then
    name, chunk = "", name
  end
  local t, args = nil, {...}
  for _, v in ipairs(args) do
    t = type(v)
    if t ~= "string" and t ~= "boolean" and t ~= "number" then
      return nil, "can't pass anything to worker other than strings, numbers, and booleans."
    end
  end
  
  if type(name)~="string" then
    return nil, "worker name must be a string"
  end
  if chunk == nil then
    if #name > 0 then
      chunk = name .. ".lua"
    else
      err = "can't load worker code -- no name or path given"
    end
  end
  
  if type(chunk)=="string" then --try to loadfile
    chunk, err = loadfile(chunk)
  end
  if not chunk then
    return nil, err
  end
  
  if type(chunk)~="function" then
    return nil, "worker must be a function or chunk"
  end
  
  --make sure the chunk has no upvalues and accepts no parameters
  local info = debug.getinfo(chunk)
  if (info.nparams or 0) > 0 then
      -- parameter count is visible only in Lua >= 5.2. Don't error out for 5.1
    return nil, "worker function must not accept any arguments"
  end
  if info.nups ~= nil and info.nups > 0 then
    local i, ups = 1, {}
    while i do
      local up, val = debug.getupvalue(chunk, i)
      if up then
        if up ~= "_ENV" then -- Lua >= 5.2 inserts this upvalue automatically. doesn't mean the code uses it, so don't error out from its presence
          table.insert(ups, up)
        end
        i=i+1
      else
        i = nil
      end
    end
    if #ups > 0 then
      return nil, ("worker function or chunk may not have any upvalues, but found %i: %s"):format(#ups, table.concat(ups, ", "))
    end
  end
  
  local function thread_spawner(socket, thread_chunk, worker_number, worker_name, ...)
    -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    -- no upvalues, closures, or requires will be available in here.
    -- tread this as if it's been started in a new Lua VM -- which is
    -- exactly what happens
    -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    local arg = {...}
    local ok, err = xpcall( function()
      local Worker = require "cqnion.worker"
      Worker.initialize(socket, worker_number, worker_name, unpack(arg))
      thread_chunk()
    end, debug.traceback)
    if not ok then
      io.stderr:write(err)
    end
  end
  
  local slot = #Master.workers+1
  
  local thread, socket, err = Thread.start(thread_spawner, chunk, slot, name, ...)
  if not thread then
    print(thread, socket, err)
    return nil, err
  else
    return thread, socket
  end
  
  table.insert(Master.workers, thread)
  
  Master.controller:wrap(function()
  print("wait on thread")
    local ret, err = thread:join()
    if not ret then io.stderr:write(("%s\n"):format(err)) end
    for k, v in pairs(Master.workers) do
      if v == thread then
        table.remove(thread)
      end
    end
  end)
  
end

function Master.loop()
  return Master.controller:loop()
end

return Master
