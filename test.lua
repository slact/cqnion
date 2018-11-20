local Master = require "cqnion.master"
local cqueues = require "cqueues"
Master.initialize()


for i=1,10 do
  print("yeah!")
  assert(Master.spawnWorker("worker"))
end

Master.controller:wrap(function()
  cqueues.sleep(10)
end)

assert(Master.loop())
