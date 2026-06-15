Config = {}

-- ==================== CONFIGURATION GÉNÉRALE ====================

Config.Debug = false

-- Keybind configuration
Config.EnableKeybind = true
Config.KeybindKey = 'F6'

-- Job configuration
Config.JobName = 'pizza'
Config.JobLabel = 'Pizza Delivery'
Config.BossGrade = 3

-- Service configuration
Config.Service = {
    enabled = true,
    -- Point pour mettre en service (optionnel - sinon utiliser commande)
    coords = vector3(-1346.729614, -1065.375854, 7.375122), -- À configurer selon votre position
    label = "Point de Service",
    interactionType = 'ox_target', -- 'ox_target' ou 'marker'
    marker = {
        type = 1,
        size = vector3(1.5, 1.5, 1.0),
        color = {r = 0, g = 255, b = 0},
        alpha = 100
    },
    -- Commande pour mettre en service (alternative au point)
    command = 'pizza_service',
    -- Tenue de service (optionnel - si nil, utilise le vestiaire)
    serviceOutfit = nil -- {tshirt = 15, torso = 15, ...}
}

-- ==================== ZONES ET BLIPS ====================

-- Blip configuration (visible pour tous les joueurs)
Config.Blip = {
    enabled = true,
    coords = vector3(-1339.516479, -1082.413208, 6.920166), -- À configurer selon votre position
    sprite = 78, -- Sprite pizza
    color = 5, -- Couleur blip
    scale = 0.7, -- Taille du blip
    label = 'Pizzeria'
}

-- ==================== VESTIAIRE (INTERACTION MONDE) ====================

Config.Vestiaire = {
    enabled = true,
    coords = vector3(-1350.843994, -1069.358276, 7.375122), -- À configurer selon votre position
    label = "Vestiaire Pizza",
    interactionType = 'ox_target', -- 'ox_target' ou 'marker'
    marker = {
        type = 1,
        size = vector3(1.5, 1.5, 1.0),
        color = {r = 255, g = 107, b = 107},
        alpha = 100
    },
    tenue = {
        male = {
            tshirt = 15,
            torso = 15,
            decals = 0,
            arms = 15,
            pants = 16,
            shoes = 15,
            mask = 0,
            vest = 0,
            bag = 0,
            hat = 0,
            glasses = 0,
            ears = 0
        },
        female = {
            tshirt = 15,
            torso = 15,
            decals = 0,
            arms = 15,
            pants = 16,
            shoes = 15,
            mask = 0,
            vest = 0,
            bag = 0,
            hat = 0,
            glasses = 0,
            ears = 0
        }
    },
    animation = {
        dict = 'clothingshirt',
        anim = 'try_shirt_positive_a',
        flags = 49
    }
}

-- ==================== GARAGE / FOURRIÈRE (INTERACTION MONDE) ====================

Config.Garage = {
    enabled = true,
    coords = vector3(-1342.760498, -1091.063721, 6.920166), -- À configurer selon votre position
    label = "Garage Pizza",
    interactionType = 'ox_target', -- 'ox_target' ou 'marker'
    marker = {
        type = 36,
        size = vector3(1.0, 1.0, 1.0),
        color = {r = 0, g = 255, b = 136},
        alpha = 100
    },
    spawnPoints = {
        { coords = vector3(-1332.276978, -1095.270264, 6.903320), heading = 0.0 },
        { coords = vector3(-1332.276978, -1095.270264, 6.903320), heading = 90.0 },
        { coords = vector3(-1332.276978, -1095.270264, 6.903320), heading = 180.0 }
    },
    returnZone = vector3(-1328.650513, -1090.246094, 6.970703), -- Zone pour ranger le véhicule
    returnRadius = 5.0, -- Rayon pour ranger
    fourrierePrice = 500, -- Prix pour récupérer véhicule en fourrière
    cooldown = 3000 -- Cooldown anti-spawn (ms)
}

-- Véhicules autorisés
Config.Vehicles = {
    {
        model = 'faggio2',
        label = 'Scooter Pizza',
        grade = 0 -- Grade minimum requis
    },
    {
        model = 'tribike2',
        label = 'Vélo Pizza',
        grade = 0
    }
}

-- ==================== LIVRAISON ====================

Config.Delivery = {
    enabled = true,
    minPay = 50,
    maxPay = 150,
    item = 'pizza',
    -- Zone de livraison random (coords du centre de la ville)
    -- Le système générera des coords random autour de ce point
    cityCenter = vector3(-1332.276978, -1095.270264, 6.903320), -- À configurer selon votre ville
    maxDistance = 1500, -- Distance max du centre pour générer livraison
    minDistance = 300 -- Distance min du centre pour éviter le centre
}

-- ==================== CUISINE / PRÉPARATION ====================

