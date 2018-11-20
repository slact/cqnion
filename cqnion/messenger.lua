local Thread = require "cqueues.thread"
local Cqueues = require "cqueues"
local Socket = require "cqueues.socket"

--[[
ipc message format:

{MSGTYPE} sz:{MSGLENGTH}\n
{MSGDATA}

if MSGTYPE == "socket" then
  MSGLENGTH must be 0
  instead of MSGDATA a socket is sent via sendfd(), and received via recvfd()
]]

local Messenger = {
  sockets = {}
}

local function receive_message(socket)
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

local function get_controller()
  local cq = Messenger.controller
  if not cq then
    return nil, "Messenger controller not set"
  end
  if Cqueues.type(cq) ~= "controller" then
    return nil, "Messenger controller invalid"
  end
  return cq
end

function Messenger.setController(cq)
  assert(Cqueues.type(cq) == "controller", "argument must be a cqueues controller object")
  Messenger.controller = cq
  return Messenger
end

function Messenger.setReceiver(receiver)
  assert(type(receiver)=="function", "message receiver must be a function")
  Messenger.receiver = receiver
  return Messenger
end

function Messenger.registerSocket(socket)
  assert(Socket.type(socket) == "socket", "argument must be a cqueues socket")
  local cq = assert(get_controller())
  Messenger.sockets[socket]=true
  cq:wrap(function()
    local receiver = Messenger.receiver
    local registered = Messenger.sockets[socket]
    local msgtype, data, received_socket, err = receive_message(socket)
    if err then
      print("receiver error:".. tostring(err))
      error(err)
    elseif registered and receiver then
      receiver(msgtype, data, received_socket)
    end
  end)
  return Messenger
end

function Messenger.send(dst_socket, msgtype, msg)
  assert(Socket.type(dst_socket) == "socket", "dst_socket must be a cqueues socket")
  assert(type(msgtype) == "string")
  msg = tostring(msg)
  if msgtype == "socket" then
    return nil, "\"socket\" messages must be sent via sendSocket"
  end
  assert(type(msg) == "string")
  local header = ("%s sz:%d\n"):format(msgtype, #msg)
  return dst_socket:write(header, msg, "\n")
end

function Messenger.sendSocket(dst_socket, socket, msg)
  assert(Socket.type(dst_socket) == "socket", "dst_socket must be a cqueues socket")
  assert(Socket.type(socket) == "socket", "socket must be a cqueues socket")
  msg = msg or ""
  assert(type(msg) == "string")
  if #msg < 1024 then
    error("sendSocket message is too long (max: 1024 bytes, current: " .. #msg .. " bytes)")
  end
  local ret, err = socket:write(("socket sz:0\n"):format(src_thread_number))
  if not ret then
    return nil, err
  end
  return dst_socket:sendfd(msg, socket_to_send)
end

return Messenger
