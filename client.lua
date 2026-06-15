-- Client-side optimized for ESX Legacy, ox_lib, ox_inventory

local isOpen = false
local isOnDuty = false
local playerData = nil
local civilianOutfit = nil


-- =========================
-- SAFE ESX GETTER
-- =========================

local function GetSafePlayerData()

    local data = ESX.GetPlayerData()

    if not data or not data.job or not data.job.name then return nil end

    return data

end

-- =========================
-- BLIP PIZZERIA
-- =========================

CreateThread(function()

    if Config.Blip.enabled then

        local blip = AddBlipForCoord(Config.Blip.coords.x, Config.Blip.coords.y, Config.Blip.coords.z)

        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Blip.scale)
        SetBlipColour(blip, Config.Blip.color)
        SetBlipAsShortRange(blip, false)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blip.label)
        EndTextCommandSetBlipName(blip)

    end

end)


-- =========================
-- OPEN MENU
-- =========================

local function OpenMenu()

    local xPlayer = GetSafePlayerData()

    if not xPlayer then
        lib.notify({
            title = 'Tablette',
            description = 'Impossible de charger vos données',
            type = 'error'
        })
        return
    end

    if not xPlayer.job or not xPlayer.job.name or xPlayer.job.name ~= Config.JobName then
        lib.notify({
            title = 'Tablette',
            description = 'Vous ne travaillez pas ici',
            type = 'error'
        })
        return
    end

    if isOpen then return end

    isOpen = true

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = "open",
        state = true
    })

end


-- =========================
-- CLOSE MENU
-- =========================

local function CloseMenu()

    if not isOpen then return end

    isOpen = false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = "close",
        state = false
    })

end


-- =========================
-- COMMAND + KEYBIND
-- =========================

RegisterCommand("pizza", function()

    if isOpen then
        CloseMenu()
    else
        OpenMenu()
    end

end)


if Config.EnableKeybind then

    lib.addKeybind({

        name = 'pizza_menu',
        description = 'Ouvrir menu Pizza',
        defaultKey = Config.KeybindKey or 'F6',

        onPressed = function()

            if isOpen then
                CloseMenu()
            else
                OpenMenu()
            end

        end

    })

end


-- =========================
-- NUI CALLBACKS
-- =========================

RegisterNUICallback("getPlayerInfo", function(_, cb)

    local info = lib.callback.await('pizza:getPlayerInfo', false)

    cb(info or {})

end)


RegisterNUICallback("startDelivery", function(_, cb)

    local success = lib.callback.await('pizza:startDelivery', false)

    cb({success = success})

end)

RegisterNUICallback("close", function(_, cb)

    CloseMenu()

    cb({})

end)

RegisterNUICallback("completeDelivery", function(_, cb)

    local result = lib.callback.await('pizza:completeDelivery', false)

    cb(result or {success = false})

end)


RegisterNUICallback("getEmployees", function(_, cb)

    local employees = lib.callback.await('pizza:getEmployees', false)

    cb(employees or {})

end)


RegisterNUICallback("setGps", function(_, cb)

    lib.notify({
        title = 'GPS',
        description = 'GPS activé',
        type = 'info'
    })

    cb({})

end)


-- =========================
-- JOB CHANGE
-- =========================

RegisterNetEvent('esx:setJob', function(job)

    local xPlayer = GetSafePlayerData()

    if isOpen and job.name ~= Config.JobName then
        CloseMenu()
    end

end)


-- =========================
-- CLEANUP
-- =========================

AddEventHandler('onResourceStop', function(resourceName)

    if GetCurrentResourceName() ~= resourceName then return end

    if isOpen then
        SetNuiFocus(false, false)
    end

end)


-- =========================
-- SERVICE SYSTEM
-- =========================

local onDuty = false

