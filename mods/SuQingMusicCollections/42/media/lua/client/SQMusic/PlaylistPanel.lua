require "RadioCom/RadioWindowModules/RWMPanel"
require "RadioCom/RadioWindowModules/RWMElement"
require "RadioCom/ISTCBoomboxWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "SQMusic/Playback"

SQMusic.NativeUI = SQMusic.NativeUI or {}
local Native = SQMusic.NativeUI
local modes = { "order", "loop", "one", "shuffle" }
local modeNames = { "UI_SQM_Order", "UI_SQM_Loop", "UI_SQM_One", "UI_SQM_Shuffle" }
local installed = false
SQMusicPlaylistPanel = RWMPanel:derive("SQMusicPlaylistPanel")

local function fontHeight() return getTextManager():getFontHeight(UIFont.Small) end

function Native.ellipsize(text, width)
    text = tostring(text or "")
    if getTextManager():MeasureStringX(UIFont.Small, text) <= width then return text end
    while #text > 0 and getTextManager():MeasureStringX(UIFont.Small, text .. "...") > width do
        local start = #text
        while start > 1 do
            local byte = string.byte(text, start)
            if byte < 128 or byte >= 192 then break end
            start = start - 1
        end
        text = string.sub(text, 1, start - 1)
    end
    return text .. "..."
end

function Native.rowText(state, id, index)
    local track = SQMusic.Catalog.tracks[id]
    local title = SQMusic.trackTitle(id)
    if SQMusic.isMixed(state) and track then title = title .. " - " .. SQMusic.artistName(track.artist) end
    return tostring(index) .. ". " .. title
end

function Native.rowTooltip(id)
    local track = SQMusic.Catalog.tracks[id]
    local title = SQMusic.trackTitle(id)
    return track and (title .. " - " .. SQMusic.artistName(track.artist)) or title
end

local function clearTooltip(list)
    if list and list.tooltipUI then
        list.tooltipUI:setVisible(false)
        list.tooltipUI:removeFromUIManager()
    end
end

local function closeCombo(combo)
    if combo and combo.expanded then combo.expanded = false; combo:hidePopup() end
    clearTooltip(combo)
end

function SQMusicPlaylistPanel:setVisible(visible)
    if not visible then closeCombo(self.combo); clearTooltip(self.list) end
    RWMPanel.setVisible(self, visible)
end

function SQMusicPlaylistPanel:createChildren()
    self.list = ISScrollingListBox:new(8, 74, self.width - 16, 180)
    self.list:initialise()
    self.list:setFont(UIFont.Small, 4)
    self.list:setOnMouseDoubleClick(self, SQMusicPlaylistPanel.onSelect)
    self.list.drawBorder = true
    self:addChild(self.list)
    self.combo = ISComboBox:new(8, 46, self.width - 16, fontHeight() + 10, self, SQMusicPlaylistPanel.onMode)
    self.combo:initialise()
    for _, key in ipairs(modeNames) do self.combo:addOption(getText(key)) end
    self:addChild(self.combo)
    self.buttons = {}
    local labels = { "UI_SQM_Previous", "UI_SQM_PlaySelected", "UI_SQM_Next", "UI_SQM_Stop" }
    local callbacks = { SQMusicPlaylistPanel.onPrevious, SQMusicPlaylistPanel.onSelect, SQMusicPlaylistPanel.onNext, SQMusicPlaylistPanel.onStop }
    for i = 1, 4 do
        local button = ISButton:new(8, 0, 130, fontHeight() + 10, getText(labels[i]), self, callbacks[i])
        button:initialise()
        self:addChild(button)
        self.buttons[i] = button
    end
    self:refresh()
    self:layout(350)
end

function SQMusicPlaylistPanel:getState()
    return self.device and SQMusic.Playback.getState(self.device) or nil
end

function SQMusicPlaylistPanel:clear()
    clearTooltip(self.list)
    closeCombo(self.combo)
    RWMPanel.clear(self)
    self.state, self.lastState, self.lastTracks, self.lastCount, self.lastIndex = nil, nil, nil, nil, nil
    if self.list then self.list:clear() end
    if self.combo then self.combo.disabled = true end
    for _, button in ipairs(self.buttons or {}) do button:setEnable(false) end
end

function SQMusicPlaylistPanel:readFromObject(player, device, data, deviceType)
    RWMPanel.readFromObject(self, player, device, data, deviceType)
    self:refresh()
    return data ~= nil and (deviceType == "InventoryItem" or deviceType == "IsoObject" or deviceType == "VehiclePart")
end

