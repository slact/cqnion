local cqueues = require "cqueues"
local Threadpool = require "threadpool"
local sleep = cqueues.sleep
local mm = require "mm"

local thread

return function(self, ...)
  thread = self
  ARGV = {...}
  print("start worker " .. thread.number)
  --TODO: do some work maybe?
  thread:wrap(function()
    local n = 0
    while true do
      sleep(10)
      --print("thread ".. thread.number .. ":" .. n)
      n=n+1
    end
  end)
end
