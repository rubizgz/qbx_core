local discord = require 'config.client'.discord

if not discord.enabled then return end

local function updatePresence()
    local name = GetPlayerName(PlayerId())
    local serverId = GetPlayerServerId(PlayerId())
    SetRichPresence(('Nombre: %s | ID: %d'):format(name, serverId))
end

AddStateBagChangeHandler('PlayerCount', '', function(bagName, _, value)
    if bagName == 'global' and value then
        updatePresence()
    end
end)

-- CreateThread(function()
--     Wait(1000)
--     updatePresence()
-- end)

SetDiscordAppId(discord.appId)
SetDiscordRichPresenceAsset(discord.largeIcon.icon)
SetDiscordRichPresenceAssetText(discord.largeIcon.text)
SetDiscordRichPresenceAssetSmall(discord.smallIcon.icon)
SetDiscordRichPresenceAssetSmallText(discord.smallIcon.text)
SetDiscordRichPresenceAction(0, discord.firstButton.text, discord.firstButton.link)
SetDiscordRichPresenceAction(1, discord.secondButton.text, discord.secondButton.link)