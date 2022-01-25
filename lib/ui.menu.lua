-- luacheck: globals screen util include _path redraw
local Text = include("lib/ui.text")
local DEFAULT_FONT_SIZE = 8
local MAX_FIELD_WIDTH = 82
local Menu = {}
Menu.__index = Menu

local function validate_menu_selection(menu, menu_items)
  menu.selected_item = util.clamp(menu.selected_item, 1, #menu_items)
end

local function draw_scroll_hint()
  screen.display_png(_path.code .. "ambalek/resources/down-arrow.png", 110, 54)
end

function Menu.new(selected_item, items)
  local menu = {}
  menu.selected_item = selected_item
  menu.items = items
  setmetatable(menu, Menu)
  return menu
end

function Menu:get_menu_items()
  if type(self.items) == "function" then
    return self.items()
  else
    return self.items
  end
end

function Menu.input_field(x, y, name, value, is_active, label_width, max_value_width)
  local margin = 4
  local font_size = DEFAULT_FONT_SIZE
  local box_level = 3
  local label_color = 8
  local value_text = Text.get_text_or_call(value)

  if is_active then box_level = 10 end

  -- Label
  screen.move(x, y)
  screen.font_size(font_size)
  screen.font_face(1)
  screen.level(label_color)
  screen.text(name)

  if not value_text then return end

  -- Box
  if is_active then
    screen.level(box_level)
    screen.rect(x + label_width + margin, y - font_size, max_value_width, font_size + margin / 2)
    screen.level(3)
    screen.fill()
  end

  -- Value
  screen.move(x + label_width + margin + margin, y - 1)
  if is_active then
    screen.level(15)
  else
    screen.level(3)
  end

  if screen.text_extents(value_text) > max_value_width - (margin * 2) then
    screen.text(util.trim_string_to_width(value_text, max_value_width - (margin * 2)))
  else
    screen.text(value_text)
  end
end

function Menu:handle_menu_enc(n, d)
  local menu_items = self:get_menu_items()
  local selected_item = menu_items[self.selected_item]
  if n == 2 then
    self.selected_item = util.clamp(self.selected_item + d, 1, #menu_items)
    redraw()
  elseif n == 3 and selected_item.enc_3_action then
    selected_item.enc_3_action(self, n, d)
  end
end

function Menu.call_key_action(menu_items, selected_item, key)
  if not menu_items[selected_item] then return end
  if key == 2 and menu_items[selected_item].key_2_action then
    menu_items[selected_item].key_2_action()
  elseif key == 3 and menu_items[selected_item].key_3_action then
    menu_items[selected_item].key_3_action()
  end
end

function Menu:redraw(page)
  local menu = page.menu
  local x = 1
  local y
  local horizontal_margin = 2
  local start_index = 1
  local max_items = page.options.type.options.max_items - 1
  local menu_items = self:get_menu_items(menu)
  if not menu_items then
    return
  end
  local item_count = #menu_items

  if page.type.options.show_title == false then
    y = 9
  else
    page:render_title()
    y = 19
  end

  if menu.selected_item > max_items then
    start_index = menu.selected_item - max_items
  end

  if #menu_items > page.type.options.max_items and menu.selected_item < #menu_items then
    draw_scroll_hint()
    item_count = start_index + util.clamp(#menu_items, 1, max_items)
  end

  validate_menu_selection(menu, menu_items)

  for i = start_index, item_count do
    local item = menu_items[i]
    self.input_field(x, y, item.name, item.value, menu.selected_item == i, 30, MAX_FIELD_WIDTH)
    y = y + DEFAULT_FONT_SIZE + horizontal_margin
  end

  page:draw_key_actions()
end

return Menu