-- luacheck: globals grid util params

local NORNS_WIDTH = 128
local NORNS_HEIGHT = 64
local GRID_WIDTH = 17
local GRID_HEIGHT = 9
local FallGrid = {}

local function leaf_to_grid_x(value)
  return util.round((value / NORNS_WIDTH) * GRID_WIDTH)
end

local function leaf_to_grid_y(value)
  return util.round((value / NORNS_HEIGHT) * GRID_HEIGHT)
end

local function grid_to_leaf_x(value)
  return util.round((value * NORNS_WIDTH) / GRID_WIDTH)
end

local function grid_to_leaf_y(value)
  return util.round((value * NORNS_HEIGHT) / GRID_HEIGHT)
end

local function remove_leaf_near(remove_leaf_by_id, grid_x, grid_y)
  for id = 1, #FallGrid.leaves do
    local leaf = FallGrid.leaves[id]
    if leaf ~= nil then
      if grid_x == leaf.grid_x and grid_y == leaf.grid_y then
        remove_leaf_by_id(id)
      end
    end
  end
end

FallGrid.init = function(remove_leaf_by_id, add_leaf)
  FallGrid.g = grid.connect()
  function FallGrid.g.key(x, y, z)
    if z == 0 and y == 8 then
      remove_leaf_near(remove_leaf_by_id, x, y)
    elseif z == 1 and y < 8 then
      add_leaf(grid_to_leaf_x(x), grid_to_leaf_y(y))
    end
  end
end

FallGrid.draw = function(leaves)
  FallGrid.g:all(0)
  FallGrid.leaves = leaves
  for i = 1, #leaves do
    local leaf = leaves[i]
    if leaf.level > 0 then
      local x = leaf_to_grid_x(leaf.x)
      local y = leaf_to_grid_y(leaf.y)
      leaf.grid_x = x
      leaf.grid_y = y
      FallGrid.g:led(x, y, leaf.level)
    end
  end
  FallGrid.g:refresh()
end

return FallGrid