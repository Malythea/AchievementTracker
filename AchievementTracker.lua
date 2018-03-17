--[[

TODO:
- maybe grow up instead of down? option to toggle

--]]

local AchievementTracker = ZO_Object:Subclass()

AchievementTracker.defaults = {
  ["tracked"] = {},
  ["position"] = {
    ["offsetX"] = 100,
    ["offsetY"] = 100,
  },
  ["fontSize"] = {
    ["name"] = 14,
    ["desc"] = 12
  },
  ["sizeX"] = 100,
  ["sizeY"] = 200,
  ["locked"] = false,
  ["showIcons"] = true,
  ["showBackground"] = true,
  ["showDesc"] = true,
  ["notify"] = false,
  ["notifyType"] = "alert",
  ["autoTrackZoneAchievements"] = false,
  ["hideOldZoneAchievements"] = true,
  ["hideCompleted"] = true,
  ["bgAlpha"] = 100,
  ["maxTracked"] = 0,
  ["hidden"] = false
}
AchievementTracker.config = nil
AchievementTracker.lastZone = nil
AchievementTracker.hiddenShortly = false
AchievementTracker.checkboxesCreated = false
AchievementTracker.heightPerLine = 50
AchievementTracker.bufferTable = {}

-- from wykkyd
local function comma_value(amount)
  local formatted = amount
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

-- from wykkyd
function AchievementTracker:Buffer(key, buffer)
  if key == nil then return end
  if self.bufferTable[key] == nil then self.bufferTable[key] = {} end
  self.bufferTable[key].buffer = buffer or 3
  self.bufferTable[key].now = GetFrameTimeMilliseconds()
  if self.bufferTable[key].last == nil then self.bufferTable[key].last = self.bufferTable[key].now end
  self.bufferTable[key].diff = self.bufferTable[key].now - self.bufferTable[key].last
  self.bufferTable[key].eval = self.bufferTable[key].diff >= self.bufferTable[key].buffer
  if self.bufferTable[key].eval then self.bufferTable[key].last = self.bufferTable[key].now end
  return self.bufferTable[key].eval
end

function AchievementTracker:GetLabel(name, parent, isBold)
  local label = parent:GetNamedChild(name) or WINDOW_MANAGER:CreateControl(parent:GetName() .. name, parent, CT_LABEL)
  label:SetHidden(false)
  label:SetDimensions(200, 25)
  label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

  local fontFile = nil
  local fontSize = self.config.fontSize["desc"]
  local fontDecoration = "soft-shadow-thin"
  if isBold then
    fontSize = self.config.fontSize["name"]
    fontFile = ZoFontGameBold:GetFontInfo()
  else
    fontFile = ZoFontGame:GetFontInfo()
  end

  label:SetFont(string.format("%s|%d|%s", fontFile, fontSize, fontDecoration))
  return label
end

function AchievementTracker:GetIcon(name, parent, texture)
  local ico = parent:GetNamedChild(name) or WINDOW_MANAGER:CreateControl(parent:GetName() .. name, parent, CT_TEXTURE)
  ico:SetHidden(false)
  ico:SetDimensions(15, 15)
  ico:SetTexture(texture)
  return ico
end

function AchievementTracker:AutoTrackZoneAchievements()
  if self.config == nil then return end

  if self.config.autoTrackZoneAchievements then
    local currentZone = GetUnitZone("player")
    if currentZone ~= self.lastZone or self.lastZone == nil then
      if self.lastZone ~= nil and self.config.hideOldZoneAchievements then
        self:FindZoneAchievements(self.lastZone, false)
      end
      self:FindZoneAchievements(currentZone, true)
      self.lastZone = currentZone
    end
  end
end

