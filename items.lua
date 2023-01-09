--[[
Copyright © 2018, Akaden
All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
* Neither the name of Dimmer nor the
names of its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.]]

_addon.name = 'Items'
_addon.author = 'Akaden; inspired by from20020516 and Chiaia'
_addon.version = '0.1'
_addon.commands = {'item', 'use', 'i'}


require('logger')
local extdata = require('extdata')
local res = require('resources')
local config = require('config')

local settings = config.load({
  order = {
    warp = {'Warp Ring', 'Instant Warp', 'Warp Cudgel'},
    rr = {"Pandit's Staff","Super Reraiser","Rebirth Feather","Dusty Reraise","Hi-Reraiser","Revive Feather","Instant Reraise","Reraiser","Scapegoat","Raphael's Rod","Mamool Ja Earring","Airmid's Gorget","Reraise Gorget","Reraise Hairpin","Kocco's Earring","Reraise Earring","Raising Earring","Reraise Ring","Wh. Rarab Cap +1",}
  },
  preferred_slots = {12, 14},
  bags = {5, 6 ,7}, -- satchel, sack, case
  gs_lock_command = 'gs disable',
  gs_unlock_command = 'gs enable',
  announce_delay = 3,
})

local language = string.lower(windower.ffxi.get_info().language)
-- language = language == 'english' and 'en' or 'ja'
local map = require('map')
local usable_bags = S{0,3} -- inventory or temp

local using_item = nil
local used_item = nil

local function get_user_slot(item)
  local found_slot
  local user_slots = S{table.unpack(settings.preferred_slots and settings.preferred_slots or {})}
  for s,_ in pairs(S(item.res.slots)) do
    if user_slots[s] then
      return s
    end
    found_slot = s
  end
  return found_slot
end

local function to_gs_name(slot)
  local slot_name = res.slots[slot].en
  return slot_name:gsub(' ', '_'):lower()
end
local function gs_lock(slot)
  windower.send_command(settings.gs_lock_command..' '..to_gs_name(slot))
end
local function gs_unlock(slot)
  windower.send_command(settings.gs_unlock_command..' '..to_gs_name(slot))
end

local function return_item(item)
  local inv_item = windower.ffxi.get_items(item.bag,item.slot)
  if item.equipped_slot then
    gs_unlock(item.equipped_slot)
    while inv_item.status == 5 do
      windower.ffxi.set_equip(0, item.equipped_slot, 0)
      coroutine.sleep(1)
      inv_item = windower.ffxi.get_items(item.bag,item.slot)
    end
  end

  if item.old_bag then
    repeat
      print('returning item')
      windower.ffxi.put_item(item.old_bag, item.slot)
      coroutine.sleep(2)
      inv_item = windower.ffxi.get_items(item.bag,item.slot)
    until not inv_item or inv_item.id ~= item.id 
  end
end

local function get_exact_item(item, bag)
  for _, check_item in ipairs(windower.ffxi.get_items(bag)) do
    if check_item and check_item.id == item.id and check_item.extdata == item.extdata then
      local new_item = table.copy(item)
      new_item.bag = bag
      new_item.slot = check_item.slot
      return new_item
    end
  end
  return nil
end

local function get_equipped_slot(item)
  local equipment = windower.ffxi.get_items().equipment
  for id, slot in pairs(res.slots) do
    local slot_key = slot.en:lower():gsub(' ', '_')
    local slot_slot = equipment[slot_key]
    local slot_bag = equipment[slot_key..'_bag']
    if slot_slot == item.slot and slot_bag == item.bag then
      return id
    end
  end
  return nil
end

local function use_item(item)
  if using_item then
    log('Item already in use: '..using_item[language])
    return
  end
  using_item = item

  if windower.ffxi.get_player().status > 1 then
      log('You cannot use items at this time.')
      return
  end

  if (item.res.category == 'Armor' and not res.bags[item.bag].equippable) or (item.res.category == 'Usable' and not usable_bags[item.bag]) then


    local count = 0
    local found_item
    repeat -- obtain the item
      -- TODO: check for resting to halt the process.

      local new_item = get_exact_item(item, 0)
      if new_item then
        -- item is in inventory
        found_item = new_item
      else
        local old_item = get_exact_item(item, item.bag)
        if old_item then
          log('Retrieving item: '..item[language])
          -- item's still there.
          windower.ffxi.get_item(item.bag, old_item.slot, 1)
        else
          -- MIA?
          log('cannot find item '..item[language])
          return
        end
      end
      coroutine.sleep(1)
    until found_item or count > 5

    if item.res.category == 'Armor' then
      found_item.old_bag = item.bag
    end
    item = found_item
  end

  local item_previously_equipped = false
  repeat --waiting cast delay
    
    -- TODO: check for resting to halt the process.

    local inv_item = windower.ffxi.get_items(item.bag,item.slot)
    if item.res.category == 'Armor' and inv_item.status ~= 5 then -- item is not equipped.
      if item_previously_equipped then
        log('Item has been unequipped. Re-equipping: '..item[language])
      else
        log('Equipping item: '..item[language])
      end
      local user_slot = get_user_slot(item)
      gs_lock(user_slot)
      item.equipped_slot = user_slot
      windower.ffxi.set_equip(item.slot, user_slot, item.bag)

      item_previously_equipped = true
    else
      local delay = 0
      if item.res.category == 'Armor' then
        item.equipped_slot = item.equipped_slot or get_equipped_slot(item)
        local ext = extdata.decode(inv_item)
        delay = ext.activation_time+18000-os.time()
      end

      if delay <= 0 then
        try_use_item = item
        windower.chat.input('/item "'..windower.to_shift_jis(item[language])..'" <me>')
      elseif delay <= settings.announce_delay then
        log('Using '..item[language]..' in '..delay..'s...')
      end
    end
    coroutine.sleep(1)
  until used_item
