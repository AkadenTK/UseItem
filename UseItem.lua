--[[
Copyright © 2023, Akaden
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

_addon.name = 'UseItem'
_addon.author = 'Akaden; inspired by from20020516 and Chiaia'
_addon.version = '0.2'
_addon.commands = {'useitem', 'use', 'i'}


require('logger')
require('queues')
local extdata = require('extdata')
local res = require('resources')
local config = require('config')

local settings = config.load({
  order = {
    warp = {'Warp Ring', 'Warp Cudgel'},
    rr = {"Pandit's Staff","Super Reraiser","Rebirth Feather","Dusty Reraise","Hi-Reraiser","Revive Feather","Instant Reraise","Reraiser","Scapegoat","Raphael's Rod","Mamool Ja Earring","Airmid's Gorget","Reraise Gorget","Reraise Hairpin","Kocco's Earring","Reraise Earring","Raising Earring","Reraise Ring","Wh. Rarab Cap +1",}
  },
  preferred_slots = {12, 14},
  bags = {5, 6 ,7}, -- satchel, sack, case
  gs_lock_command = 'gs disable',
  gs_unlock_command = 'gs enable',
  announce_delay = 3,
  bag_search_order = {'inventory','satchel','sack','case','wardrobe','wardrobe2','wardrobe3','wardrobe4','wardrobe5','wardrobe6','wardrobe7','wardrobe8'},
  debug=false,
})

local language = string.lower(windower.ffxi.get_info().language)
local map = require('map')
local usable_bags = S{0,3} -- inventory or temp

local using_item = {}
local using_equip_slot = {}
local use_queue = Q{}
local in_use = nil
local used_items = {}
local phases = {
  OBTAINING = 10,
  OBTAINED = 15,
  EQUIPPING = 20,
  EQUIPPED = 25,
  READYING = 30,
  USE_QUEUE = 35,
  TRY_USING = 40,
  USING = 45,
  USED = 50,
}
local states = {
  UNKNOWN = '???',
  READY = 'READY',
  READYING = 'READYING',
}
local player_state = states.UNKNOWN
local function debug(...)
  if settings.debug then
    log('DEBUG', ...)
  end
end

local function get_equipped_slot(item)
  local equipment = windower.ffxi.get_items().equipment
  for slot_id, slot in pairs(res.slots) do
    local slot_key = slot.en:lower():gsub(' ', '_')
    local slot_slot = equipment[slot_key]
    local slot_bag = equipment[slot_key..'_bag']
    if slot_slot == item.slot and slot_bag == item.bag then
      return slot_id
    end
  end
  return nil
end

local function to_gs_name(slot)
  local slot_name = res.slots[slot].en
  return slot_name:gsub(' ', '_'):lower()
end
local function get_state(item, command)
  if command then
    for _, v in pairs(using_item) do
      if v.command == command then
        return v
      end
    end
    for _, v in pairs(using_equip_slot) do
      if v.command == command then
        return v
      end
    end
  end
  if item.res.category == 'Armor' then
    for slot_id, _ in pairs(item.res.slots) do
      if using_equip_slot[slot_id] and using_equip_slot[slot_id].item.id == item.id then
        return using_equip_slot[slot_id]
      end
    end
    return nil
  elseif item.res.category == 'Usable' then
    return using_item[item.id]
  end
end

local function get_user_slot(item)
  local found_slot
  local user_slots = S{table.unpack(settings.preferred_slots and settings.preferred_slots or {})}
  for slot, _ in pairs(S(item.res.slots)) do
    if slot and not using_equip_slot[slot] then
      if user_slots[slot] then
        debug('get_user_slot: '..item.res[language])
        return slot
      end
      found_slot = slot
    end
  end
  debug('get_user_slot: '..item.res[language])
  return found_slot
end

local function create_state(item, command)
  if item.res.category == 'Armor' then
    local available_slot = get_user_slot(item)
    if available_slot then
      local s = {
        item = item,
        command = command,
        equip_slot = available_slot,
        original_bag = item.bag,
        is_armor = true,
        target = '<me>',
      }
      using_equip_slot[s.equip_slot] = s
      return s
    else
      return nil
    end
  elseif item.res.category == 'Usable' then
    local s =  {
      item = item,
      command = command,
      original_bag = item.bag,
      is_armor = false,
      target = '<me>',
    }
    using_item[item.id] = s
    return s
  end

  return nil
end


local function gs_lock(slot)
  windower.send_command(settings.gs_lock_command..' '..to_gs_name(slot))
end
local function gs_unlock(slot)
  windower.send_command(settings.gs_unlock_command..' '..to_gs_name(slot))
end

local function prepare_item_state(inv_item, item)
  if inv_item then
    item = item or {}
    item.id = inv_item.id
    item.res = res.items[inv_item.id]
    item.bag = inv_item.bag
    item.slot = inv_item.slot
    item.count = inv_item.count
    item.status = inv_item.status
    item.extdata = inv_item.extdata
    item.is_armor = item.res.category == 'Armor'
    item.is_usable = item.res.category == 'Usable'
    item.in_bazaar = inv_item.bazaar and inv_item.bazaar > 0
    item.is_equipped = inv_item.status == 5
    local player = windower.ffxi.get_player()
    local player_mob = windower.ffxi.get_mob_by_target('me')
    if player and player_mob and item.is_armor then
      item.is_equippable = item.res.jobs[player.main_job_id] and 
                           (not item.res.races or item.res.races[player_mob.race]) and 
                           item.res.level <= player.main_job_level and 
                           (not item.res.superior_level or item.res.superior_level <= player.superior_level)
    else
      item.is_equippable = nil
    end
    if item.status == 5 then
      item.equipped_slot = get_equipped_slot(item)
    else
      item.equipped_slot = nil
    end
    if item.is_armor then
      local ext = extdata.decode(inv_item)

      item.extdata = ext
      item.remaining_activation_time = ext.activation_time + 18000 - os.time()
      item.recharge_remaining = ext.charges_remaining and ext.charges_remaining > 0 and math.max(ext.next_use_time + 18000 - os.time(), 0)
    end
    return item
  end
  return nil
end

local function get_item(item)
  local i = windower.ffxi.get_items(item.bag, item.slot)
  if i and i.id ~= item.id then
    return nil 
  end
  if i then
    i.bag = item.bag
  end
  return i
end

local function find_exact_item(item)  
  for bag_id = 0, 100, 1 do
    local bag = res.bags[bag_id]
    if bag == nil then break end

    for _, check_item in pairs(windower.ffxi.get_items(bag_id)) do
      if type(check_item) == 'table' then
        check_item.bag = bag_id
        if check_item and check_item.id == item.id then
          if item.is_armor and item.extdata and check_item.extdata then
            local ext = extdata.decode(check_item)
            if ext and ext.next_use_time == item.extdata.next_use_time then
              return check_item
            end
          else
            return check_item
          end
        end
      end
    end
  end
  return nil
end

local function update_item_state(item, inv_item)
  inv_item = inv_item or find_exact_item(item)
  if inv_item then
    prepare_item_state(inv_item, item)
    return true
  end
  return false
end

local function clean_up(state)
  if update_item_state(state.item, get_item(state.item)) then
    gs_unlock(state.item.equipped_slot)
    while state.item.is_equipped do
      debug('Try unequip', state.item.equipped_slot)
      windower.ffxi.set_equip(0, state.item.equipped_slot, 0)
      coroutine.sleep(0.5)
      update_item_state(state.item, get_item(state.item))
    end

    if state.old_bag then
      while state.item.bag ~= state.old_bag do
        debug('Try put item back', state.old_bag)
        windower.ffxi.put_item(state.old_bag, state.item.slot)
        coroutine.sleep(.5)
        update_item_state(state.item, get_item(state.item))
      end
    end

    if state.item.is_armor then
      using_equip_slot[state.equip_slot] = nil
    else
      using_item[state.item.id] = nil
    end

    used_items[state.item.id] = nil
  else
    debug('Could not clean_up item: '..state.item.res[language])
  end
end

local function is_player_busy()
  return windower.ffxi.get_player().status > 1
end

local function is_item_in_usable_bag(item)
  if item.is_armor and res.bags[item.bag].equippable then
    return true
  elseif item.is_usable and usable_bags[item.bag] then
    return true
  end
  return false
end

local function is_item_ready_for_use(item)
  return item.is_usable or (item.recharge_remaining <= 0 and item.remaining_activation_time <= 0)
end

local function ensure_equipped(state)
  if not state.item.is_armor then return true end

  if not state.item.is_equipped then
    if state.phase >= phases.EQUIPPED then
      log('Item has been unequipped. Re-equipping: '..item.res[language])
    else
      log('Equipping item: '..state.item.res[language])
    end
    gs_lock(state.equip_slot)
    windower.ffxi.set_equip(state.item.slot, state.equip_slot, state.item.bag)
    state.phase = phases.EQUIPPING
    return false
  end
  return true
end

local function do_use(state)
  state.phase = phases.USE_QUEUE
  use_queue:push(state)
  if in_use then return end -- already running
  debug('USE QUEUE enter')

  repeat
    if is_player_busy() then
      log('You cannot use items at this time.')
      clean_up(state)
      return
    end
    in_use = use_queue:pop()
    if not update_item_state(in_use.item) then
      -- inv item is not where we expected it.
      log('Prepare item failed: '..in_use.item.res[language])
      clean_up(in_use)
    end

    if in_use.item.is_armor and not in_use.item.is_equipped then
      debug('do_use equipping')
      ensure_equipped(in_use)
      use_queue:push(in_use)
    elseif not is_item_ready_for_use(in_use.item) then
      in_use.phase = phases.READYING
      debug('do_use readying')
      use_queue:push(in_use)
    elseif in_use.phase < phases.USING then
      in_use.phase = phases.TRY_USING
      use_queue:push(in_use)
      debug('do_use try using', in_use.item.res[language], in_use.target)
      windower.chat.input('/item "'..in_use.item.res[language]..'" '..in_use.target)
      used_items[in_use.item.id] = in_use
    end
    coroutine.sleep(1)
  until use_queue:length() <= 0
  in_use = nil
  debug('USE QUEUE exit')
end

local function use_item(item, command)
  if is_player_busy() then
    log('You cannot use items at this time.')
    return
  end

  local state = get_state(item, command)
  if state then
    log('Item already in use!')
    return false
  end

  state = create_state(item)
  if not state then
    log('Cannot use item!')
    return false
  end

  if not update_item_state(state.item) then
    log('Cannot find item '..state.item.res[language])
    clean_up(state)
    return false
  end

  local count = 0
  while not is_item_in_usable_bag(state.item) and count <= 5 do -- obtain the item      
    if is_player_busy() then
      log('You cannot use items at this time.')
      clean_up(state)
      return
    end

    state.phase = phases.OBTAINING

    state.old_bag = state.item.bag
    log('Retrieving item: '..state.item.res[language])
    windower.ffxi.get_item(state.item.bag, state.item.slot, 1)

    count = count + 1
    coroutine.sleep(1)

    if not update_item_state(state.item) then
      log('Cannot find item: '..state.item.res[language])
      clean_up(state)
      return false
    end
  end
  state.phase = phases.OBTAINED

  count = 0
  repeat --waiting cast delay    
    if is_player_busy() then
      log('You cannot use items at this time.')
      clean_up(state)
      return false
    end

    if not update_item_state(state.item) then
      log('Cannot find item: '..state.item.res[language])
      clean_up(state)
      return false
    end

    if ensure_equipped(state) then

      if is_item_ready_for_use(state.item) then
        debug('Item is ready: '..state.item.res[language]) 
        do_use(state)
        break
      else
        debug('Item is equipped: '..state.item.res[language]) 
        state.phase = phases.READYING
      end
    end
    coroutine.sleep(1)
  until false
end

local function fuzzy_name(item_name)
  return item_name:lower()
end

local function item_match(item_key, item_id)
  if type(item_key) == 'number' then
    return item_key == item_id
  elseif type(item_key) == 'string' then
    local n = fuzzy_name(item_key)
    return n == fuzzy_name(res.items[item_id][language])
  end
  return false 
end

local function find_items(item_key)
  local available_items = T{}
  local all_bags = windower.ffxi.get_items()
  for bag_id, bag in pairs(res.bags) do
    if all_bags['enabled_'..bag.command] then
      for _, inv_item in ipairs(all_bags[bag.command]) do
        inv_item.bag = bag_id
        if inv_item.id ~= 0 and item_match(item_key, inv_item.id) then
          available_items:append(prepare_item_state(inv_item))
        end
      end
    end
  end
  return available_items
end

local function is_item_usable(item)
  return (item.is_armor and item.is_equippable ~= false and item.recharge_remaining <= 10) or item.is_usable
end

local function is_item_accessible(item)
  local user_bags = S(settings.bags)
  return usable_bags[item.bag] or 
         (item.is_armor and res.bags[item.bag].equippable) or 
         (user_bags[item.bag] and res.bags[item.bag].access == "Everywhere")
end

local function handle_group(group_key)
  local group = map[group_key]
  local user_items = T{}
  local user_bags = S(settings.bags)

  local all_available_items = T{}
  -- add items from group that exist in accessible inventory and are usable
  for _, item_info in pairs(group) do
    local available_items = find_items(item_info.id)
    for _, item in ipairs(available_items) do
      if is_item_accessible(item) and is_item_usable(item) then
        -- this is in accessible inventory
        all_available_items:append(item)
      end
    end
  end
  
  -- order/filter by user preferences
  if settings.order[group_key] then
    local ordered_items = T{}
    for _, item_id in ipairs(settings.order[group_key]) do
      for _, item in ipairs(all_available_items) do
        if item_match(item_id, item.id) then
          ordered_items:append(item)
        end
      end
    end
    all_available_items = ordered_items
  end

  if #all_available_items > 0 then
    return use_item(all_available_items[1], group_key)
  else
    log('No item available for group: '..group_key)
    return false
  end
end

local function handle_specific_item(item_name)  
  local found_item = nil
  local all_available_items = find_items(item_name)
  local user_bags = S(settings.bags)
  for _, item in ipairs(all_available_items) do
    if not found_item then
      if is_item_accessible(item) and is_item_usable(item) then
        found_item = item
      end
    end
  end
  if found_item then
    return use_item(found_item, item_name)
  else
    log('No item available: '..item_name)
    return false
  end
end

local function process_command(args)
  local cmd = args:concat(' ')

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
    windower.send_ipc_message(args:concat(';'))
    process_command(args)
  else
    process_command(args)
  end
end)

windower.register_event('ipc message', function (msg)
  local args = msg:split(';')
  process_command(args)
end)


local completion_action_categories = S{1,2,3,4,5,6,11,13,14,15}
local begin_action_categories = S{7,8,9,10,12}
windower.register_event('action', function(action)
  -- if completion_action_categories[action.category] then
  --   player_state = states.READY
  -- elseif begin_action_categories[action.category] then
  --   if action.param == 24931 then
  --     player_state = states.READYING
  --   else
  --     player_state = states.READY
  --   end
  -- end

  if action.category == 9 then
    
    local player = windower.ffxi.get_player()
    if action.actor_id ~= player.id then return end

    local item_id = action.targets and action.targets[1] and action.targets[1].actions and action.targets[1].actions[1] and action.targets[1].actions[1].param
    if item_id and used_items[item_id] then
      if action.param == 24931 then
        debug('Using item start: '..used_items[item_id].item.res[language])
        used_items[item_id].phase = phases.USING
      else
        log("Item use failed: "..used_items[item_id].item.res[language])
        clean_up(used_items[item_id])
      end
    end

  elseif action.category == 5 then
    
    local player = windower.ffxi.get_player()
    if action.actor_id ~= player.id then return end

    local item_id = action.param
    local success = item_id and action.targets and action.targets[1] and action.targets[1].actions and action.targets[1].actions[1] and action.targets[1].actions[1].reaction == 8
    if success and item_id and used_items[item_id] then
      debug('Item use success: '..used_items[item_id].item.res[language])
      used_items[item_id].phase = phases.USED
      clean_up(used_items[item_id])
    end
  end
end)