local function ToggleService()

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    if xPlayer.job.name ~= Config.JobName then
        lib.notify({
            title = 'Service',
            description = 'Vous ne travaillez pas ici',
            type = 'error'
        })
        return
    end

    onDuty = not onDuty

    if onDuty then
        lib.notify({
            title = 'Service',
            description = 'Vous êtes maintenant en service',
            type = 'success'
        })

        -- Apply service outfit if configured
        if Config.Service.serviceOutfit then
            SetWorkOutfit()
        end
    else
        lib.notify({
            title = 'Service',
            description = 'Vous avez quitté le service',
            type = 'info'
        })

        -- Remove service outfit if configured
        if Config.Service.serviceOutfit then
            RestoreCivilianOutfit()
        end
    end

end

-- Command to toggle service
RegisterCommand(Config.Service.command, function()
    ToggleService()
end)


-- =========================
-- OX TARGET ZONE - SERVICE
-- =========================

CreateThread(function()

    if not Config.Service.enabled then return end

    if GetResourceState('ox_target') ~= 'started' then return end

    -- Service point zone
    exports.ox_target:addBoxZone({

        coords = Config.Service.coords,
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0,
        debug = Config.Debug,

        options = {

            {
                name = 'pizza_service',
                icon = 'fa-solid fa-user-clock',
                label = Config.Service.label,
                distance = 2.0,

                canInteract = function()

                    local xPlayer = GetSafePlayerData()

                    if not xPlayer then return false end

                    return xPlayer.job.name == Config.JobName

                end,

                onSelect = function()
                    ToggleService()
                end

            }

        }

    })

end)


-- =========================
-- VESTIAIRE SYSTEM
-- =========================

local function WaitForAppearance()

    if GetResourceState('illenium-appearance') ~= 'started' then

        while GetResourceState('illenium-appearance') ~= 'started' do
            Wait(500)
        end

    end

end


local function SaveCivilianOutfit()

    WaitForAppearance()

    local ped = PlayerPedId()

    if GetResourceState('illenium-appearance') == 'started' then
        civilianOutfit = exports['illenium-appearance']:getPedAppearance(ped)
    end

end


local function RestoreCivilianOutfit()

    if not civilianOutfit then return end

    WaitForAppearance()

    local ped = PlayerPedId()

    if GetResourceState('illenium-appearance') == 'started' then
        exports['illenium-appearance']:setPedAppearance(ped, civilianOutfit)

        lib.notify({
            title = 'Vestiaire',
            description = 'Tenue civile restaurée',
            type = 'success'
        })
    else
        lib.notify({
            title = 'Vestiaire',
            description = 'Impossible de changer la tenue',
            type = 'error'
        })
    end

end


local function SetWorkOutfit()

    WaitForAppearance()

    local ped = PlayerPedId()

    if not civilianOutfit then
        SaveCivilianOutfit()
    end

    local appearance = nil
    if GetResourceState('illenium-appearance') == 'started' then
        appearance = exports['illenium-appearance']:getPedAppearance(ped)
    end

    if not appearance then
        lib.notify({
            title = 'Vestiaire',
            description = 'Impossible de changer la tenue',
            type = 'error'
        })
        return
    end

    local outfit = Config.Vestiaire.tenue.male

    if appearance.model == `mp_f_freemode_01` then
        outfit = Config.Vestiaire.tenue.female
    end

    exports['illenium-appearance']:setPedAppearance(ped, outfit)

    lib.notify({
        title = 'Vestiaire',
        description = 'Tenue de travail équipée',
        type = 'success'
    })

end


-- =========================
-- VESTIAIRE MENU
-- =========================

local function OpenVestiaireMenu()

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    if xPlayer.job.name ~= Config.JobName then return end

    lib.showContext('pizza_vestiaire')

end


CreateThread(function()

    lib.registerContext({

        id = 'pizza_vestiaire',
        title = '👕 Vestiaire Pizza',

        options = {

            {
                title = '👕 Tenue civile',
                icon = 'user',
                onSelect = function()
                    RestoreCivilianOutfit()
                end
            },

            {
                title = '👔 Tenue travail',
                icon = 'shirt',
                onSelect = function()
                    SetWorkOutfit()
                end
            },

            {
                title = '❌ Fermer',
                icon = 'xmark'
            }

        }

    })

end)


-- =========================
-- OX TARGET ZONE
-- =========================