end

local function fuzzy_name(item_name)
  return item_name:lower()
end

local function item_match(item_id, item_table)
  if type(item_id) == 'number' then
    return item_id == item_table.id
  elseif type(item_id) == 'string' then
    local n = fuzzy_name(item_id)
    return n == fuzzy_name(res.items[item_table.id].en) or
           n == fuzzy_name(res.items[item_table.id].enl) or
           n == fuzzy_name(res.items[item_table.id].ja) or
           n == fuzzy_name(res.items[item_table.id].jal)
  end
  return false 
end

local function find_items(item_id)
  local available_items = T{}
  local all_bags = windower.ffxi.get_items()
  for bag_id, bag in pairs(res.bags) do
    if all_bags['enabled_'..bag.command] then
      for _, item in ipairs(all_bags[bag.command]) do
        if item_match(item_id, item) then
          local item_res = res.items[item.id]
          available_items:append({
            id = item.id,
            count = item.count,
            bag = bag_id,
            slot = item.slot,
            english = item_res.en,
            english_long = item_res.enl,
            japanese = item_res.jp,
            japanese_long = item_res.jpl,
            res = item_res,
            extdata = item.extdata,
            bazaar = bazaar ~= nil and bazaar > 0,
            status = item.status,
          })
        end
      end
    end
  end
  return available_items
end


local function item_is_usable(item)
  if item.res.category == 'Armor' then
    if item.res.jobs[windower.ffxi.get_player().main_job_id] then
      local ext = extdata.decode(item)
      local time_remaining = ext.charges_remaining and ext.charges_remaining > 0 and math.max(ext.next_use_time + 18000 - os.time(), 0)
      if time_remaining <= 0 then
        return true
      else
        return false
      end
    else
      return false
    end
  elseif item.res.category == "Usable" then
    return true
  end
  return false
end

local function handle_group(group_key)
  local group = map[group_key]
  local user_items = T{}
  local user_bags = S(settings.bags)

  local all_available_items = T{}
  -- add items from group that exist in accessible inventory
  for _, item_info in pairs(group) do
    local available_items = find_items(item_info.id)
    for _, item in ipairs(available_items) do
      if usable_bags[item.bag] or (user_bags[item.bag] and res.bags[item.bag].access == "Everywhere") or (item.res.category == 'Armor' and res.bags[item.bag].equippable) then
        -- this is in accessible inventory
        item.group = group_key
        all_available_items:append(item)
      end
    end
  end
  
  -- order/filter by user preferences
  if settings.order[group_key] then
    local ordered_items = T{}
    for _, item_id in ipairs(settings.order[group_key]) do
      for _, item in ipairs(all_available_items) do
        if item_match(item_id, item.res) then
          ordered_items:append(item)
        end
      end
    end
    all_available_items = ordered_items
  end

  local available_item = nil
  -- loop through ordered user_items and find one that's ready
  for _, item in ipairs(all_available_items) do 
    if not available_item then
      if item_is_usable(item) then
        available_item = item
      end
    end
  end

  if available_item then
    return use_item(available_item)
  else
    log('No item available for group: '..group_key)
    return false
  end
end

local function handle_specific_item(item_name)  
  local found_item = nil
  local all_available_items = find_items(item_name)
  for _, item in ipairs(all_available_items) do
    if not found_item then
      if usable_bags[item.bag] or (user_bags[item.bag] and res.bags[item.bag].access == "Everywhere") or (item.res.category == 'Armor' and res.bags[item.bag].equippable) then
        -- item is in usable inventory
        if item_is_usable(item) then
          found_item = item
        end
      end
    end
  end
  if found_item then
    return use_item(found_item)
  else
    log('No item available: '..item_name)
    return false
  end
end

local function process_command(args)
  local cmd = args[1]

  if map[cmd:lower()] then
    handle_group(cmd:lower())
  else
    handle_specific_item(cmd:lower())
  end
end

windower.register_event('addon command', function(...)
  local args = T{...}
  local cmd = args[1]
  if cmd == 'all' then
    table.remove(args, 1)
    windower.send_ipc_message({table.unpack(args)}:concat(';'))
  else
    process_command(args)
  end
end)

windower.register_event('ipc message', function (msg)
  local args = T{msg:split(';')}
  process_command(args)
end)

windower.register_event('action', function(action)
  if action.category == 9 and try_use_item then
    local item_id = action.targets and action.targets[1] and action.targets[1].actions and action.targets[1].actions[1] and action.targets[1].actions[1].param
    if item_id and try_use_item.id == item_id then
      if action.param == 24931 then
        used_item = try_use_item
        try_use_item = nil
        using_item = nil
      else
        log("Item use failed: "..try_use_item[language])
        if try_use_item.equipped_slot then
          gs_unlock(try_use_item.equipped_slot)
        end
      end
    end

  elseif action.category == 5 and used_item then
    local success = action.param == used_item.id and action.targets and action.targets[1] and action.targets[1].actions and action.targets[1].actions[1] and action.targets[1].actions[1].reaction == 8
    if success then
      return_item(used_item)
      used_item = nil
      using_item = nil
    end
  end
end)