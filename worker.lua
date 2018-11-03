local cqueues = require "cqueues"
local Threadpool = require "threadpool"
local sleep = cqueues.sleep


local Worker = {}

local ipc_socket, worker_slot
local cq
local ARGV

local function worker_ipc_receiver(msg)
  for ln in ipc_socket:lines() do
    print("i got IPC message")
  end
end

return function(socket, num, ...)
  ipc_socket = socket
  worker_slot = num
  cq = cqueues.new()
  ARGV = {...}
  
  cq:wrap(worker_ipc_receiver)
  --TODO: do some work maybe?
  cq:wrap(function()
    local n = 0
    while true do
      sleep(0.2)
      print("thread ".. worker_slot .. ":" .. n)
      n=n+1
    end
  end)
  
  cq:loop()
end
