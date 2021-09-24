-- luacheck: globals include redraw util params clock
local MusicUtil = require "musicutil"
local settings = include("lib/settings")
local UI = include("lib/ui")

return UI.Page.new({
  title = "fall: scales",
  type = UI.Page.MENU,
  enc_handler = function(page, n, d)
    page.menu:handle_menu_enc(n, d)
  end,
  menu = UI.Menu.new(
    1,
    {
      {
        name = "scale",
        value = function()
          return settings.scales[params:get("scale")]
        end,
        enc_3_action = function(_, _, d)
          params:set("scale", util.clamp(params:get("scale") + d, 1, #settings.scales))
          redraw()
        end
      },
      {
        name = "root",
        value = function()
          return MusicUtil.note_num_to_name(params:get("root_note"), true)
        end,
        enc_3_action = function(_, _, d)
          local root = params:get("root_note")
          params:set("root_note", util.clamp(root + d, settings.midi_start_note, settings.midi_end_note))
          redraw()
        end
      },
      {
        name = "tempo",
        value = function()
          return clock.get_tempo()
        end,
      },
    }
  )
})