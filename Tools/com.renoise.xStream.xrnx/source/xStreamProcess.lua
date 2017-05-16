--[[============================================================================
xStreamProcess
============================================================================]]--
--[[

A single streaming process 

#

This class represents a 'streaming process' - basically a streaming buffer
with additional scheduling & automation-recording features on top. 

]]

--==============================================================================

class 'xStreamProcess' 

-- accessible to callback
xStreamProcess.OUTPUT_MODE = {
  STREAMING = 1,
  TRACK = 2,
  SELECTION = 3,
}

-------------------------------------------------------------------------------
-- Constructor

function xStreamProcess:__init(xstream)

  self.xstream = xstream

  --- xStreamPos
  self.xpos = xstream.xpos

  --- xStreamPrefs, current settings
  self.prefs = renoise.tool().preferences

  --- enum, one of xStreamProcess.OUTPUT_MODE
  -- usually STREAMING, but temporarily set to a different
  -- value while applying output to TRACK/SELECTION
  self.output_mode = xStreamProcess.OUTPUT_MODE.STREAMING

  --- boolean, evaluate callback while playing
  self.active = property(self.get_active,self.set_active)
  self.active_observable = renoise.Document.ObservableBoolean(false)

  --- boolean, silence output (see also xStreamBuffer.MUTE_MODE)
  self.muted = property(self.get_muted,self.set_muted)
  self.muted_observable = renoise.Document.ObservableBoolean(false)

  --- int, set to true to silence output
  self.track_index = property(self.get_track_index,self.set_track_index)
  self.track_index_observable = renoise.Document.ObservableNumber(1)

  --- xStreamPos.SCHEDULE, active scheduling mode
  self.scheduling = property(self.get_scheduling,self.set_scheduling)
  self.scheduling_observable = renoise.Document.ObservableNumber(xStreamPos.SCHEDULE.BEAT)

  --- int, read-only - set via schedule_item(), 0 means none 
  self.scheduled_favorite_index = property(self.get_scheduled_favorite_index)
  self.scheduled_favorite_index_observable  = renoise.Document.ObservableNumber(0)

  --- int, read-only - set via schedule_item(), 0 means none
  self.scheduled_model_index = property(self.get_scheduled_model_index)
  self.scheduled_model_index_observable = renoise.Document.ObservableNumber(0)

  --- int, read-only - set via schedule_item()
  self.scheduled_model = property(self.get_scheduled_model)
  self._scheduled_model = nil

  --- xSongPos, tells us when/if a scheduled event will occur
  self._scheduled_xinc = nil

  --- int, read-only - set via schedule_item()
  self.scheduled_preset_index = property(self.get_scheduled_preset_index)
  self.scheduled_preset_index_observable = renoise.Document.ObservableNumber(0)

  --- int, read-only - set via schedule_item()
  self.scheduled_preset_bank_index = property(self.get_scheduled_preset_bank_index)
  self.scheduled_preset_bank_index_observable = renoise.Document.ObservableNumber(0)

  --- renoise.DeviceParameter, selected automation parameter (can be nil)
  self.device_param = property(self.get_device_param,self.set_device_param)
  self._device_param = nil

  --- int, derived from device_param (0 = none)
  self.device_param_index_observable = renoise.Document.ObservableNumber(0)

  --- xStreamModels
  self.models = xStreamModels(self)

  --- xStreamBuffer, track position and handle streaming ...
  self.buffer = xStreamBuffer(self.xpos)
  self.buffer.mute_mode = self.prefs.mute_mode.value
  self.buffer.expand_columns = self.prefs.expand_columns.value
  self.buffer.include_hidden = self.prefs.include_hidden.value
  self.buffer.clear_undefined = self.prefs.clear_undefined.value
  self.buffer.automation_playmode = self.prefs.automation_playmode.value
  self.buffer.automation_playmode_observable:add_notifier(function()
    TRACE("*** main.lua - self.automation_playmode_observable fired...")
    self.prefs.automation_playmode.value = self.buffer.automation_playmode_observable.value
  end)
  self.buffer.include_hidden_observable:add_notifier(function()
    TRACE("*** main.lua - self.include_hidden_observable fired...")
    self.prefs.include_hidden.value = self.buffer.include_hidden_observable.value
  end)
  self.buffer.clear_undefined_observable:add_notifier(function()
    TRACE("*** main.lua - self.clear_undefined_observable fired...")
    self.prefs.clear_undefined.value = self.buffer.clear_undefined_observable.value
  end)
  self.buffer.expand_columns_observable:add_notifier(function()
    TRACE("*** main.lua - self.expand_columns_observable fired...")
    self.prefs.expand_columns.value = self.buffer.expand_columns_observable.value
  end)
  self.buffer.mute_mode_observable:add_notifier(function()
    TRACE("*** selfUI - self.mute_mode_observable fired...")
    self.prefs.mute_mode.value = self.buffer.mute_mode_observable.value
  end)

  -- preferences -> app --

  self.prefs.scheduling:add_notifier(function()
    self.scheduling_observable.value = self.prefs.scheduling.value
  end)
  self.prefs.writeahead_factor:add_notifier(function()
    xStreamPos.WRITEAHEAD_FACTOR = self.prefs.writeahead_factor.value
  end)

