RaidInvite = LibStub("AceAddon-3.0"):NewAddon("RaidInvite", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local RaidInviteLDB = LibStub("LibDataBroker-1.1"):NewDataObject("RaidInvite", {
  type = "data source",
  text = "RaidInvite",
  icon = "Interface\\Icons\\Spell_ChargePositive",
  OnClick = function(_, button) RaidInvite:OnClick(button) end,
  OnTooltipShow = function(tooltip) RaidInvite:Tooltip(tooltip) end,
})
local icon = LibStub("LibDBIcon-1.0")
local AceGUI = LibStub("AceGUI-3.0")

-- Global variables
AUTO_INV_WORDS = {'invite', 'inv', '1', 'impact'}

local defaults = {
  profile = {
    minimap = { hide = false },
    phrases = { 'invite', 'inv', '1', 'impact' },
    announcement = {
      enabled = true,
      phrase = "Raid Time! Type (#phrases) for invite!"
    }
  }
}
--
function RaidInvite:OnInitialize()
  self:Print("Available commands: /rinv on | /rinv off")
  self.db = LibStub("AceDB-3.0"):New("RaidInviteDB", defaults)
  self.enabled = false
  -- Register Minimap Icon
  icon:Register("RaidInviteLDB", RaidInviteLDB, self.db.profile.minimap)
end

function RaidInvite:HandleSlashInput(input)
  if input == 'on' then
    RaidInvite:Enable()
  elseif input == 'off' then
    RaidInvite:Disable()
  else
    self:Print("Unknown command. Available options: on, off")
  end
end

function RaidInvite:OnClick(button)
  if button == 'LeftButton' then
    return self:Trigger()
  elseif button == 'RightButton' then
    self:NotifyGuild()
  elseif button == 'MiddleButton' then
    self:ShowSettingsFrame()
  end
end

function RaidInvite:Trigger()
  if not self.enabled then
    self:Enable()
  else
    self:Disable()
  end
end

-- Addon on/off state handling
function RaidInvite:Enable()
  self:Print("enabled")
  self.enabled = true

  self:RegisterEvent("CHAT_MSG_WHISPER")
  self:RegisterEvent("CHAT_MSG_GUILD")

  -- disable addon after 30 mins
  self:ScheduleTimer("TimerTick", 60 * 30)

  -- notify guild
  self:NotifyGuild()
end

function RaidInvite:Disable()
  self:Print("disabled")
  self.enabled = false

  self:UnregisterEvent("CHAT_MSG_WHISPER")
  self:UnregisterEvent("CHAT_MSG_GUILD")

  -- clear timer
  self:CancelAllTimers()
end

-- Timer handler

function RaidInvite:TimerTick()
  if not self.enabled then return end

  self:Print("Auto-disable after 30 min")
  self:Disable()
end

-- Minimap tooltip
function RaidInvite:Tooltip(tooltip)
  tooltip:SetText("RaidInvite " .. (self.enabled and "Active" or "Disabled"))
  tooltip:AddLine("Left Click - enable/disable")
  tooltip:AddLine("Right Click - announce in guild chat")
  tooltip:AddLine("Middle Click - show settings")
end

-- Chat parser
function RaidInvite:CHAT_MSG_WHISPER(_, text, playerName, ...)
  self:HandleMessage(playerName, text)
end

function RaidInvite:CHAT_MSG_GUILD(_, text, playerName, ...)
  self:HandleMessage(playerName, text)
end

function RaidInvite:HandleMessage(playerName, text)
  local lcText = text:lower()

  if not HasSearchWord(lcText) then return end

  local playerWithoutRealm, _ = playerName:gsub("-.*", '')

  self:Printf("|cffFF6347Invitation sent: %s|r", playerWithoutRealm)
  InviteUnit(playerName)
end

function HasSearchWord(text)
  local phrases = self.db.profile.phrases
  for i = 1,  #phrases do
    if text:match(phrases[i]) then return true end
  end

  return false
end

function RaidInvite:NotifyGuild()
  local phrasesMacro = self:GeneratePhraseMacro()
  local announcementRaw = self.db.profile.announcement.phrase
  local announcement = announcementRaw:gsub("#phrases", phrasesMacro)
  SendChatMessage(announcement, "GUILD")
end

function RaidInvite:GeneratePhraseMacro()
  return self:PhrasesToString(', ')
end

-- Register Commands and Events
RaidInvite:RegisterChatCommand("rinv", "HandleSlashInput")

-- #####################################################################
-- ######################## WIDGETS AND UI #############################
-- #####################################################################

function RaidInvite:ShowSettingsFrame()
  local settingsFrame = AceGUI:Create("Frame")
  settingsFrame:SetTitle("RaidInvite Settings")
  settingsFrame:SetStatusText("RaidInvite 1.0.0 by Salmondx")
  settingsFrame:SetWidth(500)
  settingsFrame:SetHeight(350)
  settingsFrame:SetLayout("List")

  local phrasesHeader = AceGUI:Create("Heading")
  phrasesHeader:SetText("Invitation Phrases Settings")
  phrasesHeader:SetFullWidth(true)
  settingsFrame:AddChild(phrasesHeader)

  local phrasesEdit = AceGUI:Create("MultiLineEditBox")
  phrasesEdit:SetLabel("Invitation Phrases")
  phrasesEdit:SetNumLines(6)
  phrasesEdit:SetFullWidth(true)
  phrasesEdit:SetText(self:PhrasesToString('\n'))
  phrasesEdit:SetCallback("OnEnterPressed", function(widget, event, value) self:SavePhrases(value) end)
  settingsFrame:AddChild(phrasesEdit)

  local announceHeader = AceGUI:Create("Heading")
  announceHeader:SetText("Guild Announcement Settings")
  announceHeader:SetFullWidth(true)
  settingsFrame:AddChild(announceHeader)

  local announceCheckBox = AceGUI:Create("CheckBox")
  announceCheckBox:SetLabel("Announce in guild chat on activation")
  announceCheckBox:SetFullWidth(true)
  announceCheckBox:SetValue(self.db.profile.announcement.enabled)
  announceCheckBox:SetCallback("OnValueChanged", function(widget, event, value) self.db.profile.announcement.enabled = value end)
  settingsFrame:AddChild(announceCheckBox)

  local announcetEdit = AceGUI:Create("EditBox")
  announcetEdit:SetLabel("Announcement phrase (#phrases to pretty print phrases above)")
  announcetEdit:SetFullWidth(true)
  announcetEdit:SetText(self.db.profile.announcement.phrase)
  announcetEdit:SetCallback("OnEnterPressed", function(widget, event, text) self.db.profile.announcement.phrase = text end)
  settingsFrame:AddChild(announcetEdit)

end

function RaidInvite:SavePhrases(text)
  local phrases = {}
  for s in text:gmatch("[^\r\n]+") do
    -- trim string
    s = s:gsub("%s+", "")
    if s ~= nil or s ~= '' then
      table.insert(phrases, s)
    end
  end

  self.db.profile.phrases = phrases
end

function RaidInvite:PhrasesToString(separator)
  local phrases = self.db.profile.phrases
  local joinedPhrase = ''
  for i = 1, #phrases do
    if i == 1 then
      joinedPhrase = joinedPhrase .. phrases[i]
    else
      joinedPhrase = joinedPhrase .. separator .. phrases[i]
    end
  end

  return joinedPhrase
end