function AchievementTracker:FindZoneAchievements(zone, track)
  local numCats = GetNumAchievementCategories()

  local function FindAndTrack(cat, subCat, index)
    local id = GetAchievementId(cat, subCat, index)
    local name, desc = GetAchievementInfo(id)
    if string.find(name, zone) ~= nil or string.find(desc, zone) ~= nil then
      if track then
        self.config.tracked[id] = true
      else
        self.config.tracked[id] = nil
      end
    end
  end

  for iCat = 1, numCats do
    local _, numSubCats, numAchievs = GetAchievementCategoryInfo(iCat)
    if numSubCats > 0 then
      for iSubCat = 1, numSubCats do
        local _, numAchievs = GetAchievementSubCategoryInfo(iCat, iSubCat)
        for iAchiev = 1, numAchievs do
          FindAndTrack(iCat, iSubCat, iAchiev)
        end
      end
    else
      for iAchiev = 1, numAchievs do
        FindAndTrack(iCat, nil, iAchiev)
      end
    end
  end
end

function AchievementTracker:CreateWindow()
  self.frame = WINDOW_MANAGER:CreateTopLevelWindow("AchievementTrackerWindow")

  self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.config.position.offsetX, self.config.position.offsetY)
  self.frame:SetHidden(false)
  self.frame:SetMovable(not self.config.locked)
  self.frame:SetMouseEnabled(true)
  self.frame:SetResizeToFitDescendents(true)

  self.frame:SetResizeHandleSize(MOUSE_CURSOR_RESIZE_NS)
  self.frame:SetHandler("OnMouseUp", function()
    local sizeX = self.frame:GetWidth()
    local sizeY = self.frame:GetHeight()
    self.frame:SetDimensions(sizeX, sizeY)
    self.config.position.offsetX = self.frame:GetLeft()
    self.config.position.offsetY = self.frame:GetTop()
  end)

  self.frame.bg = WINDOW_MANAGER:CreateControl(nil, self.frame, CT_BACKDROP)
  self.frame.bg:SetAnchorFill(self.frame)
  self.frame.bg:SetCenterColor(0.0, 0.0, 0.0, 0.25)
  self.frame.bg:SetEdgeColor(0.0, 0.0, 0.0, 0.3)
  self.frame.bg:SetEdgeTexture(nil, 2, 2, 2.0, 2.0)
  self.frame.bg:SetDrawLayer(DL_BACKGROUND)
end

