local config = require "necro.config.Config"
local customMusic = require "necro.game.data.resource.CustomMusic"
local menu = require "necro.menu.Menu"

local registry = require "CustomArtists.scripts.ArtistRegistry"
local songRandomizer = require "CustomArtists.scripts.randomizer.Randomizer"
local stockActions = require "CustomArtists.scripts.menu.StockActions"

local ArtistActions = {}

function ArtistActions.create()
    local playlist = registry.create()

    if playlist then
        customMusic.edit(playlist)
        menu.setMouseControlActive(false)
        menu.selectByID("playlistName")
        menu.setTextEntryActive(true)
    end
end

--- Deletes through the stock Custom Music uninstall action, which asks for confirmation first
function ArtistActions.delete(playlist)
    stockActions.run("modConfig", {
        modName = playlist,
        provider = stockActions.Provider.CUSTOM_SOUNDTRACK,
    }, stockActions.findUninstall, "delete " .. tostring(playlist))
end

--- Opens a playlist's folder, or the mods folder holding every playlist when playlist is nil
function ArtistActions.openDirectory(playlist)
    if type(playlist) == "string" then
        -- The Resource Packs provider offers "Open mod directory" for local packs, and playlists are local packs
        stockActions.run("modConfig", {
            modName = playlist,
            provider = stockActions.Provider.ASSET_MODS,
        }, stockActions.findOpenDirectory, "open the folder of " .. playlist)
    else
        stockActions.run("modGrid", {
            provider = stockActions.Provider.CUSTOM_SOUNDTRACK,
        }, stockActions.findOpenDirectoryTool, "open the mods folder")
    end
end

ArtistActions.canOpenDirectory = config.osDesktop

-- Updates every open menu, since the grid behind an open dropdown shows the same state
function ArtistActions.toggleRandomized(id)
    songRandomizer.setRandomized(id, not registry.isRandomized(id))
    menu.updateAll()
end

function ArtistActions.toggleHidden(id)
    registry.setHidden(id, not registry.isHidden(id))
    menu.updateAll()
end

return ArtistActions
