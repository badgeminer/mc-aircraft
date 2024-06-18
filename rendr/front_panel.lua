--
-- Reactor PLC Front Panel GUI
--

local types             = require("rendr.types")
local util              = require("scada-common.util")

local databus           = require("rendr.databus")

local style             = require("rendr.style")

local core              = require("graphics.core")
local flasher           = require("graphics.flasher")

local Div               = require("graphics.elements.div")
local Rectangle         = require("graphics.elements.rectangle")
local TextBox           = require("graphics.elements.textbox")

local PushButton        = require("graphics.elements.controls.push_button")
local hazard_button     = require("graphics.elements.controls.hazard_button")

local LED               = require("graphics.elements.indicators.led")
local LEDPair           = require("graphics.elements.indicators.ledpair")
local AlarmLight        = require("graphics.elements.indicators.alight")
local IndicatorLight    = require("graphics.elements.indicators.light")
local RGBLED            = require("graphics.elements.indicators.ledrgb")
local SpinboxNumeric    = require("graphics.elements.controls.spinbox_numeric")
local DataIndicator     = require("graphics.elements.indicators.data")

local ALIGN = core.ALIGN

local cpair = core.cpair
local border = core.border

local ind_grn = style.ind_grn
local ind_red = style.ind_red
local ind_yllw = style.ind_yllw
local ind_wht = style.ind_wht

local bw_fg_bg = style.bw_fg_bg
local lu_cpair = style.lu_colors
local hzd_fg_bg = style.hzd_fg_bg
local dis_colors = style.dis_colors

local gry_wht = style.gray_white

local ack_fg_bg = cpair(colors.black, colors.orange)
local rst_fg_bg = cpair(colors.black, colors.lime)
local active_fg_bg = cpair(colors.white, colors.gray)

local dis_colors = style.dis_colors

local smpl = (8 * 1024)


local function callout(tx)
    os.queueEvent("audio",types.PRIORITY.BASIC,tx)
end




-- create new front panel view
---@param panel graphics_element main displaybox
local function init(panel)
    local system = Div{parent=panel,width=15,height=24,x=1,y=1}
    local header = TextBox{parent=system,y=1,text="MCP",alignment=ALIGN.CENTER,height=1,fg_bg=style.header}
    system.line_break()

    local init_ok = LED{parent=system,label="",colors=cpair(colors.green,colors.red),y=2,x=1}
    local heartbeat = LED{parent=system,label="",colors=ind_grn,y=2,x=3}
    local cat = LED{parent=system,label="",colors=ind_yllw,y=2,x=5}
    local wrn = LED{parent=system,label="",colors=ind_red,y=2,x=7}
    local fire = LED{parent=system,label="",colors=cpair(colors.orange,colors.red_off),y=2,x=9}
    local lock = LED{parent=system,label="",colors=ind_yllw,y=2,x=11}
    local gpws = LED{parent=system,label="",colors=ind_yllw,y=2,x=13}
    local gear = RGBLED{parent=system,label="",colors={colors.red,colors.orange,colors.green,colors.cyan},y=2,x=15}
    local levels = LED{parent=system,label="",colors=ind_red,y=3,x=1}
    local controls = LED{parent=system,label="",colors=ind_grn,y=3,x=3}
    local revrsr = LED{parent=system,label="",colors=ind_yllw,y=3,x=5}
    local estat = RGBLED{parent=system,label="",colors={colors.red,colors.orange,colors.green},y=3,x=7}
    local wing = RGBLED{parent=system,label="",colors={colors.red,colors.orange,colors.green,colors.cyan},y=3,x=15}
    
    local fuel_g = DataIndicator{parent=system,label="F",format="%10d",value=100000,unit="MB",lu_colors=lu_cpair,width=15,fg_bg=style.bw_fg_bg,y=4}
    local elec_g = DataIndicator{parent=system,label="E",format="%10d",value=100000,unit="FE",lu_colors=lu_cpair,width=15,fg_bg=style.bw_fg_bg,y=5}
    local rounds_g = DataIndicator{parent=system,label="Rounds",format="%10d",value=100000,unit="",lu_colors=lu_cpair,width=15,fg_bg=style.bw_fg_bg,y=6}
    local flares_g = DataIndicator{parent=system,label="Flares",format="%10d",value=100000,unit="",lu_colors=lu_cpair,width=15,fg_bg=style.bw_fg_bg,y=7}
    

    PushButton{
        parent=system,x=1,y=21,min_width=6,
        text="Gear",
        callback=databus.gear,
        fg_bg=cpair(colors.white,colors.green_off),active_fg_bg=cpair(colors.white,colors.green)
    }
    PushButton{
        parent=system,x=1,y=20,min_width=7,
        text="Sweep",
        callback=databus.sweep,
        fg_bg=cpair(colors.white,colors.green_off),active_fg_bg=cpair(colors.white,colors.green)
    }
    PushButton{
        parent=system,x=7,y=21,min_width=3,
        text="R",
        callback=databus.revrsr,
        fg_bg=cpair(colors.white,colors.red_off),active_fg_bg=cpair(colors.gray,colors.yellow_hc)
    }
    
    PushButton{
        parent=system,x=10,y=21,min_width=6,
        text="Engn",
        callback=databus.engn,
        fg_bg=cpair(colors.white,colors.yellow_off),active_fg_bg=cpair(colors.gray,colors.yellow_hc)
    }
    revrsr.update(false)

    init_ok.update(false)
    init_ok.register(databus.ps, "init_ok", init_ok.update)
    
    gear.register(databus.ps, "gear", gear.update)
    wing.register(databus.ps, "wing", wing.update)
    estat.register(databus.ps, "estat", estat.update)
    heartbeat.register(databus.ps, "heartbeat", heartbeat.update)
    cat.register(databus.ps, "caution", cat.update)
    wrn.register(databus.ps, "warning", wrn.update)

    revrsr.register(databus.ps, "revrsr", revrsr.update)

end

return init