CreateThread(function()

    if GetResourceState('ox_target') ~= 'started' then return end

    exports.ox_target:addBoxZone({

        coords = Config.Vestiaire.coords,
        size = vec3(1.5,1.5,2.0),
        rotation = 0,
        debug = Config.Debug,

        options = {

            {
                name = 'pizza_vestiaire',
                icon = 'fa-solid fa-shirt',
                label = Config.Vestiaire.label,
                distance = 2.0,

                canInteract = function()

                    local xPlayer = GetSafePlayerData()

                    if not xPlayer then return false end

                    return xPlayer.job.name == Config.JobName and onDuty

                end,

                onSelect = function()
                    OpenVestiaireMenu()
                end

            }

        }

    })

end)


-- =========================
-- INITIAL SAVE OUTFIT
-- =========================

CreateThread(function()

    Wait(5000)

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    if not civilianOutfit then
        SaveCivilianOutfit()
    end

end)


-- =========================
-- NUI CALLBACKS FOR TABLET
-- =========================

-- Get orders
RegisterNUICallback('getOrders', function(data, cb)

    TriggerServerEvent('pizza:getOrders')

    cb({})

end)

-- Get society data
RegisterNUICallback('getSocietyData', function(data, cb)

    TriggerServerEvent('pizza:getSocietyData')

    cb({})

end)

-- Accept order
RegisterNUICallback('acceptOrder', function(data, cb)

    TriggerServerEvent('pizza:acceptOrder', data.orderId)

    cb({})

end)

-- Set order GPS
RegisterNUICallback('setOrderGps', function(data, cb)

    TriggerServerEvent('pizza:setOrderGps', data.orderId)

    cb({})

end)

-- Deposit society
RegisterNUICallback('depositSociety', function(data, cb)

    TriggerServerEvent('pizza:depositSociety', data.amount)

    cb({})

end)

-- Withdraw society
RegisterNUICallback('withdrawSociety', function(data, cb)

    TriggerServerEvent('pizza:withdrawSociety', data.amount)

    cb({})

end)


-- =========================
-- CLIENT EVENTS FROM SERVER
-- =========================

-- Receive orders from server
RegisterNetEvent('pizza:sendOrders', function(orders)

    SendNUIMessage({

        action = 'updateOrders',
        orders = orders

    })

end)

-- Receive society data from server
RegisterNetEvent('pizza:sendSocietyData', function(society)

    SendNUIMessage({

        action = 'updateSociety',
        society = society

    })

end)

-- Receive deposit result from server
RegisterNetEvent('pizza:depositResult', function(result)

    SendNUIMessage({

        action = 'depositResult',
        result = result

    })

end)

-- Receive withdraw result from server
RegisterNetEvent('pizza:withdrawResult', function(result)

    SendNUIMessage({

        action = 'withdrawResult',
        result = result

    })

end)


-- =========================
-- GARAGE / FOURRIÈRE SYSTEM
-- =========================

local currentVehicle = nil
local lastSpawnTime = 0

local function SpawnJobVehicle(model)

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    -- Cooldown check
    local currentTime = GetGameTimer()
    if currentTime - lastSpawnTime < Config.Garage.cooldown then
        lib.notify({
            title = 'Garage',
            description = 'Veuillez attendre avant de sortir un autre véhicule',
            type = 'error'
        })
        return
    end

    -- Check if player already has a vehicle
    if currentVehicle then
        lib.notify({
            title = 'Garage',
            description = 'Vous avez déjà un véhicule de service',
            type = 'error'
        })
        return
    end

    -- Request server to spawn vehicle
    local success = lib.callback.await('pizza:spawnJobVehicle', false, model)

    if success then
        lastSpawnTime = currentTime
        lib.notify({
            title = 'Garage',
            description = 'Véhicule sorti avec succès',
            type = 'success'
        })
    else
        lib.notify({
            title = 'Garage',
            description = 'Impossible de sortir le véhicule',
            type = 'error'
        })
    end

end

