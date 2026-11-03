-- Only native rendering/texture/input services are fixtures. All ISUI/RWM Lua
-- classes in this suite are loaded from the installed game and True Music.
UI_TRACE = {}
UI_VIEW = {width = 1920, height = 1080, left = 0, top = 0}
UI_FONT = 14
UIFont = {Small = "Small", Medium = "Medium", Large = "Large"}
UITransition = {new = function() return {init = function() end, setFadeIn = function() end,
    update = function() end, fraction = function() return 1 end} end}
function getISUIStackTrace() return "offline-native-ui-fixture" end
function getTextManager()
    return {getFontHeight = function() return UI_FONT end,
        MeasureStringX = function(_, font, text) return #tostring(text) * UI_FONT * 0.55 end,
        MeasureStringY = function() return UI_FONT end,
        getFontFromEnum = function() return {getLineHeight = function() return UI_FONT end} end}
end
function getTexture()
    return {getWidth = function() return 16 end, getHeight = function() return 16 end}
end
function getCore()
    return {getOptionSoundVolume = function() return 10 end,
        getOptionFontSizeReal = function() return 1 end,
        getScreenWidth = function() return UI_VIEW.width end,
        getScreenHeight = function() return UI_VIEW.height end}
end
function getPlayerScreenWidth() return UI_VIEW.width end
function getPlayerScreenHeight() return UI_VIEW.height end
function getPlayerScreenLeft() return UI_VIEW.left end
function getPlayerScreenTop() return UI_VIEW.top end
function getNumActivePlayers() return 1 end
function getMouseX() return 0 end
function getMouseY() return 0 end
function getFocusForPlayer() return nil end
function getPlayerInventory() return nil end
function getPlayerLoot() return nil end
function setJoypadFocus() end
function getTimestampMs() return 0 end
ISLayoutManager = {RegisterWindow = function() end}
JoypadState = {players = {}}
Joypad = {AButton = 1, BButton = 2, YButton = 3, XButton = 4, LBumper = 5, RBumper = 6}
Keyboard = {KEY_ESCAPE = 1}
luautils = {remove = function(list, value)
    for i = #list, 1, -1 do if list[i] == value then table.remove(list, i) end end
end}
ISUITextureGetter = {checkGetTexture = function(texture) return texture end}
UIManager = {AddUI = function(value) value._attached = true end,
    RemoveElement = function(value) value._attached = false end}
UIElement = {new = function(owner)
    local result = {_owner = owner, _visible = true, _enabled = true, _children = {}}
    local methods = {
        isVisible = function(self) return self._visible end,
        setVisible = function(self, value) self._visible = value end,
        isEnabled = function(self) return self._enabled end,
        setEnabled = function(self, value) self._enabled = value end,
        isMouseOver = function() return false end,
        getTable = function(self) return self._owner end,
        AddChild = function(self, value) self._children[#self._children + 1] = value end,
        RemoveChild = function(self, value) luautils.remove(self._children, value) end,
        getAbsoluteX = function(self) return (self._owner.parent and self._owner.parent:getAbsoluteX() or 0) + self._owner.x end,
        getAbsoluteY = function(self) return (self._owner.parent and self._owner.parent:getAbsoluteY() or 0) + self._owner.y end,
    }
    setmetatable(result, {__index = function(_, key)
        if methods[key] then return methods[key] end
        if key:sub(1, 3) == "get" then
            local field = key:sub(4, 4):lower() .. key:sub(5)
            return function(self) return rawget(self, "_" .. field) or self._owner[field] or 0 end
        end
        if key:sub(1, 3) == "set" then
            local field = key:sub(4, 4):lower() .. key:sub(5)
            return function(self, value) self["_" .. field] = value end
        end
        return function(self, ...) UI_TRACE[#UI_TRACE + 1] = key end
    end})
    return result
end}

local baseDevice = fixtureDevice
function fixtureDevice(fullType, player)
    local device, power = baseDevice(fullType, player)
    function power:getDeviceName() return "Native device fixture" end
    return device, power
end
local basePlayer = fixturePlayer
function fixturePlayer()
    local player = basePlayer()
    player.setVariable = player.SetVariable
    return player
end
FIXTURE_PLAYER = fixturePlayer()
