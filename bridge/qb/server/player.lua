function AddDeprecatedFunctions(player)
    if not player then return end

    ---@deprecated call ox_inventory instead
    function player.Functions.GetCardSlot()
        error('player.Functions.GetCardSlot no es compatible. (Utilice ox_inventory en su lugar)')
    end

    ---@deprecated player.Functions.SetMetaData instead
    function player.Functions.AddField()
        error('player.Functions.AddField no es compatible. (Utilice player.Functions.SetMetaData en su lugar)')
    end

    ---@deprecated
    function player.Functions.AddMethod()
        error('player.Functions.AddMethod no es compatible')
    end

    return player
end

local playerObj = {}

---@deprecated ox_inventory automatically saves
---@param source Source
function playerObj.SaveInventory(source) -- luacheck: ignore
    assert(GetResourceState('qb-inventory') ~= 'started', 'qb-inventory no es compatible con qbx_core. Utilice ox_inventory en su lugar')
end

---@deprecated ox_inventory automatically saves
---@param playerData PlayerData
function playerObj.SaveOfflineInventory(playerData) -- luacheck: ignore
    assert(GetResourceState('qb-inventory') ~= 'started', 'qb-inventory no es compatible con qbx_core. Utilice ox_inventory en su lugar')
end

---@deprecated call ox_inventory exports directly
---@param items any[]
---@return number?
function playerObj.GetTotalWeight(items) -- luacheck: ignore
    assert(GetResourceState('qb-inventory') ~= 'started', 'qb-inventory no es compatible con qbx_core. Utilice ox_inventory en su lugar')
end

---@deprecated call ox_inventory exports directly
---@param items any[]
---@param itemName string
---@return integer[]? slots
function playerObj.GetSlotsByItem(items, itemName) -- luacheck: ignore
    assert(GetResourceState('qb-inventory') ~= 'started', 'qb-inventory no es compatible con qbx_core. Utilice ox_inventory en su lugar')
end

---@deprecated call ox_inventory exports directly
---@param items any[]
---@param itemName string
---@return integer? slot
function playerObj.GetFirstSlotByItem(items, itemName) -- luacheck: ignore
    assert(GetResourceState('qb-inventory') ~= 'started', 'qb-inventory no es compatible con qbx_core. Utilice ox_inventory en su lugar')
end

---@param source Source
---@param citizenid? string
---@param newData? PlayerEntity
---@return boolean success
function playerObj.Login(source, citizenid, newData)
    return exports.qbx_core:Login(source, citizenid, newData)
end

---@param citizenid string
---@return Player? player if found in storage
function playerObj.GetOfflinePlayer(citizenid)
    return AddDeprecatedFunctions(exports.qbx_core:GetOfflinePlayer(citizenid))
end

---@deprecated unsupported. Call Login or CreatePlayer
function playerObj.CheckPlayerData()
    error('No compatible. (Utilice Call Login o CreatePlayer en su lugar)')
end

---On player logout
---@param source Source
function playerObj.Logout(source)
    exports.qbx_core:Logout(source)
end

---Create a new character
---Don't touch any of this unless you know what you are doing
---Will cause major issues!
---@param playerData PlayerData
---@param Offline boolean
---@return Player?
function playerObj.CreatePlayer(playerData, Offline)
    return AddDeprecatedFunctions(exports.qbx_core:CreatePlayer(playerData, Offline))
end

---Save player info to database (make sure citizenid is the primary key in your database)
---@param source Source
function playerObj.Save(source)
    exports.qbx_core:Save(source)
end

---@param playerData PlayerEntity
function playerObj.SaveOffline(playerData)
    exports.qbx_core:SaveOffline(playerData)
end

playerObj.DeleteCharacter = DeleteCharacter

---@param citizenid string
function playerObj.ForceDeleteCharacter(citizenid)
    exports.qbx_core:DeleteCharacter(citizenid)
end

---Generate unique values for player identifiers
---@param type UniqueIdType The type of unique value to generate
---@return string | number UniqueVal unique value generated
function playerObj.GenerateUniqueIdentifier(type)
    return exports.qbx_core:GenerateUniqueIdentifier(type)
end


---@deprecated player.GenerateUniqueIdentifier('citizenid') instead
---@return string citizenid unique citizenid generated
function playerObj.CreateCitizenId()
    return exports.qbx_core:GenerateUniqueIdentifier('citizenid')
end

return playerObj