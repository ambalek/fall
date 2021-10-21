-- luacheck: globals screen util clock params softcut engine include
local settings = include("lib/settings")
local LFO_SINE = 1
local LFO_SQUARE = 2
local LFO_SH = 3
local LFO_MAX = 3
local LFO_RESOLUTION = 100
local LFO_TIMER_INTERVAL = (math.pi * 2) / LFO_RESOLUTION
local LFO_RATE_MAX = 100
local LFO_TOTAL_TIME = 4 * math.pi
local LFO_QUANTIZED_RATE_VALUES = { -2.0, -1.0, -0.75, -0.5, -0.25, 0.25, 0.5, 0.75, 1.0, 2.0 }
local LFO_BITS_BASE = 8
local LFO_BITS_MAX = 24

local LFO = {
  lfos = {},
  last_attack_value = 0,
  last_release_value = 0,
}

LFO.__index = LFO

LFO.SHAPES = {
 "Sine",
 "Square",
 "S+H"
}

LFO.TARGETS = { "l del", "s del", "pw", "attack", "release", "bits", "scale", "root" }

LFO.LFO_RATE_MAX = LFO_RATE_MAX

local LFO_TARGET_DELAY_1_RATE = 1
local LFO_TARGET_DELAY_2_RATE = 2
local LFO_TARGET_PW = 3
local LFO_TARGET_ATTACK = 4
local LFO_TARGET_RELEASE = 5
local LFO_TARGET_BITS = 6
local LFO_TARGET_SCALE = 7
local LFO_TARGET_ROOT = 8

function LFO.new(params_id)
  local lfo = {}
  setmetatable(lfo, LFO)
  lfo.params_id = params_id
  lfo.time = 0
  lfo.current_value = {
    time = 0,
    value = 0
  }
  lfo.timer_countdown = 0
  return lfo
end

function LFO.init()
  params:add_separator("lfo")
  for i = 1, LFO_MAX do
    params:add_option(
      "lfo_" .. i .. "_target",
      "lfo " .. i .. " target",
      LFO.TARGETS,
      LFO_TARGET_PW
    )
    params:add_number("lfo_" .. i .. "_rate", "lfo " .. i .. " rate", 1, LFO_RATE_MAX, 90)
    params:add_option("lfo_" .. i .. "_shape", "lfo " .. i .. " shape", LFO.SHAPES, LFO_SINE)
    params:add_taper("lfo_" .. i .. "_depth", "lfo " .. i .. " depth", 1, 10, 1, 0.01)
    params:add_taper("lfo_" .. i .. "_min", "lfo " .. i .. " min", 0, 1, 0, 0.01)
    params:add_taper("lfo_" .. i .. "_max", "lfo " .. i .. " max", 0, 1, 1, 0.01)
    params:add_option("lfo_" .. i .. "_is_active", "lfo " .. i .. " is_active", { "No", "Yes" }, 1)

    local lfo = LFO.new(i)

    params:set_action("lfo_" .. i .. "_rate", function()
      lfo:generate_preview()
    end)

    params:set_action("lfo_" .. i .. "_shape", function()
      lfo:generate_preview()
    end)

    params:set_action("lfo_" .. i .. "_min", function()
      lfo:generate_preview()
    end)

    params:set_action("lfo_" .. i .. "_max", function()
      lfo:generate_preview()
    end)

    lfo:generate_preview()
    table.insert(LFO.lfos, lfo)
    lfo:start()
  end
end

function LFO:target()
  return params:get("lfo_" .. self.params_id .. "_target")
end

function LFO:rate()
  return params:get("lfo_" .. self.params_id .. "_rate")
end

function LFO:shape()
  return params:get("lfo_" .. self.params_id .. "_shape")
end

function LFO:depth()
  return params:get("lfo_" .. self.params_id .. "_depth")
end

function LFO:min()
  return params:get("lfo_" .. self.params_id .. "_min")
end

function LFO:max()
  return params:get("lfo_" .. self.params_id .. "_max")
end

function LFO:is_active()
  return params:get("lfo_" .. self.params_id .. "_is_active") == 2
end

