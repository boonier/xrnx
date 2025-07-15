--[[----------------------------------------------------------------------------
-- Duplex.Nektar-Panorama-T6
----------------------------------------------------------------------------]]--

duplex_configurations:insert {

  -- configuration properties
  name = "Mixer + Transport",
  pinned = true,

  -- device properties
  device = {
    class_name = nil,          
    display_name = "Nektar Panorama T6 (Port 2)",
    device_port_in = "PANORAMA T6 (Mixer)",
    device_port_out = "PANORAMA T6 (Mixer)",
    control_map = "Controllers/Nektar-Panorama-T6/Controlmaps/Nektar-Panorama-T6.xml",
    thumbnail = "Controllers/Nektar-Panorama-T6/Nektar-Panorama-T6.bmp",
    protocol = DEVICE_PROTOCOL.MIDI
  },
  

  
  applications = {
    Mixer = {
      mappings = {
        panning = {
          group_name = "Pans",
        },
        levels = {
          group_name = "Levels",
        },
        solo = {
          group_name= "Solos",
        },
        mute = {
          group_name= "Mutes",
        },
    },
  },
    Transport = {
      mappings = {
        goto_previous = {
          group_name = "Transport",
          index = 1,
        },
        goto_next = {
          group_name = "Transport",
          index = 2,
        },
        stop_playback = {
          group_name = "Transport",
          index = 3,
        },
        start_playback = {
          group_name = "Transport",
          index = 4,
        },
        edit_mode = {
          group_name = "Transport",
          index = 5,
        },
        metronome_toggle = {
          group_name = "Transport",
          index = 6,
        },
        follow_player = {
          group_name = "Transport",
          index = 7,
        },
        loop_pattern = {
          group_name = "Transport",
          index = 8,
        },
      },
    },
  }
}

