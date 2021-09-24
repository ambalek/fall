-- luacheck: globals include redraw util params
local UI = include("lib/ui")
local settings = include("lib/settings")

local function round(value)
  return util.round(value, 0.0001)
end

return UI.Page.new({
  title = "fall: delays",
  type = UI.Page.MENU,
  enc_handler = function(page, n, d)
    page.menu:handle_menu_enc(n, d)
  end,
  menu = UI.Menu.new(
    1,
    {
      {
        name = "1 time",
        value = function()
          return round(params:get("short_delay_time"))
        end,
        enc_3_action = function(_, _, d)
          params:set("short_delay_time", util.clamp(params:get("short_delay_time") + d / 100, 1, 5))
          redraw()
        end
      },
      {
        name = "1 fdbk",
        value = function()
          return round(params:get("short_delay_feedback"))
        end,
        enc_3_action = function(_, _, d)
          params:set("short_delay_feedback", util.clamp(params:get("short_delay_feedback") + d / 1000, 0, 1))
          redraw()
        end
      },
      {
        name = "1 level",
        value = function()
          return round(params:get("short_delay_level"))
        end,
        enc_3_action = function(_, _, d)
          params:set("short_delay_level", util.clamp(params:get("short_delay_level") + d / 1000, 0, 1))
          redraw()
        end
      },
      {
        name = "2 time",
        value = function()
          return round(params:get("long_delay_time"))
        end,
        enc_3_action = function(_, _, d)
          params:set("long_delay_time", util.clamp(params:get("long_delay_time") + d / 10, 1, settings.max_loop_length))
          redraw()
        end
      },
      {
        name = "2 fdbk",
        value = function()
          return round(params:get("long_delay_feedback"))
        end,
        enc_3_action = function(_, _, d)
          params:set("long_delay_feedback", util.clamp(params:get("long_delay_feedback") + d / 1000, 0, 1))
          redraw()
        end
      },
      {
        name = "2 level",
        value = function()
          return round(params:get("long_delay_level"))
        end,
        enc_3_action = function(_, _, d)
          params:set("long_delay_level", util.clamp(params:get("long_delay_level") + d / 1000, 0, 1))
          redraw()
        end
      },
    }
  )
})