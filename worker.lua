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
  
  thread:setMessageHandler(function(msgtype, data, fd)
    print("thread "..self.number.." got msg:", msgtype, data, fd)
  end)
  
  thread:wrap(function()
    local n = 0
    while true do
      sleep(3)
      local msg = "idea number "..n
      print("msg size: ", #msg)
      thread:sendMessage("idea", "idea number "..n)
      --print("thread ".. thread.number .. ":" .. n)
      n=n+1
    end
  end)
end
