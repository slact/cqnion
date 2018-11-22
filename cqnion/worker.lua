local Messenger = require "cqnion.messenger"
local Thread = require "cqueues.thread"
local Socket = require "cqueues.socket"
local Cqueues = require "cqueues"
local Util = require "cqnion.util"

local Worker = {}
local initialized = false

function Worker.initialize(messaging_socket, number, name, ...)
  assert(not initialized, "worker is already initialized")
  initialized = true
  local thread = Thread.self()
  assert(thread, "Cannot initialize non-thread as a cqnion worker")
  assert(Socket.type(messaging_socket)=="socket", "messaging_socket must be a cqueues socket")
  Worker.thread = thread
  Worker.args = {...}
  
  
  Worker.number = tonumber(number)
  
  assert(type(number) == "number", "worker number invalid")
  if select("#", ...) ~= #Worker.args then
    --we've got nils in the args. this is disallowed because all args past the nil may be silently inaccessible
    error("worker args with nils are forbidden")
  end
  Worker.name = tostring(name) or ""
  if thread.setname then
    thread:setname(("%i%s%s"):format(Worker.number, #Worker.name>0 and ": " or "", Worker.name))
  end
  Worker.master_socket = messaging_socket
  Worker.controller = Cqueues.new()
  assert(Messenger.setController(Worker.controller))
  assert(Messenger.registerSocket(Worker.master_socket))
  return Worker
end
  
function Worker.setMessageHandler(handler)
  return Messenger.setReceiver(handler)
end

function Worker.messageMaster(message_type, message, ...)
  if message_type=="socket" then
    local socket_to_send = ...
    return Messenger.sendSocket(Worker.master_socket, socket_to_send, message)
  else
    return Messenger.send(Worker.master_socket, message_type, message)
  end
end

--Execute function inside a new cqueues coroutine, making it asynchronous
function Worker.async(func)
  assert(type(func) == "function", "function expected")
  return Util.wrap(Worker.controller, func)
end


function Worker.loop()
  return Worker.controller:loop()
end

return Worker
