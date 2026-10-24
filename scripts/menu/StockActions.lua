local assets = require "CustomArtists.scripts.menu.Assets"

-- Mods cannot delete files or open folders, but stock menus can. These helpers build a stock menu in memory, without
-- opening or drawing it, and run one of its actions.

local StockActions = {}

StockActions.Provider = {
    ASSET_MODS = 4,
    CUSTOM_SOUNDTRACK = 6,
}

local TOOL_ICON_OPEN_DIRECTORY = 2

-- The sidebar entry describing the selected pack starts with its picture
local SIDEBAR_IMAGE_ID = "sidebar1"
local TILE_ID_PREFIX = "tile_"

--- Builds a stock menu's entries without opening it; nil if the menu handler fails
function StockActions.build(menuName, arg)
    local ev = {
        arg = arg,
        menuName = menuName,
    }
    local success, err = pcall(event.menu.fire, ev, menuName)

    if not success then
        log.warn("[CustomArtists] Failed to build stock menu '%s': %s", menuName, tostring(err))

        return nil
    end

    return ev.menu and ev.menu.entries
end

function StockActions.run(menuName, arg, findAction, description)
    local entries = StockActions.build(menuName, arg)
    local action = entries and findAction(entries)

    if action then
        action()
    else
        log.warn("[CustomArtists] Could not find the stock action to %s", description)
    end
end

--- "Manage mod": uninstall directly follows "Change priority", the only entry with an enableIf check
function StockActions.findUninstall(entries)
    for i, entry in ipairs(entries) do
        if entry.enableIf then
            return entries[i + 1] and entries[i + 1].action
        end
    end
end

function StockActions.findOpenDirectory(entries)
    local toggleCount = 0

    for _, entry in ipairs(entries) do
        if entry.enableIf then
            return nil
        elseif entry.action then
            if toggleCount >= 2 then
                return entry.action
            elseif type(entry.label) == "function" then
                toggleCount = toggleCount + 1
            end
        end
    end
end

function StockActions.findOpenDirectoryTool(entries)
    for _, entry in ipairs(entries) do
        local icon = type(entry.icon) == "table" and entry.icon
        local imageRect = icon and icon.image == assets.TOOLS and icon.imageRect

        if imageRect and imageRect[1] == 16 * (TOOL_ICON_OPEN_DIRECTORY - 1) then
            return entry.action
        end
    end
end

function StockActions.findCreateMod(entries)
    for _, entry in ipairs(entries) do
        if entry.id == "create" then
            return entry.action
        end
    end
end

function StockActions.listAssetMods()
    local entries = StockActions.build("modGrid", { provider = StockActions.Provider.ASSET_MODS })
    local result = {}

    for _, entry in ipairs(entries or {}) do
        local id = type(entry.id) == "string" and entry.id

        if id and id:sub(1, #TILE_ID_PREFIX) == TILE_ID_PREFIX then
            result[#result + 1] = id:sub(#TILE_ID_PREFIX + 1)
        end
    end

    return result
end

-- Packs don't store their author, and a pack from the workshop keeps its picture there rather than in its folder. The
-- game looks both up to build the grid with the pack selected and read them off it.
function StockActions.findResourcePackInfo(modName)
    local entries = StockActions.build("modGrid", {
        provider = StockActions.Provider.ASSET_MODS,
        selectedMod = modName,
    })
    local author, image = nil, nil

    for _, entry in ipairs(entries or {}) do
        if not author and type(entry.label) == "function" then
            local success, label = pcall(entry.label)
            local found = success and type(label) == "string" and label:match("^Authors?: (.+)$")

            if found and found ~= "" then
                author = found
            end
        end

        if not image and entry.id == SIDEBAR_IMAGE_ID and type(entry.icon) == "function" then
            local success, icon = pcall(entry.icon)
            local path = success and type(icon) == "table" and icon.image

            if type(path) == "string" then
                image = path
            end
        end
    end

    return author, image
end

return StockActions