function SQMusicPlaylistPanel:refresh()
    if not self.list then return end
    local state = self:getState()
    self.state = state
    if not state then
        closeCombo(self.combo)
        if self.lastState then self.list:clear(); clearTooltip(self.list) end
        self.lastState, self.lastTracks, self.lastCount, self.lastIndex = nil, nil, nil, nil
        self.combo.disabled = true
        for _, button in ipairs(self.buttons) do button:setEnable(false) end
        return
    end
    if self.lastState ~= state or self.lastTracks ~= state.tracks or self.lastCount ~= #state.tracks then
        clearTooltip(self.list)
        self.list:clear()
        for i, id in ipairs(state.tracks) do self.list:addItem(Native.rowText(state, id, i), i, Native.rowTooltip(id)) end
        self.lastState, self.lastTracks, self.lastCount, self.lastIndex = state, state.tracks, #state.tracks, nil
    end
    if self.lastIndex ~= state.index then
        self.list.selected = state.index
        for i, row in ipairs(self.list.items) do row.textColor = i == state.index and {r = 0.65, g = 1, b = 0.75, a = 1} or nil end
        self.lastIndex = state.index
    end
    for i, mode in ipairs(modes) do if mode == state.mode then self.combo.selected = i end end
    self.combo.disabled = false
    for _, button in ipairs(self.buttons) do button:setEnable(true) end
    self.buttons[4]:setEnable(SQMusic.Playback.isPlaying(self.device))
end

function SQMusicPlaylistPanel:layout(maxHeight)
    if not self.list then return end
    local width = self:getWidth()
    local fh, gap, pad = fontHeight(), 4, 8
    self.lineHeight = fh + 4
    local controlHeight = math.max(24, fh + 10)
    local fixed = pad * 2 + self.lineHeight * 2 + controlHeight * 3 + gap * 4
    local minimum = pad * 2 + self.lineHeight + controlHeight * 3 + gap * 4 + fh + 8
    self.compactNotice = self.state ~= nil and maxHeight < minimum
    local details = self.state ~= nil and not self.compactNotice
    self.list:setVisible(details)
    self.combo:setVisible(details)
    for _, button in ipairs(self.buttons) do button:setVisible(details) end
    if not details then
        closeCombo(self.combo)
        self:setHeight(self.compactNotice and (self.lineHeight * 2 + pad * 2) or (self.lineHeight + pad * 2))
        return
    end
    local compact = maxHeight < fixed + (fh + 8) * 2
    local informationHeight = compact and self.lineHeight or self.lineHeight * 2
    fixed = fixed - self.lineHeight * (compact and 1 or 0)
    self.compact = compact
    self.combo:setX(pad); self.combo:setY(pad + informationHeight + gap)
    self.combo:setWidth(width - pad * 2); self.combo:setHeight(controlHeight)
    local listY = self.combo:getY() + controlHeight + gap
    local listHeight = math.max(fh + 8, math.min(220, maxHeight - fixed))
    self.list:setX(pad); self.list:setY(listY)
    self.list:setWidth(width - pad * 2); self.list:setHeight(listHeight)
    local buttonY = listY + listHeight + gap
    local buttonWidth = (width - pad * 2 - gap) / 2
    for i, button in ipairs(self.buttons) do
        button:setX(pad + ((i - 1) % 2) * (buttonWidth + gap))
        button:setY(buttonY + math.floor((i - 1) / 2) * (controlHeight + gap))
        button:setWidth(buttonWidth); button:setHeight(controlHeight)
    end
    self:setHeight(buttonY + controlHeight * 2 + gap + pad)
end

