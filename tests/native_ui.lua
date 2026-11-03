local M, P, C = SQMusic, SQMusic.Playback, SQMusic.Catalog
local player = FIXTURE_PLAYER
local earlyDevice = fixtureDevice("Tsarcraft.TCWalkman", player)
local earlyHost = ISTCBoomboxWindow.activate(player, earlyDevice)
equal(#earlyHost.modules, 4, "host can exist before new module's GameStart installation")
fire("OnGameStart")
equal(#earlyHost.modules, 5, "GameStart installation attaches playlist to an already open native host")
local device = fixtureDevice("Tsarcraft.TCBoombox", player)
device:getDeviceData()._headphones = 0
local albumType
for fullType, info in pairs(C.albumsByType) do
    if info.kind == "cassette" and not info.custom and #C.artists[info.artist].tracks >= 4 then albumType = fullType; break end
end
local loose = player:getInventory():AddItem(instanceItem(albumType))
local looseState = M.copy(M.state(loose))
local preview = SQMusicWindow.open(player, loose)
check(preview.javaObject and preview.list.javaObject, "read-only preview instantiated through real ISUIElement")
equal(#preview.list.items, #looseState.tracks, "preview lists actual songs")
equal(preview.combo, nil, "loose album has no playback mode control")
equal(preview.onSelect, nil, "loose preview has no play/select action")
preview.list.selected = 2; preview:refresh()
check(deepEqual(M.state(loose), looseState), "preview selection cannot modify carrier")
preview:close()

local function insert(item, slot)
    local call = ISTCBoomboxAction:new("AddMedia", player, device, item, slot)
    check(call:isValidAddMedia(), "actual upstream add validates")
    call:performAddMedia()
end
insert(loose, 1)
local another = player:getInventory():AddItem(instanceItem(albumType))
M.state(another).index = 3
insert(another, 2)

-- This runs real vanilla ISRadioWindow -> True Music override -> native host,
-- with real RWMElement and all base ISUI lifecycle methods, not a fake Host.
local host = M.NativeUI.open(player, device)
equal(host.Type, "ISTCBoomboxWindow", "native activation resolves to actual True Music host")
equal(#host.modules, 5, "four existing native modules plus one playlist module")
local module, panel = host.sqMusicPlaylistModule, host.sqMusicPlaylistPanel
check(module and panel and module.element.javaObject and panel.javaObject, "playlist instantiated within real RWMElement")
check(module.enabled and module.element.isExpanded, "new playlist enabled and expanded by default")
equal(panel.device, device, "RWM readFromObject binds actual device")
equal(#panel.list.items, #P.getState(device).tracks, "native playlist has real tracks")
equal(#panel.combo.options, 4, "native playlist has four modes")
for _, button in ipairs(panel.buttons) do
    check(button:getX() >= 0 and button:getRight() <= panel:getWidth(), "two-column transport fits native 300 width")
end
resetAudio()
panel.list.selected = 2; panel:onSelect()
check(P.isPlaying(device), "native panel starts playback")
local count = #AUDIO.private
panel.list.selected = 3; panel:onSelect()
equal(#AUDIO.private, count + 1, "native select starts one replacement handle")
equal(P.getState(device).index, 3, "native selection updates state")
panel.combo.selected = 4; panel:onMode()
equal(P.getState(device).mode, "shuffle", "native mode control uses production playback")
panel:refresh(); equal(panel.list.selected, 3, "current track remains highlighted")
assertPrivate("real native playlist controls")

TCMusic.setBoomboxMediaSlot(device:getModData().tcmusic, 2)
panel:refresh(); equal(panel.list.selected, 3, "slot switch binds distinct saved state")
TCMusic.setBoomboxMediaSlot(device:getModData().tcmusic, 3)
panel:refresh(); equal(#panel.list.items, 0, "empty slot clears stale tracks")
check(panel.combo.disabled, "empty slot disables mode control")
for _, button in ipairs(panel.buttons) do check(not button.enable, "empty slot disables transport") end
TCMusic.setBoomboxMediaSlot(device:getModData().tcmusic, 1)
panel:refresh(); check(#panel.list.items > 0, "returning to loaded slot restores track display")

for _, height in ipairs({720, 1080, 1440}) do
    UI_VIEW.width, UI_VIEW.height = math.floor(height * 16 / 9), height
    host:setX(4000); host:setY(4000)
    host:prerender()
    check(host:getY() >= 0 and host:getY() + host:getHeight() <= height, "native height/position fits viewport " .. height)
    check(host:getX() >= 0 and host:getX() + host:getWidth() <= UI_VIEW.width, "native width/position fits viewport " .. height)
    for _, button in ipairs(panel.buttons) do
        if button:getIsVisible() then check(button:getBottom() <= panel:getHeight(), "transport remains within playlist panel") end
    end
end
host:clear()
equal(panel.device, nil, "native clear unbinds playlist device")
equal(#panel.list.items, 0, "native clear removes song list")
host:readFromObject(player, device)
equal(panel.device, device, "native read lifecycle can bind again after clear")
check(#panel.list.items > 0, "native read lifecycle repopulates list")
local popup = {setVisible = function(self, value) self.visible = value end,
    removeFromUIManager = function(self) self.removed = true end}
panel.combo.popup = popup; panel.combo.expanded = true
host:close()
equal(panel.device, nil, "native close clears playlist binding")
check(not panel.combo.expanded and popup.removed, "native close removes detached combo popup")
check(P.isPlaying(device), "closing native window keeps device playback running")
P.stopAll()
print("ASSERTIONS=" .. tostring(CHECKS))
return true
