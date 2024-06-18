package.path = package.path .. ";/?;/?/init.lua"
local renderer   = require('rendr.renderer')
local databus    = require("rendr.databus")
local threads    = require("rendr.threads")
local util       = require("scada-common.util")
local log        = require("scada-common.log")
local tcd        = require("scada-common.tcd")
local core       = require("graphics.core")
local types      = require("rendr.types")
local modem      = peripheral.find('modem')
local speaker = peripheral.find("speaker")
modem.open(0)
local config = {
    COMMS_TIMEOUT = 5
}

databus.ps.subscribe("GEAR",function(val)
    databus.ps.toggle('init_ok')
    modem.transmit(0,0,textutils.serialise({"GEAR",val}))
end)



local speaker    = peripheral.find('speaker')
local dfpwm      = require("cc.audio.dfpwm")


local smpl = (8 * 1024)

local function callout(tx)
    local url = "https://music.madefor.cc/tts?text=" .. textutils.urlEncode(tx)
    local response, err = http.get { url = url, binary = true }
    if not response then error(err, 0) end
    local prog = tonumber(response.getResponseHeaders()["Content-Length"])
    
    local decoder = dfpwm.make_decoder()

    while true do
        local chunk
        if prog < smpl then
            chunk = response.read(prog)
        else
            chunk = response.read(smpl)
        end
        if not chunk or #chunk <=0 then break end

        prog = prog -#chunk

        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end
    os.pullEvent("speaker_audio_empty")
    speaker.stop()
end

local queue = {
    p0 = {},
    p1 = {},
    p2 = {},
    p3 = {},
    p4 = {}
}
local function fetch()
    if #queue.p4 > 0 then
        return table.remove(queue.p4,1)
    elseif #queue.p3 > 0 then
        return table.remove(queue.p3,1)
    elseif #queue.p2 > 0 then
        return table.remove(queue.p2,1)
    elseif #queue.p1 > 0 then
        return table.remove(queue.p1,1)
    elseif #queue.p0 > 0 then
        return table.remove(queue.p0,1)
    end
end


local GEAR = types.GEAR_STATE.DOWN
local wings = types.Wings.forward
local REVR = false
local drop = false
local nuke = false
local engn = true
local nlcd = 0
local function dropsafe ()
    local t = (
        GEAR == types.GEAR_STATE.UP and
        engn
    )
    if nuke then
        t = t and nlcd == 123456
    end
    databus.ps.publish('drop',t)
end

local function main()
    local conn_wd = {
        sv = util.new_watchdog(config.COMMS_TIMEOUT),
        api = util.new_watchdog(config.COMMS_TIMEOUT)
    }
    conn_wd.sv.cancel()
    conn_wd.api.cancel()
    local MAIN_CLOCK = 0.5
    local loop_clock = util.new_clock(MAIN_CLOCK)
    local ui_ok, message = renderer.try_start_ui()
    if not ui_ok then
        print(util.c("UI error: ", message))
        log.error(util.c("startup> GUI render failed with error ", message))
    else
        -- start clock
        loop_clock.start()
    end



    if ui_ok then
        -- start connection watchdogs
        conn_wd.sv.feed()
        conn_wd.api.feed()
        log.debug("startup> conn watchdog started")
        databus.ps.publish("init_ok",true)


        -- main event loop
        while true do
            local event, param1, param2, param3, param4, param5 = util.pull_event()

            -- handle event
            if event == "timer" then
                if loop_clock.is_clock(param1) then
                    -- main loop tick

                    -- relink if necessary
                    databus.heartbeat()
                    

                    loop_clock.start()
                elseif conn_wd.sv.is_timer(param1) then
                    -- supervisor watchdog timeout
                    log.info("supervisor server timeout")
                    
                elseif conn_wd.api.is_timer(param1) then
                    -- coordinator watchdog timeout
                    log.info("coordinator api server timeout")

                else
                    -- a non-clock/main watchdog timer event
                    -- notify timer callback dispatcher
                    tcd.handle(param1)
                end
            elseif event == "modem_message" then
                ---- got a packet
                --local packet = superv_comms.parse_packet(param1, param2, param3, param4, param5)
                --superv_comms.handle_packet(packet)
            elseif event == "monitor_touch" or event == "mouse_click" or event == "mouse_up" or
                event == "mouse_drag" or event == "mouse_scroll" or event == "double_click" then
                -- handle a mouse event
                renderer.handle_mouse(core.events.new_mouse_event(event, param1, param2, param3))
            end

            -- check for termination request
            if event == "terminate" then
                log.info("terminate requested, closing server connections...")
                
                log.info("connections closed")
                break
            end
        end

        --renderer.close_ui()
    end

    print("exited")
    log.info("exited")
