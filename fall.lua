-- fall (1.3.2)
--
-- generative melodies
--
-- E2: Add/remove leaves
-- E3: Cycle attack/release times
-- K2: Rand notes
-- K3: Rand notes and scales
--
-- written by ambalek for
-- the norns community

-- luacheck: globals engine clock util screen softcut enc key audio init redraw midi params include crow

local settings = include("lib/settings")
local SoundConfigPage = include("lib/page.sound")
local ScaleConfigPage = include("lib/page.scales")
local DelayConfigPage = include("lib/page.delays")
local LFOPage = include("lib/page.lfo")
local LFO = include("lib/lfo")
local FallGrid = include("lib/grid")
local MusicUtil = require "musicutil"
local UI = require "ui"
local ground_level = 58
local screen_width = 120
local midi_device = nil
local midi_start_note = settings.midi_start_note
local midi_end_note = settings.midi_end_note
local max_light_leaves = 20
local max_heavy_leaves = 10
local crow_gate_voltages = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
local visual_timers = {
  default_time = 1500,
  attack = 0,
  release = 0
}

engine.name = 'Autumn'

local pages = UI.Pages.new(1, 5)

local function use_midi()
  return params:get("use_midi") == 1
end

local function use_crow()
  return params:get("use_crow") == 1
end

local function use_jf()
  return params:get("use_jf") == 1
end

local function panic()
  if use_midi() then
    for note = 1, 127 do
      for channel = 1, 16 do
        midi_device:note_off(note, 0, channel)
      end
    end
  end
end

local function make_scale_options()
  local scale_index = params:get("scale")
  local random_scale = settings.scales[scale_index]
  local start_note = params:get("root_note")
  local notes = MusicUtil.generate_scale(start_note, random_scale, 1)

  -- A reference so people know what notes are used
  params:set("notes", table.concat(MusicUtil.note_nums_to_names(notes, false), " "))

  -- Two sets of scales, low and high, to pull from when generating notes
  return {
    high = MusicUtil.generate_scale(start_note, random_scale, 2),
    bass = MusicUtil.generate_scale(start_note - 12, random_scale, 1),
  }
end