end

-------------------------------------------------------------------------------
-- Getters/setters
-------------------------------------------------------------------------------

function xStreamProcess:get_active()
  return self.active_observable.value
end

function xStreamProcess:set_active(val)
  self.active_observable.value = val
end

-------------------------------------------------------------------------------

function xStreamProcess:get_muted()
  return self.muted_observable.value
end

function xStreamProcess:set_muted(val)
  TRACE("xStreamProcess:set_muted(val)",val)
  self.muted_observable.value = val
  if val then
    self.buffer:mute()
  else
    self.buffer:unmute()
  end

end

-------------------------------------------------------------------------------

function xStreamProcess:get_track_index()
  return self.buffer.track_index 
end

function xStreamProcess:set_track_index(idx)
  self.buffer.track_index = idx
  if self.active then
    self.buffer:update_read_buffer()
  end
end

-------------------------------------------------------------------------------

function xStreamProcess:get_scheduling()
  return self.scheduling_observable.value
end

function xStreamProcess:set_scheduling(val)
  TRACE("xStreamProcess:set_scheduling(val)",val)
  self.scheduling_observable.value = val
end

-------------------------------------------------------------------------------

function xStreamProcess:get_scheduled_favorite_index()
  return self.scheduled_favorite_index_observable.value
end

-------------------------------------------------------------------------------

function xStreamProcess:get_scheduled_model_index()
  return self.scheduled_model_index_observable.value
end

-------------------------------------------------------------------------------

function xStreamProcess:get_scheduled_model()
  return self._scheduled_model
end

-------------------------------------------------------------------------------

function xStreamProcess:get_scheduled_preset_index()
  return self.scheduled_preset_index_observable.value
end

-------------------------------------------------------------------------------

function xStreamProcess:get_scheduled_preset_bank_index()
  return self.scheduled_preset_bank_index_observable.value
end

-------------------------------------------------------------------------------

function xStreamProcess:get_device_param()
  return self._device_param
end

function xStreamProcess:set_device_param(val)
  self._device_param = val

  local param_idx
  if val then
    param_idx = xAudioDevice.resolve_parameter(val,self.buffer.track_index)
  end
  self.device_param_index_observable.value = param_idx or 0

end

-------------------------------------------------------------------------------
-- Class methods
-------------------------------------------------------------------------------

function xStreamProcess:reset()

  self.buffer:clear()
  self:clear_schedule()

end

-------------------------------------------------------------------------------

function xStreamProcess:stop()
  self.active = false
  self:clear_schedule()
end

-------------------------------------------------------------------------------
-- @param playmode, renoise.Transport.PLAYMODE

function xStreamProcess:start(playmode)
  print("xStreamProcess:start(playmode)",playmode)

  if self.active then 
    return 
  end
  self:reset()
  self.active = true
  self.xpos:start(playmode)

