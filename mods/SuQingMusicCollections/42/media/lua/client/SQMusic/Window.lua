require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "SQMusic/PlaylistPanel"

-- Loose carriers have a read-only preview. Playback controls live exclusively
-- inside the native device window's playlist module.
SQMusicWindow = ISCollapsableWindow:derive("SQMusicWindow")
SQMusicWindow.instances = {}

function SQMusicWindow:getState() return self.item and SQMusic.state(self.item) or nil end

function SQMusicWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.list = ISScrollingListBox:new(12, 78, self.width - 24, self.height - 90)
    self.list:initialise()
    self.list:setFont(UIFont.Small, 5)
    self.list.drawBorder = true
    self:addChild(self.list)
    self:refresh()
end

function SQMusicWindow:refresh()
    if not self.list then return end
    local state = self:getState()
    if self.lastState == state then return end
    self.list:clear()
    if state then
        for i, id in ipairs(state.tracks) do
            self.list:addItem(SQMusic.NativeUI.rowText(state, id, i), i, SQMusic.NativeUI.rowTooltip(id))
        end
    end
    self.lastState = state
end

function SQMusicWindow:prerender()
    if not self.player or self.player:isDead() or not SQMusic.owned(self.player, self.item) then self:close(); return end
    ISCollapsableWindow.prerender(self)
    self:refresh()
    SQMusic.NativeUI.clamp(self)
    local state = self:getState()
    local title = state and SQMusic.title(state) or getText("UI_SQM_NoAlbum")
    self:drawText(SQMusic.NativeUI.ellipsize(title, self.width - 28), 14, 30, 0.9, 0.9, 1, 1, UIFont.Small)
    self:drawText(getText("UI_SQM_Preview"), 14, 52, 0.7, 0.9, 0.8, 1, UIFont.Small)
end

function SQMusicWindow:close()
    if self.list and self.list.tooltipUI then
        self.list.tooltipUI:setVisible(false)
        self.list.tooltipUI:removeFromUIManager()
    end
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end

function SQMusicWindow:new(player, item)
    local screenWidth, screenHeight = getCore():getScreenWidth(), getCore():getScreenHeight()
    local width, height = math.min(520, screenWidth - 24), math.min(420, screenHeight - 24)
    local o = ISCollapsableWindow.new(self, (screenWidth - width) / 2, (screenHeight - height) / 2, width, height)
    o.player, o.item, o.characterNum = player, item, player:getPlayerNum()
    o.title, o.resizable = getText("UI_SQM_ViewAlbum"), false
    return o
end

function SQMusicWindow.open(player, item, device)
    if device then return SQMusic.NativeUI.open(player, device) end
    if not player or not item then return nil end
    local number = player:getPlayerNum()
    local window = SQMusicWindow.instances[number]
    if not window then
        window = SQMusicWindow:new(player, item)
        window:initialise()
        window:instantiate()
        SQMusicWindow.instances[number] = window
    else
        window.player, window.item, window.lastState = player, item, nil
        window:refresh()
    end
    window:addToUIManager()
    window:setVisible(true)
    SQMusic.NativeUI.clamp(window)
    return window
end