local function make_new_scale_options()
  params:set("scale", math.random(1, #settings.scales))
  params:set("root_note", math.random(midi_start_note, midi_end_note))
  return make_scale_options()
end

local scale = nil

-- 4*4 sprites
local sprites = {
  leaves = {
    {
      { 0, 0, 1, 0 },
      { 0, 1, 1, 0 },
      { 0, 1, 1, 0 },
      { 1, 1, 0, 0 },
    },
    {
      { 0, 1, 1, 0 },
      { 0, 1, 1, 1 },
      { 0, 0, 1, 1 },
      { 0, 0, 0, 0 },
    },
   {
      { 0, 0, 0, 0 },
      { 0, 1, 1, 1 },
      { 0, 1, 1, 0 },
      { 1, 1, 0, 0 },
    },
    {
      { 0, 1, 0, 0 },
      { 0, 1, 1, 0 },
      { 0, 1, 1, 0 },
      { 0, 0, 1, 0 },
    },
    {
      { 0, 0, 0, 0 },
      { 0, 1, 1, 1 },
      { 1, 1, 1, 0 },
      { 0, 0, 0, 0 },
    },
    {
      { 1, 0, 0, 0 },
      { 1, 1, 1, 0 },
      { 0, 1, 1, 1 },
      { 0, 0, 0, 0 },
    },
    {
      { 0, 1, 0, 0 },
      { 0, 1, 0, 0 },
      { 0, 1, 0, 0 },
      { 0, 0, 1, 0 },
    },
  }
}

local leaves = {}

local function get_midi_note(bass)
  if bass then
    return scale.bass[math.random(1, #scale.bass)]
  else
    return scale.high[math.random(1, #scale.high)]
  end
end

local function get_attack(_)
  return params:get("attack")
end

local function get_release(_)
  return params:get("release")
end

local function make_leaf(bass, x, y)
  local velocity = math.random(params:get("velocity_min"), params:get("velocity_max"))
  if bass then
    velocity = math.random(params:get("bass_velocity_min"), params:get("bass_velocity_max"))
  end
  if x == nil then
    x = math.random(20, 100)
  end
  if y == nil then
    y = math.random(1, 40)
  end
  return {
    bass = bass,
    sway = math.random(),
    speed = math.random() * (params:get("gravity") / 5),
    sprite_change = math.random(3, 10),
    sprite = math.random(1, #sprites.leaves),
    x = x,
    y = y,
    level = math.random(2, 12),
    fade = math.random(
      params:get("fade_median") - params:get("fade_range"),
      params:get("fade_median") + params:get("fade_range")
    ),
    resting = false,
    midi_note_number = get_midi_note(bass),
    release = get_release(bass),
    attack = get_attack(bass),
    amp = (velocity / 127),
    velocity = velocity,
    collision_counter = nil
  }
end

local function add_random_leaf(x, y)
  local bass = math.random() > 0.85
  if bass then
    params:set("heavy_leaves", util.clamp(params:get("heavy_leaves") + 1, 0, max_heavy_leaves))
  else
    params:set("light_leaves", util.clamp(params:get("light_leaves") + 1, 1, max_light_leaves))
  end
  if #leaves < (max_heavy_leaves + max_light_leaves) then
    table.insert(leaves, make_leaf(bass, x, y))
  end
end

local function remove_leaf_by_id(id)
  if leaves[id].bass and params:get("heavy_leaves") > 0 then
    params:set("heavy_leaves", params:get("heavy_leaves") - 1)
  elseif params:get("light_leaves") > 1 then
    params:set("light_leaves", params:get("light_leaves") - 1)
  end
  table.remove(leaves, id)
end

local function remove_random_leaf()
  if #leaves > 1 then
    local id = math.random(1, #leaves)
    remove_leaf_by_id(id)
  end
end

local function get_pan(leaf)
  return ((leaf.x / screen_width) - 0.5) * 2
end

local function schedule_note_off(leaf)
  local ticks = math.ceil((leaf.attack * 10) * (leaf.release * 10))
  clock.run(
    function()
      while ticks > 0 do
        ticks = ticks - 1
        clock.sync(1 / 16)
        if ticks == 0 then
          midi_device:note_off(leaf.midi_note_number, leaf.velocity, params:get("midi_out_channel"))
        end
      end
    end
  )
end

local function make_sound()
  return params:get("make_sound") == 1
end

local function make_rustle()
  return params:get("make_rustle") == 1
end

local function play(leaf)
  if make_sound() then
    engine.release(leaf.release + LFO.last_release_value)
    engine.attack(leaf.attack + LFO.last_attack_value)
    engine.pan(get_pan(leaf))
    engine.amp(leaf.amp)
    engine.hz(MusicUtil.note_num_to_freq(leaf.midi_note_number))
  end
  if use_midi() and midi_device then
    midi_device:note_on(leaf.midi_note_number, leaf.velocity, params:get("midi_out_channel"))
    if params:get("use_midi_pan") == 1 then
      midi_device:cc(10, math.floor(get_pan(leaf) * 127))
    end
    schedule_note_off(leaf)
  end
  if use_crow() then
    crow.output[1].volts = (((leaf.midi_note_number)-60)/12)
    local gate_voltage = params:get("crow_volt")
    if params:get("crow_dyn") == 1 then
       gate_voltage = gate_voltage * (leaf.velocity/127)
    end
    crow.output[2].action = "{to(".. gate_voltage ..",0),to(0,".. 0.05 .. ")}"
    crow.output[2]()
  end
  if use_jf() then
    crow.ii.jf.play_note((leaf.midi_note_number-60)/12, 5)
  end
end

local function play_rustle(leaf)
  if make_rustle() then
    local amp = (util.wrap(leaf.sway, 1, params:get("rustle_limit")) / 100) + 0.1
    local freq = math.floor(1200 + (leaf.speed * 5000))
    engine.rustlepan(get_pan(leaf))
    engine.rustleamp(amp)
    engine.rustle(freq)
  end
end

local function winds()
  local wind = params:get("wind") / 100
  for i = 1, #leaves do
    local leaf = leaves[i]
    if leaf.resting == true then
      leaf.fade = leaf.fade - 0.1
      leaf.level = math.floor(leaf.fade)
      if leaf.level < 0 then
        leaves[i] = make_leaf(leaf.bass)
        leaves[i].y = 0
      end
    else
      leaf.y = leaf.y + leaf.speed
      leaf.sway = leaf.sway + wind
      leaf.x = util.wrap(leaf.x + math.sin(leaf.sway), 0, 120)
      leaf.sprite_change = leaf.sprite_change - 1
      if leaf.sprite_change == 0 then
        leaf.sprite_change = math.random(3, 10)
        leaf.sprite = math.random(1, #sprites.leaves)
      end
      if leaf.y > ground_level then
        leaf.resting = true
        play(leaf)
      end
    end
  end
end

local function collisions()
  local collision_map = {}
  for i = 1, #leaves do
    local leaf = leaves[i]
    if leaf.resting == false then
      local x = math.floor(leaf.x / 4)
      local y = math.floor(leaf.y / 4)
      if collision_map[y] == nil then
        collision_map[y] = {}
      end
      if collision_map[y][x] == 1 then
        if leaf.collision_counter ~= nil then
          leaf.collision_counter = leaf.collision_counter - 1
          if leaf.collision_counter == 0 then
            leaf.collision_counter = nil
          end
        else
          leaf.collision_counter = 10
          play_rustle(leaf)
        end
      else
        collision_map[y][x] = 1
      end
    end
  end
end

local function level_for_timer(value)
  return util.round((value / visual_timers.default_time) * 15)
end

function redraw()
  screen.clear()
  if pages.index == 1 then
    for i = 1, #leaves do
      local leaf = leaves[i]
      local leaf_sprite = sprites.leaves[leaf.sprite]
      screen.level(leaf.level)
      for ly = 1, #leaf_sprite do
        for lx = 1, #leaf_sprite[ly] do
          if leaf_sprite[ly][lx] == 1 then
            screen.pixel(leaf.x + lx, leaf.y + ly)
            screen.stroke()
          end
        end
      end
      if visual_timers.attack > 0 then
        visual_timers.attack = visual_timers.attack - 1
        screen.level(level_for_timer(visual_timers.attack))
        screen.move(10, 5)
        screen.text("atk: " .. util.round(params:get("attack"), 0.00001))
      end
      if visual_timers.release > 0 then
        visual_timers.release = visual_timers.release - 1
        screen.level(level_for_timer(visual_timers.release))
        screen.move(10, 15)
        screen.text("rel: " .. util.round(params:get("release"), 0.00001))
      end
    end
  elseif pages.index == 2 then
    pages:redraw()
    ScaleConfigPage.menu:redraw(ScaleConfigPage)
  elseif pages.index == 3 then
    pages:redraw()
    SoundConfigPage.menu:redraw(SoundConfigPage)
  elseif pages.index == 4 then
    pages:redraw()
    DelayConfigPage.menu:redraw(DelayConfigPage)
  elseif pages.index == 5 then
    pages:redraw()
    local page = LFOPage
    page.LFO = LFO
    page.render(page)
  end
  FallGrid.draw(leaves)
  screen.update()
end

local function softcut_delay(ch, time, feedback, rate, level)
  softcut.level(ch, level)
  softcut.level_slew_time(ch, 0)
  softcut.level_input_cut(ch, 1, 1.0)
  softcut.level_input_cut(ch, 2, 1.0)
  softcut.pan(ch, 0.0)
  softcut.play(ch, 1)
  softcut.rate(ch, rate)
  softcut.rate_slew_time(ch, 0)
  softcut.loop_start(ch, 0)
  softcut.loop_end(ch, time)
  softcut.loop(ch, 1)
  softcut.fade_time(ch, 0.1)
  softcut.rec(ch, 1)
  softcut.rec_level(ch, 1)
  softcut.pre_level(ch, feedback)
  softcut.position(ch, 0)
  softcut.enable(ch, 1)
  softcut.pre_filter_dry(ch, 0)
  softcut.pre_filter_hp(ch, 1.0)
  softcut.pre_filter_fc(ch, 300)
  softcut.pre_filter_rq(ch, 4.0)
end

local function apply_delays()
  softcut_delay(1,
    params:get("long_delay_time"), params:get("long_delay_feedback"), 1.0, params:get("long_delay_level")
  )
  softcut_delay(2,
    params:get("short_delay_time"), params:get("short_delay_feedback"), 1.0, params:get("short_delay_level")
  )
end

local function softcut_setup()
  softcut.reset()
  for i = 1, 2 do
    softcut.position(i, 0)
    softcut.rate(0, 1)
  end
  softcut.buffer_clear()
  audio.level_cut(1.0)
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  apply_delays()
end

local function make_leaves()
  leaves = {}
  for _ = 1, params:get("light_leaves") do
    table.insert(leaves, make_leaf(false))
  end

  for _ = 1, params:get("heavy_leaves") do
    table.insert(leaves, make_leaf(true))
  end
end

local function repitch_leaves()
  scale = make_scale_options()
  for i = 1, #leaves do
    local leaf = leaves[i]
    leaf.midi_note_number = get_midi_note(leaf.bass)
  end
end

local function setup_params()
  params:add_separator("midi")
  local vports = {}
  params:add_option("use_midi", "use midi", { "Yes", "No" }, 2)
  params:set_action("use_midi", function(value)
    local device = params:get("midi_out_device")
    if device == nil and #vports > 0 then
      device = vports[0]
    end
    if value == 1 and device ~= nil then
      midi_device = midi.connect(device)
    end
  end)
  local function refresh_params_vports()
    for i = 1, #midi.vports do
      vports[i] = midi.vports[i].name ~= "none" and
        util.trim_string_to_width(midi.vports[i].name, 70) or
        tostring(i)..": [device]"
    end
  end
  refresh_params_vports()
  params:add_option("midi_out_device", "MIDI out", vports, 1)
  params:set_action("midi_out_device", function(value)
    midi_device = midi.connect(value)
  end)
  params:add_number("midi_out_channel", "midi out channel", 1, 16, 1)
  params:add_option("use_midi_pan", "midi panning", { "Yes", "No" }, 2)
  params:add_separator("crow")
  params:add_option("use_crow", "use crow (1+2)", { "Yes", "No" }, 2)
  params:add_option("crow_volt", "gate voltage", crow_gate_voltages, 8)
  params:add_option("crow_dyn", "dynamic gates", {"Yes", "No"}, 2)
  params:add_separator("just friends")
  params:add_option("use_jf", "use just friends", { "Yes", "No" }, 2)
  params:set_action("use_jf", function(value)
    if value == 1 then
      crow.ii.pullup(true)
      crow.ii.jf.mode(1)
    end
  end)
  params:add_separator("sound")
  params:add_option("make_sound", "make sound", { "Yes", "No" }, 1)
  params:add_option("make_rustle", "make rustles", { "Yes", "No" }, 1)
  params:add_number("velocity_min", "velocity min", 1, 127, 20)
  params:add_number("velocity_max", "velocity max", 1, 127, 90)
  params:add_number("bass_velocity_min", "bass velocity min", 1, 127, 10)
  params:add_number("bass_velocity_max", "bass velocity max", 1, 127, 70)
  params:add_number("rustle_limit", "rustle gain limit", 1, 50, 20)

  params:add_separator("time and delays")
  params:add_taper("short_delay_time", "short delay", 1, 5, 1, 0.01, "sec")
  params:set_action("short_delay_time", function(value) softcut.loop_end(2, value) end)
  params:add_taper("short_delay_level", "short delay gain", 0, 1, 0.4, 0.01, "")
  params:set_action("short_delay_level", function(value) softcut.level(2, value) end)
  params:add_taper("short_delay_feedback", "short delay feedback", 0, 1, 0.5, 0.01)
  params:set_action("short_delay_feedback", function()
    apply_delays()
  end)
  params:add_taper("long_delay_time", "long delay", 1, settings.max_loop_length, 10, 0.1, "sec")
  params:set_action("long_delay_time", function(value) softcut.loop_end(1, value) end)
  params:add_taper("long_delay_level", "long delay gain", 0, 1, 0.6, 0.01, "")
  params:set_action("long_delay_level", function(value) softcut.level(1, value) end)
  params:add_taper("long_delay_feedback", "long delay feedback", 0, 1, 0.5, 0.01)
  params:set_action("long_delay_feedback", function()
    apply_delays()
  end)

  params:add_separator("melodies")
  params:add_option("scale", "scale", settings.scales, math.random(1, #settings.scales))
  params:add_text("notes", "notes", "")
  params:set_action("scale", function()
    repitch_leaves()
  end)
  params:add_number(
    "root_note", "root note", midi_start_note, midi_end_note, math.random(midi_start_note, midi_end_note),
    function(root_note)
      return MusicUtil.note_num_to_name(root_note.value, true)
    end
  )
  params:set_action("root_note", function()
    repitch_leaves()
  end)
  params:add_taper("wind", "wind", 1, 10, 3, 0.01, "")
  params:add_taper("gravity", "gravity", 0.01, 10, 2, 0.01, "")
  params:add_number("fade_median", "leaf fade median", 1, 50, 14)
  params:add_number("fade_range", "leaf fade range", 1, 50, 8)
  params:add_number("light_leaves", "total light leaves", 1, max_light_leaves, 8)
  params:add_number("heavy_leaves", "total heavy leaves", 1, max_heavy_leaves, 2)

  params:add_separator("autumn engine")
  params:add_taper("attack", "attack", 0, 10, 1.0, 0.001, "seconds")
  params:add_taper("release", "release", 0, 10, 3.0, 0.001, "seconds")
  params:add_taper("pw", "pulse width", 0, 1, 0.6, 0.01)
  params:set_action("pw", function(value)
    engine.pw(value)
  end)
  params:add_number("bits", "bits", 6, 32, 13)
  params:set_action("bits", function(value)
    engine.bits(value)
  end)
  engine.bits(params:get("bits"))
  LFO.init()
end

function enc(n, d)
  if n == 1 then
    pages:set_index_delta(util.clamp(d, -1, 1), false)
  end
  if pages.index == 1 then
    if n == 2 then
      if math.random() > 0.8 then
        if d > 0 then
          add_random_leaf()
        else
          remove_random_leaf()
        end
      end
    elseif n == 3 then
      if d > 0 then
        local attack = params:get("attack")
        visual_timers.attack = visual_timers.default_time
        params:set("attack", util.wrap(attack - (d / 100), 0, 10))
      else
        local release = params:get("release")
        visual_timers.release = visual_timers.default_time
        params:set("release", util.wrap(release + (d / 100), 0, 10))
      end
    end
  elseif pages.index == 2 then
    ScaleConfigPage.enc_handler(ScaleConfigPage, n, d)
  elseif pages.index == 3 then
    SoundConfigPage.enc_handler(SoundConfigPage, n, d)
  elseif pages.index == 4 then
    DelayConfigPage.enc_handler(DelayConfigPage, n, d)
  elseif pages.index == 5 then
    LFOPage.enc_handler(LFOPage, n, d)
  end
end

local function call_key_page_action(page, key)
  if key == 2 and page.key_2_action then
    page.key_2_action.action(page)
  elseif key == 3 and page.key_3_action then
    page.key_3_action.action(page)
  end
end

function key(n, z)
  if pages.index == 1 then
    if n == 3 and z == 1 then
      softcut_setup()
      scale = make_new_scale_options()
      make_leaves()
    elseif n == 2 and z == 1 then
      scale = make_scale_options()
      make_leaves()
    end
  elseif pages.index == 5 and z == 1 then
    call_key_page_action(LFOPage, n)
  end
end

function init()
  FallGrid.init(remove_leaf_by_id, add_random_leaf)
  setup_params()
  params:default()
  scale = make_scale_options()
  softcut_setup()
  panic()
  make_leaves()
  engine.hiss(0)
  engine.attack(0.1)
  engine.release(4)
  engine.amp(0.2)
  engine.pan(0.5)
  engine.pw(params:get("pw"))

  clock.run(
    function()
      while true do
        clock.sleep(1 / 30)
        redraw()
      end
    end
  )

  clock.run(
    function()
      while true do
        clock.sync(1 / 16)
        winds()
      end
    end
  )

  clock.run(
    function()
      while true do
        clock.sync(1 / 10)
        collisions()
      end
    end
  )
end
