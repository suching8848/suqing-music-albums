-- UI widgets are controlled fixtures; Window/Context/ExchangeAction remain production.
UIFont = {Small = "Small"}
local Widget = ISBaseObject:derive("FixtureWidget")
function Widget:new(x, y, width, height)
    local o = ISBaseObject.new(self)
    o.x, o.y, o.width, o.height, o.children = x, y, width, height, {}
    return o
end
function Widget:initialise() self.initialised = true end
function Widget:addToUIManager()
    self.visible = true
    if self.createChildren and not self.childrenCreated then self.childrenCreated = true; self:createChildren() end
    FIXTURE_LAST_WINDOW = self
end
function Widget:addChild(child) table.insert(self.children, child) end
function Widget:createChildren() end
function Widget:prerender() end
function Widget:drawText() end
function Widget:setEnable(value) self.enabled = value end
ISCollapsableWindow = Widget:derive("ISCollapsableWindow")
ISScrollingListBox = Widget:derive("ISScrollingListBox")
function ISScrollingListBox:new(x, y, width, height)
    local o = Widget.new(self, x, y, width, height); o.items, o.selected = {}, 1; return o
end
function ISScrollingListBox:setFont() end
function ISScrollingListBox:setOnMouseDoubleClick(target, fn) self.target, self.doubleClick = target, fn end
function ISScrollingListBox:clear() self.items = {} end
function ISScrollingListBox:addItem(label, data) table.insert(self.items, {text = label, item = data}) end
ISComboBox = Widget:derive("ISComboBox")
function ISComboBox:new(x, y, width, height, target, callback)
    local o = Widget.new(self, x, y, width, height); o.options, o.selected, o.target, o.callback = {}, 1, target, callback; return o
end
function ISComboBox:addOption(label) table.insert(self.options, label) end
ISButton = Widget:derive("ISButton")
function ISButton:new(x, y, width, height, text, target, callback)
    local o = Widget.new(self, x, y, width, height); o.text, o.target, o.callback = text, target, callback; return o
end
ISModalRichText = Widget:derive("ISModalRichText")
function ISModalRichText:new(x, y, width, height, text, yesno, target, callback, number)
    local o = Widget.new(self, x, y, width, height); o.text, o.target, o.callback = text, target, callback
    FIXTURE_LAST_MODAL = o; return o
end
ISInventoryPane = {getActualItems = function(items) return items end}
ISInventoryPaneContextMenu = {addToolTip = function() return {} end}
function fixtureContext()
    local menu = {options = {}}
    function menu:addOption(name, target, callback)
        local option = {name = name, target = target, callback = callback}
        self.options[#self.options + 1] = option; return option
    end
    function menu:find(name) for _, option in ipairs(self.options) do if option.name == name then return option end end end
    return menu
end
ProceduralDistributions = {list = {Untouched = {items = {"Base.Untouched", 9.25}}}}
for _, name in ipairs({"MusicStoreCDs", "MusicStoreOthers", "ElectronicStoreMusic", "LivingRoomShelf", "BedroomDresser"}) do
    ProceduralDistributions.list[name] = {items = {"Base.Existing", 3.5}}
end
