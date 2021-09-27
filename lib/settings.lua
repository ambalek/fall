-- luacheck: globals

local midi_start_note = 46
local midi_end_note = 74

return {
  scales = { "Minor Pentatonic", "Major Pentatonic", "Mixolydian", "Phrygian" },
  midi_start_note = midi_start_note,
  midi_end_note = midi_end_note,
  max_loop_length = 50
}