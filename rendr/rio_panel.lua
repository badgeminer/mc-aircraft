
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
local RADAR            = require("rendr.radar")
local SpinboxNumeric    = require("graphics.elements.controls.spinbox_numeric")

local ALIGN = core.ALIGN

local cpair = core.cpair
local border = core.border


local bw_fg_bg = style.bw_fg_bg

local ind_grn = style.ind_grn
local ind_red = style.ind_red
local ind_yllw = style.ind_yllw

local ack_fg_bg = cpair(colors.black, colors.orange)
local rst_fg_bg = cpair(colors.black, colors.lime)
local active_fg_bg = cpair(colors.white, colors.gray)

local gry_wht = style.gray_white

local dis_colors = style.dis_colors

-- create new front panel view
---@param panel graphics_element main displaybox
local function init(panel)
    local header = TextBox{parent=panel,text="RIO",alignment=ALIGN.CENTER,height=1,fg_bg=style.header}
    panel.line_break()
    local radar = RADAR{parent=panel,reactor_l=17,reactor_w=17}
    local launch = hazard_button{accent=colors.red,parent=panel,x=25,y=2,min_width=8,text="LAUNCH",dis_colors=cpair(colors.red_off,colors.lightGray),callback=databus.ap_dc,fg_bg=cpair(colors.white,colors.gray)}
    local disc = hazard_button{accent=colors.yellow,parent=panel,x=25,y=5,min_width=9,text=" EJECT ",dis_colors=cpair(colors.yellow_off,colors.lightGray),callback=databus.ap_dc,fg_bg=cpair(colors.white,colors.gray)}
    radar.update({})
    radar.register(databus.ps,"radar",radar.update)
    disc.disable()
    disc.register(databus.ps,"AP",function(v)
        if v then
            disc.enable()
        else
            disc.on_response(true)

            disc.disable()
            
        end
    end)
    disc.register(databus.ps,"AT",function(v)
        if v then
            disc.enable()
        else
            disc.on_response(true)

            disc.disable()
            
        end
    end)

end
return init