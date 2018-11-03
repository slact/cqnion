local Threadpool = require "threadpool"
local cqueues = require "cqueues"
local HttpServer = require "http.server"
local Websocket = require "http.websocket"

return function(cq, threadpool)
  assert(cq)
  
  threadpool:setMessageHandler(function(msgtype, data, fd)
    print("controller got msg", msgtype, data, fd)
  end)
  
  local myserver = assert(HttpServer.listen {
    cq = cq,
    host = "0.0.0.0";
    port = 7080;
    onstream = function(myserver,stream) -- luacheck: ignore 212
      print("hello new connection")
      local ws, err = Websocket.new_from_stream(stream, assert(stream:get_headers()))
      assert(ws, err)
      ws:accept()
      for k,v in ws:each() do
        print(k, v)
      end
    end,
    onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
      local msg = op .. " on " .. tostring(context) .. " failed"
      if err then
        msg = msg .. ": " .. tostring(err)
      end
      assert(io.stderr:write(msg, "\n"))
    end;
  })

  -- Manually call :listen() so that we are bound before calling :localname()
  assert(myserver:listen())
  local bound_port = select(3, myserver:localname())
  assert(io.stderr:write(string.format("Now listening on port %d\n", bound_port)))
  
  assert(threadpool:run())
  assert(cq:loop())
end
