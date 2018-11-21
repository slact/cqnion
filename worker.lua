local Worker = require "cqnion.worker"
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