end

-------------------------------------------------------------------------------
-- Called on abrupt position change

function xStreamProcess:refresh()
  TRACE("xStreamProcess:refresh()")
  if self.active then
    self.buffer:update_read_buffer()
  end
end

-------------------------------------------------------------------------------
-- Called on periodic updates

function xStreamProcess:callback()
  TRACE("xStreamProcess:callback()")

  if self.active and self.models.selected_model then
    if self._scheduled_xinc then
      if (self.xpos.xinc == self._scheduled_xinc) then
        self:apply_schedule()
      end
    end
    local live_mode = true
    self.buffer:write_output(self.xpos.pos,self.xpos.xinc,nil,live_mode)
  end

end

-------------------------------------------------------------------------------
-- Schedule model or model+preset
-- @param model_name (string), unique name of model
-- @param preset_index (int),  preset to dial in - optional
-- @param preset_bank_name (string), preset bank - optional, TODO
-- @return true when item got scheduled, false if not
-- @return err (string), the reason scheduling failed

function xStreamProcess:schedule_item(model_name,preset_index,preset_bank_name)
  TRACE("xStreamProcess:schedule_item(model_name,preset_index,preset_bank_name)",model_name,preset_index,preset_bank_name)

  if not self.active then
    return false,"Can't schedule items while inactive"
  end

  assert(model_name,"Required argument missing: model_name")
  assert((type(model_name)=="string"),"Invalid argument type: model_name - expected string")

  local model_index,model = self.models:get_by_name(model_name)
  if not model then
    return false,"Could not schedule, model not found: "..model_name
  end

  self._scheduled_model = model
  self.scheduled_model_index_observable.value = model_index
  
  -- validate preset
  
  if (type(preset_index)=="number") then
    local num_presets = #model.selected_preset_bank.presets
    if (preset_index <= num_presets) then
      self.scheduled_preset_index_observable.value = preset_index
    end
  end

  if preset_bank_name then
    local preset_bank_index = model:get_preset_bank_by_name(preset_bank_name)
    --print("preset_bank_name,preset_bank_index",preset_bank_name,preset_bank_index)
    self.scheduled_preset_bank_index_observable.value = preset_bank_index
    --print("xStreamProcess:schedule_item - self.scheduled_preset_bank_index",preset_bank_index)
  end

  local favorite_idx = self.favorites:get(model_name,preset_index,preset_bank_name)
  --print("favorite_idx",favorite_idx)
  if favorite_idx then
    self.scheduled_favorite_index_observable.value = favorite_idx
  end

  -- now figure out the time
  if (self.scheduling == xStreamPos.SCHEDULE.LINE) then
    if self._scheduled_model then
      self:apply_schedule() -- set immediately 
    end
  else
    self:compute_scheduling_pos()
  end

  -- if scheduled event is going to take place within the
  -- space of already-computed lines, wipe the buffer
  if self._scheduled_xinc then
    local happening_in_lines = self._scheduled_xinc-self.xpos.xinc
    if (happening_in_lines <= xStreamPos.determine_writeahead()) then
      --print("wipe the buffer")
      self.buffer:wipe_futures()
    end
  end

end

-------------------------------------------------------------------------------
-- Schedule, or re-schedule (when external conditions change)

function xStreamProcess:compute_scheduling_pos()
  TRACE("xStreamProcess:compute_scheduling_pos()")

  local pos = xSongPos.create(self.xpos.playpos)
  self._scheduled_xinc = self.xpos.xinc

  local xinc = 0
  if (self.scheduling == xStreamPos.SCHEDULE.LINE) then
    error("Scheduling should already have been applied")
  elseif (self.scheduling == xStreamPos.SCHEDULE.BEAT) then
    xinc = xSongPos.next_beat(pos)
  elseif (self.scheduling == xStreamPos.SCHEDULE.BAR) then
    xinc = xSongPos.next_bar(pos)  
  elseif (self.scheduling == xStreamPos.SCHEDULE.BLOCK) then
    xinc = xSongPos.next_block(pos)
  elseif (self.scheduling == xStreamPos.SCHEDULE.PATTERN) then
    -- if we are within a blockloop, do not set a schedule position
    -- (once the blockloop is disabled, this function is invoked)
    if not rns.transport.loop_block_enabled then
      xinc = xSongPos.next_pattern(pos)
    else
      pos = nil
    end
  else
    error("Unknown scheduling mode")
  end

  if pos then
    self._scheduled_xinc = self._scheduled_xinc + xinc
  else 
    self._scheduled_xinc = nil
  end