function AchievementTracker:LoadTrackedAchievements(updatedId)
  -- check options and act accordingly
  if self.config.showBackground then
    self.frame.bg:SetHidden(false)
    self.frame.bg:SetAlpha(self.config.bgAlpha / 100)
  else
    self.frame.bg:SetHidden(true)
  end

  if self.config.locked then
    self.frame:SetMovable(false)
  else
    self.frame:SetMovable(true)
  end

  if self.config.autoTrackZoneAchievements then
    self:AutoTrackZoneAchievements(GetUnitZone("player"))
  end

  if self.hiddenShortly or self.config.hidden then
    self.frame:SetHidden(true)
  else
    self.frame:SetHidden(false)
  end

  -- notify
  if updatedId ~= nil and updatedId > 0 and self.config.notify then
    local name, desc, _, icon, done = GetAchievementInfo(updatedId)
    if name ~= "" and name ~= nil then
      local numCriteria = GetAchievementNumCriteria(updatedId)
      local totalCompleted = 0
      local totalRequired = 0
      for criteria = 1, numCriteria do
        local _, critCompleted, critRequired = GetAchievementCriterion(updatedId, criteria)
        totalCompleted = totalCompleted + critCompleted
        totalRequired = totalRequired + critRequired
      end

      local quarterNeeded = totalRequired * 0.25
      local halfNeeded = totalRequired * 0.5
      local threeQuartersNeeded = totalRequired * 0.75

      local showUpdate = false
      if (totalCompleted == quarterNeeded or totalCompleted == halfNeeded or totalCompleted == threeQuartersNeeded) or totalRequired <= 100 then
        showUpdate = true
      end

      local finished = false
      if totalRequired == totalCompleted then
        showUpdate = true
        finished = true
      end

      totalCompleted = comma_value(totalCompleted)
      totalRequired = comma_value(totalRequired)

      if showUpdate then
        if finished then
          if self.config.notifyType == "alert" then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, "Achievement |cFF4136" .. name .. "|r completed.")
          elseif self.config.notifyType == "chat" then
            d("Achievement |cFF4136" .. name .. "|r completed.")
          end
        else
          if self.config.notifyType == "alert" then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, "Achievement |cFF4136" .. name .. "|r advanced. (" .. totalCompleted .. "/" .. totalRequired .. ")")
          elseif self.config.notifyType == "chat" then
            d("Achievement |cFF4136" .. name .. "|r advanced. (" .. totalCompleted .. "/" .. totalRequired .. ")")
          end
        end
      end
    end
  end

  -- hide children and adjust size of the frame
  local numChildren = self.frame:GetNumChildren()
  for i = 1, numChildren do
    local child = self.frame:GetChild(i)
    if child then
      local height = child:GetHeight()
      child:SetHidden(true)
      child:SetDimensions(0, 0)
      self.frame:SetHeight(self.frame:GetHeight() - height)
    end
  end

  -- no need to do all the stuff below if frame is hidden
  if self.frame:IsHidden() then return end

  local i = 1
  local lastTotalHeight = 0;

  -- traverse tracked achievs and display them
  for id, isTracked in pairs(self.config.tracked) do
    local name, desc, _, icon, done = GetAchievementInfo(id)

    -- check if done
    local continue = true
    if done and self.config.hideCompleted then
      continue = false
      self.config.tracked[id] = nil
    end

    local max = self.config.maxTracked
    if self.config.maxTracked == 0 then max = 9999 end

    if i > max then return end

    if isTracked and continue then
      local offsetY = 5
      if lastTotalHeight > 0 then offsetY = lastTotalHeight end

      -- icon
      local achievIcon = self:GetIcon("Icon" .. i, self.frame, icon)
      achievIcon:SetAnchor(TOPLEFT, self.frame, TOPLEFT, 5, offsetY)
      achievIcon:SetHidden(not self.config.showIcons)

      -- name
      local achievName = self:GetLabel("Label" .. i, self.frame, true)
      local xPos = 5
      if achievIcon:IsHidden() then xPos = -15 end
      achievName:SetHeight(15)
      achievName:SetAnchor(TOPLEFT, achievIcon, TOPRIGHT, xPos, 0)
      achievName:SetText(name)
      achievName:SetMouseEnabled(true)
      if done then
        achievName:SetColor(0, 1, 0, 1)
      else
        achievName:SetColor(1, 1, 1, 1)
      end

      achievName:SetHandler("OnMouseEnter", function(self)
        achievName:SetColor(1, 0.86, 0, 1)
      end)
      achievName:SetHandler("OnMouseExit", function(self)
        if done then
          achievName:SetColor(0, 1, 0, 1)
        else
          achievName:SetColor(1, 1, 1, 1)
        end
      end)
      achievName:SetHandler("OnMouseUp", function(_, button)
        if button == 1 then
          local catId, subCatId, achievIndex = GetCategoryInfoFromAchievementId(id)
          -- TODO: figure out way of opening right cat/subcat? :/
          SCENE_MANAGER:Show("achievements")
        elseif button == 3 then
          self.config.tracked[id] = nil
          return self:LoadTrackedAchievements()
        elseif button == 2 then
          achievName.showDetails = not achievName.showDetails
          return self:LoadTrackedAchievements()
        end
      end)

      -- description
      local achievDesc = self:GetLabel("Desc" .. i, self.frame)
      achievDesc:SetHeight(100)
      achievDesc:SetAnchor(TOPLEFT, achievName, TOPLEFT, 10, achievName:GetTextHeight())
      if done then
        achievDesc:SetColor(0, 1, 0, 1)
      else
        achievDesc:SetColor(0.8, 0.8, 0.8, 1)
      end

      if self.config.showDesc then
        achievDesc:SetText(desc)
      else
        achievDesc:SetText("")
      end

      -- criteria
      local achievCriteria = self:GetLabel("Criteria" .. i, self.frame)
      achievCriteria:SetAnchor(TOPLEFT, achievDesc, TOPLEFT, 0, achievDesc:GetTextHeight())
      if done then
        achievCriteria:SetColor(0, 1, 0, 1)
      else
        achievCriteria:SetColor(0.8, 0.8, 0.8, 1)
      end

      local numCriteria = GetAchievementNumCriteria(id)
      local totalCompleted = 0
      local totalRequired = 0
      for criteria = 1, numCriteria do
        local critDesc, critCompleted, critRequired = GetAchievementCriterion(id, criteria)
        totalCompleted = totalCompleted + critCompleted
        totalRequired = totalRequired + critRequired
      end
      if totalCompleted > 1 then
        totalCompleted = comma_value(totalCompleted)
      end
      if totalRequired > 1 then
        totalRequired = comma_value(totalRequired)
        achievCriteria:SetText(" - " .. totalCompleted .. "/" .. totalRequired)
      else
        achievCriteria:SetText("")
      end

      if achievName.showDetails then
        local text = ""
        for criteria = 1, numCriteria do
          local critDesc, critCompleted, critRequired = GetAchievementCriterion(id, criteria)
          if criteria > 1 then text = text .. "\n" end
          if critCompleted == critRequired then
            text = text .. "|c2ECC40 - " .. critDesc .. "|r"
          else
            text = text .. " - " .. critDesc
          end
        end
        achievCriteria:SetText(text)
      end

      -- add the total height of this achiev so the next one gets positioned correctly. plus a 10px padding
      lastTotalHeight = lastTotalHeight + achievName:GetTextHeight() + achievDesc:GetTextHeight() + math.max(achievCriteria:GetHeight(), achievCriteria:GetTextHeight()) + 10

      i = i + 1
    end
  end
