#!/bin/lua
--[[
A simple HTTP server
If a request is not a HEAD method, then reply with "Hello world!"
Usage: lua examples/server_hello.lua [<port>]
]]
local port = arg[1] or 7080 -- 0 means pick one at random
local cqueues = require "cqueues"
local cq = cqueues.new()
local Pool = require "cqworkers.pool"
local Controller = require "controller"
local threadpool = Pool.new(cq, 10, "worker")

Controller(cq, threadpool)
