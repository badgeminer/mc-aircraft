local speaker = peripheral.find("speaker")

local buffer = {}
local t, dt = 0, 2 * math.pi * 550 / 48000
for i = 1, 4 * 1024 do
    buffer[i] = math.floor(math.sin(t) * 127)
    t = (t + dt) % (math.pi * 2)
end

speaker.playAudio(buffer)