end

function AchievementTracker:CreateCheckboxes()
  local list = ZO_AchievementsContentsAchievementListScrollChild
  local numOfAchievements = list:GetNumChildren()

  for i = 1, numOfAchievements do
    local achievement = list:GetChild(i)
    if achievement ~= nil then
      local title = achievement:GetNamedChild("Title")
      if title ~= nil then
        title:SetAnchor(3, achievement, 3, 110, 10)

        local id = achievement["achievement"]["achievementId"]

        local controlName = tostring(title:GetName() .. "TrackerCheckbox")

        local cb = title:GetNamedChild("TrackerCheckbox") or WINDOW_MANAGER:CreateControlFromVirtual(controlName, title, "ZO_CheckButton")
        cb:SetAnchor(LEFT, title, LEFT, -20, 0)
        cb:SetDimensions(15, 15)
        cb:SetHidden(false)
        cb:SetHandler("OnMouseUp", function() self:ToggleTracked() end)

        if self.config.tracked[id] == true then
          state = BSTATE_PRESSED
        else
          state = BSTATE_NORMAL
        end

        cb:SetState(state, false)
      end
    end
  end
end

function AchievementTracker:ToggleNotifications()
  local text = ""
  self.config.notify = not self.config.notify
  if self.config.notify then text = "ON" else text = "OFF" end
  ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, "Achievement notifications are now " .. text)
end

function AchievementTracker:ToggleWindow()
  self.config.hidden = not self.config.hidden
  AchievementTracker:LoadTrackedAchievements()
end

function AchievementTracker:ToggleTracked()
  local control = WINDOW_MANAGER:GetMouseOverControl()
  local firer = control:GetParent():GetParent()
  local id = firer["achievement"]["achievementId"]

  if self.config.tracked[id] then
    self.config.tracked[id] = nil
  else
    self.config.tracked[id] = true
  end

  self:LoadTrackedAchievements()
end

function AchievementTracker:CheckAchievementJournalVisibility()
  if not AchievementTracker:Buffer("CheckAchievementJournalVisibility", 50) then return end

  if ZO_AchievementsContentsAchievementListScrollChild:IsHidden() == false then
    self:CreateCheckboxes()
  end
