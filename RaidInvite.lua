RaidInvite = LibStub("AceAddon-3.0"):NewAddon("RaidInvite", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local RaidInviteLDB = LibStub("LibDataBroker-1.1"):NewDataObject("RaidInvite", {
  type = "data source",
  text = "RaidInvite",
  icon = "Interface\\Icons\\Spell_ChargePositive",
  OnClick = function() RaidInvite:Trigger() end,
  OnTooltipShow = function(tooltip) RaidInvite:Tooltip(tooltip) end,
})
local icon = LibStub("LibDBIcon-1.0")

-- Global variables
AUTO_INV_WORDS = {'invite', 'inv', '1', 'impact'}
--
function RaidInvite:OnInitialize()
  self:Print("Available commands: /rinv on | /rinv off")
  self.db = LibStub("AceDB-3.0"):New("RaidInviteDB", {
    profile = {
      minimap = { hide = false }
    }
  })
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

function RaidInvite:Trigger()
  if not self.enabled then
    self:Enable()
  else
    self:Disable()
  end
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
  for i = 1, #AUTO_INV_WORDS do
    if text:match(AUTO_INV_WORDS[i]) then return true end
  end

  return false
end

function RaidInvite:NotifyGuild()
  local invitationList = '('
  for i = 1, #AUTO_INV_WORDS do
    if i == 1 then
      invitationList = invitationList .. AUTO_INV_WORDS[i]
    else
      invitationList = invitationList .. ', ' .. AUTO_INV_WORDS[i]
    end
  end
  invitationList = invitationList .. ')'

  SendChatMessage("Impact Raid Time! Type " .. invitationList .. " for invite!", "GUILD")
end

-- Register Commands and Events
RaidInvite:RegisterChatCommand("rinv", "HandleSlashInput")