end

-------------------------------------------------------------------------------
-- Invoked when cancelling schedule, or scheduled event has happened

function xStreamProcess:clear_schedule()
  TRACE("xStreamProcess:clear_schedule()")

  self._scheduled_model = nil
  self._scheduled_xinc = nil
  self.scheduled_model_index_observable.value = 0
  self.scheduled_preset_index_observable.value = 0
  self.scheduled_preset_bank_index_observable.value = 0
  self.scheduled_favorite_index_observable.value = 0

end

-------------------------------------------------------------------------------
-- Switch to scheduled model/preset

function xStreamProcess:apply_schedule()
  TRACE("xStreamProcess:apply_schedule()")

  -- remember value (otherwise lost when setting model)
  local preset_index = self.scheduled_preset_index
  local preset_bank_index = self.scheduled_preset_bank_index

  if not self.scheduled_model then
    self:clear_schedule()
    return
  end

  self.models.selected_model_index = self.scheduled_model_index

  if preset_bank_index then
    self.models.selected_model.selected_preset_bank_index = preset_bank_index
  end

  self.models.selected_model.selected_preset_bank.selected_preset_index = preset_index

  self:clear_schedule()

end

-------------------------------------------------------------------------------
-- Fill pattern-track in selected pattern
 
function xStreamProcess:fill_track()
  TRACE("xStreamProcess:fill_track()")
  
  local patt_num_lines = xPatternSequencer.get_number_of_lines(rns.selected_sequence_index)
  self.output_mode = xStreamProcess.OUTPUT_MODE.TRACK
  self:apply_to_range(1,patt_num_lines)

  self.output_mode = xStreamProcess.OUTPUT_MODE.STREAMING

end

-------------------------------------------------------------------------------
-- Ensure that selection is valid (not spanning multiple tracks)
-- @return bool
 
function xStreamProcess:validate_selection()
  TRACE("xStreamProcess:validate_selection()")

  local sel = rns.selection_in_pattern
  if not sel then
    return false,"Please create a (single-track) selection in the pattern"
  end
  if (sel.start_track ~= sel.end_track) then
    return false,"Selection must start and end in the same track"
  end

  return true

end

-------------------------------------------------------------------------------
-- Fill pattern-track in selected pattern
-- @param locally (bool) relative to the top of the pattern
 
function xStreamProcess:fill_selection(locally)
  TRACE("xStreamProcess:fill_selection(locally)",locally)

  local passed,err = self.validate_selection()
  if not passed then
    renoise.app():show_warning(err)
    return
  end

  --local num_lines = xSongPos.get_number_of_lines(rns.selected_sequence_index)
  local from_line = rns.selection_in_pattern.start_line
  local to_line = rns.selection_in_pattern.end_line
  local xinc = (not locally) and (from_line-1) or 0 

  -- backup settings
  local cached_track_index = self.buffer.track_index

  -- write output
  self.buffer.track_index = rns.selection_in_pattern.start_track
  self.output_mode = xStreamProcess.OUTPUT_MODE.SELECTION
  self:apply_to_range(from_line,to_line,xinc)

  -- restore settings
  self.buffer.track_index = cached_track_index
  self.output_mode = xStreamProcess.OUTPUT_MODE.STREAMING

end

-------------------------------------------------------------------------------
-- Apply the callback to a range in the selected pattern,  
-- temporarily switching to a different set of buffers
-- @param from_line (int)
-- @param to_line (int) 
-- @param [xinc] (int) where the callback 'started'