end

function AchievementTracker:Reset()
  for id, isTracked in pairs(self.config.tracked) do
    self.config.tracked[id] = nil
  end

  self:LoadTrackedAchievements()
end

function AchievementTracker:CreateSettingsWindow()
  local LAM = LibStub:GetLibrary("LibAddonMenu-1.0")
  local panel = LAM:CreateControlPanel("_bikisAddons", "Biki's Addons")

  LAM:AddHeader(panel, "AchievementTracker_General", "Achievement Tracker")

  LAM:AddCheckbox(panel, "locked", 'Lock in place', 'Makes the window unmovable and fixed to its position', function() return self.config.locked end, function()
    self.config.locked = not self.config.locked
    self:LoadTrackedAchievements()
  end)
  LAM:AddCheckbox(panel, "showIcons", 'Show icons', 'Shows the corresponding icon to the left of the achievement name', function() return self.config.showIcons end, function()
    self.config.showIcons = not self.config.showIcons
    self:LoadTrackedAchievements()
  end)
  LAM:AddCheckbox(panel, "showDesc", 'Show description', 'Shows the description text underneath the name. Toggle to save space', function() return self.config.showDesc end, function()
    self.config.showDesc = not self.config.showDesc
    self:LoadTrackedAchievements()
  end)
  LAM:AddCheckbox(panel, "notify", 'Notify progress', 'Notifies you when you advance any achievement', function() return self.config.notify end, function()
    self.config.notify = not self.config.notify
  end)
  LAM:AddDropdown(panel, "notifyType", ' - Type', 'Select the type of notification you wish to receive', {"alert", "chat"}, function() return self.config.notifyType end, function(value)
    self.config.notifyType = value
  end)
  LAM:AddCheckbox(panel, "autoTrackZoneAchievements", 'Auto track zone achievements', 'Automatically tries to detect achievements of the current zone you are in and tracks them', function() return self.config.autoTrackZoneAchievements end, function()
    self.config.autoTrackZoneAchievements = not self.config.autoTrackZoneAchievements
    self.lastZone = nil
    self:LoadTrackedAchievements()
  end)
  LAM:AddCheckbox(panel, "hideOldZoneAchievements", ' - Hide old zone achievements', 'Automatically hides achievements from the old zone when you change zones', function() return self.config.hideOldZoneAchievements end, function()
    self.config.hideOldZoneAchievements = not self.config.hideOldZoneAchievements
    self.lastZone = nil
    self:LoadTrackedAchievements()
  end)
  LAM:AddCheckbox(panel, "hideCompleted", 'Hide completed', 'Automatically hides achievements after you complete them. Also disables tracking of already completed Achievs of course', function() return self.config.hideCompleted end, function()
    self.config.hideCompleted = not self.config.hideCompleted
    self.lastZone = nil
    self:LoadTrackedAchievements()
  end)
  LAM:AddCheckbox(panel, "showBackground", 'Show background', 'Shows a background behind the tracker window', function() return self.config.showBackground end, function()
    self.config.showBackground = not self.config.showBackground
    self:LoadTrackedAchievements()
  end)
  LAM:AddSlider(panel, "maxTracked", 'Maximum tracked', 'Adjust the maximum number of tracked achievements. 0 means unlimited', 0, 10, 1, function() return self.config.maxTracked end, function(value)
    self.config.maxTracked = value
    self:LoadTrackedAchievements()
  end)
  LAM:AddSlider(panel, "bgAlpha", 'Background alpha', 'Adjust the alpha value of the background', 0, 100, 1, function() return self.config.bgAlpha end, function(value)
    self.config.bgAlpha = value
    self:LoadTrackedAchievements()
  end)
  LAM:AddSlider(panel, "fontSizeName", 'Name font size', 'Adjust the font size of the tracked achievement names', 8, 30, 1, function() return self.config.fontSize["name"] end, function(value)
    self.config.fontSize["name"] = value
    self:LoadTrackedAchievements()
  end)
  LAM:AddSlider(panel, "fontSizeDesc", 'Description font size', 'Adjust the font size of the tracked achievement descriptions', 8, 30, 1, function() return self.config.fontSize["desc"] end, function(value)
    self.config.fontSize["desc"] = value
    self:LoadTrackedAchievements()
  end)

  LAM:AddButton(panel, "reset", 'Untrack all', 'Untracks all tracked achievements', function()
    return self:Reset()
  end)