end
local function wrap(periph)
    return peripheral.wrap(periph)
end
local function newMotor(periph)
    local m = wrap(periph)
    m.stop()
    return m
end

local function calculateRotationAngle(A, B)
    -- Calculate the difference
    local rotationAngle = B - A

    -- Normalize the angle to the range [-180, 180)
    if rotationAngle > 180 then
        rotationAngle = rotationAngle - 360
    elseif rotationAngle < -180 then
        rotationAngle = rotationAngle + 360
    end

    return rotationAngle
end

local periphs = {}
local config = setmetatable({
    Digital = function(dig)
        periphs[dig] = wrap(dig)
    end,
    Mon = function(m)
        local M = wrap(m)
        M.setTextScale(0.5)
        local t = {}
        function t:redir()
            term.redirect(M)
            return t
        end
        return t
    end,
    Motor = function(bnd,mtr)
        local MTR = newMotor(mtr)
        local m = {}
        local M = {
            Motors = {MTR},
            Bearing= {},
            
        }
        function M:setSpeed(rpm)
            for index, m in ipairs(self.Motors) do
                m.setSpeed(rpm)
            end
        end
        function M:stop()
            self:setSpeed(0)
        end
        function M:rotate(d,rpm)
            self:setSpeed(rpm)
            return MTR.rotate(d,rpm)
        end
        function M:rot(d,rpm)
            local t = M:rotate(d,rpm)
            sleep(t)
            self:stop()
        end

        function m:Bearing(dig,dir)
            function M.Bearing:angle()
                local a = periphs[dig].getBearingAngle(dir)
                if a < 0 then
                    a = 360+a
                end
                return a
            end
            function M.Bearing:rotateAbs(d,rpm)
                local A = calculateRotationAngle(M.Bearing:angle(),d)
                if A < 0 then
                    rpm = -rpm
                    A = -A
                end
                M:setSpeed(rpm)
                return periphs[dig].getDurationAngle(A,rpm)
            end
            function M.Bearing:rotate(d,rpm)
                local t = self:rotateAbs(d,rpm)
                sleep(t)
                M:stop()
                printError(t)
                
            end
            return m
        end
        function m:bind(Mtr)
            table.insert(M.Motors,newMotor(Mtr))
            return m
        end
        periphs[bnd] = M
        return m
    end,
    Gear = function(bnd,gr)
        local G = {}
        local shft = wrap(gr)
        function G:move(distance,modify)
            shft.move(distance,modify)
        end
        function G:rotate(angle,modify)
            shft.rotate(angle,modify)
        end
        periphs[bnd] = G
    end
},{__index=_ENV})
local fn,err = loadfile("conect.lua","t",config)
if not fn then
    printError(err)
    return
end
local ok,err = pcall(fn)
if not ok then
    printError(err)
    return
end

local function button_press(m)
    m = m or 0
    local buffer = {}
    local t, dt = 0, 2 * math.pi * (250+m) / 48000
    for i = 1, 2 * 1024 do
        buffer[i] = math.floor(math.sin(t) * 127)
        t = (t + dt) % (math.pi * 2)
    end

    speaker.playAudio(buffer)
end
local function alarm(l,m)
    m = m or 0
    local buffer = {}
    local t, dt = 0, 2 * math.pi * (250+m) / 48000
    for i = 1, (l+2) * 1024 do
        buffer[i] = math.floor(math.sin(t) * 127)
        t = (t + dt) % (math.pi * 2)
    end

    speaker.playAudio(buffer)
end

