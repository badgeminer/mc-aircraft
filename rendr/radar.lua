-- Reactor Core View Graphics Element

local util    = require("scada-common.util")

local core    = require("graphics.core")
local pxt    = require("pixelBox")
local element = require("graphics.element")

local function buildPx(char)
    if char[6] == 1 then for i = 1, 5 do char[i] = 1-char[i] end end
    local n = 128
    for i = 0, 4 do n = n + char[i+1]*2^i end
    return string.char(n),char[6] == 1 and "F" or "D",char[6] == 1 and "D" or "F"
end

---@class core_map_args
---@field reactor_l integer reactor length
---@field reactor_w integer reactor width
---@field parent graphics_element
---@field id? string element id
---@field x? integer 1 if omitted
---@field y? integer auto incremented if omitted

-- new core map box
---@nodiscard
---@param args core_map_args
---@return graphics_element element, element_id id
local function core_map(args)

    -- require max dimensions
    args.width = 18
    args.height = 18

    -- inherit only foreground color
    args.fg_bg = core.cpair(args.parent.get_fg_bg().fgd, colors.gray)

    -- create new graphics element base object
    local e = element.new(args)

    e.value = 0

    local alternator = false

    local core_l = args.height-1
    local core_w = args.width-1

    local shift_x = 8 - math.floor(core_l / 2)
    local shift_y = 8 - math.floor(core_w / 2)

    local start_x = 2 + shift_x
    local start_y = 2 + shift_y

    local inner_width = core_l
    local inner_height = core_w
    local pb = pxt.new(e.window)
    local pix = {}

    local function map_coordinates(X, Y)
        local x = math.floor((X - 1) / 2) + 1
        local y = math.floor((Y - 1) / 3) + 1
        local col_offset = (X - 1) % 2
        local row_offset = (Y - 1) % 3
        local i = row_offset * 2 + col_offset + 1
        return x, y, i
    end

    -- Center point
    local centerX, centerY = 16, 24

    -- Function to convert polar to Cartesian coordinates
    local function polarToCartesian(angle, distance)
        local radians = math.rad(angle)
        local x = centerX + math.floor(distance * math.cos(radians)+0.5)
        local y = centerY + math.floor(distance * math.sin(radians)+0.5)
        return x, y
    end



    for x = 1, core_l, 1 do
        local r = {}
        for y = 1, core_w, 1 do
            table.insert(r,{0,0,0,0,0,0})
            --r[y][y%6] = 1
            --r[y][x%6] = 1
        end
        pix[x] = r
    end
    -- create coordinate grid and frame
    local function draw_frame()
        e.w_set_fgd(colors.white)

        for x = 0, (inner_width - 1) do
            e.w_set_cur(x + start_x, 1)
            e.w_write(util.sprintf("%X", math.abs(8-x)))
        end

        for y = 0, (inner_height - 1) do
            e.w_set_cur(1, y + start_y)
            e.w_write(util.sprintf("%X", math.abs(8-y)))
        end

        -- even out bottom edge
        e.w_set_fgd(e.fg_bg.bkg)
        e.w_set_bkg(args.parent.get_fg_bg().bkg)
        e.w_set_cur(1, e.frame.h)
        e.w_write(string.rep("\x8f", e.frame.w))
        e.w_set_fgd(e.fg_bg.fgd)
        e.w_set_bkg(e.fg_bg.bkg)
    end

    -- draw the core
    ---@param t number temperature in K
    local function draw_core(t)
        local i = 1
        -- draw pattern
        for y = start_y, inner_height + (start_y - 1),1 do
            e.w_set_bkg(colors.black)
            e.w_set_cur(start_x, y)
            for x = 1, inner_width,1 do
                e.w_blit(buildPx(pix[x][(y-start_y)+1] or {1,1,1,1,1,1}))
            end

        end
    end

    local function set_px(x,y,i)
        --print(x,y,i)
        pix[x][y][i] = 1
    end
    local function unset_px(x,y,i)
        pix[x][y][i] = 0
    end
    

    -- Function to process multiple points
    local function processPoints(radar_returns)
        for i, point in pairs(radar_returns) do
            local angle, distance = point.angle-90, point.distance
            local x, y = polarToCartesian(angle, distance)
            --print(angle,distance,"|",x,y)
            set_px(map_coordinates(x,y))
        end
    end

    local function wipe()
        for x = 1, core_l, 1 do
            for y = 1, core_w, 1 do
                pix[x][y] = {0,0,0,0,0,0}
                --r[y][y%6] = 1
                --r[y][x%6] = 1
            end
        end
    end

    -- on state change
    ---comment
    ---@param radar_returns table
    function e.on_update(radar_returns)
        e.value = radar_returns
        wipe()
        processPoints(radar_returns)
        
        --e.redraw()
        draw_core(1)
    end

    

    -- set temperature to display
    ----@param val number degrees K
    --function e.set_value(val) e.on_update(val) end

    

    -- Example points
    local pointsT = {
        {angle = 45, distance = 0},
    }

    -- Process the points
    processPoints(pointsT)




    -- resize reactor dimensions
    ---@param reactor_l integer reactor length (rendered in 2D top-down as width)
    ---@param reactor_w integer reactor width (rendered in 2D top-down as height)
    function e.resize(reactor_l, reactor_w)
        -- enforce possible dimensions
        if reactor_l > 18 then reactor_l = 18 elseif reactor_l < 3 then reactor_l = 3 end
        if reactor_w > 18 then reactor_w = 18 elseif reactor_w < 3 then reactor_w = 3 end

        -- update dimensions
        core_l = reactor_l - 2
        core_w = reactor_w - 2
        shift_x = 8 - math.floor(core_l / 2)
        shift_y = 8 - math.floor(core_w / 2)
        start_x = 2 + shift_x
        start_y = 2 + shift_y
        inner_width = core_l
        inner_height = core_w

        e.window.clear()

        -- re-draw
        draw_frame()
        e.on_update(e.value)
    end

    -- redraw both frame and core
    function e.redraw()
        draw_frame()
        draw_core(1)
        --pb:render()
    end
    --set_px(2,5,3)
    -- initial draw
    e.redraw()

    return e.complete()
end

return core_map
