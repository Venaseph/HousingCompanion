-- Housing Reputations addon data file
-- Each faction is keyed by factionID.
-- Fill in the actual itemIDs and requirements later.
HOUSING_REP_CONFIG = {

    -----------------------------------------------------
    -- Brawler's Guild (placeholder; unknown factionID)
    -----------------------------------------------------

    -- Add the real faction ID when the new season goes live:
    -- [0000] = {
    --     kind = "standard", -- might be friendship/renown
    --     expansion = "The War Within",
    --     rewards = {
    --         { itemID = 0, requiredStanding = "Honored" },
    --     },
    -- },

    -----------------------------------------------------
    -- Classic / Cataclysm
    -----------------------------------------------------

    [72] = { -- 
        label = "Stormwind",
        kind = "standard",
        expansion = "Classic",
        vendor = {
            npcID = 49877,
            name = "Captain Lancy Revshon",
            zone = "Stormwind City",
            subzone = "Trade District",
            uiMapID = 84,
            x = 67.6,
            y = 72.8
        },
        faction = "Alliance",
        rewards = {{
            itemID = 248795,
            itemName = "Elwynn Fencepost",
            requiredStanding = "Friendly"
        }, {
            itemID = 248794,
            itemName = "Elwynn Fence",
            requiredStanding = "Friendly"
        }, {
            itemID = 248939,
            itemName = "Stormwind Lamppost",
            requiredStanding = "Honored"
        }, {
            itemID = 248333,
            itemName = "Stormwind Large Wooden Table",
            requiredStanding = "Honored"
        }, {
            itemID = 248620,
            itemName = "Stormwind Trellis and Basin",
            requiredStanding = "Revered"
        }, {
            itemID = 248617,
            itemName = "Stormwind Keg Stand",
            requiredStanding = "Revered"
        }, {
            itemID = 248665,
            itemName = "Stormwind Peddler's Cart",
            requiredStanding = "Exalted"
        }, {
            itemID = 248619,
            itemName = "Stormwind Gazebo",
            requiredStanding = "Exalted"
        }}
    },

    [47] = { -- 
        label = "Ironforge",
        kind = "standard",
        expansion = "Classic",
        vendor = {
            npcID = 50309,
            name = "Captain Stonehelm",
            zone = "Ironforge",
            subzone = "The Great Forge",
            uiMapID = 87,
            x = 55.8,
            y = 47.8
        },
        faction = "Alliance",
        rewards = {{
            itemID = 246490,
            itemName = "Ironforge Fencepost",
            requiredStanding = "Friendly"
        }, {
            itemID = 246491,
            itemName = "Ironforge Fence",
            requiredStanding = "Friendly"
        }, {
            itemID = 252010,
            itemName = "Ornate Ironforge Bench",
            requiredStanding = "Honored"
        }, {
            itemID = 246426,
            itemName = "Ornate Ironforge Table",
            requiredStanding = "Honored"
        }, {
            itemID = 256333,
            itemName = "Ornate Dwarven Wardrobe",
            requiredStanding = "Revered"
        }}
    },

    [1134] = { -- 
        label = "Gilneas",
        kind = "standard",
        expansion = "Cataclysm",
        vendor = {
            npcID = 50307,
            name = "Lord Candren",
            zone = "Darnassus",
            subzone = "Temple Gardens",
            uiMapID = 89,
            x = 37.0,
            y = 47.8
        },
        faction = "Alliance",
        rewards = {{
            itemID = 245605,
            itemName = "Gilnean Stone Wall",
            requiredStanding = "Honored"
        }, {
            itemID = 245603,
            itemName = "Gilnean Noble's Trellis",
            requiredStanding = "Revered"
        }}
    },

    [1174] = { -- 
        label = "Wildhammer Clan",
        kind = "standard",
        expansion = "Cataclysm",
        vendor = {
            npcID = nil, -- housing vendor uses Breana; original rep has others
            name = "Breana Bitterbrand",
            zone = "Twilight Highlands",
            subzone = "Thundermar",
            uiMapID = 241,
            x = 49.6,
            y = 29.6
        },
        faction = "Alliance",
        rewards = {{
            itemID = 246425,
            itemName = "Round Dwarven Table",
            requiredStanding = "Friendly"
        }, {
            itemID = 246108,
            itemName = "Embellished Dwarven Tome",
            requiredStanding = "Honored"
        }}
    },

    -----------------------------------------------------
    -- The Burning Crusade
    -----------------------------------------------------

    [922] = { -- 
        label = "Tranquillien",
        kind = "standard",
        expansion = "The Burning Crusade",
        vendor = {
            npcID = 16528,
            name = "Provisioner Vredigar",
            zone = "Ghostlands",
            subzone = "Tranquillien",
            uiMapID = 95,
            x = 47.6,
            y = 32.2
        },
        faction = "Horde",
        rewards = {{
            itemID = 256049,
            itemName = "Sin'dorei Sleeper",
            requiredStanding = "Exalted"
        }, {
            itemID = 257419,
            itemName = "Sin'dorei Crafter's Forge",
            requiredStanding = "Exalted"
        }}
    },

    -----------------------------------------------------
    -- Mists of Pandaria
    -----------------------------------------------------

    [1273] = { -- 
        label = "Jogu the Drunk",
        kind = "friendship",
        group = "The Tillers",
        expansion = "Mists of Pandaria",
        vendor = {
            npcID = 58706,
            name = "Gina Mudclaw",
            zone = "Valley of the Four Winds",
            subzone = "Halfhill",
            uiMapID = 376,
            x = 52.2,
            y = 48.6
        },
        rewards = {{
            itemID = 247737,
            itemName = "Stormstout Brew Keg",
            requiredStanding = "Good Friend"
        }}
    },

    [1283] = { -- 
        label = "Farmer Fung",
        kind = "friendship",
        group = "The Tillers",
        expansion = "Mists of Pandaria",
        vendor = {
            npcID = 58706,
            name = "Gina Mudclaw",
            zone = "Valley of the Four Winds",
            subzone = "Halfhill",
            uiMapID = 376,
            x = 52.2,
            y = 48.6
        },
        rewards = {{
            itemID = 247734,
            itemName = "Paw'don Well",
            requiredStanding = "Good Friend"
        }}
    },

    [1275] = { -- 
        label = "Ella",
        kind = "friendship",
        group = "The Tillers",
        expansion = "Mists of Pandaria",
        vendor = {
            npcID = 58706,
            name = "Gina Mudclaw",
            zone = "Valley of the Four Winds",
            subzone = "Halfhill",
            uiMapID = 376,
            x = 52.2,
            y = 48.6
        },
        rewards = {{
            itemID = 247670,
            itemName = "Pandaren Pantry",
            requiredStanding = "Good Friend"
        }}
    },

    [1280] = { -- 
        label = "Tina Mudclaw",
        kind = "friendship",
        group = "The Tillers",
        expansion = "Mists of Pandaria",
        vendor = {
            npcID = 58706,
            name = "Gina Mudclaw",
            zone = "Valley of the Four Winds",
            subzone = "Halfhill",
            uiMapID = 376,
            x = 52.2,
            y = 48.6
        },
        rewards = {{
            itemID = 245508,
            itemName = "Pandaren Cooking Table",
            requiredStanding = "Good Friend"
        }}
    },

    [1345] = { -- 
        label = "The Lorewalkers",
        kind = "standard",
        expansion = "Mists of Pandaria",
        vendor = {
            npcID = 64605,
            name = "Tan Shin Tiao",
            zone = "Vale of Eternal Blossoms",
            subzone = nil,
            uiMapID = 390,
            x = 82.2,
            y = 29.4
        },
        rewards = {{
            itemID = 245512,
            itemName = "Pandaren Cradle Stool",
            requiredStanding = "Friendly"
        }, {
            itemID = 247662,
            itemName = "Pandaren Scholar's Lectern",
            requiredStanding = "Honored"
        }, {
            itemID = 247855,
            itemName = "Pandaren Lacquered Crate",
            requiredStanding = "Honored"
        }, {
            itemID = 247663,
            itemName = "Pandaren Scholar's Bookcase",
            requiredStanding = "Revered"
        }, {
            itemID = 258147,
            itemName = "Empty Lorewalker's Bookcase",
            requiredStanding = "Revered"
        }}
    },

    [1271] = { -- 
        label = "Order of the Cloud Serpent",
        kind = "standard",
        expansion = "Mists of Pandaria",
        vendor = {
            npcID = 58414,
            name = "San Redscale",
            zone = "The Jade Forest",
            subzone = "The Arboretum",
            uiMapID = 371,
            x = 56.6,
            y = 44.4
        },
        rewards = {{
            itemID = 247732,
            itemName = "Lucky Hanging Lantern",
            requiredStanding = "Honored"
        }, {
            itemID = 247730,
            itemName = "Red Crane Kite",
            requiredStanding = "Revered"
        }}
    },

    -----------------------------------------------------
    -- Draenor
    -----------------------------------------------------

    [1731] = { -- 
        label = "Council of Exarchs",
        kind = "standard",
        expansion = "Warlords of Draenor",
        vendor = {
            npcID = 85932,
            name = "Vindicator Nuurem",
            zone = "Ashran",
            subzone = "Stormshield",
            uiMapID = 588,
            x = 40.39,
            y = 97.11
        },
        faction = "Alliance",
        rewards = {{
            itemID = 251483,
            itemName = "Draenethyst Lantern",
            requiredStanding = "Friendly"
        }, {
            itemID = 245423,
            itemName = "Spherical Draenic Topiary",
            requiredStanding = "Friendly"
        }, {
            itemID = 251493,
            itemName = "Small Karabor Fountain",
            requiredStanding = "Honored"
        }, {
            itemID = 251481,
            itemName = "Elodor Armory Rack",
            requiredStanding = "Honored"
        }, {
            itemID = 251484,
            itemName = "\"Dawning Hope Mosaic\"",
            requiredStanding = "Revered"
        }, {
            itemID = 251476,
            itemName = "Embroidered Embaari Tent",
            requiredStanding = "Revered"
        }, {
            itemID = 251551,
            itemName = "Grand Draenethyst Lamp",
            requiredStanding = "Exalted"
        }, {
            itemID = 251479,
            itemName = "Shadowmoon Greenhouse",
            requiredStanding = "Exalted"
        }}
    },

    [1710] = { -- 
        label = "Sha'tari Defense",
        kind = "standard",
        expansion = "Warlords of Draenor",
        vendor = {
            npcID = 85427,
            name = "Maaria",
            zone = "Shadowmoon Valley",
            subzone = "Lunarfall",
            uiMapID = 539,
            x = 29.8,
            y = 14.2
        },
        faction = "Alliance",
        rewards = {{
            itemID = 245424,
            itemName = "Draenic Storage Chest",
            requiredStanding = "Friendly"
        }, {
            itemID = 251544,
            itemName = "Telredor Recliner",
            requiredStanding = "Friendly"
        }}
    },

    [1708] = { -- 
        label = "Laughing Skull Orcs",
        kind = "standard",
        expansion = "Warlords of Draenor",
        vendor = {
            npcID = 86698,
            name = "Kil'rip",
            zone = "Frostfire Ridge",
            subzone = "Frostwall",
            uiMapID = 525,
            x = 47.3,
            y = 66.4
        },
        faction = "Horde",
        rewards = {{
            itemID = 245431,
            itemName = "Draenor Cookpot",
            requiredStanding = "Friendly"
        }, {
            itemID = 245433,
            itemName = "Blackrock Strongbox",
            requiredStanding = "Friendly"
        }}
    },

    [1515] = { --
        label = "Arrakoa Outcasts",
        kind = "standard",
        expansion = "Warlords of Draenor",
        vendor = {{
            npcID = 85946,
            faction = "Alliance",
            name = "Shadow-Sage Brakoss",
            zone = "Ashran",
            subzone = "Stormshield",
            uiMapID = 588,
            x = 45.8,
            y = 74.8
        }, {
            npcID = 86037,
            faction = "Horde",
            name = "Ravenspeaker Skeega",
            zone = "Ashran",
            subzone = "Warspear",
            uiMapID = 588,
            x = 53.3,
            y = 60.0
        }},
        rewards = {{
            itemID = 258743,
            itemName = "Arakkoan Alchemy Tools",
            requiredStanding = "Honored"
        }, {
            itemID = 258746,
            itemName = "High Arakkoan Alchemist's Shelf",
            requiredStanding = "Revered"
        }, {
            itemID = 258747,
            itemName = "High Arakkoan Shelf",
            requiredStanding = "Friendly"
        }}
    },

    -----------------------------------------------------
    -- Legion
    -----------------------------------------------------

    [1828] = { -- 
        label = "Highmountain Tribe",
        kind = "standard",
        expansion = "Legion",
        vendor = {
            npcID = 106902,
            name = "Ransa Greyfeather",
            zone = "Highmountain",
            subzone = "Thunder Totem",
            uiMapID = 650,
            x = 45.33,
            y = 60.39
        },
        rewards = {{
            itemID = 245458,
            itemName = "Riverbend Jar",
            requiredStanding = "Friendly"
        }, {
            itemID = 245454,
            itemName = "Small Highmountain Drum",
            requiredStanding = "Friendly"
        }, {
            itemID = 248985,
            itemName = "Tauren Hanging Brazier",
            requiredStanding = "Honored"
        }, {
            itemID = 245452,
            itemName = "Stonebull Canoe",
            requiredStanding = "Honored"
        }, {
            itemID = 245270,
            itemName = "Thunder Totem Kiln",
            requiredStanding = "Revered"
        }, {
            itemID = 243359,
            itemName = "Tauren Windmill",
            requiredStanding = "Revered"
        }, {
            itemID = 245450,
            itemName = "Highmountain Totem",
            requiredStanding = "Exalted"
        }, {
            itemID = 243290,
            itemName = "Tauren Waterwheel",
            requiredStanding = "Exalted"
        }}
    },

    [1883] = { -- 
        label = "Dreamweavers",
        kind = "standard",
        expansion = "Legion",
        vendor = {
            npcID = 253387,
            name = "Sylvia Hartshorn",
            zone = "Val'sharah",
            subzone = "Lorlathil",
            uiMapID = 641,
            x = 54.6,
            y = 73.2
        },
        rewards = {{
            itemID = 251494,
            itemName = "Moon-Blessed Barrel",
            requiredStanding = "Friendly"
        }, {
            itemID = 238861,
            itemName = "Cenarion Rectangular Rug",
            requiredStanding = "Honored"
        }, {
            itemID = 264168,
            itemName = "Cenarion Round Rug",
            requiredStanding = "Honored"
        }, {
            itemID = 245261,
            itemName = "Kaldorei Washbasin",
            requiredStanding = "Revered"
        }, {
            itemID = 238859,
            itemName = "Cenarion Privacy Screen",
            requiredStanding = "Exalted"
        }}
    },

    [1859] = { -- 
        label = "The Nightfallen",
        kind = "standard",
        expansion = "Legion",
        vendor = { -- now a list of vendors
        {
            npcID = 97140,
            name = "First Arcanist Thalyssra",
            zone = "Suramar",
            subzone = "Meredil",
            uiMapID = 680,
            x = 37.0,
            y = 46.2
        }, {
            npcID = 248594,
            name = "Sundries Merchant",
            zone = "Suramar",
            subzone = "Suramar City",
            uiMapID = 680,
            x = 50.0,
            y = 78.0
        }},
        rewards = {{
            itemID = 247910,
            itemName = "Suramar Sconce",
            requiredStanding = "Friendly",
            vendor = 1
        }, {
            itemID = 247921,
            itemName = "Nightborne Wall Shelf",
            requiredStanding = "Friendly",
            vendor = 1
        }, {
            itemID = 247844,
            itemName = "Suramar Library",
            requiredStanding = "Honored",
            vendor = 1
        }, {
            itemID = 247845,
            itemName = "Nightborne Bench",
            requiredStanding = "Honored",
            vendor = 1
        }, {
            itemID = 247847,
            itemName = "Arcwine Counter",
            requiredStanding = "Revered",
            vendor = 1
        }, {
            itemID = 247924,
            itemName = "Suramar Street Light",
            requiredStanding = "Revered",
            vendor = 1
        }, {
            itemID = 244536,
            itemName = "Nightborne Fireplace",
            requiredStanding = "Exalted",
            vendor = 1
        }, {
            itemID = 246850,
            itemName = "\"Fruit of the Arcan'dor\" Painting",
            requiredStanding = "Exalted",
            vendor = 1
        }, {
            itemID = 245448,
            itemName = "\"Night on the Jeweled Estate\" Painting",
            requiredStanding = "Exalted",
            vendor = 1
        }, {
            itemID = 244654,
            itemName = "Small Purple Suramar Seat Cushion",
            requiredStanding = "Friendly",
            vendor = 2
        }, {
            itemID = 244676,
            itemName = "Teal Suramar Seat Cushion",
            requiredStanding = "Honored",
            vendor = 2
        }, {
            itemID = 244677,
            itemName = "Purple Suramar Seat Cushion",
            requiredStanding = "Revered",
            vendor = 2
        }, {
            itemID = 244678,
            itemName = "Small Red Suramar Seat Cushion",
            requiredStanding = "Friendly",
            vendor = 2
        }, {
            itemID = 246001,
            itemName = "Orange Suramar Seat Cushion",
            requiredStanding = "Honored",
            vendor = 2
        }, {
            itemID = 246002,
            itemName = "Red Suramar Seat Cushion",
            requiredStanding = "Revered",
            vendor = 2
        }}
    },

    -----------------------------------------------------
    -- BfA
    -----------------------------------------------------

    [2162] = { -- 
        label = "Storm's Wake",
        kind = "standard",
        expansion = "Battle for Azeroth",
        vendor = {
            npcID = 252313,
            name = "Caspian",
            zone = "Stormsong Valley",
            subzone = nil,
            uiMapID = 942,
            x = 59.40,
            y = 69.6
        },
        faction = "Alliance",
        rewards = {{
            itemID = 252396,
            itemName = "Admiralty's Copper Lantern",
            requiredStanding = "Friendly"
        }, {
            itemID = 252398,
            itemName = "Stormsong Water Pump",
            requiredStanding = "Honored"
        }, {
            itemID = 252394,
            itemName = "Bowhull Bookcase",
            requiredStanding = "Revered"
        }, {
            itemID = 252652,
            itemName = "Copper Stormsong Well",
            requiredStanding = "Revered"
        }}
    },

    [2160] = { -- 
        label = "Proudmoore Admiralty",
        kind = "standard",
        expansion = "Battle for Azeroth",
        vendor = {
            npcID = 135808,
            name = "Provisioner Fray",
            zone = "Boralus",
            subzone = nil,
            uiMapID = 1161,
            x = 67.5,
            y = 21.6
        },
        faction = "Alliance",
        rewards = {{
            itemID = 252388,
            itemName = "Boralus Fencepost",
            requiredStanding = "Friendly"
        }, {
            itemID = 252387,
            itemName = "Boralus Fence",
            requiredStanding = "Friendly"
        }, {
            itemID = 246222,
            itemName = "Boralus String Lights",
            requiredStanding = "Honored"
        }, {
            itemID = 252402,
            itemName = "Tidesage's Double Bookshelves",
            requiredStanding = "Revered"
        }, {
            itemID = 252036,
            itemName = "Tidesage's Bookcase",
            requiredStanding = "Revered"
        }}
    },

    [2103] = { -- 
        label = "Zandalari Empire",
        kind = "standard",
        expansion = "Battle for Azeroth",
        vendor = {
            npcID = 252326,
            name = "T'lama",
            zone = "Dazar'alor",
            subzone = "The Great Seal",
            uiMapID = 1165,
            x = 49.8,
            y = 42.4
        },
        faction = "Horde",
        rewards = {{
            itemID = 245521,
            itemName = "Stone Zandalari Lamp",
            requiredStanding = "Friendly"
        }, {
            itemID = 243113,
            itemName = "Blue Dazar'alor Rug",
            requiredStanding = "Honored"
        }, {
            itemID = 243130,
            itemName = "Zandalari Weapon Rack",
            requiredStanding = "Honored"
        }, {
            itemID = 256919,
            itemName = "Zandalari War Chandelier",
            requiredStanding = "Revered"
        }, {
            itemID = 257399,
            itemName = "Zandalari War Brazier",
            requiredStanding = "Revered"
        }}
    },

    [2156] = { -- 
        label = "Talanji's Expedition",
        kind = "standard",
        expansion = "Battle for Azeroth",
        vendor = {
            npcID = 135459,
            name = "Provisioner Lija",
            zone = "Nazmir",
            subzone = nil,
            uiMapID = 863,
            x = 39.0,
            y = 79.4
        },
        faction = "Horde",
        rewards = {{
            itemID = 257394,
            itemName = "Zandalari War Torch",
            requiredStanding = "Honored"
        }, {
            itemID = 245413,
            itemName = "Zandalari Sconce",
            requiredStanding = "Honored"
        }, {
            itemID = 245500,
            itemName = "Red Dazar'alor Tent",
            requiredStanding = "Revered"
        }, {
            itemID = 245495,
            itemName = "Dazar'alor Market Tent",
            requiredStanding = "Revered"
        }}
    },

    [2157] = { -- 
        label = "The Honorbound",
        kind = "standard",
        expansion = "Battle for Azeroth",
        vendor = {
            npcID = 251921,
            name = "Provisioner Mukra",
            zone = "Zuldazar",
            subzone = "Port of Zandalar",
            uiMapID = 862,
            x = 58.0,
            y = 62.6
        },
        faction = "Horde",
        rewards = {{
            itemID = 245480,
            itemName = "Lordaeron Torch",
            requiredStanding = "Honored"
        }, {
            itemID = 245478,
            itemName = "Lordaeron Sconce",
            requiredStanding = "Honored"
        }, {
            itemID = 245481,
            itemName = "Blightfire Torch",
            requiredStanding = "Revered"
        }, {
            itemID = 245479,
            itemName = "Blightfire Sconce",
            requiredStanding = "Revered"
        }}
    },

    [2391] = { -- 
        label = "Rustbolt Resistance",
        kind = "standard",
        expansion = "Battle for Azeroth",
        vendor = {
            npcID = 150716,
            name = "Stolen Royal Vendorbot",
            zone = "Mechagon",
            subzone = "Rustbolt",
            uiMapID = 1462,
            x = 73.6,
            y = 36.6
        },
        rewards = {{
            itemID = 246497,
            itemName = "Small Emergency Warning Lamp",
            requiredStanding = "Friendly"
        }, {
            itemID = 246484,
            itemName = "Mechagon Hanging Floodlight",
            requiredStanding = "Friendly"
        }, {
            itemID = 246503,
            itemName = "Large H.O.M.E Cog",
            requiredStanding = "Honored"
        }, {
            itemID = 246498,
            itemName = "Emergency Warning Lamp",
            requiredStanding = "Honored"
        }, {
            itemID = 246605,
            itemName = "Mecha-Storage Mecha-Chest",
            requiredStanding = "Revered"
        }, {
            itemID = 246499,
            itemName = "Mechagon Eyelight Lamp",
            requiredStanding = "Revered"
        }, {
            itemID = 246501,
            itemName = "Gnomish Safety Flamethrower",
            requiredStanding = "Exalted"
        }, {
            itemID = 246480,
            itemName = "Automated Gnomeregan Guardian",
            requiredStanding = "Exalted"
        }}
    },

    -----------------------------------------------------
    -- Dragonflight
    -----------------------------------------------------

    [2510] = { -- 
        label = "Valdrakken Accord",
        kind = "renown",
        expansion = "Dragonflight",
        vendor = {
            npcID = 253067,
            name = "Silvrath",
            zone = "Valdrakken",
            subzone = "The Bronze Enclave",
            uiMapID = 2112,
            x = 72.0,
            y = 49.6
        },
        rewards = {{
            itemID = 256169,
            itemName = "Valdrakken Oven",
            requiredStanding = "Renown 3"
        }, {
            itemID = 248112,
            itemName = "Valdrakken Garden Fountain",
            requiredStanding = "Renown 6"
        }, {
            itemID = 248103,
            itemName = "Draconic Stone Table",
            requiredStanding = "Renown 14"
        }, {
            itemID = 248652,
            itemName = "Dragon's Grand Mirror",
            requiredStanding = "Renown 20"
        }}
    },

    -----------------------------------------------------
    -- The War Within
    -----------------------------------------------------

    [2675] = { -- 
        label = "Blackwater Cartel",
        kind = "standard",
        expansion = "The War Within",
        vendor = {
            npcID = 231405,
            name = "Boatswain Hardee",
            zone = "Undermine",
            subzone = nil,
            uiMapID = 2346, -- Undermine
            x = 63.2,
            y = 16.8
        },
        rewards = {{
            itemID = 255642,
            itemName = "Undermine Alleyway Sconce",
            requiredStanding = "Honored"
        }, {
            itemID = 248758,
            itemName = "Relaxing Goblin Beach Chair with Cup Gripper",
            requiredStanding = "Revered"
        }}
    },

    [2677] = {
        label = "Steamwheedle Cartel",
        kind = "standard",
        expansion = "The War Within",
        vendor = {
            npcID = 231408,
            name = "Lab Assistant Laszly",
            zone = "Undermine",
            subzone = nil,
            uiMapID = 2346,
            x = 27.2,
            y = 72.4
        },
        rewards = {{
            itemID = 245321,
            itemName = "Rust-Plated Storage Barrel",
            requiredStanding = "Friendly"
        }, {
            itemID = 255641,
            itemName = "Undermine Mechanic's Hanging Lamp",
            requiredStanding = "Honored"
        }}
    },

    [2673] = {
        label = "Bilgewater Cartel",
        kind = "standard",
        expansion = "The War Within",
        vendor = {
            npcID = 231406,
            name = "Rocco Razzboom",
            zone = "Undermine",
            subzone = nil,
            uiMapID = 2346,
            x = 39.0,
            y = 22.0
        },
        rewards = {{
            itemID = 255674,
            itemName = "Incontinental Table Lamp",
            requiredStanding = "Honored"
        }, {
            itemID = 245313,
            itemName = "Spring-Powered Undermine Chair",
            requiredStanding = "Honored"
        }}
    },

    [2671] = {
        label = "Venture Company",
        kind = "standard",
        expansion = "The War Within",
        vendor = {
            npcID = 231407,
            name = "Shredz the Scrapper",
            zone = "Undermine",
            subzone = nil,
            uiMapID = 2346,
            x = 53.2,
            y = 72.6
        },
        rewards = {{
            itemID = 245311,
            itemName = "Undermine Wall Shelf",
            requiredStanding = "Honored"
        }, {
            itemID = 255647,
            itemName = "Spring-Powered Pointer",
            requiredStanding = "Revered"
        }}
    },

    [2669] = {
        label = "Darkfuse Solutions",
        kind = "standard",
        expansion = "The War Within",
        vendor = {
            npcID = 231396,
            name = "Sitch Lowdown",
            zone = "Undermine",
            subzone = nil,
            uiMapID = 2346,
            x = 30.6,
            y = 38.8
        },
        rewards = {{
            itemID = 256327,
            itemName = "Open Rust-Plated Storage Crate",
            requiredStanding = "Friendly"
        }, {
            itemID = 245307,
            itemName = "Undermine Bookcase",
            requiredStanding = "Honored"
        }}
    },

    [2688] = {
        label = "Flame's Radiance",
        kind = "renown",
        expansion = "The War Within",
        vendor = {
            npcID = 240852,
            name = "Lars Bronsmaelt",
            zone = "Hallowfall",
            subzone = nil,
            uiMapID = 2215,
            x = 28.2,
            y = 56.2
        },
        rewards = {{
            itemID = 245293,
            itemName = "Collection of Arathi Scripture",
            requiredStanding = "Renown 8"
        }}
    },

    [2766] = {
        label = "Brawl'gar Arena",
        kind = "friendship",
        expansion = "The War Within",
        vendor = {
            npcID = 68363,
            name = "Paul North",
            zone = "Orgrimmar",
            subzone = "Brawl'gar Arena",
            uiMapID = 85,
            x = 70.52,
            y = 30.90
        },
        faction = "Horde",
        rewards = {{
            itemID = 263026,
            itemName = "Brawler's Barricade",
            requiredStanding = "Rank 2"
        }, {
            itemID = 259071,
            itemName = "Brawler's Guild Punching Bag",
            requiredStanding = "Rank 5"
        }, {
            itemID = 255840,
            itemName = "Champion Brawler's Gloves",
            requiredStanding = "Rank 7"
        }}
    },

    [2767] = {
        label = "Bizmo's Brawlpub",
        kind = "friendship",
        expansion = "The War Within",
        vendor = {
            npcID = 68363,
            name = "Quackenbush",
            zone = "Stormwind",
            subzone = "Deeprun Tram",
            uiMapID = 84,
            x = 67.11,
            y = 33.65
        },
        faction = "Alliance",
        rewards = {{
            itemID = 263026,
            itemName = "Brawler's Barricade",
            requiredStanding = "Rank 2"
        }, {
            itemID = 259071,
            itemName = "Brawler's Guild Punching Bag",
            requiredStanding = "Rank 5"
        }, {
            itemID = 255840,
            itemName = "Champion Brawler's Gloves",
            requiredStanding = "Rank 7"
        }}
    }
}
