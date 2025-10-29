local config = require 'config.server'
local defaultSpawn = require 'config.shared'.defaultSpawn
local logger = require 'modules.logger'
local storage = require 'server.storage.main'
local triggerEventHooks = require 'modules.hooks'
local maxJobsPerPlayer = GetConvarInt('qbx:max_jobs_per_player', 1)
local maxGangsPerPlayer = GetConvarInt('qbx:max_gangs_per_player', 1)
local setJobReplaces = GetConvar('qbx:setjob_replaces', 'true') == 'true'
local setGangReplaces = GetConvar('qbx:setgang_replaces', 'true') == 'true'
local accounts = json.decode(GetConvar('inventory:accounts', '["money"]'))
local accountsAsItems = table.create(0, #accounts)

for i = 1, #accounts do
    accountsAsItems[accounts[i]] = 0
end

---@param source Source
---@param citizenid? string
---@param newData? PlayerEntity
---@return boolean success
function Login(source, citizenid, newData)
    if not source or source == '' then
        lib.print.error('No se especificó la fuente al iniciar sesión')
        return false
    end

    if QBX.Players[source] then
        DropPlayer(tostring(source), locale('info.exploit_dropped'))
        logger.log({
            source = GetInvokingResource() or cache.resource,
            webhook = config.logging.webhook.anticheat,
            event = 'Anti-Cheat',
            color = 'white',
            tags = config.logging.role,
            message = ('%s [%s] Se ha interrumpido la sesión por intentar iniciar sesión dos veces'):format(GetPlayerName(tostring(source)), tostring(source))
        })
        return false
    end

    local license, license2 = GetPlayerIdentifierByType(source --[[@as string]], 'license'), GetPlayerIdentifierByType(source --[[@as string]], 'license2')
    local userId = license2 and storage.fetchUserByIdentifier(license2) or storage.fetchUserByIdentifier(license)
    if not userId then
        lib.print.error('El usuario no existe. Licencias comprobadas:', license2, license)
        return false
    end
    if citizenid then
        local playerData = storage.fetchPlayerEntity(citizenid)
        if playerData and (playerData.license == license2 or playerData.license == license) then
            playerData.userId = userId
            return CheckPlayerData(source, playerData) ~= nil
        else
            DropPlayer(tostring(source), locale('info.exploit_dropped'))
            logger.log({
                source = GetInvokingResource() or cache.resource,
                webhook = config.logging.webhook.anticheat,
                event = 'Anti-Cheat',
                color = 'white',
                tags = config.logging.role,
                message = ('%s ha sido expulsado por un exploit de unión de personajes'):format(GetPlayerName(source))
            })
        end
    else
        newData.userId = userId

        local player = CheckPlayerData(source, newData)
        Save(player.PlayerData.source)
        return true
    end

    return false
end

exports('Login', Login)

---@param citizenid string
---@return Player? player if found in storage
function GetOfflinePlayer(citizenid)
    if not citizenid then return end
    local playerData = storage.fetchPlayerEntity(citizenid)
    if not playerData then return end
    return CheckPlayerData(nil, playerData)
end

exports('GetOfflinePlayer', GetOfflinePlayer)

---Overwrites current primary job with a new job. Removing the player from their current primary job
---@param identifier Source | string
---@param jobName string name
---@param grade? integer defaults to 0
---@return boolean success if job was set
---@return ErrorResult? errorResult
function SetJob(identifier, jobName, grade)
    jobName = jobName:lower()
    grade = tonumber(grade) or 0

    local job = GetJob(jobName)

    if not job then
        lib.print.error(('El trabajo %s no existe'):format(jobName))

        return false
    end

    if not job.grades[grade] then
        lib.print.error(('El trabajo %s no tiene el grado %s'):format(jobName, grade))

        return false
    end

    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if setJobReplaces and player.PlayerData.job.name ~= 'unemployed' then
        local success, errorResult = RemovePlayerFromJob(player.PlayerData.citizenid, player.PlayerData.job.name)

        if not success then
            return false, errorResult
        end
    end

    if jobName ~= 'unemployed' then
        local success, errorResult = AddPlayerToJob(player.PlayerData.citizenid, jobName, grade)

        if not success then
            return false, errorResult
        end
    end

    return SetPlayerPrimaryJob(player.PlayerData.citizenid, jobName)
end

exports('SetJob', SetJob)

---@param identifier Source | string
---@param onDuty boolean
function SetJobDuty(identifier, onDuty)
    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player then return end

    player.PlayerData.job.onduty = not not onDuty

    if player.Offline then return end

    TriggerEvent('QBCore:Server:SetDuty', player.PlayerData.source, player.PlayerData.job.onduty)
    TriggerClientEvent('QBCore:Client:SetDuty', player.PlayerData.source, player.PlayerData.job.onduty)

    UpdatePlayerData(identifier)
end

exports('SetJobDuty', SetJobDuty)

---@param jobName string
---@param job Job
---@param grade integer
---@return PlayerJob
local function toPlayerJob(jobName, job, grade)
    return {
        name = jobName,
        label = job.label,
        isboss = job.grades[grade].isboss or false,
        onduty = job.defaultDuty or false,
        payment = job.grades[grade].payment or 0,
        type = job.type,
        grade = {
            name = job.grades[grade].name,
            level = grade
        }
    }
end

---Sets a player's job to be primary only if they already have it.
---@param citizenid string
---@param jobName string
---@return boolean success
---@return ErrorResult? errorResult
function SetPlayerPrimaryJob(citizenid, jobName)
    local player = GetPlayerByCitizenId(citizenid) or GetOfflinePlayer(citizenid)
    if not player then
        return false, {
            code = 'player_not_found',
            message = ('Jugador no encontrado con citizenid %s'):format(citizenid)
        }
    end

    local grade = jobName == 'unemployed' and 0 or player.PlayerData.jobs[jobName]
    if not grade then
        return false, {
            code = 'player_not_in_job',
            message = ('El jugador %s no tiene el trabajo %s'):format(citizenid, jobName)
        }
    end

    local job = GetJob(jobName)
    if not job then
        return false, {
            code = 'job_not_found',
            message = ('%s no existe en la memoria principal'):format(jobName)
        }
    end

    assert(job.grades[grade] ~= nil, ('El trabajo %s no tiene el grado %s'):format(jobName, grade))

    player.PlayerData.job = toPlayerJob(jobName, job, grade)

    if player.Offline then
        SaveOffline(player.PlayerData)
    else
        Save(player.PlayerData.source)
        UpdatePlayerData(player.PlayerData.source)
        TriggerEvent('QBCore:Server:OnJobUpdate', player.PlayerData.source, player.PlayerData.job)
        TriggerClientEvent('QBCore:Client:OnJobUpdate', player.PlayerData.source, player.PlayerData.job)
    end

    return true
end

exports('SetPlayerPrimaryJob', SetPlayerPrimaryJob)

---Adds a player to the job or overwrites their grade for a job already held
---@param citizenid string
---@param jobName string
---@param grade? integer
---@return boolean success
---@return ErrorResult? errorResult
function AddPlayerToJob(citizenid, jobName, grade)
    jobName = jobName:lower()
    grade = tonumber(grade) or 0

    -- unemployed job is the default, so players cannot be added to it
    if jobName == 'unemployed' then
        return false, {
            code = 'unemployed',
            message = 'Los jugadores no pueden ser añadidos al puesto de desempleado'
        }
    end

    local job = GetJob(jobName)
    if not job then
        return false, {
            code = 'job_not_found',
            message = ('%s no existe en la memoria principal'):format(jobName)
        }
    end

    if not job.grades[grade] then
        return false, {
            code = 'job_missing_grade',
            message = ('El trabajo %s no tiene el grado %s'):format(jobName, grade),
        }
    end

    local player = GetPlayerByCitizenId(citizenid) or GetOfflinePlayer(citizenid)
    if not player then
        return false, {
            code = 'player_not_found',
            message = ('Jugador no encontrado con citizenid %s'):format(citizenid)
        }
    end

    if player.PlayerData.jobs[jobName] == grade then
        return true
    end

    if qbx.table.size(player.PlayerData.jobs) >= maxJobsPerPlayer and not player.PlayerData.jobs[jobName] then
        return false, {
            code = 'max_jobs',
            message = 'El jugador ya tiene la cantidad máxima de trabajos permitidos'
        }
    end

    storage.addPlayerToJob(citizenid, jobName, grade)

    if not player.Offline then
        player.PlayerData.jobs[jobName] = grade
        SetPlayerData(player.PlayerData.source, 'jobs', player.PlayerData.jobs)
        TriggerEvent('qbx_core:server:onGroupUpdate', player.PlayerData.source, jobName, grade)
        TriggerClientEvent('qbx_core:client:onGroupUpdate', player.PlayerData.source, jobName, grade)
    end

    if player.PlayerData.job.name == jobName then
        SetPlayerPrimaryJob(citizenid, jobName)
    end

    return true
end

exports('AddPlayerToJob', AddPlayerToJob)

---If the job removed from is primary, sets the primary job to unemployed.
---@param citizenid string
---@param jobName string
---@return boolean success
---@return ErrorResult? errorResult
function RemovePlayerFromJob(citizenid, jobName)
    if jobName == 'unemployed' then
        return false, {
            code = 'unemployed',
            message = 'Los jugadores no pueden ser despedidos por desempleo'
        }
    end

    local player = GetPlayerByCitizenId(citizenid) or GetOfflinePlayer(citizenid)
    if not player then
        return false, {
            code = 'player_not_found',
            message = ('Jugador no encontrado con citizenid %s'):format(citizenid)
        }
    end

    if not player.PlayerData.jobs[jobName] then
        return true
    end

    storage.removePlayerFromJob(citizenid, jobName)
    player.PlayerData.jobs[jobName] = nil

    if player.PlayerData.job.name == jobName then
        local job = GetJob('unemployed')
        assert(job ~= nil, 'No se encuentra ningún puesto de trabajo para desempleados. ¿Existe en shared/jobs.lua?')
        player.PlayerData.job = toPlayerJob('unemployed', job, 0)
        if player.Offline then
            SaveOffline(player.PlayerData)
        else
            Save(player.PlayerData.source)
        end
    end

    if not player.Offline then
        SetPlayerData(player.PlayerData.source, 'jobs', player.PlayerData.jobs)
        TriggerEvent('qbx_core:server:onGroupUpdate', player.PlayerData.source, jobName)
        TriggerClientEvent('qbx_core:client:onGroupUpdate', player.PlayerData.source, jobName)
    end

    return true
end

exports('RemovePlayerFromJob', RemovePlayerFromJob)

---Removes the player from their current primary gang and adds the player to the new gang
---@param identifier Source | string
---@param gangName string name
---@param grade? integer defaults to 0
---@return boolean success if gang was set
---@return ErrorResult? errorResult
function SetGang(identifier, gangName, grade)
    gangName = gangName:lower()
    grade = tonumber(grade) or 0

    local gang = GetGang(gangName)

    if not gang then
        lib.print.error(('No se puede establecer la banda %s porque no existe'):format(gangName))

        return false
    end

    if not gang.grades[grade] then
        lib.print.error(('No se puede establecer la banda %s porque no tiene el grado %s'):format(gangName, grade))

        return false
    end

    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if setGangReplaces and player.PlayerData.gang.name ~= 'none' then
        local success, errorResult = RemovePlayerFromGang(player.PlayerData.citizenid, player.PlayerData.gang.name)

        if not success then
            return false, errorResult
        end
    end

    if gangName ~= 'none' then
        local success, errorResult = AddPlayerToGang(player.PlayerData.citizenid, gangName, grade)

        if not success then
            return false, errorResult
        end
    end

    return SetPlayerPrimaryGang(player.PlayerData.citizenid, gangName)
end

exports('SetGang', SetGang)

---Sets a player's gang to be primary only if they already have it.
---@param citizenid string
---@param gangName string
---@return boolean success
---@return ErrorResult? errorResult
function SetPlayerPrimaryGang(citizenid, gangName)
    local player = GetPlayerByCitizenId(citizenid) or GetOfflinePlayer(citizenid)
    if not player then
        return false, {
            code = 'player_not_found',
            message = ('Jugador no encontrado con citizenid %s'):format(citizenid)
        }
    end

    local grade = gangName == 'none' and 0 or player.PlayerData.gangs[gangName]
    if not grade then
        return false, {
            code = 'player_not_in_gang',
            message = ('El jugador %s no tiene la banda %s'):format(citizenid, gangName)
        }
    end

    local gang = GetGang(gangName)
    if not gang then
        return false, {
            code = 'gang_not_found',
            message = ('%s no existe en la memoria principal'):format(gangName)
        }
    end

    assert(gang.grades[grade] ~= nil, ('La banda %s no tiene grado %s'):format(gangName, grade))

    player.PlayerData.gang = {
        name = gangName,
        label = gang.label,
        isboss = gang.grades[grade].isboss,
        bankAuth = gang.grades[grade].bankAuth,
        grade = {
            name = gang.grades[grade].name,
            level = grade
        }
    }

    if player.Offline then
        SaveOffline(player.PlayerData)
    else
        Save(player.PlayerData.source)
        UpdatePlayerData(player.PlayerData.source)
        TriggerEvent('QBCore:Server:OnGangUpdate', player.PlayerData.source, player.PlayerData.gang)
        TriggerClientEvent('QBCore:Client:OnGangUpdate', player.PlayerData.source, player.PlayerData.gang)
    end

    return true
end

exports('SetPlayerPrimaryGang', SetPlayerPrimaryGang)

---Adds a player to the gang or overwrites their grade if already in the gang
---@param citizenid string
---@param gangName string
---@param grade? integer
---@return boolean success
---@return ErrorResult? errorResult
function AddPlayerToGang(citizenid, gangName, grade)
    gangName = gangName:lower()
    grade = tonumber(grade) or 0

    if gangName == 'none' then
        return false, {
            code = 'none',
            message = 'Ninguna es la banda predeterminada, por lo que no se pueden agregar jugadores a ella',
        }
    end

    local gang = GetGang(gangName)
    if not gang then
        return false, {
            code = 'gang_not_found',
            message = ('%s no existe en la memoria principal'):format(gangName)
        }
    end

    if not gang.grades[grade] then
        return false, {
            code = 'gang_missing_grade',
            message = ('La banda %s no tiene grado %s'):format(gangName, grade)
        }
    end

    local player = GetPlayerByCitizenId(citizenid) or GetOfflinePlayer(citizenid)
    if not player then
        return false, {
            code = 'player_not_found',
            message = ('Jugador no encontrado con citizenid %s'):format(citizenid)
        }
    end

    if player.PlayerData.gangs[gangName] == grade then
        return true
    end

    if qbx.table.size(player.PlayerData.gangs) >= maxGangsPerPlayer and not player.PlayerData.gangs[gangName] then
        return false, {
            code = 'max_gangs',
            message = 'El jugador ya tiene la cantidad máxima de pandillas permitida'
        }
    end

    storage.addPlayerToGang(citizenid, gangName, grade)

    if not player.Offline then
        player.PlayerData.gangs[gangName] = grade
        SetPlayerData(player.PlayerData.source, 'gangs', player.PlayerData.gangs)
        TriggerEvent('qbx_core:server:onGroupUpdate', player.PlayerData.source, gangName, grade)
        TriggerClientEvent('qbx_core:client:onGroupUpdate', player.PlayerData.source, gangName, grade)
    end

    if player.PlayerData.gang.name == gangName then
        SetPlayerPrimaryGang(citizenid, gangName)
    end

    return true
end

exports('AddPlayerToGang', AddPlayerToGang)

---Remove a player from a gang, setting them to the default no gang.
---@param citizenid string
---@param gangName string
---@return boolean success
---@return ErrorResult? errorResult
function RemovePlayerFromGang(citizenid, gangName)
    if gangName == 'none' then
        return false, {
            code = 'none',
            message = 'Ninguna es la banda predeterminada, por lo que los jugadores no pueden ser expulsados de ella',
        }
    end

    local player = GetPlayerByCitizenId(citizenid) or GetOfflinePlayer(citizenid)
    if not player then
        return false, {
            code = 'player_not_found',
            message = ('Jugador no encontrado con citizenid %s'):format(citizenid)
        }
    end

    if not player.PlayerData.gangs[gangName] then
        return true
    end

    storage.removePlayerFromGang(citizenid, gangName)
    player.PlayerData.gangs[gangName] = nil

    if player.PlayerData.gang.name == gangName then
        local gang = GetGang('none')
        assert(gang ~= nil, 'No se encuentra ninguna pandilla. ¿Existe en shared/gangs.lua?')
        player.PlayerData.gang = {
            name = 'none',
            label = gang.label,
            isboss = false,
            bankAuth = false,
            grade = {
                name = gang.grades[0].name,
                level = 0
            }
        }
        if player.Offline then
            SaveOffline(player.PlayerData)
        else
            Save(player.PlayerData.source)
        end
    end

    if not player.Offline then
        SetPlayerData(player.PlayerData.source, 'gangs', player.PlayerData.gangs)
        TriggerEvent('qbx_core:server:onGroupUpdate', player.PlayerData.source, gangName)
        TriggerClientEvent('qbx_core:client:onGroupUpdate', player.PlayerData.source, gangName)
    end

    return true
end

exports('RemovePlayerFromGang', RemovePlayerFromGang)

---@param source? integer if player is online
---@param playerData? PlayerEntity|PlayerData
---@return Player player
function CheckPlayerData(source, playerData)
    playerData = playerData or {}
    ---@diagnostic disable-next-line: param-type-mismatch
    local playerState = Player(source)?.state
    local Offline = true
    if source then
        playerData.source = source
        playerData.license = playerData.license or GetPlayerIdentifierByType(source --[[@as string]], 'license2') or GetPlayerIdentifierByType(source --[[@as string]], 'license')
        playerData.name = GetPlayerName(source)
        Offline = false
    end

    playerData.userId = playerData.userId or nil
    playerData.citizenid = playerData.citizenid or GenerateUniqueIdentifier('citizenid')
    playerData.cid = playerData.charinfo?.cid or playerData.cid or 1
    playerData.money = playerData.money or {}
    for moneytype, startamount in pairs(config.money.moneyTypes) do
        playerData.money[moneytype] = playerData.money[moneytype] or startamount
    end

    -- Charinfo
    playerData.charinfo = playerData.charinfo or {}
    playerData.charinfo.firstname = playerData.charinfo.firstname or 'Nombre'
    playerData.charinfo.lastname = playerData.charinfo.lastname or 'Apellido'
    playerData.charinfo.birthdate = playerData.charinfo.birthdate or '00-00-0000'
    playerData.charinfo.gender = playerData.charinfo.gender or 0
    playerData.charinfo.backstory = playerData.charinfo.backstory or 'Historia de fondo'
    playerData.charinfo.nationality = playerData.charinfo.nationality or 'UE'
    playerData.charinfo.phone = playerData.charinfo.phone or GenerateUniqueIdentifier('PhoneNumber')
    playerData.charinfo.account = playerData.charinfo.account or GenerateUniqueIdentifier('AccountNumber')
    playerData.charinfo.cid = playerData.charinfo.cid or playerData.cid
    -- Metadata
    playerData.metadata = playerData.metadata or {}
    playerData.metadata.optin = playerData.metadata.optin and true or false
    playerData.metadata.health = playerData.metadata.health or 200
    playerData.metadata.hunger = playerData.metadata.hunger or 100
    playerData.metadata.thirst = playerData.metadata.thirst or 100
    playerData.metadata.stress = playerData.metadata.stress or 0
    if playerState then
        playerState:set('hunger', playerData.metadata.hunger, true)
        playerState:set('thirst', playerData.metadata.thirst, true)
        playerState:set('stress', playerData.metadata.stress, true)
    end

    playerData.metadata.isdead = playerData.metadata.isdead or false
    playerData.metadata.inlaststand = playerData.metadata.inlaststand or false
    playerData.metadata.armor = playerData.metadata.armor or 0
    playerData.metadata.ishandcuffed = playerData.metadata.ishandcuffed or false
    playerData.metadata.tracker = playerData.metadata.tracker or false
    playerData.metadata.injail = playerData.metadata.injail or 0
    playerData.metadata.jailitems = playerData.metadata.jailitems or {}
    playerData.metadata.status = playerData.metadata.status or {}
    playerData.metadata.phone = playerData.metadata.phone or {}
    playerData.metadata.bloodtype = playerData.metadata.bloodtype or config.player.bloodTypes[math.random(1, #config.player.bloodTypes)]
    playerData.metadata.dealerrep = playerData.metadata.dealerrep or 0
    playerData.metadata.craftingrep = playerData.metadata.craftingrep or 0
    playerData.metadata.attachmentcraftingrep = playerData.metadata.attachmentcraftingrep or 0
    playerData.metadata.currentapartment = playerData.metadata.currentapartment or nil
    playerData.metadata.jobrep = playerData.metadata.jobrep or {}
    playerData.metadata.jobrep.tow = playerData.metadata.jobrep.tow or 0
    playerData.metadata.jobrep.trucker = playerData.metadata.jobrep.trucker or 0
    playerData.metadata.jobrep.taxi = playerData.metadata.jobrep.taxi or 0
    playerData.metadata.jobrep.hotdog = playerData.metadata.jobrep.hotdog or 0
    playerData.metadata.callsign = playerData.metadata.callsign or 'Sin distintivo de llamada'
    playerData.metadata.fingerprint = playerData.metadata.fingerprint or GenerateUniqueIdentifier('FingerId')
    playerData.metadata.walletid = playerData.metadata.walletid or GenerateUniqueIdentifier('WalletId')
    playerData.metadata.criminalrecord = playerData.metadata.criminalrecord or {
        hasRecord = false,
        date = nil
    }
    playerData.metadata.licences = playerData.metadata.licences or {
        id = true,
        driver = true,
        weapon = false,
    }
    playerData.metadata.inside = playerData.metadata.inside or {
        house = nil,
        apartment = {
            apartmentType = nil,
            apartmentId = nil,
        }
    }
    playerData.metadata.phonedata = playerData.metadata.phonedata or {
        SerialNumber = GenerateUniqueIdentifier('SerialNumber'),
        InstalledApps = {},
    }
    local jobs, gangs = storage.fetchPlayerGroups(playerData.citizenid)

    local job = GetJob(playerData.job?.name) or GetJob('unemployed')
    assert(job ~= nil, 'No se encontró el puesto de trabajo para desempleados. ¿Existe en shared/jobs.lua?')
    local jobGrade = GetJob(playerData.job?.name) and playerData.job.grade.level or 0
    if not job.grades[jobGrade] then
        jobGrade = 0
    end

    playerData.job = {
        name = playerData.job?.name or 'unemployed',
        label = job.label,
        payment = job.grades[jobGrade].payment or 0,
        type = job.type,
        onduty = playerData.job?.onduty or false,
        isboss = job.grades[jobGrade].isboss or false,
        bankAuth = job.grades[jobGrade].bankAuth or false,
        grade = {
            name = job.grades[jobGrade].name,
            level = jobGrade,
        }
    }
    if QBX.Shared.ForceJobDefaultDutyAtLogin and (job.defaultDuty ~= nil) then
        playerData.job.onduty = job.defaultDuty
    end

    playerData.jobs = jobs or {}
    local gang = GetGang(playerData.gang?.name) or GetGang('none')
    assert(gang ~= nil, 'No se encontró la pandilla none. ¿Existe en shared/gangs.lua?')
    local gangGrade = GetGang(playerData.gang?.name) and playerData.gang.grade.level or 0
    playerData.gang = {
        name = playerData.gang?.name or 'none',
        label = gang.label,
        isboss = gang.grades[gangGrade].isboss or false,
        bankAuth = gang.grades[gangGrade].bankAuth or false,
        grade = {
            name = gang.grades[gangGrade].name,
            level = gangGrade
        }
    }
    playerData.gangs = gangs or {}
    playerData.position = playerData.position or defaultSpawn
    playerData.items = {}
    return CreatePlayer(playerData --[[@as PlayerData]], Offline)
end

---On player logout
---@param source Source
function Logout(source)
    local player = GetPlayer(source)
    if not player then return end
    local playerState = Player(source)?.state
    player.PlayerData.metadata.hunger = playerState?.hunger or player.PlayerData.metadata.hunger
    player.PlayerData.metadata.thirst = playerState?.thirst or player.PlayerData.metadata.thirst
    player.PlayerData.metadata.stress = playerState?.stress or player.PlayerData.metadata.stress

    TriggerClientEvent('QBCore:Client:OnPlayerUnload', source)
    TriggerEvent('QBCore:Server:OnPlayerUnload', source)

    player.PlayerData.lastLoggedOut = os.time()
    Save(player.PlayerData.source)

    Wait(200)
    QBX.Players[source] = nil
    GlobalState.PlayerCount -= 1
    TriggerClientEvent('qbx_core:client:playerLoggedOut', source)
    TriggerEvent('qbx_core:server:playerLoggedOut', source)
end

exports('Logout', Logout)

---Create a new character
---Don't touch any of this unless you know what you are doing
---Will cause major issues!
---@param playerData PlayerData
---@param Offline boolean
---@return Player player
function CreatePlayer(playerData, Offline)
    local self = {}
    self.Functions = {}
    self.PlayerData = playerData
    self.Offline = Offline

    ---@deprecated use UpdatePlayerData instead
    function self.Functions.UpdatePlayerData()
        if self.Offline then
            lib.print.warn('UpdatePlayerData no es compatible con jugadores sin conexión')
            return
        end

        UpdatePlayerData(self.PlayerData.source)
    end

    ---@deprecated use SetJob instead
    ---Overwrites current primary job with a new job. Removing the player from their current primary job
    ---@param jobName string name
    ---@param grade? integer defaults to 0
    ---@return boolean success if job was set
    ---@return ErrorResult? errorResult
    function self.Functions.SetJob(jobName, grade)
        return SetJob(self.PlayerData.source, jobName, grade)
    end

    ---@deprecated use SetGang instead
    ---Removes the player from their current primary gang and adds the player to the new gang
    ---@param gangName string name
    ---@param grade? integer defaults to 0
    ---@return boolean success if gang was set
    ---@return ErrorResult? errorResult
    function self.Functions.SetGang(gangName, grade)
        return SetGang(self.PlayerData.source, gangName, grade)
    end

    ---@deprecated use SetJobDuty instead
    ---@param onDuty boolean
    function self.Functions.SetJobDuty(onDuty)
        SetJobDuty(self.PlayerData.source, onDuty)
    end

    ---@deprecated use SetPlayerData instead
    ---@param key string
    ---@param val any
    function self.Functions.SetPlayerData(key, val)
        SetPlayerData(self.PlayerData.source, key, val)
    end

    ---@deprecated use SetMetadata instead
    ---@param meta string
    ---@param val any
    function self.Functions.SetMetaData(meta, val)
        SetMetadata(self.PlayerData.source, meta, val)
    end

    ---@deprecated use GetMetadata instead
    ---@param meta string
    ---@return any
    function self.Functions.GetMetaData(meta)
        return GetMetadata(self.PlayerData.source, meta)
    end

    ---@deprecated use SetMetadata instead
    ---@param amount number
    function self.Functions.AddJobReputation(amount)
        if not amount then return end

        amount = tonumber(amount) --[[@as number]]

        self.PlayerData.metadata[self.PlayerData.job.name].reputation += amount

        ---@diagnostic disable-next-line: param-type-mismatch
        UpdatePlayerData(self.Offline and self.PlayerData.citizenid or self.PlayerData.source)
    end

    ---@param moneytype MoneyType
    ---@param amount number
    ---@param reason? string
    ---@return boolean success if money was added
    function self.Functions.AddMoney(moneytype, amount, reason)
        return AddMoney(self.PlayerData.source, moneytype, amount, reason)
    end

    ---@param moneytype MoneyType
    ---@param amount number
    ---@param reason? string
    ---@return boolean success if money was removed
    function self.Functions.RemoveMoney(moneytype, amount, reason)
        return RemoveMoney(self.PlayerData.source, moneytype, amount, reason)
    end

    ---@param moneytype MoneyType
    ---@param amount number
    ---@param reason? string
    ---@return boolean success if money was set
    function self.Functions.SetMoney(moneytype, amount, reason)
        return SetMoney(self.PlayerData.source, moneytype, amount, reason)
    end

    ---@param moneytype MoneyType
    ---@return boolean | number amount or false if moneytype does not exist
    function self.Functions.GetMoney(moneytype)
        return GetMoney(self.PlayerData.source, moneytype)
    end

    local function qbItemCompat(item)
        if not item then return end

        item.info = item.metadata
        item.amount = item.count

        return item
    end

    ---@param item string
    ---@return string
    local function oxItemCompat(item)
        return item == 'cash' and 'money' or item
    end

    ---@deprecated use ox_inventory exports directly
    ---@param item string
    ---@param amount number
    ---@param metadata? table
    ---@param slot? number
    ---@return boolean success
    function self.Functions.AddItem(item, amount, slot, metadata)
        assert(not self.Offline, 'No compatible con jugadores sin conexión')
        return exports.ox_inventory:AddItem(self.PlayerData.source, oxItemCompat(item), amount, metadata, slot)
    end

    ---@deprecated use ox_inventory exports directly
    ---@param item string
    ---@param amount number
    ---@param slot? number
    ---@return boolean success
    function self.Functions.RemoveItem(item, amount, slot)
        assert(not self.Offline, 'No compatible con jugadores sin conexión')
        return exports.ox_inventory:RemoveItem(self.PlayerData.source, oxItemCompat(item), amount, nil, slot)
    end

    ---@deprecated use ox_inventory exports directly
    ---@param slot number
    ---@return any table
    function self.Functions.GetItemBySlot(slot)
        assert(not self.Offline, 'No compatible con jugadores sin conexión')
        return qbItemCompat(exports.ox_inventory:GetSlot(self.PlayerData.source, slot))
    end

    ---@deprecated use ox_inventory exports directly
    ---@param itemName string
    ---@return any table
    function self.Functions.GetItemByName(itemName)
        assert(not self.Offline, 'No compatible con jugadores sin conexión')
        return qbItemCompat(exports.ox_inventory:GetSlotWithItem(self.PlayerData.source, oxItemCompat(itemName)))
    end

    ---@deprecated use ox_inventory exports directly
    ---@param itemName string
    ---@return any table
    function self.Functions.GetItemsByName(itemName)
        assert(not self.Offline, 'No compatible con jugadores sin conexión')
        return qbItemCompat(exports.ox_inventory:GetSlotsWithItem(self.PlayerData.source, oxItemCompat(itemName)))
    end

    ---@deprecated use ox_inventory exports directly
    function self.Functions.ClearInventory()
        assert(not self.Offline, 'No compatible con jugadores sin conexión')
        return exports.ox_inventory:ClearInventory(self.PlayerData.source)
    end

    ---@deprecated use ox_inventory exports directly
    function self.Functions.SetInventory()
        error('La función Player.Functions.SetInventory no es compatible con ox_inventory. Pruebe con ClearInventory y, a continuación, añada los objetos que desee.')
    end

    ---@deprecated use SetCharInfo instead
    ---@param cardNumber number
    function self.Functions.SetCreditCard(cardNumber)
        self.PlayerData.charinfo.card = cardNumber

        ---@diagnostic disable-next-line: param-type-mismatch
        UpdatePlayerData(self.Offline and self.PlayerData.citizenid or self.PlayerData.source)
    end

    ---@deprecated use Save or SaveOffline instead
    function self.Functions.Save()
        if self.Offline then
            SaveOffline(self.PlayerData)
        else
            Save(self.PlayerData.source)
        end
    end

    ---@deprecated call exports.qbx_core:Logout(source)
    function self.Functions.Logout()
        assert(not self.Offline, 'No compatible con jugadores sin conexión')
        Logout(self.PlayerData.source)
    end

    AddEventHandler('qbx_core:server:onJobUpdate', function(jobName, job)
        if self.PlayerData.job.name ~= jobName then return end

        if not job then
            self.PlayerData.job = {
                name = 'unemployed',
                label = 'Civil',
                isboss = false,
                bankAuth = false,
                onduty = true,
                payment = 1,
                grade = {
                    name = 'Desempleado',
                    level = 0,
                }
            }
        else
            self.PlayerData.job.label = job.label
            self.PlayerData.job.type = job.type or 'none'

            local jobGrade = job.grades[self.PlayerData.job.grade.level]

            if jobGrade then
                self.PlayerData.job.grade.name = jobGrade.name
                self.PlayerData.job.payment = jobGrade.payment or 30
                self.PlayerData.job.isboss = jobGrade.isboss or false
                self.PlayerData.job.bankAuth = jobGrade.bankAuth or false
            else
                self.PlayerData.job.grade = {
                    name = 'Sin calificaciones',
                    level = 0,
                    payment = 3,
                    isboss = false,
                }
            end
        end

        if not self.Offline then
            UpdatePlayerData(self.PlayerData.source)
            TriggerEvent('QBCore:Server:OnJobUpdate', self.PlayerData.source, self.PlayerData.job)
            TriggerClientEvent('QBCore:Client:OnJobUpdate', self.PlayerData.source, self.PlayerData.job)
        end
    end)

    AddEventHandler('qbx_core:server:onGangUpdate', function(gangName, gang)
        if self.PlayerData.gang.name ~= gangName then return end

        if not gang then
            self.PlayerData.gang = {
                name = 'none',
                label = 'Sin afiliación a pandillas',
                isboss = false,
                bankAuth = false,
                grade = {
                    name = 'none',
                    level = 0
                }
            }
        else
            self.PlayerData.gang.label = gang.label

            local gangGrade = gang.grades[self.PlayerData.gang.grade.level]

            if gangGrade then
                self.PlayerData.gang.grade.name = gangGrade.name
                self.PlayerData.gang.isboss = gangGrade.isboss or false
                self.PlayerData.gang.bankAuth = gangGrade.bankAuth or false
            else
                self.PlayerData.gang.grade = {
                    name = 'Sin calificaciones',
                    level = 0,
                }
                self.PlayerData.gang.isboss = false
                self.PlayerData.gang.bankAuth = false
            end
        end

        if not self.Offline then
            UpdatePlayerData(self.PlayerData.source)
            TriggerEvent('QBCore:Server:OnGangUpdate', self.PlayerData.source, self.PlayerData.gang)
            TriggerClientEvent('QBCore:Client:OnGangUpdate', self.PlayerData.source, self.PlayerData.gang)
        end
    end)

    if not self.Offline then
        QBX.Players[self.PlayerData.source] = self
        local ped = GetPlayerPed(self.PlayerData.source)
        lib.callback.await('qbx_core:client:setHealth', self.PlayerData.source, self.PlayerData.metadata.health)
        SetPedArmour(ped, self.PlayerData.metadata.armor)
        -- At this point we are safe to emit new instance to third party resource for load handling
        GlobalState.PlayerCount += 1
        UpdatePlayerData(self.PlayerData.source)
        Player(self.PlayerData.source).state:set('loadInventory', true, true)
        TriggerEvent('QBCore:Server:PlayerLoaded', self)
    end

    return self
end

exports('CreatePlayer', CreatePlayer)

---Save player info to database (make sure citizenid is the primary key in your database)
---@param source Source
function Save(source)
    local ped = GetPlayerPed(source)
    local playerData = QBX.Players[source].PlayerData
    local playerState = Player(source)?.state
    local pcoords = playerData.position
    if not playerState.inApartment and not playerState.inProperty then
        local coords = GetEntityCoords(ped)
        pcoords = vec4(coords.x, coords.y, coords.z, GetEntityHeading(ped))
    end
    if not playerData then
        lib.print.error('QBX.PLAYER.SAVE - ¡PLAYERDATA ESTÁ VACÍO!')
        return
    end

    playerData.metadata.health = GetEntityHealth(ped)
    playerData.metadata.armor = GetPedArmour(ped)

    if playerState.isLoggedIn then
        playerData.metadata.hunger = playerState.hunger or 0
        playerData.metadata.thirst = playerState.thirst or 0
        playerData.metadata.stress = playerState.stress or 0
    end

    CreateThread(function()
        storage.upsertPlayerEntity({
            playerEntity = playerData,
            position = pcoords,
        })
    end)
    assert(GetResourceState('qb-inventory') ~= 'started', 'qb-inventory no es compatible con qbx_core. Utilice ox_inventory en su lugar')
    lib.print.verbose(('%s JUGADOR GUARDADO.'):format(playerData.name))
end

exports('Save', Save)

---@param playerData PlayerEntity
function SaveOffline(playerData)
    if not playerData then
        lib.print.error('SaveOffline - ¡LOS DATOS DEL JUGADOR ESTÁN VACÍOS!')
        return
    end

    CreateThread(function()
        storage.upsertPlayerEntity({
            playerEntity = playerData,
            position = playerData.position.xyz
        })
    end)
    assert(GetResourceState('qb-inventory') ~= 'started', 'qb-inventory no es compatible con qbx_core. Utilice ox_inventory en su lugar')
    lib.print.verbose(('¡%s JUGADOR SIN CONEXIÓN GUARDADO.'):format(playerData.name))
end

exports('SaveOffline', SaveOffline)

---@param identifier Source | string
---@param key string
---@param value any
function SetPlayerData(identifier, key, value)
    if type(key) ~= 'string' then return end

    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player then return end

    player.PlayerData[key] = value

    UpdatePlayerData(identifier)
end

exports('SetPlayerData', SetPlayerData)

---@param identifier Source | string
function UpdatePlayerData(identifier)
    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player or player.Offline then return end

    TriggerEvent('QBCore:Player:SetPlayerData', player.PlayerData)
    TriggerClientEvent('QBCore:Player:SetPlayerData', player.PlayerData.source, player.PlayerData)
end

exports('UpdatePlayerData', UpdatePlayerData)

---@param identifier Source | string
---@param metadata string
---@param value any
function SetMetadata(identifier, metadata, value)
    if type(metadata) ~= 'string' then return end

    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player then return end

    local oldValue

    if metadata:match('%.') then
        local metaTable, metaKey = metadata:match('([^%.]+)%.(.+)')

        if metaKey:match('%.') then
            lib.print.error('No se pueden obtener metadatos anidados a más de un nivel de profundidad')
        end

        oldValue = player.PlayerData.metadata[metaTable]

        player.PlayerData.metadata[metaTable][metaKey] = value

        metadata = metaTable
    else
        oldValue = player.PlayerData.metadata[metadata]

        player.PlayerData.metadata[metadata] = value
    end

    UpdatePlayerData(identifier)

    if not player.Offline then
        local playerState = Player(player.PlayerData.source).state

        TriggerClientEvent('qbx_core:client:onSetMetaData', player.PlayerData.source, metadata, oldValue, value)
        TriggerEvent('qbx_core:server:onSetMetaData', metadata,  oldValue, value, player.PlayerData.source)

        if (metadata == 'hunger' or metadata == 'thirst' or metadata == 'stress') then
            value = lib.math.clamp(value, 0, 100)

            if playerState[metadata] ~= value then
                playerState:set(metadata, value, true)
            end
        end

        if (metadata == 'dead' or metadata == 'inlaststand') then
            playerState:set('canUseWeapons', not value, true)
        end
    end

    if metadata == 'inlaststand' or metadata == 'isdead' then
        if player.Offline then
            SaveOffline(player.PlayerData)
        else
            Save(player.PlayerData.source)
        end
    end
end

exports('SetMetadata', SetMetadata)

---@param identifier Source | string
---@param metadata string
---@return any
function GetMetadata(identifier, metadata)
    if type(metadata) ~= 'string' then return end

    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player then return end

    if metadata:match('%.') then
        local metaTable, metaKey = metadata:match('([^%.]+)%.(.+)')

        if metaKey:match('%.') then
            lib.print.error('No se pueden obtener metadatos anidados a más de un nivel de profundidad')
        end

        return player.PlayerData.metadata[metaTable][metaKey]
    else
        return player.PlayerData.metadata[metadata]
    end
end

exports('GetMetadata', GetMetadata)

---@param identifier Source | string
---@param charInfo string
---@param value any
function SetCharInfo(identifier, charInfo, value)
    if type(charInfo) ~= 'string' then return end

    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player then return end

    --local oldCharInfo = player.PlayerData.charinfo[charInfo]

    player.PlayerData.charinfo[charInfo] = value

    UpdatePlayerData(identifier)
end

exports('SetCharInfo', SetCharInfo)

---@param source Source
---@param playerMoney table
---@param moneyType MoneyType
---@param amount number
---@param actionType 'add' | 'remove' | 'set'
---@param reason? string
---@param difference? number
local function emitMoneyEvents(source, playerMoney, moneyType, amount, actionType, reason, difference)
    local isSet = actionType == 'set'
    local isRemove = actionType == 'remove'

    TriggerClientEvent('hud:client:OnMoneyChange', source, moneyType, isSet and math.abs(difference) or amount, isSet and difference < 0 or isRemove, reason)
    TriggerClientEvent('QBCore:Client:OnMoneyChange', source, moneyType, amount, actionType, reason)
    TriggerEvent('QBCore:Server:OnMoneyChange', source, moneyType, amount, actionType, reason)

    if moneyType == 'bank' and isRemove then
        TriggerClientEvent('qb-phone:client:RemoveBankMoney', source, amount)
    end

    local oxMoneyType = moneyType == 'cash' and 'money' or moneyType

    if accountsAsItems[oxMoneyType] then
        exports.ox_inventory:SetItem(source, oxMoneyType, playerMoney[moneyType])
    end
end

---@param identifier Source | string
---@param moneyType MoneyType
---@param amount number
---@param reason? string
---@return boolean success if money was added
function AddMoney(identifier, moneyType, amount, reason)
    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player then return false end

    reason = reason or 'unknown'
    amount = qbx.math.round(tonumber(amount) --[[@as number]])

    if amount < 0 or not player.PlayerData.money[moneyType] then return false end

    if not triggerEventHooks('addMoney', {
        source = player.PlayerData.source,
        moneyType = moneyType,
        amount = amount
    }) then return false end

    player.PlayerData.money[moneyType] += amount

    if player.Offline then
        SaveOffline(player.PlayerData)
    else
        UpdatePlayerData(identifier)

        local tags = amount > 100000 and config.logging.role or nil
        local resource = GetInvokingResource() or cache.resource

        logger.log({
            source = resource,
            webhook = config.logging.webhook['playermoney'],
            event = 'AddMoney',
            color = 'lightgreen',
            tags = tags,
            message = ('**%s (ID de ciudadano: %s | id: %s)** $%s (%s) agregado, nuevo %s saldo: $%s motivo: %s'):format(GetPlayerName(player.PlayerData.source), player.PlayerData.citizenid, player.PlayerData.source, amount, moneyType, moneyType, player.PlayerData.money[moneyType], reason),
            --oxLibTags = ('script:%s,playerName:%s,citizenId:%s,playerSource:%s,amount:%s,moneyType:%s,newBalance:%s,reason:%s'):format(resource, GetPlayerName(player.PlayerData.source), player.PlayerData.citizenid, player.PlayerData.source, amount, moneyType, player.PlayerData.money[moneyType], reason)
        })

        emitMoneyEvents(player.PlayerData.source, player.PlayerData.money, moneyType, amount, 'add', reason)
    end

    return true
end

exports('AddMoney', AddMoney)

---@param identifier Source | string
---@param moneyType MoneyType
---@param amount number
---@param reason? string
---@return boolean success if money was removed
function RemoveMoney(identifier, moneyType, amount, reason)
    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player then return false end

    reason = reason or 'unknown'
    amount = qbx.math.round(tonumber(amount) --[[@as number]])

    if amount < 0 or not player.PlayerData.money[moneyType] then return false end

    if not triggerEventHooks('removeMoney', {
        source = player.PlayerData.source,
        moneyType = moneyType,
        amount = amount
    }) then return false end

    for _, mType in pairs(config.money.dontAllowMinus) do
        if mType == moneyType then
            if (player.PlayerData.money[moneyType] - amount) < 0 then
                return false
            end
        end
    end

    player.PlayerData.money[moneyType] -= amount

    if player.Offline then
        SaveOffline(player.PlayerData)
    else
        UpdatePlayerData(identifier)

        local tags = amount > 100000 and config.logging.role or nil
        local resource = GetInvokingResource() or cache.resource

        logger.log({
            source = resource,
            webhook = config.logging.webhook['playermoney'],
            event = 'RemoveMoney',
            color = 'red',
            tags = tags,
            message = ('** %s (ID de ciudadano: %s | id: %s)** $%s (%s) eliminado, nuevo %s saldo: $%s motivo: %s'):format(GetPlayerName(player.PlayerData.source), player.PlayerData.citizenid, player.PlayerData.source, amount, moneyType, moneyType, player.PlayerData.money[moneyType], reason),
            --oxLibTags = ('script:%s,playerName:%s,citizenId:%s,playerSource:%s,amount:%s,moneyType:%s,newBalance:%s,reason:%s'):format(resource, GetPlayerName(player.PlayerData.source), player.PlayerData.citizenid, player.PlayerData.source, amount, moneyType, player.PlayerData.money[moneyType], reason)
        })

        emitMoneyEvents(player.PlayerData.source, player.PlayerData.money, moneyType, amount, 'remove', reason)
    end

    return true
end

exports('RemoveMoney', RemoveMoney)

---@param identifier Source | string
---@param moneyType MoneyType
---@param amount number
---@param reason? string
---@return boolean success if money was set
function SetMoney(identifier, moneyType, amount, reason)
    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player then return false end

    reason = reason or 'unknown'
    amount = qbx.math.round(tonumber(amount) --[[@as number]])
    local oldAmount = player.PlayerData.money[moneyType]

    if amount < 0 or not oldAmount then return false end

    if not triggerEventHooks('setMoney', {
        source = player.PlayerData.source,
        moneyType = moneyType,
        amount = amount
    }) then return false end

    player.PlayerData.money[moneyType] = amount

    if player.Offline then
        SaveOffline(player.PlayerData)
    else
        UpdatePlayerData(identifier)

        local difference = amount - oldAmount
        local dirChange = difference < 0 and 'removed' or 'added'
        local absDifference = math.abs(difference)
        local tags = absDifference > 50000 and config.logging.role or {}
        local resource = GetInvokingResource() or cache.resource

        logger.log({
            source = resource,
            webhook = config.logging.webhook['playermoney'],
            event = 'SetMoney',
            color = difference < 0 and 'red' or 'green',
            tags = tags,
            message = ('**%s (ID de ciudadano: %s | id: %s)** $%s (%s) %s, nuevo %s saldo: $%s motivo: %s'):format(GetPlayerName(player.PlayerData.source), player.PlayerData.citizenid, player.PlayerData.source, absDifference, moneyType, dirChange, moneyType, player.PlayerData.money[moneyType], reason),
        })

        emitMoneyEvents(player.PlayerData.source, player.PlayerData.money, moneyType, amount, 'set', reason, difference)
    end

    return true
end

exports('SetMoney', SetMoney)

---@param identifier Source | string
---@param moneyType MoneyType
---@return boolean | number amount or false if moneytype does not exist
function GetMoney(identifier, moneyType)
    if not moneyType then return false end

    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player then return false end

    return player.PlayerData.money[moneyType]
end

exports('GetMoney', GetMoney)

---@param source Source
---@param citizenid string
---@return boolean success
function DeleteCharacter(source, citizenid)
    local license, license2 = GetPlayerIdentifierByType(source --[[@as string]], 'license'), GetPlayerIdentifierByType(source --[[@as string]], 'license2')
    local result, success = storage.fetchPlayerEntity(citizenid)?.license, false

    if license == result or license2 == result then
        success = storage.deletePlayer(citizenid)
        if success then
            logger.log({
                source = 'qbx_core',
                webhook = config.logging.webhook['joinleave'],
                event = 'Character Deleted',
                color = 'red',
                message = ('**%s** ha eliminado el personaje **%s**...'):format(GetPlayerName(source), citizenid, source),
            })
        end
    else
        DropPlayer(tostring(source), locale('info.exploit_dropped'))
        logger.log({
            source = 'qbx_core',
            webhook = config.logging.webhook['anticheat'],
            event = 'Anti-Cheat',
            color = 'white',
            tags = config.logging.role,
            message = ('%s ha sido expulsado por intentar eliminar un personaje de forma indebida'):format(GetPlayerName(source)),
        })
    end

    return success
end

lib.callback.register('qbx_core:server:deleteCharacter', DeleteCharacter)

---@param citizenid string
function ForceDeleteCharacter(citizenid)
    local result = storage.fetchPlayerEntity(citizenid).license
    if result then
        local player = GetPlayerByCitizenId(citizenid)
        if player then
            DropPlayer(player.PlayerData.source --[[@as string]], 'Un administrador eliminó el personaje que estás usando actualmente')
        end

        CreateThread(function()
            local success = storage.deletePlayer(citizenid)
            if success then
                logger.log({
                    source = 'qbx_core',
                    webhook = config.logging.webhook['joinleave'],
                    event = 'Character Force Deleted',
                    color = 'red',
                    message = ('El personaje **%s** fue eliminado'):format(citizenid),
                })
            end
        end)
    end
end

exports('DeleteCharacter', ForceDeleteCharacter)

---Generate unique values for player identifiers
---@param type UniqueIdType The type of unique value to generate
---@return string | number UniqueVal unique value generated
function GenerateUniqueIdentifier(type)
    local isUnique, uniqueId
    local table = config.player.identifierTypes[type]
    repeat
        uniqueId = table.valueFunction()
        isUnique = storage.fetchIsUnique(type, uniqueId)
    until isUnique
    return uniqueId
end

exports('GenerateUniqueIdentifier', GenerateUniqueIdentifier)
