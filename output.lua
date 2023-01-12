require('logger')

language = string.lower(windower.ffxi.get_info().language)

local item_name = function(state) return state.item.res[language] end
local messages = {
  ['player_busy'] = {english = 'You cannot use items at this time.'},
  ['equipment_slot_collision'] = {english = 'Equipment slot already in use.'},
  ['item_collision'] = {english = 'Item already in use.'},
  ['item_not_found'] = {english = 'Cannot find item: %s', fn = item_name},
  ['retrieve_item'] = {english = 'Retrieving item: %s', fn = item_name},
  ['item_state_failed'] = {english = 'Cannot use item!'},
  ['obtain_timeout'] = {english = 'Could not obtain item after %d tries', fn = function() return settings.obtain_item_timeout end},
  ['item_ready'] = {english = 'Item is ready: %s', fn = item_name},
  ['item_equipped'] = {english = 'Item is equipped: %s', fn = item_name},
  ['group_not_ready'] = {english = 'No items ready for use in group: %s', fn = function(cmd) return cmd end},
  ['item_not_available_or_ready'] = {english = 'Item not available or not ready: %s', fn = function(cmd) return cmd end},
  ['try_item_return'] = {english = 'Try put item back: %s bag: %s', fn = function(state) return item_name(state), state.old_bag end},
  ['cleanup_failed'] = {english = 'Could not clean_up item: %s', fn = item_name},
  ['prepare_failed'] = {english = 'Prepare item failed: %s', fn = item_name},
  ['item_use_failed'] = {english = 'Item use interrupted: %s', fn = item_name},
  ['item_use_success'] = {english = 'Item use success: %s', fn = item_name},
  ['equip_item'] = {english = 'Equipping item: %s', fn = item_name},
  ['reequip_item'] = {english = 'Re-equipping item: %s', fn = item_name},
}


function log_message(msg_key, state)
  if messages[msg_key] then
    local vs = messages[msg_key].fn and {messages[msg_key].fn(state)} or {}
    log(string.format(messages[msg_key][language], table.unpack(vs)))
  end
end
function debug_message(msg_key, state)
  if settings.debug then
    log_message(msg_key, state)
  end
end