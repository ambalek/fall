-- luacheck: globals screen include redraw
local Text = include("lib/ui.text")
local Pages = include("lib/ui.pages")
local SCREEN_BOTTOM = 64
local Page = {
  MENU = {
    type = "menu",
    options = {
      max_items = 5,
      show_title = true
    },
  },
  MENU_WITH_TITLE = {
    type = "menu_with_title",
    options = {
      max_items = 4,
      show_title = true
    },
  },
  CUSTOM = {
    type = "custom",
    options = {
      show_title = true
    },
  },
}
Page.__index = Page

function Page.new(options)
  local page = {}
  setmetatable(page, Page)
  page.options = options
  page.title = options.title
  page.menu = options.menu
  page.type = options.type
  page.key_2_action = options.key_2_action
  page.key_3_action = options.key_3_action
  page.enc_handler = options.enc_handler
  page.selected_item = options.selected_item
  page.render = options.render
  return page
end

Page.go_to_page = function(page)
  Pages.selected_page = page
  redraw()
end

function Page:draw_key_actions()
  screen.level(3)
  if self.options.key_2_action and self.options.key_2_action.label then
    screen.move(0, SCREEN_BOTTOM)
    screen.text(Text.get_text_or_call(self.options.key_2_action.label, self))
  end
  if self.options.key_3_action and self.options.key_3_action.label then
    screen.move(94, SCREEN_BOTTOM)
    screen.text(Text.get_text_or_call(self.options.key_3_action.label, self))
  end
end

function Page:render_title()
  screen.level(3)
  screen.move(1, 9)
  screen.text(Text.get_text_or_call(self.options.title, self.options))
end

return Page