Config.Kitchen = {
    -- Point de préparation pizza
    preparation = {
        enabled = true,
        coords = vector3(-1338.883545, -1061.248291, 7.375122), -- À configurer
        label = "Préparation Pizza",
        interactionType = 'ox_target',
        marker = {
            type = 1,
            size = vector3(1.5, 1.5, 1.0),
            color = {r = 255, g = 107, b = 107},
            alpha = 100
        },
        animation = {
            dict = 'anim@amb@clubhouse@tutorial@bouncer_tutorial@bouncer_tutorial_base@',
            anim = 'base',
            flags = 49
        },
        recipes = {
            {
                id = 'pizza_margherita',
                label = 'Pizza Margherita',
                items = {
                    {item = 'pate_pizza', count = 1},
                    {item = 'sauce_tomate', count = 1},
                    {item = 'fromage', count = 1},
                    {item = 'basilic', count = 1}
                },
                result = {item = 'pizza_margherita', count = 1},
                time = 5000, -- Temps de préparation en ms
                grade = 0
            },
            {
                id = 'pizza_pepperoni',
                label = 'Pizza Pepperoni',
                items = {
                    {item = 'pate_pizza', count = 1},
                    {item = 'sauce_tomate', count = 1},
                    {item = 'fromage', count = 1},
                    {item = 'pepperoni', count = 1}
                },
                result = {item = 'pizza_pepperoni', count = 1},
                time = 6000,
                grade = 1
            },
            {
                id = 'pizza_vegetarienne',
                label = 'Pizza Végétarienne',
                items = {
                    {item = 'pate_pizza', count = 1},
                    {item = 'sauce_tomate', count = 1},
                    {item = 'fromage', count = 1},
                    {item = 'legumes', count = 1}
                },
                result = {item = 'pizza_vegetarienne', count = 1},
                time = 5500,
                grade = 0
            }
        }
    },

    -- Point frigo (stockage + achat ingrédients)
    fridge = {
        enabled = true,
        coords = vector3(-1341.085693, -1060.681274, 7.375122), -- À configurer
        label = "Frigo Pizza",
        interactionType = 'ox_target',
        marker = {
            type = 1,
            size = vector3(1.5, 1.5, 1.0),
            color = {r = 100, g = 200, b = 255},
            alpha = 100
        },
        -- Ingrédients disponibles à l'achat
        ingredients = {
            {item = 'pate_pizza', label = 'Pâte à pizza', price = 5},
            {item = 'sauce_tomate', label = 'Sauce tomate', price = 3},
            {item = 'fromage', label = 'Fromage', price = 8},
            {item = 'pepperoni', label = 'Pepperoni', price = 10},
            {item = 'basilic', label = 'Basilic', price = 2},
            {item = 'legumes', label = 'Légumes', price = 6}
        }
    },

    -- Point visualisation recettes
    recipes = {
        enabled = true,
        coords = vector3(-1337.986816, -1058.637329, 7.425659), -- À configurer
        label = "Livre de Recettes",
        interactionType = 'ox_target',
        marker = {
            type = 1,
            size = vector3(1.0, 1.0, 1.0),
            color = {r = 255, g = 200, b = 100},
            alpha = 100
        }
    }
}

-- ==================== INVENTAIRES ====================

Config.Stashes = {


    fridge = {
        coords = vector3(-1339.687866, -1059.586792, 7.375122),
        label = "Frigo Ingrédients"
    },


    stock = {
        coords = vector3(-1347.270386, -1063.569214, 7.375122),
        label = "Stock Société"
    },


    boss = {
        coords = vector3(-1345.859375, -1052.742798, 3.853516),
        label = "Coffre Patron"
    }

}
-- ==================== TABLETTE NUI ====================

Config.Tablet = {
    enabled = true,
    animation = {
        dict = 'anim@heists@ornate_bank@grab_cash',
        anim = 'grab',
        flags = 49,
    },
    prop = {
        model = 'prop_cs_tablet',
        bone = 28422,
        offset = vector3(0.12, 0.03, -0.02),
        rotation = vector3(10.0, -10.0, 0.0)
    },
    keybind = 'F6'
}

-- ==================== SOCIÉTÉ ====================

Config.Society = {
    enabled = true,
    accountName = 'society_pizza',
    initialBalance = 50000,
    maxWithdraw = 1000000000000,
    depositFee = 0,
    withdrawFee = 0
}

-- ==================== COMMANDES ====================

Config.Orders = {
    enabled = true,
    maxActiveOrders = 3,
    orderTimeout = 600
}

-- ==================== STATISTIQUES ====================

Config.Stats = {
    enabled = true,
    xpPerDelivery = 10,
    levels = {
        { level = 1, xp = 0, bonus = 0 },
        { level = 2, xp = 100, bonus = 5 },
        { level = 3, xp = 300, bonus = 10 },
        { level = 4, xp = 600, bonus = 15 },
        { level = 5, xp = 1000, bonus = 20 }
    }
}
