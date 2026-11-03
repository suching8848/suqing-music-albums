require "SQMusic/Window"
require "SQMusic/ExchangeAction"
require "ISUI/ISModalRichText"

local function modalText(text)
    return tostring(text):gsub("[<>]", "")
end

local function exchange(player, operation, items)
    local lines = { getText(operation == "merge" and "UI_SQM_ConfirmMerge" or "UI_SQM_ConfirmSplit") }
    for _, item in ipairs(items) do lines[#lines + 1] = modalText(item:getName()) end
    local callback = function(target, button)
        if button.internal == "YES" then ISTimedActionQueue.add(SQMusicExchangeAction:new(player, operation, items)) end
    end
    local modal = ISModalRichText:new(200, 180, 560, 360, table.concat(lines, " <LINE> "), true, nil, callback, player:getPlayerNum())
    modal:initialise()
    modal:addToUIManager()
end

local function inventoryContext(number, context, selected)
    if isClient() or isServer() then return end
    local player = getSpecificPlayer(number)
    local actual = ISInventoryPane.getActualItems(selected)
    if not player or not actual then return end
    local vehicle = player:getVehicle()
    local radio = vehicle and vehicle:getPartById("Radio")
    if radio and radio:getModData().tcmusic then
        context:addOption(getText("UI_SQM_VehiclePlayer"), player, function(p) SQMusic.NativeUI.open(p, radio) end)
    end
    local singles = {}
    for _, item in ipairs(actual) do
        local fullType = item:getFullType()
        if SQMusic.Catalog.byItem[fullType] then singles[#singles + 1] = item end
        if SQMusic.Catalog.albumsByType[fullType] then
            context:addOption(getText("UI_SQM_ViewAlbum"), player, function(p) SQMusicWindow.open(p, item) end)
            if SQMusic.canSplit(player, item) then
                context:addOption(getText("UI_SQM_Split"), player, function(p) exchange(p, "split", { item }) end)
            end
        end
        if instanceof(item, "Radio") and (TCMusic.ItemMusicPlayer[fullType] or TCMusic.WalkmanPlayer[fullType]) then
            context:addOption(getText("UI_SQM_OpenPlayer"), player, function(p) SQMusic.NativeUI.open(p, item) end)
        end
    end
    if #singles >= 2 then
        local ok, reason = SQMusic.canMerge(player, singles)
        local option = context:addOption(getText("UI_SQM_Merge"), player, function(p) exchange(p, "merge", singles) end)
        if not ok then
            option.notAvailable = true
            local tooltip = ISInventoryPaneContextMenu.addToolTip()
            tooltip.description = getText("UI_" .. reason)
            option.toolTip = tooltip
        end
    end
end

local function worldContext(number, context, objects, test)
    if test or isClient() or isServer() then return end
    local player = getSpecificPlayer(number)
    for _, object in ipairs(objects) do
        local data = object:getModData().tcmusic
        if data and data.deviceType == "IsoObject" then
            context:addOption(getText("UI_SQM_OpenPlayer"), player, function(p) SQMusic.NativeUI.open(p, object) end)
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(inventoryContext)
Events.OnFillWorldObjectContextMenu.Add(worldContext)