end

function AchievementTracker:GetFrame()
  return self.frame
end

function AchievementTracker:GetIsHiddenShortly()
  return self.hiddenShortly
end

function AchievementTracker:SetHiddenShortly(hidden)
  local oldStatus = self.hiddenShortly
  self.hiddenShortly = hidden
  if self.hiddenShortly ~= oldStatus then self:LoadTrackedAchievements() end
end

function AchievementTracker:Init(event, name)
  if name ~= "AchievementTracker" then return end

  self.config = ZO_SavedVars:New("AchievementTrackerSavedVars", 3.0, nil, self.defaults)

  -- keybind strings
  ZO_CreateStringId("SI_BINDING_NAME_TOGGLE_ACHIEVEMENT_TRACKER", "Toggle Achievement Tracker")
  ZO_CreateStringId("SI_BINDING_NAME_TOGGLE_ACHIEVEMENT_NOTIFICATIONS", "Toggle Achievement Notifications")

  ZO_Achievements:SetHandler("OnUpdate", function()
    self:CheckAchievementJournalVisibility()
  end)

  self:CreateSettingsWindow()
  self:CreateWindow()

  -- hide listeners
  ZO_PreHookHandler(ZO_MainMenuCategoryBar, "OnShow", function()
    self:SetHiddenShortly(true)
  end)
  ZO_PreHookHandler(ZO_InteractWindow, "OnShow", function()
    self:SetHiddenShortly(true)
  end)
  ZO_PreHookHandler(ZO_GameMenu_InGame, "OnShow", function()
    self:SetHiddenShortly(true)
  end)
  ZO_PreHookHandler(ZO_KeybindStripControl, "OnShow", function()
    self:SetHiddenShortly(true)
  end)

  -- show listeners
  ZO_PreHookHandler(ZO_MainMenuCategoryBar, "OnHide", function()
    self:SetHiddenShortly(false)
  end)
  ZO_PreHookHandler(ZO_InteractWindow, "OnHide", function()
    self:SetHiddenShortly(false)
  end)
  ZO_PreHookHandler(ZO_GameMenu_InGame, "OnHide", function()
    self:SetHiddenShortly(false)
  end)
  ZO_PreHookHandler(ZO_KeybindStripControl, "OnHide", function()
    self:SetHiddenShortly(false)
  end)

  -- event hooks
  AchievementTrackerWindow:RegisterForEvent(EVENT_ZONE_CHANGED, function() self:AutoTrackZoneAchievements() end)
  AchievementTrackerWindow:RegisterForEvent(EVENT_ACHIEVEMENT_UPDATED, function(_, id) self:LoadTrackedAchievements(id) end)

  -- called after a slight delay. an instant call causes weird spacing errors inside the frame
  zo_callLater(function() self:LoadTrackedAchievements() end, 300)
end

-- called from the keybind
function AchievementTracker_ToggleWindow()
  AchievementTracker:ToggleWindow()
end

function AchievementTracker_ToggleNotifications()
  AchievementTracker:ToggleNotifications()
end

-- public debug functions. can be called via /script AT_update()
function AT_update()
  AchievementTracker:LoadTrackedAchievements()
end

function AT_reset()
  AchievementTracker:Reset()
end

EVENT_MANAGER:RegisterForEvent("AchievementTracker", EVENT_ADD_ON_LOADED, function(...) AchievementTracker:Init(...) end)