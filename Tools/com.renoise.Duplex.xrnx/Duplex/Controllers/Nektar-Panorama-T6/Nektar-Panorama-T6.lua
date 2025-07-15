--[[----------------------------------------------------------------------------
-- Duplex.Nektar-Panorama-T6
----------------------------------------------------------------------------]]--

--[[

Inheritance: MidiDevice > Device

A generic MidiDevice class 

--]]

class "NektarPanoramaControl" (MidiDevice)

function NektarPanoramaControl:__init(display_name, message_stream, port_in, port_out)
  MidiDevice.__init(self, display_name, message_stream, port_in, port_out)
  self.allow_zero_velocity_note_on = true
end
