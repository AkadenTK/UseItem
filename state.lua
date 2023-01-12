

using_item = {}
using_equip_slot = {}
use_queue = Q{}
in_use = nil
used_items = {}
phases = {
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

function get_state(item, command)
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
  if item.is_equipment then
    for slot_id, _ in pairs(item.res.slots) do
      if using_equip_slot[slot_id] and using_equip_slot[slot_id].item.id == item.id then
        return using_equip_slot[slot_id]
      end
    end
    return nil
  elseif item.is_usable then
    return using_item[item.id]
  end
end

function create_state(item, command)
  if item.is_equipment then
    local available_slot = get_user_preferred_slot(item, using_equip_slot)
    if available_slot then
      local s = {
        item = item,
        command = command,
        equip_slot = available_slot,
        original_bag = item.bag,
        is_equipment = true,
        target = '<me>',
      }
      using_equip_slot[s.equip_slot] = s
      return s
    else
      return nil
    end
  elseif item.is_usable then
    local s =  {
      item = item,
      command = command,
      original_bag = item.bag,
      is_equipment = false,
      target = '<me>',
    }
    using_item[item.id] = s
    return s
  end

  return nil
end

function clean_up_state(state)
  if state.item.is_equipment then
    using_equip_slot[state.equip_slot] = nil
  else
    using_item[state.item.id] = nil
  end

  used_items[state.item.id] = nil
end

local completion_action_categories = S{1,2,3,4,5,6,11,13,14,15}
local begin_action_categories = S{7,8,9,10,12}
local last_item_start = nil
windower.register_event('action', function(action)

  if action.category == 9 then
    
    local player = windower.ffxi.get_player()
    if action.actor_id ~= player.id then return end

    local starting = action.param == 24931

    local item_id = not starting and last_item_start or action.targets and action.targets[1] and action.targets[1].actions and action.targets[1].actions[1] and action.targets[1].actions[1].param
    if item_id and used_items[item_id] then
      if starting then
        used_items[item_id].phase = phases.USING
        last_item_start = item_id
      else
        log_message('item_use_failed', used_items[item_id])
        clean_up(used_items[item_id])
      end
    end

  elseif action.category == 5 then
    
    local player = windower.ffxi.get_player()
    if action.actor_id ~= player.id then return end

    last_item_start = nil

    local item_id = action.param
    local success = item_id and action.targets and action.targets[1] and action.targets[1].actions and action.targets[1].actions[1] and action.targets[1].actions[1].reaction == 8
    if success and item_id and used_items[item_id] then
      debug_message('item_use_success', used_items[item_id])
      used_items[item_id].phase = phases.USED
      clean_up(used_items[item_id])
    end
  end
end)