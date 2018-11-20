local Thread = require "cqueues.thread"
local mm = require "mm"
local Threadpool = {}

function Threadpool.new(cq, num, thread_module_name)
  assert(cq, "cqueues object mising")
  local tp = setmetatable({
    cq = cq,
    threads = {},
    thread_count = 0
  }, Threadpool._mt)
  tp:setSize(num)
  tp:setThread(thread_module_name)
  return tp
end


--[[
ipc message format:

{MSGTYPE} {MSGLENGTH}\n
{MSGDATA}

if MSGTYPE == "socket" then
  MSGLENGTH must be 0
  instead of MSGDATA a socket is sent via sendfd(), and received via recvfd()
]]

local function ipc_send_msg(socket, src_thread_number, msgtype, msg)
  assert(type(src_thread_number) == "number" and src_thread_number >= 0)
  assert(type(msgtype) == "string")
  msg = tostring(msg)
  assert(type(msg) == "string")
  local header = ("%s src:%d sz:%d\n"):format(msgtype, src_thread_number, #msg)
  socket:send(header, 1, #header)
  socket:send(msg, 1, #msg)
  socket:send("\n", 1, 1)
end
local function ipc_send_socket(socket, src_thread_number, socket_to_send, msg)
  msg = msg or ""
  assert(type(src_thread_number) == "number" and src_thread_number >= 0)
  assert(type(msg) == "string")
  assert(#msg < 1024)
  socket:send(("socket src:%d sz:0\n"):format(src_thread_number), 1, -1)
  return socket:sendfd(msg, socket_to_send)
end

local function ipc_receive(socket)
  local header, msgtype, src, size, data, fd, src, err
  header, err = socket:read("*l")
  if not header then return nil, nil, nil, err end
  print("HDR:<"..header..">")
  msgtype, src, size = header:match("^(%w+) src:(%d+) sz:(%d+)$")
  size = tonumber(size)
  src = tonumber(src)
  assert(msgtype and size and src)
  if msgtype == "socket" then
    data, fd, err = socket:recvfd(1024)
  else
    data, err = socket:read(size+1) --+1 for trailing newline
  end
  
  if data ~= nil then
    return msgtype, data, fd
  else
    return nil, nil, nil, err
  end
end


local function set_message_handler(self, handler)
  assert(type(handler)=="function")
  self.__msg_handler = handler
  return self
end

local function ipc_yield_for_message(self, socket)
  local coro, is_main = coroutine.running()
  if is_main == true then
    coro = nil
  end
  assert(coro, "must be run from coroutine")
  if not self.__msg_coroutines then
    self.__msg_coroutines = {}
  end
  table.insert(self,__msg_coroutines, coro)
  return coroutine.yield()
end

local function ipc_socket_receiver_generator(self, socket)
  return function()
    local msgtype, data, fd, err
    while not err do
      msgtype, data, fd, err = ipc_receive(socket)
      if self.__msg_coroutines then
        local coros = self.__msg_coroutines
        self.__msg_coroutines = nil
        for _, coro in pairs(coros) do
          coroutine.resume(msgtype, data, fd, err)
        end
      end
      if self.__msg_handler then
        self.__msg_handler(thread, msgtype, data, fd)
      end
    end
  end
end

local thread_mt = {__index = {
  setMessageHandler = set_message_handler,
  receiveMessage = ipc_yield_for_message,
  sendMessage = function(self, msgtype, msg)
    return ipc_send_msg(self.socket, self.number, msgtype, msg)
  end,
  sendSocket = function(self, socket, msg)
    return ipc_send_socket(self.socket, self.number, socket, msg)
  end,
  run = function(self)
    local ret, err, etc = self.cq:loop()
    return ret, err, etc
  end,
  wrap = function(self, func)
    assert(type(func) == "function", "expected to wrap a function")
    return self.cq:wrap(function()
      xpcall(func, function(errmsg)
        errmsg = ("\27[91;1mError in thread %d: %s\27[31;2m"):format(self.number, errmsg)
        io.stderr:write(("%s\27[0m\n"):format(debug.traceback(errmsg, 1)))
      end)
    end)
  end,
  attach = function(self, coro)
    assert(type(coro) == "thread", "expected to attach a coroutine")
    return self.cq:attach(coro)
  end
}}

function Threadpool.newThread(socket, threadnum)
  local cqueues = require "cqueues"
  local cqueue_thread = Thread.self()
  assert(cqueue_thread, "called newThread outside of a thread. That's not how it's supposed to work")
  local cq = cqueues.new()
  if cqueue_thread.setname then
    cqueue_thread:setname("thread "..threadnum)
  end
  
  local self = setmetatable({
    cq = cq,
    socket = socket,
    number = threadnum,
    thread = cqueue_thread,
  }, thread_mt)
  --thread socketpair receiver
  self.cq:wrap(ipc_socket_receiver_generator(self, socket))
  return self
end


Threadpool._mt = {__index = {
  setThread = function(self, thread_module_name)
    assert(type(thread_module_name) == "string")
    self.thread_module_name = thread_module_name
    return self
  end,
  
  -- set the expected number of threads to maintain
  setSize = function(self, n)
    assert(type(n) == "number")
    self.max_thread_count = n
    return self
  end,
  
  run = function(self)
    assert(self.max_thread_count > 0, "max_thread_count is not set")
    assert(self.thread_module_name, "thread module name not set")
    while self.thread_count <= self.max_thread_count do
      self:spawn()
    end
    return self
  end,
  
  setMessageHandler = set_message_handler,
  receiveMessage = ipc_yield_for_message,
  -- add a single thread to thread pool
  -- if slot is present, replaces thread at that index
  spawn = function(self, slot, ...)
    if self.thread_count > self.max_thread_count then
      return nil, "no need to spawn any more threads"
    end
    if slot then
      assert(type(slot) == "number" and slot > 0 and slot <= self.max_thread_count)
      assert(self.threads[slot] == nil, "tried spawning thread in nonempty slot")
    else
      slot = self.thread_count + 1
    end
    local thread_spawn = function(socket, num, thread_worker_module, ...)
      -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      -- no upvalues, closures, or requires will be available in here.
      -- tread this as if it's been started in a new Lua VM -- which is
      -- exactly what happens
      -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      local Threadpool = require "cqworkers.pool"
      local worker = require(thread_worker_module)
      local thread = Threadpool.newThread(socket, num)
      worker(thread, ...)
      assert(pcall(thread.run, thread))
    end
    
    local thread, socket, err = Thread.start(thread_spawn, slot, self.thread_module_name, ...)
    assert(thread, err)
    self.thread_count = self.thread_count + 1
    self.threads[slot] = {
      thread = thread,
      socket = socket
    }
    
    --thread socketpair receiver
    self.cq:wrap(ipc_socket_receiver_generator(self, socket))
    
    --thread termination watcher
    self.cq:wrap(function()
      local done, err, msg
      repeat
        done, err, msg = thread:join()
        print("thread done?", done, err, msg)
      until done
      if err then
        io.stderr:write(("thread error %d: %s\n"):format(my_num, tostring(err)))
      end
    end)
  end,
  
  sendMessage = function(self, dst, msgtype, msg)
  
  end,
  sendSocket = function(self, dst, socket, msg)
  
  end,
  broadcastMessage = function(self, msgtype, msg)
  
  end,
  broadcastSocket = function(self, socket, msg)
  
  end,
  
  
  
}}

return Threadpool