function xStreamProcess:apply_to_range(from_line,to_line,xinc)
  TRACE("xStreamProcess:apply_to_range(from_line,to_line,xinc)",from_line,to_line,xinc)

  local pos = {
    sequence = rns.transport.edit_pos.sequence,
    line = from_line
  }

  if not xinc then 
    xinc = 0
  end

  local live_mode = false -- start from first line
  local num_lines = to_line-from_line+1

  self:reset()

  -- backup settings
  local cached_active = self.active
  local cached_buffer = self.buffer.output_buffer
  local cached_read_buffer = self.buffer.pattern_buffer
  local cached_pos = self.xpos.pos
  local cached_bounds = xSongPos.DEFAULT_BOUNDS_MODE
  local cached_loop = xSongPos.DEFAULT_LOOP_MODE
  local cached_block = xSongPos.DEFAULT_BLOCK_MODE
  -- ignore any kind of loop (realtime only)
  xSongPos.DEFAULT_BOUNDS_MODE = xSongPos.OUT_OF_BOUNDS.CAP
  xSongPos.DEFAULT_LOOP_MODE = xSongPos.LOOP_BOUNDARY.NONE
  xSongPos.DEFAULT_BLOCK_MODE = xSongPos.BLOCK_BOUNDARY.NONE
  -- write output
  self.active = true
  self.xpos.pos.line = from_line
  self.buffer:write_output(pos,xinc,num_lines,live_mode)

  -- restore settings
  self.active = cached_active
  self.buffer.output_buffer = cached_buffer
  self.buffer.pattern_buffer = cached_read_buffer
  self.xpos.pos = cached_pos
  xSongPos.DEFAULT_BOUNDS_MODE = cached_bounds
  xSongPos.DEFAULT_LOOP_MODE = cached_loop
  xSongPos.DEFAULT_BLOCK_MODE = cached_block

end


-------------------------------------------------------------------------------
-- Resolve or create automation for parameter in the provided seq-index
-- can return nil if trying to create automation on non-automateable param.
-- @param seq_idx (int)
-- @return renoise.PatternTrackAutomation or nil

function xStreamProcess:resolve_automation(seq_idx)
  TRACE("xStreamProcess:resolve_automation(seq_idx)",seq_idx)
 
  local patt_idx = rns.sequencer:pattern(seq_idx)
  local patt = rns.patterns[patt_idx]
  assert(patt,"Could not find pattern")
  --local param = self.device.parameters[self.param_index]
  --assert(param,"Could not find device parameter")
  assert(self.device_param,"Could not find device parameter")

  if not self.device_param.is_automatable then
    return
  end

  local ptrack = patt.tracks[self.buffer.track_index]
  assert(ptrack,"Could not find pattern-track")

  return xAutomation.get_or_create_automation(ptrack,self.device_param)

end

-------------------------------------------------------------------------------
-- @param arg_name (string), e.g. "tab.my_arg" or "my_arg"
-- @param val (number/boolean/string)

function xStreamProcess:handle_arg_events(arg_name,val)
  TRACE("xStreamProcess:handle_arg_events(arg_name,val)",arg_name,val)

  -- pass to event handlers (if any)
  local event_key = "args."..arg_name
  self:handle_event(event_key,val)

end

-------------------------------------------------------------------------------
-- @param event_key (string), e.g. "midi.note_on"
-- @param arg (number/boolean/string/table) value to pass 

function xStreamProcess:handle_event(event_key,arg)
  TRACE("xStreamProcess:handle_event(event_key,arg)",event_key,arg)

  if not self.models.selected_model then
    LOG("*** WARNING Can't handle events - no model was selected")
    return
  end

  local handler = self.models.selected_model.events_compiled[event_key]
  if handler then
    --print("about to handle event",event_key,arg,self.models.selected_model.name)
    local passed,err = pcall(function()
      handler(arg)
    end)
    if not passed then
      LOG("*** Error while handling event",err)
    end
  --else
  --  LOG("*** could not locate handler for event",event_key)
  end

end

