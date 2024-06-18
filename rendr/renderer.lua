local panel_view_front = require("rendr.front_panel")
local panel_view_side = require("rendr.rio_panel")
local log         = require("scada-common.log")
local style = require "rendr.style"

local core       = require("graphics.core")
local flasher    = require("graphics.flasher")
local cpair      = core.cpair

local ap_win = window.create(peripheral.wrap("monitor_0"),1,1,15,24)
local rio_win = window.create(peripheral.wrap("monitor_1"),1,1,36,24)

local DisplayBox = require("graphics.elements.displaybox")

log.init("/log/log.txt", 0, true)

---@class reactor_plc_renderer
local renderer   = {}
local a          = {
    ["black"] = 0x111111, ["blue"] = 0x2A7BDE, ["brown"] = 0x571213, ["cyan"] = 0x34bac8, ["gray"] = 0x444444,
    ["green"] = 0x26A269, ["lightBlue"] = 0x00AEFF, ["lightGray"] = 0x777777, ["lime"] = 0x16665a, ["magenta"] = 0x85862c,
    ["orange"] = 0xD06018, ["pink"] = 0x191919, ["purple"] = 0xe3bc2a, ["red"] = 0xC01C28, ["white"] = 0xFFFFFF,
    ["yellow"] = 0xF3F03E }
local ui         = {
    display = nil,
    ap_display = nil,
}

-- try to start the UI
---@return boolean success, any error_msg
function renderer.try_start_ui()
    local status, msg = true, nil

    if ui.display == nil then
        -- reset terminal
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1, 1)

    

        -- set overridden colors

        for b, c in pairs(a) do
            ap_win.setPaletteColor(colors[b], c)
            rio_win.setPaletteColor(colors[b], c)
        end
        for i = 1, #style.colors do
            --mon.setPaletteColor(style.colors[i].c, style.colors[i].hex)
            --term.setPaletteColor(style.colors[i].c, style.colors[i].hex)
        end

        -- init front panel view
        status, msg = pcall(function()
            --ui.display = DisplayBox { window = term.current(), fg_bg = cpair(colors.white, colors.black) }
            ui.display = DisplayBox { window = ap_win, fg_bg = cpair(colors.white, colors.black) }
            ui.ap_display = DisplayBox { window = rio_win, fg_bg = cpair(colors.white, colors.black) }
        
            panel_view_front(ui.display)
            panel_view_side(ui.ap_display)
        end)

        if status then
            -- start flasher callback task
            flasher.run()
        else
            -- report fail and close ui
            msg = core.extract_assert_msg(msg)
            renderer.close_ui()
        end
    end

    return status, msg
end

-- close out the UI
function renderer.close_ui()
    if ui.display ~= nil then
        -- stop blinking indicators
        flasher.clear()

        -- delete element tree
        ui.display.delete()
        ui.display = nil

        -- restore colors
        for b, c in pairs(a) do term.setPaletteColor(colors[b], term.nativePaletteColor(colors[b])) end

        -- reset terminal
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1, 1)
    end
end

-- is the UI ready?
---@nodiscard
---@return boolean ready
function renderer.ui_ready() return ui.display ~= nil end

-- handle a mouse event
---@param event mouse_interaction|nil
function renderer.handle_mouse(event)
    if ui.display ~= nil and event ~= nil then
        
        if event.monitor == "monitor_0" then
            ui.display.handle_mouse(event)
        elseif event.monitor == "monitor_1" then
            ui.ap_display.handle_mouse(event)
        end
        
    end
end

return renderer
