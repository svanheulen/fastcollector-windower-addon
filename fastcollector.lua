--[[
Copyright (c) 2014, Seth VanHeulen
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--]]

-- addon information

_addon.name = 'fastcollector'
_addon.version = '1.0.3'
_addon.command = 'fastcollector'
_addon.commands = {'fc'}
_addon.author = 'Seth VanHeulen (Acacia@Odin)'

-- modules

config = require('config')
res = require('resources')
require('sets')

-- default settings

defaults = {}
defaults.safe = true
defaults.storage = true
defaults.locker = true
defaults.satchel = true
defaults.sack = true
defaults.case = true
defaults.forcenomad = false
defaults.delay = 2
defaults.ignore = {
    ['01']='Linkshell', ['02']='Linkpearl', ['03']='Pearlsack',
    ['04']="Beastmen's Seal", ['05']="Kindred's Seal", ['06']="Kindred's Crest", ['07']='H. Kindred Crest', ['08']='S. Kindred Crest',
    ['09']='Warp Ring', ['10']='Mecisto. Mantle', ['11']='Capacity Ring'
}
defaults.sets = {}
defaults.sets.empty = {}

settings = config.load(defaults)

current_bag = nil

function next_bag()
    if current_bag == nil then
        current_bag = 1
        if not settings.safe or not windower.ffxi.get_bag_info(1).enabled then
            next_bag()
        end
    elseif current_bag == 1 then
        current_bag = 4
        if not settings.locker or not windower.ffxi.get_bag_info(4).enabled then
            next_bag()
        end
    elseif current_bag == 2 then
        current_bag = 5
        if not settings.satchel or not windower.ffxi.get_bag_info(5).enabled then
            next_bag()
        end
    elseif current_bag == 4 then
        current_bag = 2
        if not settings.storage or not windower.ffxi.get_bag_info(2).enabled then
            next_bag()
        end
    elseif current_bag == 5 then
        current_bag = 6
        if not settings.sack or not windower.ffxi.get_bag_info(6).enabled then
            next_bag()
        end
    elseif current_bag == 6 then
        current_bag = 7
        if not settings.case or not windower.ffxi.get_bag_info(7).enabled then
            next_bag()
        end
    elseif current_bag == 7 then
        current_bag = nil
    end
end

function put_away()
    local moved = 0
    local dest_items = windower.ffxi.get_items(current_bag)
    local dest_space = dest_items.max - dest_items.count
    for inv_slot,inv_item in pairs(windower.ffxi.get_items(0)) do
        if dest_space < 1 then
            break
        end
        if type(inv_item) == 'table' and inv_item.id ~= 0 and inv_item.status == 0 and not item_set:contains(res.items[inv_item.id].name) and not ignore:contains(res.items[inv_item.id].name) then
            windower.ffxi.put_item(current_bag, inv_slot, inv_item.count)
            dest_space = dest_space - 1
            moved = moved + 1
        end
    end
    if moved == 0 then
        get_out()
    else
        windower.add_to_chat(200, 'stored %s item(s) in your %s':format(moved, res.bags[current_bag].name:lower()))
        windower.send_command('wait %s; lua i fastcollector get_out':format(settings.delay))
    end
end

function get_out()
    local moved = 0
    local inv_items = windower.ffxi.get_items(0)
    local inv_space = inv_items.max - inv_items.count
    for src_slot,src_item in pairs(windower.ffxi.get_items(current_bag)) do
        if inv_space < 1 then
            break
        end
        if type(src_item) == 'table' and src_item.id ~= 0 and src_item.status == 0 and item_set:contains(res.items[src_item.id].name) then
            windower.ffxi.get_item(current_bag, src_slot, src_item.count)
            inv_space = inv_space - 1
            moved = moved + 1
        end
    end
    if moved == 0 then
        next_bag()
        if current_bag then
            put_away()
        else
            windower.add_to_chat(200, 'collection complete')
            windower.send_command('input /heal on')
        end
    else
        windower.add_to_chat(200, 'retrieved %s item(s) from your %s':format(moved, res.bags[current_bag].name:lower()))
        windower.send_command('wait %s; lua i fastcollector put_away':format(settings.delay))
    end
end

function fastcollector_command(...)
    if curent_bag ~= nil then
        windower.add_to_chat(167, 'wait for collection to complete')
    elseif #arg == 0 then
        windower.add_to_chat(167, 'usage:')
        windower.add_to_chat(167, '  fc make <set name>')
        windower.add_to_chat(167, '  fc list [set name]')
        windower.add_to_chat(167, '  fc <set name> [set name] ...')
    elseif #arg == 2 and arg[1]:lower() == 'make' then
        local set_name = arg[2]:lower()
        if settings.sets[set_name] then
            windower.add_to_chat(167, 'existing set: ' .. set_name)
        else
            windower.add_to_chat(204, 'making set: ' .. set_name)
            local new_set = {}
            ignore = S(settings.ignore)
            for _,item in pairs(windower.ffxi.get_items().inventory) do
                if type(item) == 'table' and item.id ~= 0  and not ignore:contains(res.items[item.id].name) then
                    table.insert(new_set, res.items[item.id].name)
                end
            end
            settings.sets[set_name] = new_set
            settings:save()
        end
    elseif (#arg == 1 or #arg == 2) and arg[1]:lower() == 'list' then
        if #arg == 1 then
            windower.add_to_chat(204, 'available sets:')
            for k,v in pairs(settings.sets) do
                windower.add_to_chat(204, '  ' .. k)
            end
        else
            local set_name = arg[2]:lower()
            if settings.sets[set_name] == nil then
                windower.add_to_chat(167, 'unknown set: ' .. set_name)
            else
                windower.add_to_chat(204, 'equipment in %s:':format(set_name))
                for k,v in pairs(settings.sets[set_name]) do
                    windower.add_to_chat(204, '  ' .. v)
                end
            end
        end
    else
        item_set = S{}
        ignore = S(settings.ignore)
        for _,set_name in ipairs(arg) do
            if settings.sets[set_name] then
                for _,item_name in pairs(settings.sets[set_name]) do
                    item_set[item_name] = true
                end
            else
                windower.add_to_chat(167, 'unknown set: ' .. set_name)
            end
        end
        next_bag()
        if current_bag then
            windower.add_to_chat(200, 'collection started')
            for i = 0,15 do
                windower.ffxi.set_equip(0, i, 0)
            end
            windower.send_command('wait %s; lua i fastcollector put_away':format(settings.delay))
        else
            windower.add_to_chat(167, 'no bags enabled')
        end
    end
end

windower.register_event('addon command', fastcollector_command)
