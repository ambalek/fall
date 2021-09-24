-- luacheck: globals include screen params util
local UI = include("lib/ui")

return UI.Page.new({
  title = "fall: LFOs",
  type = UI.Page.CUSTOM,
  selected_lfo = 1,
  selected_menu_item = 1,
  key_3_action = {
    label = function(page)
    local LFO = page.LFO
    local lfo = LFO.lfos[page.options.selected_lfo]
      if lfo:is_active() then
        return "K3: off"
      else
        return "K3: on"
      end
    end,
    action = function(page)
      print("K3 action")
      local LFO = page.LFO
      local lfo = LFO.lfos[page.options.selected_lfo]
      lfo:toggle()
    end
  },
  enc_handler = function(page, n, d)
    local LFO = page.LFO
    if LFO == nil then return end
    local lfo = LFO.lfos[page.options.selected_lfo]
    if n == 2 then
      page.options.selected_menu_item = util.clamp(page.options.selected_menu_item + d, 1, 6)
    elseif n == 3 then
      if page.options.selected_menu_item == 1 then
        page.options.selected_lfo = util.clamp(page.options.selected_lfo + d, 1, #LFO.lfos)
      elseif page.options.selected_menu_item == 2 then
        local target_index = util.clamp(lfo:target() + d, 1, #LFO.TARGETS)
        params:set("lfo_" .. lfo.params_id .. "_target", target_index)
      elseif page.options.selected_menu_item == 3 then
        local rate = util.clamp(lfo:rate() + d, 1, LFO.LFO_RATE_MAX)
        params:set("lfo_" .. lfo.params_id .. "_rate", rate)
      elseif page.options.selected_menu_item == 4 then
        local shape = util.clamp(lfo:shape() + d, 1, #LFO.SHAPES)
        params:set("lfo_" .. lfo.params_id .. "_shape", shape)
      elseif page.options.selected_menu_item == 5 then
        local min = util.clamp(lfo:min() + (d / 100), 0, 1)
        if min > 1 then min = 1 end
        if min < 0 then min = 0 end
        params:set("lfo_" .. lfo.params_id .. "_min", min)
      elseif page.options.selected_menu_item == 6 then
        local max = lfo:max() + (d / 100)
        if max > 1 then max = 1 end
        if max < 0 then max = 0 end
        params:set("lfo_" .. lfo.params_id .. "_max", max)
      end
    end
  end,
  render_options = function(page)
    local LFO = page.LFO
    local lfo = LFO.lfos[page.options.selected_lfo]
    local lfo_ids = {}
    for i = 1, #LFO.lfos do
      table.insert(lfo_ids, LFO.lfos[i].params_id)
    end
    local lfo_options = {
      { name = "TRG", index = lfo:target(), values = LFO.TARGETS },
      { name = "SPD", index = lfo:rate() },
      { name = "SHP", index = lfo:shape(), values = LFO.SHAPES },
      { name = "MIN", index = lfo:min(), },
      { name = "MAX", index = lfo:max(), },
    }
    local width = 120 / #lfo_options
    local height = 10
    local margin = 2
    if page.options.selected_menu_item == 1 then
      screen.level(15)
    else
      screen.level(5)
    end
    screen.move(95, 10)
    screen.text("LFO: " .. lfo.params_id)
    local max_value_width = width - margin * 2
    for i = 1, #lfo_options do
      local option = lfo_options[i]
      local x = 4 + ((i - 1) * width)
      local y = 15
      local value_text = tostring(option.index)
      if option.values then
        value_text = tostring(option.values[option.index])
      end
      screen.level(5)
      screen.rect(x, y, width, height)
      screen.stroke()
      screen.move(x + margin, margin + y + height / 2)
      if page.options.selected_menu_item == i + 1 then
        screen.level(15)
      end
      screen.text(option.name)
      screen.level(5)
      screen.rect(x, y + height, width, height)
      screen.stroke()
      screen.move(x + margin, margin + y + height + (height / 2))
      screen.text(util.trim_string_to_width(value_text, max_value_width))
    end
  end,
  render = function(page)
    local LFO = page.LFO
    local x_offset = 5
    local y_offset = 46
    local y_scale = 8
    local x_scale = 9
    page:render_title()
    page.options.render_options(page)
    local lfo = LFO.lfos[page.options.selected_lfo]
    for x = 1, #lfo.data do
      screen.pixel((lfo.data[x].time * x_scale) + x_offset, (lfo.data[x].value * y_scale) + y_offset)
      screen.level(1)
      screen.fill()
    end
    screen.pixel((lfo.current_value.time * x_scale) + x_offset, (lfo.current_value.value * y_scale) + y_offset)
    screen.level(10)
    screen.fill()
    page:draw_key_actions()
    screen.stroke()
  end
})