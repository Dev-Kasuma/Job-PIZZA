-- Server-side optimized for ESX Legacy, ox_lib, ox_inventory, oxmysql

local PlayerData = {}
local SocietyData = {
    balance = Config.Society.initialBalance,
    transactions = {}
}

-- Initialize database on resource start
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `pizza_delivery` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(50) NOT NULL,
            `deliveries` INT DEFAULT 0,
            `earnings` INT DEFAULT 0,
            `last_delivery` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `identifier` (`identifier`)
        )
    ]])
    
    -- Create society tables if enabled
    if Config.Society.enabled then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `pizza_society` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `balance` INT DEFAULT 50000
            )
        ]])
        
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `pizza_society_logs` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `identifier` VARCHAR(50) NOT NULL,
                `action` VARCHAR(50) NOT NULL,
                `amount` INT NOT NULL,
                `date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                KEY `idx_identifier` (`identifier`),
                KEY `idx_date` (`date`)
            )
        ]])
        
        -- Load society balance from database
        local result = MySQL.query.await('SELECT balance FROM pizza_society ORDER BY id DESC LIMIT 1')
        if result and result[1] then
            SocietyData.balance = result[1].balance
        else
            -- Initialize society balance
            MySQL.insert.await('INSERT INTO pizza_society (balance) VALUES (?)', {Config.Society.initialBalance})
        end
        
        -- Load recent transactions
        local transactions = MySQL.query.await('SELECT * FROM pizza_society_logs ORDER BY date DESC LIMIT 20')
        if transactions then
            SocietyData.transactions = transactions
        end
    end
end)

-- Get player data with caching
local function GetPlayerData(identifier)
    if PlayerData[identifier] then
        return PlayerData[identifier]
    end

    local result = MySQL.query.await('SELECT * FROM pizza_delivery WHERE identifier = ?', {identifier})
    
    if result and result[1] then
        PlayerData[identifier] = result[1]
        return result[1]
    else
        -- Create new entry
        MySQL.insert.await('INSERT INTO pizza_delivery (identifier, deliveries, earnings) VALUES (?, 0, 0)', {identifier})
        PlayerData[identifier] = {identifier = identifier, deliveries = 0, earnings = 0}
        return PlayerData[identifier]
    end
end

-- Update player data
local function UpdatePlayerData(identifier)
    if not PlayerData[identifier] then return end
    
    MySQL.update.await('UPDATE pizza_delivery SET deliveries = ?, earnings = ? WHERE identifier = ?', {
        PlayerData[identifier].deliveries,
        PlayerData[identifier].earnings,
        identifier
    })
end

-- Callback: Get player info
lib.callback.register('pizza:getPlayerInfo', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    local playerData = GetPlayerData(xPlayer.identifier)
    
    return {
        name = xPlayer.getName(),
        job = xPlayer.job.name,
        jobGrade = xPlayer.job.grade,
        money = xPlayer.getAccount('bank').money,
        deliveries = playerData.deliveries,
        earnings = playerData.earnings
    }
end)

-- Callback: Start delivery
lib.callback.register('pizza:startDelivery', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Verify job
    if xPlayer.job.name ~= Config.JobName then
        return false
    end

    -- Calculate random payment
    local payment = math.random(Config.Delivery.minPay, Config.Delivery.maxPay)

    -- Give pizza item
    if ox_inventory then
        local canCarry = exports.ox_inventory:CanCarryItem(source, Config.Delivery.item, 1)
        if not canCarry then return false end

        exports.ox_inventory:AddItem(source, Config.Delivery.item, 1)
    else
        xPlayer.addInventoryItem(Config.Delivery.item, 1)
    end

    -- Send delivery config to client (client will generate random coords)
    TriggerClientEvent('pizza:startDelivery', source, {
        cityCenter = Config.Delivery.cityCenter,
        minDistance = Config.Delivery.minDistance,
        maxDistance = Config.Delivery.maxDistance
    }, payment)

    return true
end)

-- Callback: Complete delivery
lib.callback.register('pizza:completeDelivery', function(source, payment)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Verify job
    if xPlayer.job.name ~= Config.JobName then
        return false
    end

    -- Verify player has pizza
    local hasPizza = false
    if ox_inventory then
        local searchResult = exports.ox_inventory:Search(source, 'count', Config.Delivery.item)
        local count = type(searchResult) == 'number' and searchResult or (searchResult and #searchResult or 0)
        hasPizza = count and count > 0
    else
        local pizzaItem = xPlayer.getInventoryItem(Config.Delivery.item)
        hasPizza = pizzaItem and pizzaItem.count > 0
    end

    if not hasPizza then return false end

    -- Remove pizza
    if ox_inventory then
        exports.ox_inventory:RemoveItem(source, Config.Delivery.item, 1)
    else
        xPlayer.removeInventoryItem(Config.Delivery.item, 1)
    end

    -- Calculate payment if not provided
    if not payment then
        payment = math.random(Config.Delivery.minPay, Config.Delivery.maxPay)
    end

    -- Add money immediately
    xPlayer.addAccountMoney('bank', payment)

    -- Update stats
    local playerData = GetPlayerData(xPlayer.identifier)
    playerData.deliveries = playerData.deliveries + 1
    playerData.earnings = playerData.earnings + payment
    UpdatePlayerData(xPlayer.identifier)

    return {
        success = true,
        payment = payment,
        totalDeliveries = playerData.deliveries,
        totalEarnings = playerData.earnings
    }
end)

-- Callback: Get employees
lib.callback.register('pizza:getEmployees', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    -- Verify boss permission
    if xPlayer.job.name ~= Config.JobName or xPlayer.job.grade < Config.BossGrade then
        return {}
    end

    local employees = {}
    local xPlayers = ESX.GetPlayers()

    for _, playerId in ipairs(xPlayers) do
        local employee = ESX.GetPlayerFromId(playerId)
        if employee and employee.job.name == Config.JobName then
            table.insert(employees, {
                name = employee.getName(),
                grade = employee.job.grade,
                identifier = employee.identifier
            })
        end
    end

    return employees
end)

-- Event: Player disconnecting - clean up cache
AddEventHandler('playerDropped', function(reason)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        UpdatePlayerData(xPlayer.identifier)
        PlayerData[xPlayer.identifier] = nil
    end
end)

-- Event: Resource stopping - save all cached data
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for identifier, data in pairs(PlayerData) do
        UpdatePlayerData(identifier)
    end
    
    -- Save society balance
    if Config.Society.enabled then
        MySQL.update.await('UPDATE pizza_society SET balance = ? ORDER BY id DESC LIMIT 1', {SocietyData.balance})
    end
end)

-- ==================== SOCIETY SYSTEM ====================

-- Helper function to log society transactions
local function LogTransaction(identifier, action, amount)
    MySQL.insert.await('INSERT INTO pizza_society_logs (identifier, action, amount) VALUES (?, ?, ?)', {
        identifier,
        action,
        amount
    })
    
    -- Update local transactions cache
    table.insert(SocietyData.transactions, 1, {
        identifier = identifier,
        action = action,
        amount = amount,
        date = os.date('%Y-%m-%d %H:%M:%S')
    })
    
    -- Keep only last 20 transactions
    if #SocietyData.transactions > 20 then
        local newTransactions = {}
        for i = 1, 20 do
            table.insert(newTransactions, SocietyData.transactions[i])
        end
        SocietyData.transactions = newTransactions
    end
end

-- Event: Deposit to society (called from client)
RegisterNetEvent('pizza:depositSociety', function(amount)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    -- Verify boss permission
    if xPlayer.job.name ~= Config.JobName or xPlayer.job.grade < Config.BossGrade then
        TriggerClientEvent('pizza:depositResult', source, {success = false, message = 'Accès refusé'})
        return
    end

    -- Validate amount
    if not amount or amount <= 0 then
        TriggerClientEvent('pizza:depositResult', source, {success = false, message = 'Montant invalide'})
        return
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        TriggerClientEvent('pizza:depositResult', source, {success = false, message = 'Montant invalide'})
        return
    end

    -- Check player has enough money
    local bankAccount = xPlayer.getAccount('bank')
    if bankAccount.money < amount then
        TriggerClientEvent('pizza:depositResult', source, {success = false, message = 'Fonds insuffisants'})
        return
    end

    -- Remove money from player
    xPlayer.removeAccountMoney('bank', amount)

    -- Add to society balance
    SocietyData.balance = SocietyData.balance + amount

    -- Log transaction
    LogTransaction(xPlayer.identifier, 'deposit', amount)

    TriggerClientEvent('pizza:depositResult', source, {success = true, newBalance = SocietyData.balance})
end)

-- Event: Withdraw from society (called from client)
RegisterNetEvent('pizza:withdrawSociety', function(amount)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    -- Verify boss permission
    if xPlayer.job.name ~= Config.JobName or xPlayer.job.grade < Config.BossGrade then
        TriggerClientEvent('pizza:withdrawResult', source, {success = false, message = 'Accès refusé'})
        return
    end

    -- Validate amount
    if not amount or amount <= 0 then
        TriggerClientEvent('pizza:withdrawResult', source, {success = false, message = 'Montant invalide'})
        return
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        TriggerClientEvent('pizza:withdrawResult', source, {success = false, message = 'Montant invalide'})
        return
    end

    -- Check society has enough money
    if SocietyData.balance < amount then
        TriggerClientEvent('pizza:withdrawResult', source, {success = false, message = 'Fonds insuffisants'})
        return
    end

    -- Check max withdraw limit
    if amount > Config.Society.maxWithdraw then
        TriggerClientEvent('pizza:withdrawResult', source, {success = false, message = 'Montant maximum dépassé'})
        return
    end

    -- Remove from society balance
    SocietyData.balance = SocietyData.balance - amount

    -- Add money to player
    xPlayer.addAccountMoney('bank', amount)

    -- Log transaction
    LogTransaction(xPlayer.identifier, 'withdraw', amount)

    TriggerClientEvent('pizza:withdrawResult', source, {success = true, newBalance = SocietyData.balance})
end)

-- Callback: Promote employee
lib.callback.register('pizza:promoteEmployee', function(source, targetIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {success = false} end

    if not targetIdentifier then return {success = false} end

    -- Verify boss permission
    if xPlayer.job.name ~= Config.JobName or xPlayer.job.grade < Config.BossGrade then
        return {success = false, message = 'Accès refusé'}
    end

    -- Find target player
    local targetPlayer = nil
    local xPlayers = ESX.GetPlayers()
    
    for _, playerId in ipairs(xPlayers) do
        local player = ESX.GetPlayerFromId(playerId)
        if player and player.identifier == targetIdentifier then
            targetPlayer = player
            break
        end
    end

    if not targetPlayer then
        return {success = false, message = 'Joueur non trouvé'}
    end

    -- Verify target is in the same job
    if targetPlayer.job.name ~= Config.JobName then
        return {success = false, message = 'Le joueur n\'est pas dans cette entreprise'}
    end

    -- Promote (increase grade)
    local newGrade = math.min(targetPlayer.job.grade + 1, Config.BossGrade)
    if newGrade == targetPlayer.job.grade then
        return {success = false, message = 'Grade maximum atteint'}
    end

    targetPlayer.setJob(Config.JobName, newGrade)

    return {success = true, newGrade = newGrade}
end)

-- Callback: Fire employee
lib.callback.register('pizza:fireEmployee', function(source, targetIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {success = false} end

    if not targetIdentifier then return {success = false} end

    -- Verify boss permission
    if xPlayer.job.name ~= Config.JobName or xPlayer.job.grade < Config.BossGrade then
        return {success = false, message = 'Accès refusé'}
    end

    -- Find target player
    local targetPlayer = nil
    local xPlayers = ESX.GetPlayers()
    
    for _, playerId in ipairs(xPlayers) do
        local player = ESX.GetPlayerFromId(playerId)
        if player and player.identifier == targetIdentifier then
            targetPlayer = player
            break
        end
    end

    if not targetPlayer then
        return {success = false, message = 'Joueur non trouvé'}
    end

    -- Verify target is in the same job
    if targetPlayer.job.name ~= Config.JobName then
        return {success = false, message = 'Le joueur n\'est pas dans cette entreprise'}
    end

    -- Fire (set to unemployed)
    targetPlayer.setJob('unemployed', 0)

    return {success = true}
end)

-- Event: Get orders (called from client)
RegisterNetEvent('pizza:getOrders', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    -- Verify job
    if xPlayer.job.name ~= Config.JobName then
        TriggerClientEvent('pizza:sendOrders', source, {})
        return
    end

    -- Return empty orders for now (can be implemented with database later)
    TriggerClientEvent('pizza:sendOrders', source, {})
end)

-- Event: Get society data (called from client)
RegisterNetEvent('pizza:getSocietyData', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    -- Verify boss permission
    if xPlayer.job.name ~= Config.JobName or xPlayer.job.grade < Config.BossGrade then
        TriggerClientEvent('pizza:sendSocietyData', source, {})
        return
    end

    TriggerClientEvent('pizza:sendSocietyData', source, {
        balance = SocietyData.balance,
        transactions = SocietyData.transactions
    })
end)

-- Event: Accept order
RegisterNetEvent('pizza:acceptOrder', function(orderId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    if not orderId then return end

    -- Verify job
    if xPlayer.job.name ~= Config.JobName then return end

    -- For now, just return success (can be implemented with database later)
end)

-- Event: Set order GPS
RegisterNetEvent('pizza:setOrderGps', function(orderId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    if not orderId then return end

    -- Verify job
    if xPlayer.job.name ~= Config.JobName then return end

    -- For now, just return (GPS logic can be implemented later)
end)


-- =========================
-- VEHICLE MANAGEMENT
-- =========================

-- Callback: Spawn job vehicle (secure)
lib.callback.register('pizza:spawnJobVehicle', function(source, model)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Verify job
    if xPlayer.job.name ~= Config.JobName then
        return false
    end

    -- Verify vehicle exists in config and player has grade
    local validVehicle = false
    for _, v in ipairs(Config.Vehicles) do
        if v.model == model and xPlayer.job.grade >= (v.grade or 0) then
            validVehicle = true
            break
        end
    end

    if not validVehicle then
        return false
    end

    -- Find available spawn point
    local spawnPoint = nil
    for _, point in ipairs(Config.Garage.spawnPoints) do
        -- Check if spawn point is clear
        local vehicles = GetVehiclesInArea(point.coords, 3.0)
        if #vehicles == 0 then
            spawnPoint = point
            break
        end
    end

    if not spawnPoint then
        return false
    end

    -- Spawn vehicle on client side with server verification
    TriggerClientEvent('pizza:spawnVehicle', source, model, spawnPoint.coords, spawnPoint.heading)
    return true
end)

-- Event: Return vehicle
RegisterNetEvent('pizza:returnVehicle', function(netId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    -- Verify job
    if xPlayer.job.name ~= Config.JobName then
        return
    end

    -- Verify vehicle exists
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 then
        return
    end

    -- Delete vehicle
    DeleteEntity(vehicle)

    -- Notify client
    TriggerClientEvent('pizza:vehicleDeleted', source)
end)

-- Callback: Recover from fourrière
lib.callback.register('pizza:recoverFromFourriere', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Verify job
    if xPlayer.job.name ~= Config.JobName then
        return false
    end

    -- Check player has enough money
    local bankMoney = xPlayer.getAccount('bank').money
    if bankMoney < Config.Garage.fourrierePrice then
        return false
    end

    -- Remove money
    xPlayer.removeAccountMoney('bank', Config.Garage.fourrierePrice)

    -- Find available spawn point
    local spawnPoint = nil
    for _, point in ipairs(Config.Garage.spawnPoints) do
        local vehicles = GetVehiclesInArea(point.coords, 3.0)
        if #vehicles == 0 then
            spawnPoint = point
            break
        end
    end

    if not spawnPoint then
        -- Refund if no spawn point available
        xPlayer.addAccountMoney('bank', Config.Garage.fourrierePrice)
        return false
    end

    -- Spawn player's last vehicle (simplified - spawns first available vehicle)
    local vehicleModel = Config.Vehicles[1].model
    TriggerClientEvent('pizza:spawnVehicle', source, vehicleModel, spawnPoint.coords, spawnPoint.heading)

    return true
end)

-- Helper: Get vehicles in area
function GetVehiclesInArea(coords, radius)
    local vehicles = {}
    local areaVehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(areaVehicles) do
        local vehicleCoords = GetEntityCoords(vehicle)
        if #(vehicleCoords - coords) <= radius then
            table.insert(vehicles, vehicle)
        end
    end

    return vehicles
end


-- =========================
-- KITCHEN / FRIDGE SYSTEM
-- =========================

-- Callback: Buy ingredient
lib.callback.register('pizza:buyIngredient', function(source, item, price)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Verify job
    if xPlayer.job.name ~= Config.JobName then
        return false
    end

    -- Verify ingredient exists in config
    local validIngredient = false
    for _, ingredient in ipairs(Config.Kitchen.fridge.ingredients) do
        if ingredient.item == item and ingredient.price == price then
            validIngredient = true
            break
        end
    end

    if not validIngredient then
        return false
    end

    -- Check player money
    local bankMoney = xPlayer.getAccount('bank').money
    if bankMoney < price then
        return false
    end

    -- Remove money
    xPlayer.removeAccountMoney('bank', price)

    -- Add ingredient to fridge stash
    if ox_inventory then
        exports.ox_inventory:AddItem('stash', 'pizza_fridge', item, 1)
    else
        -- Fallback: add to player inventory if ox_inventory not available
        xPlayer.addInventoryItem(item, 1)
    end

    return true
end)

-- Callback: Prepare pizza
lib.callback.register('pizza:preparePizza', function(source, recipeId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Verify job
    if xPlayer.job.name ~= Config.JobName then
        return false
    end

    -- Find recipe
    local recipe = nil
    for _, r in ipairs(Config.Kitchen.preparation.recipes) do
        if r.id == recipeId then
            recipe = r
            break
        end
    end

    if not recipe then
        return false
    end

    -- Verify player grade
    if xPlayer.job.grade < recipe.grade then
        return false
    end

    -- Check if fridge has all required ingredients
    for _, item in ipairs(recipe.items) do
        local hasItem = false
        if ox_inventory then
            local searchResult = exports.ox_inventory:Search('stash', 'pizza_fridge', item.item)
            local count = type(searchResult) == 'number' and searchResult or (searchResult and #searchResult or 0)
            hasItem = count and count >= item.count
        else
            -- Fallback: check player inventory
            local inventoryItem = xPlayer.getInventoryItem(item.item)
            hasItem = inventoryItem and inventoryItem.count >= item.count
        end

        if not hasItem then
            return false
        end
    end

    -- Remove ingredients from fridge
    for _, item in ipairs(recipe.items) do
        if ox_inventory then
            exports.ox_inventory:RemoveItem('stash', 'pizza_fridge', item.item, item.count)
        else
            -- Fallback: remove from player inventory
            xPlayer.removeInventoryItem(item.item, item.count)
        end
    end

    -- Give result to player
    if ox_inventory then
        local canCarry = exports.ox_inventory:CanCarryItem(source, recipe.result.item, recipe.result.count)
        if not canCarry then
            -- Refund ingredients if can't carry
            for _, item in ipairs(recipe.items) do
                if ox_inventory then
                    exports.ox_inventory:AddItem('stash', 'pizza_fridge', item.item, item.count)
                else
                    xPlayer.addInventoryItem(item.item, item.count)
                end
            end
            return false
        end

        exports.ox_inventory:AddItem(source, recipe.result.item, recipe.result.count)
    else
        xPlayer.addInventoryItem(recipe.result.item, recipe.result.count)
    end

    return true
end)

--- =========================
--- KITCHEN / FRIDGE SYSTEM
--- =========================
CreateThread(function()

    -- 🧊 FRIGO INGREDIENTS
    exports.ox_inventory:RegisterStash(
        'pizza_fridge',
        'Frigo Ingrédients Pizza',
        50,
        100000,
        false,
        {
            ['pizza'] = 0
        }
    )


    -- 📦 COFFRE SOCIETE
    exports.ox_inventory:RegisterStash(
        'pizza_stock',
        'Stock Société Pizza',
        100,
        250000,
        false,
        {
            ['pizza'] = 0
        }
    )


    -- 👔 COFFRE BOSS
    exports.ox_inventory:RegisterStash(
        'pizza_boss',
        'Coffre Patron Pizza',
        50,
        100000,
        false,
        {
            ['pizza'] = 3
        }
    )

end)
