name = ' Craft From Chest [DST] Fixed'
description = 'When crafting items, ingredients are automatically obtained from nearby containers. No manually searching for necessary items anymore! '
author = 'Editor & Monti'
version = '1.1.11.3'
-- forumthread = ''
-- api_version = 6
-- priority = 1
-- dont_starve_compatible = true
-- reign_of_giants_compatible = true
-- shipwrecked_compatible = true
-- hamlet_compatible = true

-- This lets other players know if your mod is out of date, update it to match the current version in the game
api_version = 10

-- Compatible with Don't Starve Together
dst_compatible = true --兼容联机

-- Not compatible with Don't Starve
dont_starve_compatible = false --不兼容原版
reign_of_giants_compatible = false --不兼容巨人DLC

-- Character mods need this set to true
all_clients_require_mod = true --所有人mod

priority = 2022 --set priority higher because this mod overrides some functions so that other overriden functions from mods are not lost

-- The mod's tags displayed on the server list
server_filter_tags = {  --服务器标签
"tweak",
}

icon_atlas = "modicon.xml"
icon = "modicon.tex"

configuration_options = {
    {
        name = "range",
        label = "Nearby Range",
        options = {
            { description = "10", data = 10 },
            { description = "30", data = 30 },
            { description = "50", data = 50 },
            { description = "Infinite", data = -1 },
        },
        default = 10
    },
    {
        name = "is_inv_first",
        label = "Take from: ",
        options = {
            { description = "Inv first", data = true },
            { description = "Chest first", data = false },
        },
        default = false
    },
    {
        name = "keep_one_item",
        label = "Keep one item in chest?: ",
        options = {
            { description = "Yes", data = true },
            { description = "No", data = false },
        },
        default = false
    },
    {
        name = "debug",
        label = "Debug msg",
        options = {
            { description = "Enable", data = true },
            { description = "Disable", data = false },
        },
        default = false
    },
}