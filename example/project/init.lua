#!/usr/bin/env tarantool

require('strict').on()

if package.setsearchroot ~= nil then
    package.setsearchroot()
else
    -- Workaround for rocks loading in tarantool 1.10
    -- It can be removed in tarantool > 2.2
    -- By default, when you do require('mymodule'), tarantool looks into
    -- the current working directory and whatever is specified in
    -- package.path and package.cpath. If you run your app while in the
    -- root directory of that app, everything goes fine, but if you try to
    -- start your app with "tarantool myapp/init.lua", it will fail to load
    -- its modules, and modules from myapp/.rocks.
    local fio = require('fio')
    local app_dir = fio.abspath(fio.dirname(arg[0]))
    print('App dir set to ' .. app_dir)
    package.path = app_dir .. '/?.lua;' .. package.path
    package.path = app_dir .. '/?/init.lua;' .. package.path
    package.path = app_dir .. '/.rocks/share/tarantool/?.lua;' .. package.path
    package.path = app_dir .. '/.rocks/share/tarantool/?/init.lua;' .. package.path
    package.cpath = app_dir .. '/?.so;' .. package.cpath
    package.cpath = app_dir .. '/?.dylib;' .. package.cpath
    package.cpath = app_dir .. '/.rocks/lib/tarantool/?.so;' .. package.cpath
    package.cpath = app_dir .. '/.rocks/lib/tarantool/?.dylib;' .. package.cpath
end

local cartridge = require('cartridge')
local membership = require('membership')
local log = require("log")
local ok, err = cartridge.cfg({
    workdir = 'tmp/db',
    roles = {
        'cartridge.roles.vshard-storage',
        'cartridge.roles.vshard-router',
        'cartridge.roles.metrics',
        'app.roles.custom'
    },
    cluster_cookie = 'project-cluster-cookie',
})

assert(ok, tostring(err))

local all = {
    'vshard-storage',
    'vshard-router',
    'metrics',
    'app.roles.custom'
}

local _, err = cartridge.admin_join_server({
    uri = membership.myself().uri,
    roles = all,
})

if err ~= nil then
    log.warn('%s', tostring(err))
else
    local _, err = cartridge.admin_bootstrap_vshard()
    if err ~= nil then
        log.error('%s', tostring(err))
        os.exit(1)
    end

    -- This code is only for example purposes
    -- DO NOT USE IT IN PROD CLUSTERS WITH MORE THAN 1 INSTANCE!
    cartridge.config_patch_clusterwide({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
                {
                    path = '/metrics/prometheus',
                    format = 'prometheus'
                }
            }
        }
    })
end

