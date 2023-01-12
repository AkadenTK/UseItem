
function get_equipped_slot(item)
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

function to_gs_name(slot)
  local slot_name = res.slots[slot].en
  return slot_name:gsub(' ', '_'):lower()
end
function disable_gearswap_slot(slot)
  windower.send_command(settings.gs_lock_command..' '..to_gs_name(slot))
end
function enable_gearswap_slot(slot)
  windower.send_command(settings.gs_unlock_command..' '..to_gs_name(slot))
end

function get_user_preferred_slot(item, using_equip_slot)
  local found_slot
  local user_slots = S{table.unpack(settings.preferred_slots and settings.preferred_slots or {})}
  for slot, _ in pairs(S(item.res.slots)) do
    if slot and not using_equip_slot[slot] then
      if user_slots[slot] then
        return slot
      end
      found_slot = slot
    end
  end
  return found_slot
end

function get_item_from_last_known_bag(item)
  local i = windower.ffxi.get_items(item.bag, item.slot)
  if i and i.id ~= item.id then
    return nil 
  end
  if i then
    i.bag = item.bag
  end
  return i
end

function is_player_busy()
  return windower.ffxi.get_player().status > 1
end

local usable_bags = S{0,3} -- inventory or temp
function is_item_ready_for_use(item)
  return item.is_usable or (item.recharge_remaining <= 0 and item.remaining_activation_time <= 0)
end
function is_item_usable(item)
  return (item.is_equipment and item.is_equippable ~= false and item.charges_remaining >= 1 and item.recharge_remaining <= 10) or item.is_usable
end
function is_item_in_usable_inventory(item)
  return usable_bags[item.bag] or 
         (item.is_equipment and res.bags[item.bag].equippable)
end  
function is_item_accessible(item)
  local user_bags = S(settings.bags)
  return is_item_in_usable_inventory(item) or 
         (user_bags[item.bag] and res.bags[item.bag].access == "Everywhere")
end

function find_item_by_id_and_extdata(item)  
  for bag_id = 0, 100, 1 do
    local bag = res.bags[bag_id]
    if bag == nil then break end

    for _, check_item in pairs(windower.ffxi.get_items(bag_id)) do
      if type(check_item) == 'table' then
        check_item.bag = bag_id
        if check_item and check_item.id == item.id then
          if item.is_equipment and item.extdata and check_item.extdata then
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

function prepare_item_state(inv_item, item)
  if inv_item then
    item = item or {}
    item.id = inv_item.id
    item.res = res.items[inv_item.id]
    item.bag = inv_item.bag
    item.slot = inv_item.slot
    item.count = inv_item.count
    item.status = inv_item.status
    item.extdata = inv_item.extdata
    item.is_equipment = item.res.category == 'Armor' or item.res.category == 'Weapon'
    item.is_usable = item.res.category == 'Usable'
    item.in_bazaar = inv_item.bazaar and inv_item.bazaar > 0
    item.is_equipped = inv_item.status == 5
    local player = windower.ffxi.get_player()
    local player_mob = windower.ffxi.get_mob_by_target('me')
    if player and player_mob and item.is_equipment then
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
    if item.is_equipment then
      local ext = extdata.decode(inv_item)

      item.extdata = ext
      item.remaining_activation_time = ext.activation_time + 18000 - os.time()
      item.charges_remaining = ext.charges_remaining
      item.recharge_remaining = ext.charges_remaining and ext.charges_remaining > 0 and math.max(ext.next_use_time + 18000 - os.time(), 0)
    end
    return item
  end
  return nil
end

function update_item_state(item, inv_item)
  inv_item = inv_item or find_item_by_id_and_extdata(item)
  if inv_item then
    prepare_item_state(inv_item, item)
    return true
  end
  return false
end

function ensure_equipped(state)
  if not state.item.is_equipment then return true end

  if not state.item.is_equipped then
    local msg_key = 'equip_item'
    if state.item.has_been_equipped then
      msg_key = 'reequip_item'
    end
    disable_gearswap_slot(state.equip_slot)
    windower.ffxi.set_equip(state.item.slot, state.equip_slot, state.item.bag)
    state.item.has_been_equipped = true
    return false, msg_key
  end
  return true
end

local function fuzzy_name(item_name)
  return item_name:lower()
end

local function item_match(item_key, item_id)
  if type(item_key) == 'number' then
    return item_key == item_id
  elseif type(item_key) == 'string' then
    local n = fuzzy_name(item_key)
    return n == fuzzy_name(res.items[item_id][language]) or 
           n == fuzzy_name(res.items[item_id][language..'_log'])
  end
  return false 
end

function find_items(item_key)
  local available_items = T{}
  local all_bags = windower.ffxi.get_items()
  for bag_id = 0, 100, 1 do
    local bag = res.bags[bag_id]
    if bag == nil then break end

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