local function ReturnVehicle()

    if not currentVehicle then
        lib.notify({
            title = 'Garage',
            description = 'Aucun véhicule à ranger',
            type = 'error'
        })
        return
    end

    -- Check if player is in the vehicle
    local ped = PlayerPedId()
    local currentVeh = GetVehiclePedIsIn(ped, false)

    -- Allow returning if player is in the vehicle OR near the vehicle
    if currentVeh ~= currentVehicle then
        local playerCoords = GetEntityCoords(ped)
        local vehicleCoords = GetEntityCoords(currentVehicle)
        local distance = #(playerCoords - vehicleCoords)

        if distance > 10.0 then
            lib.notify({
                title = 'Garage',
                description = 'Vous devez être dans ou près de votre véhicule',
                type = 'error'
            })
            return
        end
    end

    -- Request server to delete vehicle
    TriggerServerEvent('pizza:returnVehicle', VehToNet(currentVehicle))

    -- Delete vehicle locally
    DeleteEntity(currentVehicle)
    currentVehicle = nil

    lib.notify({
        title = 'Garage',
        description = 'Véhicule rangé avec succès',
        type = 'success'
    })

end

local function RecoverFromFourriere()

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    -- Request server to recover vehicle (server handles money check)
    local success = lib.callback.await('pizza:recoverFromFourriere', false)

    if success then
        lib.notify({
            title = 'Fourrière',
            description = 'Véhicule récupéré avec succès',
            type = 'success'
        })
    else
        lib.notify({
            title = 'Fourrière',
            description = 'Impossible de récupérer le véhicule',
            type = 'error'
        })
    end

end

local function OpenGarageMenu()

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    if xPlayer.job.name ~= Config.JobName then
        lib.notify({
            title = 'Garage',
            description = 'Vous ne travaillez pas ici',
            type = 'error'
        })
        return
    end

    -- Build vehicle options based on player grade
    local options = {}

    for _, vehicle in ipairs(Config.Vehicles) do
        if xPlayer.job.grade >= (vehicle.grade or 0) then
            table.insert(options, {
                title = vehicle.label,
                icon = 'car',
                onSelect = function()
                    SpawnJobVehicle(vehicle.model)
                end
            })
        end
    end

    -- Add return vehicle option if player has a vehicle
    if currentVehicle then
        table.insert(options, {
            title = 'Ranger mon véhicule',
            icon = 'arrow-left',
            onSelect = function()
                ReturnVehicle()
            end
        })
    end

    -- Add fourrière option
    table.insert(options, {
        title = 'Récupérer véhicule (Fourrière)',
        icon = 'truck-tow',
        onSelect = function()
            RecoverFromFourriere()
        end
    })

    lib.registerContext({
        id = 'pizza_garage',
        title = '🚗 Garage Pizza',
        options = options
    })

    lib.showContext('pizza_garage')

end

-- Event: Vehicle spawned by server
RegisterNetEvent('pizza:vehicleSpawned', function(netId)
    currentVehicle = NetToVeh(netId)
end)

-- Event: Vehicle deleted by server
RegisterNetEvent('pizza:vehicleDeleted', function()
    currentVehicle = nil
end)

-- Event: Spawn vehicle (from server)
RegisterNetEvent('pizza:spawnVehicle', function(model, coords, heading)
    local ped = PlayerPedId()

    -- Load vehicle model
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    -- Create vehicle
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)

    -- Set vehicle as mission entity so it doesn't despawn
    SetEntityAsMissionEntity(vehicle, true, true)

    -- Set plate
    local plate = 'PIZZA' .. math.random(100, 999)
    SetVehicleNumberPlateText(vehicle, plate)

    -- Notify server of spawned vehicle
    TriggerServerEvent('pizza:vehicleSpawned', VehToNet(vehicle))

    -- Set player into vehicle
    TaskWarpPedIntoVehicle(ped, vehicle, -1)

    -- Release model
    SetModelAsNoLongerNeeded(model)
end)


-- =========================
-- DELIVERY SYSTEM
-- =========================

local currentDelivery = nil
local deliveryBlip = nil

