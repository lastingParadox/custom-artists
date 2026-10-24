local menu = require "necro.menu.Menu"
local settings = require "necro.config.Settings"
local ui = require "necro.render.UI"

local utils = require "system.utils.Utilities"

local assets = require "CustomArtists.scripts.menu.Assets"

-- Sort, view and icon size options of the artist grid, mirroring the stock mod grid

local GridView = {}

GridView.SortMode = {
    { id = "MODDED",  name = "Modded",     image = assets.SORT_MODDED },
    { id = "NAME",    name = "Name",       icon = 3 },
    { id = "ENABLED", name = "Randomized", icon = 4 },
}

GridView.ViewMode = {
    { id = "GRID", name = "Grid", icon = 6 },
    {
        id = "LIST",
        name = "List",
        icon = 5,
        boundingBoxFullWidth = true,
        pageScroll = 5,
        showDescriptions = true,
        showNames = true,
        singleColumn = true,
    },
}

GridView.IconSize = {
    {
        id = "TINY",
        name = "Tiny",
        icon = 8,
        size = 36,
        spacing = 1,
        descLines = 0,
        listOffsetY = 6,
        groupFont = ui.Font.SMALL,
        tileFont = utils.mergeDefaults(ui.Font.LARGE, { alignY = 0.5, size = 9 }),
    },
    {
        id = "SMALL",
        name = "Small",
        icon = 9,
        size = 48,
        spacing = 2,
        descLines = 1,
        tileFont = utils.mergeDefaults(ui.Font.LARGE, { alignY = 0.5, size = 12 }),
    },
    {
        id = "MEDIUM",
        name = "Medium",
        icon = 10,
        size = 72,
        spacing = 4,
        descLines = 2,
        tileFont = utils.mergeDefaults(ui.Font.LARGE, { alignY = 0.5, size = 18 }),
    },
    {
        id = "LARGE",
        name = "Large",
        icon = 11,
        size = 120,
        spacing = 8,
        descLines = 4,
        tileFont = utils.mergeDefaults(ui.Font.LARGE, { alignY = 0.5, size = 30 }),
    },
}

local OPTIONS = {
    sort = GridView.SortMode,
    view = GridView.ViewMode,
    size = GridView.IconSize,
}

local DEFAULTS = {
    sort = "MODDED",
    view = "GRID",
    size = "MEDIUM",
}

viewSettings = settings.user.table({
    id = "viewSettings",
    visibility = settings.Visibility.HIDDEN,
    default = DEFAULTS,
})

local function find(options, id)
    for _, option in ipairs(options) do
        if option.id == id then
            return option
        end
    end
end

function GridView.get(key)
    local options = OPTIONS[key]
    local id = type(viewSettings) == "table" and viewSettings[key] or nil

    return find(options, id) or find(options, DEFAULTS[key]) or options[1]
end

function GridView.cycle(key)
    local options = OPTIONS[key]
    local current = GridView.get(key)
    local index = 1

    for i, option in ipairs(options) do
        if option == current then
            index = i
        end
    end

    local newSettings = utils.fastCopy(type(viewSettings) == "table" and viewSettings or {})
    newSettings[key] = options[index % #options + 1].id
    viewSettings = newSettings

    menu.update()
end

return GridView
