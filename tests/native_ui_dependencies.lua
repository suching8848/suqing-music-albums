-- Pre-existing power/volume/media panel contents are fixture boundaries; the
-- actual Host.addModule, RWMElement and new playlist panel run unmodified.
ISTextEntryBox = ISPanel:derive("ISTextEntryBox")
for _, name in ipairs({"TCRWMPower", "TCRWMGridPower", "TCRWMVolume", "TCRWMMedia"}) do
    local class = RWMPanel:derive(name)
    function class:new(x, y, width, height) return RWMPanel.new(self, x, y, width, 46) end
    function class:readFromObject(player, device, data, deviceType)
        RWMPanel.readFromObject(self, player, device, data, deviceType)
        return self.Type ~= "TCRWMGridPower"
    end
    _G[name] = class
end
