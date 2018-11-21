local Master = require "cqnion.master"
local cqueues = require "cqueues"
Master.initialize()


for i=1,10 do
  assert(Master.spawnWorker("worker")) --runs ./worker.lua as a new cqueues thread
end

Master.setMessageHandler(function(...)
  print(...)
end)

Master.async(function()
  while true do
    cqueues.sleep(3)
    Master.messageWorkers("hello", "HEY GUYS")
  end
end)

assert(Master.loop())
