#!/bin/lua
--[[
A simple HTTP server
If a request is not a HEAD method, then reply with "Hello world!"
Usage: lua examples/server_hello.lua [<port>]
]]
local port = arg[1] or 7080 -- 0 means pick one at random
local cqueues = require "cqueues"
local cq = cqueues.new()
local Threadpool = require "threadpool"
local Controller = require "controller"
local threadpool = Threadpool.new(cq, 10, "worker")

Controller(cq, threadpool)
assert(threadpool:run())
assert(cq:loop())