-- Event: Start delivery (from server)
RegisterNetEvent('pizza:startDelivery', function(deliveryConfig, payment)
    -- Generate random delivery location
    local angle = math.random() * 2 * math.pi
    local distance = math.random(deliveryConfig.minDistance, deliveryConfig.maxDistance)
    local offsetX = math.cos(angle) * distance
    local offsetY = math.sin(angle) * distance

    local deliveryCoords = vector3(
        deliveryConfig.cityCenter.x + offsetX,
        deliveryConfig.cityCenter.y + offsetY,
        deliveryConfig.cityCenter.z
    )

    -- Get ground height for the coords
    local success, groundZ = GetGroundZFor_3dCoord(deliveryCoords.x, deliveryCoords.y, deliveryCoords.z + 500.0, false)
    if success then
        deliveryCoords = vector3(deliveryCoords.x, deliveryCoords.y, groundZ)
    end

    currentDelivery = {
        location = {
            coords = deliveryCoords,
            label = "Livraison #" .. math.random(1000, 9999)
        },
        payment = payment
    }

    -- Create GPS blip
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
    end

    deliveryBlip = AddBlipForCoord(deliveryCoords.x, deliveryCoords.y, deliveryCoords.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipColour(deliveryBlip, 5)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip, 5)
    SetBlipScale(deliveryBlip, 0.8)

    lib.notify({
        title = 'Livraison',
        description = 'Livraison en cours: ' .. currentDelivery.location.label .. ' - Récompense: $' .. payment,
        type = 'info'
    })
end)

-- Function: Complete delivery
local function CompleteDelivery()
    if not currentDelivery then
        lib.notify({
            title = 'Livraison',
            description = 'Aucune livraison en cours',
            type = 'error'
        })
        return
    end

    -- Check if player is at delivery location
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local deliveryCoords = currentDelivery.location.coords
    local distance = #(playerCoords - deliveryCoords)

    if distance > 10.0 then
        lib.notify({
            title = 'Livraison',
            description = 'Vous devez être au point de livraison',
            type = 'error'
        })
        return
    end

    -- Complete delivery via server
    local result = lib.callback.await('pizza:completeDelivery', false, currentDelivery.payment)

    if result and result.success then
        -- Remove blip
        if deliveryBlip then
            RemoveBlip(deliveryBlip)
            deliveryBlip = nil
        end

        currentDelivery = nil

        lib.notify({
            title = 'Livraison',
            description = 'Livraison terminée! +$' .. result.payment,
            type = 'success'
        })
    else
        lib.notify({
            title = 'Livraison',
            description = 'Impossible de terminer la livraison',
            type = 'error'
        })
    end
end

-- Export complete delivery function
exports('CompleteDelivery', CompleteDelivery)

-- Add command to complete delivery
RegisterCommand('pizzacomplete', function()
    CompleteDelivery()
end)


-- =========================
-- KITCHEN / FRIDGE SYSTEM
-- =========================

local function BuyIngredient(item, price, label)

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    -- Request server to buy ingredient (server handles money check)
    local success = lib.callback.await('pizza:buyIngredient', false, item, price)

    if success then
        lib.notify({
            title = 'Frigo',
            description = label .. ' acheté pour $' .. price,
            type = 'success'
        })
    else
        lib.notify({
            title = 'Frigo',
            description = 'Impossible d\'acheter cet ingrédient',
            type = 'error'
        })
    end

end

local function OpenFridgeMenu()

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    if xPlayer.job.name ~= Config.JobName then
        lib.notify({
            title = 'Frigo',
            description = 'Vous ne travaillez pas ici',
            type = 'error'
        })
        return
    end

    if not onDuty then
        lib.notify({
            title = 'Frigo',
            description = 'Vous devez être en service',
            type = 'error'
        })
        return
    end

    -- Build ingredient options
    local options = {}

    for _, ingredient in ipairs(Config.Kitchen.fridge.ingredients) do
        table.insert(options, {
            title = ingredient.label .. ' ($' .. ingredient.price .. ')',
            icon = 'box',
            onSelect = function()
                BuyIngredient(ingredient.item, ingredient.price, ingredient.label)
            end
        })
    end

    lib.registerContext({
        id = 'pizza_fridge',
        title = '❄️ Frigo Pizza',
        options = options
    })

    lib.showContext('pizza_fridge')

