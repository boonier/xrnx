--[[----------------------------------------------------------------------------
-- Duplex.Nektar-Panorama-T6
----------------------------------------------------------------------------]]--

duplex_configurations:insert {

  -- configuration properties
  name = "Effects + Transport",
  pinned = true,

  -- device properties
  device = {
    class_name = "NektarPanoramaControl",          
    display_name = "Nektar Panorama T6",
    device_port_in = "PANORAMA T6 (Internal)",
    device_port_out = "PANORAMA T6 (Internal)",
    control_map = "Controllers/Nektar-Panorama-T6/Controlmaps/Nektar-Panorama-T6_Effects.xml",
    thumbnail = "Controllers/Nektar-Panorama-T6/Nektar-Panorama-T6.bmp",
    protocol = DEVICE_PROTOCOL.MIDI
  },
    
  applications = {

    Effect = {
      mappings = {
        
        parameters = {
          group_name = "EffectEncoders*"
        },

        param_names = {
          group_name = "EffectParamLabels*",
          index = 1
        },
        param_values = {
          group_name = "EffectParamLabels*",
          index = 2
        },

        device_prev = {
          group_name = "DeviceSelectors",
          index = 2
        },
        device_next = {
          group_name = "DeviceSelectors",
          index = 3
        },
        param_prev = {
          group_name = "PageSelectors",
          index = 2
        },
        param_next = {
          group_name = "PageSelectors",
          index = 3
        },

        device_name = {
          group_name = "DeviceNameLabel",
          index = 1
        },

      }
    },

    TrackSelector = {
      mappings = {
        track_name = {
          group_name = "TrackNameLabel",
          index = 1
        }
      }
    },

   --[[ Transport = {
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
    },]]--
  }
}