databus.ps.subscribe("nlcd",function(v)
    nlcd = v
end)
databus.ps.subscribe("engn",function(v)
    engn =not engn
    button_press(50)
    if engn then
        databus.ps.publish("estat",types.ENGN_STATE.NORM)
    else
        if REVR then
            databus.ps.publish("Trevrsr",555)
        end
        databus.ps.publish("estat",types.ENGN_STATE.CUT)
    end
end)
databus.ps.subscribe("ARM_AP",function(v)
    databus.ps.publish('AP',v)
end)
databus.ps.subscribe("ARM_AT",function(v)
    databus.ps.publish('AT',v)
end)
databus.ps.subscribe("tgl_gear",function(v)
    
    if (GEAR == types.GEAR_STATE.UP) then
        button_press(15)
        databus.ps.publish('gear',types.GEAR_STATE.DOWN)
        GEAR = types.GEAR_STATE.DOWN
        drop = false
        periphs["Gear"]:rotate(90,-1)
        
    elseif (GEAR == types.GEAR_STATE.DOWN) then
        button_press(15)
        databus.ps.publish('gear',types.GEAR_STATE.UP)
        GEAR = types.GEAR_STATE.UP
        drop = false
        periphs["Gear"]:rotate(90,1)
    else
        button_press(-100)
    end
    --print(periphs["Gear"].Bearing:angle())
    
end)
databus.ps.subscribe("sweep",function(v)
    if (wings == types.Wings.forward) then
        databus.ps.publish('wing',types.Wings.Swept)
        wings = types.Wings.Swept
        periphs["Wing_Sweep"]:rotate(63,1)
        
    elseif (wings == types.Wings.Swept) then
        databus.ps.publish('wing',types.Wings.forward)
        wings = types.Wings.forward
        periphs["Wing_Sweep"]:rotate(63,-1)
    end
    --print(periphs["Wing_Sweep"].Bearing:angle())
    
end)
databus.ps.subscribe("Trevrsr",function(v)
    if (GEAR == types.GEAR_STATE.DOWN or GEAR == types.GEAR_STATE.LOCK) and engn then
        REVR = not REVR
        if REVR then
            databus.ps.publish('gear',types.GEAR_STATE.LOCK)
            GEAR = types.GEAR_STATE.LOCK
        else
            databus.ps.publish('gear',types.GEAR_STATE.DOWN)
            GEAR = types.GEAR_STATE.DOWN
        end
        databus.ps.publish('revrsr',REVR)
        
    elseif REVR then
        if GEAR == types.GEAR_STATE.LOCK then
            databus.ps.publish('gear',types.GEAR_STATE.DOWN)
            GEAR = types.GEAR_STATE.DOWN
        end
        databus.ps.publish('revrsr',false)
        --databus.ps.publish("caution",true)
        REVR = false
    end
    
end)
parallel.waitForAll(main,function()
    databus.ps.publish("nuke",nuke)
    databus.ps.publish("estat",types.ENGN_STATE.NORM)
    while true do
        dropsafe()
        sleep(1)
    end
end,function()
    while true do
        if REVR and GEAR == types.GEAR_STATE.DOWN then
            databus.ps.publish('gear',types.GEAR_STATE.LOCK)
            GEAR = types.GEAR_STATE.LOCK

        elseif REVR and GEAR == types.GEAR_STATE.UP then
            databus.ps.publish("warning",true)
        end
        sleep(0.5)
    end
end,function()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        local bus = textutils.unserialise(message)
        databus.ps.publish(table.unpack(bus))
    end
end,

function()
    while true do
        if engn ~= true and GEAR == types.GEAR_STATE.UP then
            alarm(2,400)
        elseif wings == types.Wings.Swept and GEAR == types.GEAR_STATE.DOWN then
            alarm(2,200)
        end
        sleep(0.25)
    end
end,
function()
    local a = 0
    local points
    local i = 0
    while true do
        i = i + 1
        a = (a + 2)%360
        points = {
            {angle = 45+a, distance = 5},
            {angle = 45+a, distance = 10},
            {angle = 180+a, distance = 9+(i%5)},
            {angle = 0, distance = 0},
            {angle = a, distance = 5},
            {angle = a, distance = 10},
            {angle = (-45)+a, distance = 5},
            {angle = (-45)+a, distance = 10},
            -- Add more points as needed
        }
        databus.ps.publish("radar",points)
        sleep(0.25)
    end
end)
local ok, m = pcall(main)
if not ok then
    print(m)

    pcall(renderer.close_ui)
else
    log.close()
end