end


-- =========================
-- KITCHEN / PREPARATION SYSTEM
-- =========================

local function PreparePizza(recipe)

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    -- Request server to prepare pizza (server checks fridge stash)
    local success = lib.callback.await('pizza:preparePizza', false, recipe.id)

    if success then
        -- Play animation
        local ped = PlayerPedId()
        RequestAnimDict(Config.Kitchen.preparation.animation.dict)
        while not HasAnimDictLoaded(Config.Kitchen.preparation.animation.dict) do
            Wait(10)
        end

        TaskPlayAnim(ped, Config.Kitchen.preparation.animation.dict, Config.Kitchen.preparation.animation.anim,
            Config.Kitchen.preparation.animation.flags, 1.0, 1.0, -1, 1,  false, false, false)

        -- Wait for preparation time
        Wait(recipe.time)

        -- Clear animation
        ClearPedTasks(ped)

        lib.notify({
            title = 'Préparation',
            description = recipe.label .. ' préparée avec succès!',
            type = 'success'
        })
    else
        lib.notify({
            title = 'Préparation',
            description = 'Impossible de préparer cette pizza (ingrédients manquants dans le frigo)',
            type = 'error'
        })
    end

end

local function OpenPreparationMenu()

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    if xPlayer.job.name ~= Config.JobName then
        lib.notify({
            title = 'Préparation',
            description = 'Vous ne travaillez pas ici',
            type = 'error'
        })
        return
    end

    if not onDuty then
        lib.notify({
            title = 'Préparation',
            description = 'Vous devez être en service',
            type = 'error'
        })
        return
    end

    -- Build recipe options based on player grade
    local options = {}

    for _, recipe in ipairs(Config.Kitchen.preparation.recipes) do
        if xPlayer.job.grade >= recipe.grade then
            table.insert(options, {
                title = recipe.label,
                icon = 'pizza-slice',
                description = 'Temps: ' .. (recipe.time / 1000) .. 's',
                onSelect = function()
                    PreparePizza(recipe)
                end
            })
        end
    end

    lib.registerContext({
        id = 'pizza_preparation',
        title = '👨‍🍳 Préparation Pizza',
        options = options
    })

    lib.showContext('pizza_preparation')

end


-- =========================
-- KITCHEN / RECIPES SYSTEM
-- =========================

local function OpenRecipesMenu()

    local xPlayer = GetSafePlayerData()

    if not xPlayer then return end

    if xPlayer.job.name ~= Config.JobName then
        lib.notify({
            title = 'Recettes',
            description = 'Vous ne travaillez pas ici',
            type = 'error'
        })
        return
    end

    if not onDuty then
        lib.notify({
            title = 'Recettes',
            description = 'Vous devez être en service',
            type = 'error'
        })
        return
    end

    -- Build recipe display options
    local options = {}

    for _, recipe in ipairs(Config.Kitchen.preparation.recipes) do
        local ingredientsText = ''
        for i, item in ipairs(recipe.items) do
            if i > 1 then ingredientsText = ingredientsText .. ', ' end
            ingredientsText = ingredientsText .. item.item .. ' x' .. item.count
        end

        table.insert(options, {
            title = recipe.label,
            icon = 'book',
            description = 'Ingrédients: ' .. ingredientsText .. ' | Temps: ' .. (recipe.time / 1000) .. 's | Grade: ' .. recipe.grade,
            readOnly = true
        })
    end

    lib.registerContext({
        id = 'pizza_recipes',
        title = '📖 Livre de Recettes',
        options = options
    })

    lib.showContext('pizza_recipes')

end


-- =========================
-- OX TARGET ZONES - KITCHEN
-- =========================

CreateThread(function()

    if not Config.Kitchen.fridge.enabled then return end

    if GetResourceState('ox_target') ~= 'started' then return end

    -- Fridge zone
    exports.ox_target:addBoxZone({

        coords = Config.Kitchen.fridge.coords,
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0,
        debug = Config.Debug,

        options = {

            {
                name = 'pizza_fridge',
                icon = 'fa-solid fa-snowflake',
                label = Config.Kitchen.fridge.label,
                distance = 2.0,

                canInteract = function()

                    local xPlayer = GetSafePlayerData()

                    if not xPlayer then return false end

                    return xPlayer.job.name == Config.JobName and onDuty

                end,

                onSelect = function()
                    OpenFridgeMenu()
                end

            }

        }

    })

end)