function LFO:set_is_active(is_active)
  local is_active_index = 1
  if is_active then
    is_active_index = 2
  end
  params:set("lfo_" .. self.params_id .. "_is_active", is_active_index)
end

function LFO:toggle()
  self:set_is_active(not self:is_active())
  if self:is_active() then
    self:start()
  else
    self:stop()
  end
end

function LFO:update()
  self.time = self.time + 1
  if self.time > #self.data then
    self.time = 1
  end
  if self.data[self.time] then
    self.current_value = self.data[self.time]
  end
end

function LFO:generate_sine()
  local range = (self:max() - self:min())
  local time = 0
  while true do
    time = time + LFO_TIMER_INTERVAL
    if time > LFO_TOTAL_TIME then
      return
    end
    local value = math.sin(time)
    table.insert(self.data, { time = time, value = value * range })
  end
end

function LFO:generate_square()
  local time = 0
  local range = (self:max() - self:min())
  local p = math.pi * 2
  local value
  while true do
    time = time + LFO_TIMER_INTERVAL
    if time > LFO_TOTAL_TIME then
      return
    end
    if time % p < p / 2 then
      value = 1
    else
      value = -1
    end
    table.insert(self.data, { time = time, value = value * range })
  end
end

function LFO:generate_sh()
  local time = 0
  local range = (self:max() - self:min())
  local p = 20
  local value = math.random()
  while true do
    time = time + LFO_TIMER_INTERVAL
    if time > LFO_TOTAL_TIME then
      return
    end
    if math.floor(time * 100) % math.floor(p) == 0 then
      value = math.random()
    end
    table.insert(self.data, { time = time, value = value * range })
  end
end

function LFO:generate_preview()
  self.data = {}
  if self:shape() == LFO_SINE then
    self:generate_sine()
  elseif self:shape() == LFO_SQUARE then
    self:generate_square()
  elseif self:shape() == LFO_SH then
    self:generate_sh()
  end
end

local function quantize(value, values)
  local last = values[1]
  if value < last then
    return last
  end
  for i = 2, #values do
    local current = values[i]
    if value == current then
      return current
    elseif value >= last and value <= current then
      return current
    end
    last = current
  end
  return last
end

local function scale_range(value, new_min, new_max)
  local min = -1
  local max = 1
  return math.floor((
    (
      (value - min)
      * (new_max - new_min)
      / (max - min)
    )
    + new_min
  ) + 0.5)
end

function LFO:apply_action()
  local target = self:target()
  local value = self.current_value.value
  -- value range = -1 to 1
  if target == LFO_TARGET_DELAY_1_RATE then
    softcut.rate(1, quantize(value, LFO_QUANTIZED_RATE_VALUES))
  elseif target == LFO_TARGET_DELAY_2_RATE then
    softcut.rate(2, quantize(value, LFO_QUANTIZED_RATE_VALUES))
  elseif target == LFO_TARGET_PW then
    -- Pivot around the params pw value because value will be negative (-1 to 1)
    local pw = util.clamp(((value) / 2) + params:get("pw"), 0, 1)
    engine.pw(pw)
  elseif target == LFO_TARGET_ATTACK then
    LFO.last_attack_value = (value / 2) + 1
  elseif target == LFO_TARGET_RELEASE then
    LFO.last_release_value = (value / 2) + 1
  elseif target == LFO_TARGET_BITS then
    local bits = scale_range(value, LFO_BITS_BASE, LFO_BITS_MAX)
    engine.bits(bits)
  elseif target == LFO_TARGET_SCALE then
    local scale = scale_range(value, 1, #settings.scales)
    params:set("scale", scale)
  elseif target == LFO_TARGET_ROOT then
    local root_note = scale_range(value, settings.midi_start_note, settings.midi_end_note)
    params:set("root_note", root_note)
  end
end

function LFO:start()
  self.clock = clock.run(function()
    while true do
      if self.timer_countdown == 0 then
        self.timer_countdown = LFO_RATE_MAX - self:rate() + 1
        if self:is_active() then
          self:update()
          self:apply_action()
        end
      end
      self.timer_countdown = self.timer_countdown - 1
      clock.sync(1 / 128)
    end
  end)
end

function LFO:stop()
  clock.cancel(self.clock)
end

return LFO