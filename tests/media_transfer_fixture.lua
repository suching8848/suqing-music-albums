-- Java-owned UI and inventory values required to load the production modules.
ISPanelJoypad = ISBaseObject
ISInventoryPage = {}
ItemPicker = {updateOverlaySprite = function() end}
UIFont = {Small = "Small"}
function getTextManager() return {getFontHeight = function() return 14 end} end
CharacterTrait = {DEXTROUS = "DEXTROUS", ALL_THUMBS = "ALL_THUMBS"}
ItemContainer = {chainContainsContainingItem = function() return false end}
DesignationZoneAnimal = {removeItemFromGround = function() end}

local queue = {indexOf = function() return -1 end, onCompleted = function() end}
function ISTimedActionQueue.getTimedActionQueue() return queue end