function SQMusicPlaylistPanel:prerender()
    RWMPanel.prerender(self)
    local state = self.state
    local width = self:getWidth() - 16
    if not state then
        self:drawText(Native.ellipsize(getText("UI_SQM_NoAlbum"), width), 8, 8, 0.9, 0.8, 0.6, 1, UIFont.Small)
        return
    end
    self:drawText(Native.ellipsize(SQMusic.title(state), width), 8, 8, 0.9, 0.9, 1, 1, UIFont.Small)
    if self.compactNotice then
        self:drawText(Native.ellipsize(getText("UI_SQM_CompactHint"), width), 8, 8 + self.lineHeight, 0.9, 0.8, 0.6, 1, UIFont.Small)
    elseif not self.compact then
        local data = self.device:getModData().tcmusic
        local personal = data and data.deviceType == "InventoryItem"
            and (TCMusic.WalkmanPlayer[self.device:getFullType()] or self.device:getDeviceData():getHeadphoneType() >= 0)
        local status = getText(SQMusic.Playback.isPlaying(self.device) and "UI_SQM_Playing" or "UI_SQM_Paused")
            .. " | " .. getText(personal and "UI_SQM_Private" or "UI_SQM_Public")
            .. "  " .. tostring(state.index) .. "/" .. tostring(#state.tracks)
        self:drawText(Native.ellipsize(status, width), 8, 8 + self.lineHeight, 0.7, 0.9, 0.8, 1, UIFont.Small)
    end
end

function SQMusicPlaylistPanel:onSelect()
    local state = self:getState()
    if not state or state ~= self.lastState then self:refresh(); return end
    local selected = self.list.selected
    if selected < 1 or selected > #state.tracks then return end
    local playing = SQMusic.Playback.isPlaying(self.device)
    if not SQMusic.Playback.select(self.device, selected) then return end
    if not playing then SQMusic.Playback.play(self.device, self.player) end
    self:refresh()
end

function SQMusicPlaylistPanel:onMode()
    if self.state then SQMusic.Playback.setMode(self.device, modes[self.combo.selected]) end
end
function SQMusicPlaylistPanel:onPrevious() if self.device then SQMusic.Playback.step(self.device, -1) end end
function SQMusicPlaylistPanel:onNext() if self.device then SQMusic.Playback.step(self.device, 1) end end
function SQMusicPlaylistPanel:onStop() if self.device then SQMusic.Playback.stop(self.device) end end

function SQMusicPlaylistPanel:new(x, y, width, height)
    local o = RWMPanel.new(self, x, y, width, height)
    o.background = false
    return o
end

local function viewport(playerNum)
    if getPlayerScreenWidth and getPlayerScreenHeight then
        return getPlayerScreenLeft(playerNum), getPlayerScreenTop(playerNum), getPlayerScreenWidth(playerNum), getPlayerScreenHeight(playerNum)
    end
    return 0, 0, getCore():getScreenWidth(), getCore():getScreenHeight()
end

function Native.clamp(host)
    local left, top, width, height = viewport(host.characterNum or 0)
    host:setX(math.max(left, math.min(host:getX(), left + width - host:getWidth())))
    host:setY(math.max(top, math.min(host:getY(), top + height - host:getHeight())))
end

local function attach(host)
    if host.sqMusicPlaylistModule then return host.sqMusicPlaylistModule end
    host:addModule(SQMusicPlaylistPanel:new(0, 0, host:getWidth(), 300), getText("UI_SQM_Playlist"), true)
    local module = host.modules[#host.modules]
    host.sqMusicPlaylistModule, host.sqMusicPlaylistPanel = module, module.element.subpanel
    return module
end

function Native.fit(host)
    local module, panel = host.sqMusicPlaylistModule, host.sqMusicPlaylistPanel
    if not module or not panel or not module.enabled then return end
    panel:refresh()
    local _, _, _, screenHeight = viewport(host.characterNum or 0)
    local used = host:titleBarHeight() + 2
    for _, other in ipairs(host.modules) do
        if other ~= module and other.enabled then used = used + other.element:getHeight() + 1 end
    end
    local header = module.element.headerButton and module.element.headerButton:getHeight() or (fontHeight() + 2)
    panel:setWidth(host:getWidth())
    panel:layout(math.max(fontHeight() + 16, screenHeight - used - header - 16))
    module.element:calculateHeights()
end

local function validHost(host)
    local player, device = host.character, host.device
    if not player or not device or player:isDead() then return false end
    if host.deviceType == "InventoryItem" then return SQMusic.owned(player, device) end
    if host.deviceType == "VehiclePart" then return player:getVehicle() == device:getVehicle() end
    if host.deviceType == "IsoObject" then
        return device:getSquare() ~= nil and player:getZ() == device:getZ()
            and math.abs(player:getX() - device:getX()) < 4 and math.abs(player:getY() - device:getY()) < 4
    end
    return false
end

function Native.install()
    if installed or isClient() or isServer() then return end
    installed = true
    local Host = ISTCBoomboxWindow
    local create = Host.createChildren
    function Host:createChildren() create(self); attach(self) end
    local read = Host.readFromObject
    function Host:readFromObject(player, device)
        attach(self)
        read(self, player, device)
        local module = self.sqMusicPlaylistModule
        if module and module.enabled then module.element:setExpanded(true) end
        Native.fit(self)
    end
    local update = Host.update
    function Host:update()
        if self:getIsVisible() and self.device and not validHost(self) then self:close(); return end
        update(self)
    end
    local prerender = Host.prerender
    function Host:prerender() Native.fit(self); prerender(self); Native.clamp(self) end
    -- Equipping a radio during character creation may have created a native
    -- window before OnGameStart installed these wrappers.
    for _, pool in ipairs({ Host.instances, Host.instancesIso }) do
        for _, host in pairs(pool) do
            local player, device = host.character, host.device
            if player and device then host:readFromObject(player, device) end
        end
    end
end

function Native.open(player, device)
    if not player or not device or isClient() or isServer() then return nil end
    Native.install()
    local host
    if instanceof(device, "VehiclePart") then host = ISTCBoomboxWindow.activate(player, device)
    else host = ISRadioWindow.activate(player, device) end
    local module = host and host.sqMusicPlaylistModule
    if module and module.enabled then module.element:setExpanded(true); Native.fit(host); Native.clamp(host) end
    return host
end

Events.OnGameStart.Add(Native.install)