CreateThread(function()

    if not Config.Kitchen.preparation.enabled then return end

    if GetResourceState('ox_target') ~= 'started' then return end

    -- Preparation zone
    exports.ox_target:addBoxZone({

        coords = Config.Kitchen.preparation.coords,
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0,
        debug = Config.Debug,

        options = {

            {
                name = 'pizza_preparation',
                icon = 'fa-solid fa-pizza-slice',
                label = Config.Kitchen.preparation.label,
                distance = 2.0,

                canInteract = function()

                    local xPlayer = GetSafePlayerData()

                    if not xPlayer then return false end

                    return xPlayer.job.name == Config.JobName and onDuty

                end,

                onSelect = function()
                    OpenPreparationMenu()
                end

            }

        }

    })

end)

CreateThread(function()

    if not Config.Kitchen.recipes.enabled then return end

    if GetResourceState('ox_target') ~= 'started' then return end

    -- Recipes zone
    exports.ox_target:addBoxZone({

        coords = Config.Kitchen.recipes.coords,
        size = vec3(1.0, 1.0, 2.0),
        rotation = 0,
        debug = Config.Debug,

        options = {

            {
                name = 'pizza_recipes',
                icon = 'fa-solid fa-book',
                label = Config.Kitchen.recipes.label,
                distance = 2.0,

                canInteract = function()

                    local xPlayer = GetSafePlayerData()

                    if not xPlayer then return false end

                    return xPlayer.job.name == Config.JobName and onDuty

                end,

                onSelect = function()
                    OpenRecipesMenu()
                end

            }

        }

    })

end)


-- =========================
-- OX TARGET ZONE - GARAGE
-- =========================

CreateThread(function()

    if not Config.Garage.enabled then return end

    if GetResourceState('ox_target') ~= 'started' then return end

    exports.ox_target:addBoxZone({

        coords = Config.Garage.coords,
        size = vec3(2.0, 2.0, 2.0),
        rotation = 0,
        debug = Config.Debug,

        options = {

            {
                name = 'pizza_garage',
                icon = 'fa-solid fa-car',
                label = Config.Garage.label,
                distance = 3.0,

                canInteract = function()

                    local xPlayer = GetSafePlayerData()

                    if not xPlayer then return false end

                    return xPlayer.job.name == Config.JobName and onDuty

                end,

                onSelect = function()
                    OpenGarageMenu()
                end

            }

        }

    })

end)

--- ============================
--- Coffre OX
--- ============================
CreateThread(function()


    -- 🧊 FRIGO
    exports.ox_target:addBoxZone({

        coords = Config.Stashes.fridge.coords,

        size = vec3(1,1,2),

        options = {

            {
                label = Config.Stashes.fridge.label,
                icon = "fa-solid fa-snowflake",

                onSelect = function()

                    exports.ox_inventory:openInventory(
                        'stash',
                        'pizza_fridge'
                    )

                end
            }

        }

    })



    -- 📦 STOCK
    exports.ox_target:addBoxZone({

        coords = Config.Stashes.stock.coords,

        size = vec3(1,1,2),

        options = {

            {
                label = Config.Stashes.stock.label,
                icon = "fa-solid fa-box",

                onSelect = function()

                    exports.ox_inventory:openInventory(
                        'stash',
                        'pizza_stock'
                    )

                end
            }

        }

    })



    -- 👔 BOSS
    exports.ox_target:addBoxZone({

        coords = Config.Stashes.boss.coords,

        size = vec3(1,1,2),

        options = {

            {
                label = Config.Stashes.boss.label,
                icon = "fa-solid fa-user-tie",

                onSelect = function()

                    exports.ox_inventory:openInventory(
                        'stash',
                        'pizza_boss'
                    )

                end
            }

        }

    })


end)