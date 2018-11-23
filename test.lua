local Master = require "cqnion.master"
local cqueues = require "cqueues"
Master.initialize()

function worker_func()
  local Worker = require "cqnion.worker"
  local Util = require "cqnion.util"
  local cqueues = require "cqueues"
  local sleep = cqueues.sleep

  print("start worker " .. Worker.number)
  --TODO: do some work maybe?

  Worker.controller:wrap(function()
    local n = 0
    while true do
      sleep(3)
      local msg = "idea number "..n
      --Worker.messageMaster("idea", "thread " .. Worker.number .. " says " .. msg)
      n=n+1
    end
  end)

  Worker.setMessageHandler(function(src_sock, msgtype, msg, sock)
    print("message from master: " .. msgtype .. " : "..msg)
  end)

  assert(Worker.controller:loop())
end

local Util = require "cqnion.util"

for i=1,10 do
  assert(Master.spawnWorker("worker", worker_func)) --runs ./worker.lua as a new cqueues thread
end

Master.setMessageHandler(function(...)
  print(...)
end)
local mm = require "mm"

Master.async(function()
  while true do
    cqueues.sleep(3)
    Master.messageWorkers("hello", "HEY GUYS")
  end
end)

Util.timer(Master.controller, 4, function(timer)
  print(mm(timer))
  print("time is ", os.time(), "timeout is ", timer.timeout)
  return timer.timeout - 1 >= 0 and timer.timeout - 1 or false
end)

assert(Master.loop())
