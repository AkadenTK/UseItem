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
_addon.version = '0.3'
_addon.commands = {'useitem', 'use', 'i'}


require('queues')
extdata = require('extdata')
res = require('resources')
local config = require('config')

require('output')
require('helpers')
require('state')

settings = config.load({
  groups = {
    warp = {'Warp Ring', 'Instant Warp', 'Warp Cudgel'},
    dem = {'Dim. Ring (Dem)'},
    mea = {'Dim. Ring (Mea)'},
    holla = {'Dimensional Ring (Holla)'},
    dim = {'Dimensional Ring (Dem)', 'Dimensional Ring (Mea)','Dimensional Ring (Holla)'},
    rr = {"Pandit's Staff","Super Reraiser","Rebirth Feather","Dusty Reraise","Hi-Reraiser","Revive Feather","Instant Reraise","Reraiser","Scapegoat","Raphael's Rod","Mamool Ja Earring","Airmid's Gorget","Reraise Gorget","Reraise Hairpin","Kocco's Earring","Reraise Earring","Raising Earring","Reraise Ring","Wh. Rarab Cap +1",},
    silena = {'Echo Drops', 'Remedy'},
  },
  preferred_slots = {12, 14}, -- right ring and earring
  bags = {5, 6 ,7}, -- satchel, sack, case
  gs_lock_command = 'gs disable',
  gs_unlock_command = 'gs enable',
  obtain_item_timeout = 5,
  debug=false,
})

function clean_up(state)
  clean_up_state(state)

  if update_item_state(state.item, get_item_from_last_known_bag(state.item)) then
    if state.item.equipped_slot then
      enable_gearswap_slot(state.item.equipped_slot)
    end
    while state.item.is_equipped do
      windower.ffxi.set_equip(0, state.item.equipped_slot, 0)
      coroutine.sleep(0.5)
      update_item_state(state.item, get_item_from_last_known_bag(state.item))
    end

    if state.old_bag then
      while state.item.bag ~= state.old_bag do
        windower.ffxi.put_item(state.old_bag, state.item.slot)
        coroutine.sleep(.5)
        update_item_state(state.item, get_item_from_last_known_bag(state.item))
      end
    end
  else
    log_message(cleanup_failed, state)
  end
end

local function do_use(state)
  state.phase = phases.USE_QUEUE
  use_queue:push(state)
  if in_use then return end -- already running

  repeat
    if is_player_busy() then
      log_message('player_busy')
      clean_up(state)
      return
    end
    in_use = use_queue:pop()
    if not update_item_state(in_use.item) then
      -- inv item is not where we expected it.
      log_message('prepare_failed', state)
      clean_up(in_use)
    end

    if in_use.item.is_equipment and not in_use.item.is_equipped then
      local _, msg_key = ensure_equipped(in_use)
      state.phase = phases.EQUIPPING
      log_message(msg_key, state)
      use_queue:push(in_use)
    elseif not is_item_ready_for_use(in_use.item) then
      in_use.phase = phases.READYING
      use_queue:push(in_use)
    elseif in_use.phase < phases.USING then
      in_use.phase = phases.TRY_USING
      use_queue:push(in_use)
      windower.chat.input('/item "'..in_use.item.res[language]..'" '..in_use.target)
      used_items[in_use.item.id] = in_use
    end
    coroutine.sleep(1)
  until use_queue:length() <= 0
  in_use = nil
end

local function use_item(item, command)
  if is_player_busy() then
    log_message('player_busy')
    return false
  end

  local state = get_state(item, command)
  if state then
    if item.is_equipment then
      log_message('equipment_slot_collision')
    else
      log_message('item_collision')
    end
    return false
  end

  state = create_state(item)
  if not state then
    log_message('item_state_failed')
    return false
  end

  if not update_item_state(state.item) then
    log_message('item_not_found', state)
    clean_up(state)
    return false
  end

  local count = 0
  while not is_item_in_usable_inventory(state.item) and count <= settings.obtain_item_timeout do -- obtain the item      
    if is_player_busy() then
      log_message('player_busy')
      clean_up(state)
      return false
    end

    state.phase = phases.OBTAINING

    state.old_bag = state.item.bag
    log_message('retrieve_item', state)
    windower.ffxi.get_item(state.item.bag, state.item.slot, 1)

    count = count + 1
    coroutine.sleep(1)

    if not update_item_state(state.item) then
      log_message('item_not_found', state)
      clean_up(state)
      return false
    end
  end
  if not is_item_accessible(state.item) then
    log_message('obtain_timeout')
    clean_up(state)
    return false
  end
  state.phase = phases.OBTAINED

  count = 0
  repeat --waiting cast delay    
    if is_player_busy() then
      log_message('player_busy')
      clean_up(state)
      return false
    end

    if not update_item_state(state.item) then
      log_message('item_not_found', state)
      clean_up(state)
      return false
    end

    local equipped, msg_key = ensure_equipped(state)
    if equipped then
      if is_item_ready_for_use(state.item) then
        debug_message('item_ready', state)
        do_use(state)
        break
      else
        debug_message('item_equipped', state)
        state.phase = phases.READYING
      end
    else
      log_message(msg_key, state)
    end
    coroutine.sleep(1)
  until false
end

local function use_items(items, cmd)
  local user_bags = S(settings.bags)

  local all_available_items = T{}
  for _, item_name_or_id in ipairs(items) do
    local available_items = find_items(item_name_or_id)
    for _, item in ipairs(available_items) do
      if is_item_accessible(item) and is_item_usable(item) then
        -- this is in accessible inventory
        all_available_items:append(item)
      end
    end
  end

  if #all_available_items > 0 then
    return use_item(all_available_items[1], cmd)
  elseif cmd and settings.groups[cmd] then
    log_message('group_not_ready', cmd)
  elseif cmd then
    log_message('item_not_available_or_ready', cmd)
  end
  return false
end

local function process_command(args)
  local cmd = args:concat(' ')

  if settings.groups[cmd:lower()] then
    -- this is a group name, try to use one of these items
    use_items(settings.groups[cmd:lower()], cmd:lower())
  else
    -- this is an item name, not a group, try to use this item
    use_items({cmd:lower()}, cmd:lower())
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
