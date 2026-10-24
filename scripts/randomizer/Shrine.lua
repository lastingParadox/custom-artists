local action = require "necro.game.system.Action"
local components = require "necro.game.data.Components"
local currentLevel = require "necro.game.level.CurrentLevel"
local customEntities = require "necro.game.data.CustomEntities"
local lobbyGeneration = require "necro.game.data.level.LobbyGeneration"
local localCoop = require "necro.client.LocalCoop"
local menu = require "necro.menu.Menu"
local minimapTheme = require "necro.game.data.tile.MinimapTheme"
local object = require "necro.game.object.Object"
local ping = require "necro.client.Ping"
local collision = require "necro.game.tile.Collision"
local sound = require "necro.audio.Sound"
local turn = require "necro.cycles.Turn"

local ecs = require "system.game.Entities"

local songRandomizer = require "CustomArtists.scripts.randomizer.Randomizer"

-- Lobby shrine that opens the Song Randomizer menu, two tiles left of the Change Skin shrine

local Mode = songRandomizer.Mode

local MODE_FRAMES = {
    [Mode.OFF] = 1,
    [Mode.RANDOM_ARTIST] = 2,
    [Mode.SHUFFLE_SONGS] = 3,
}

components.register({
    CustomArtists_interactableSongRandomizer = {},
})

local shrineEntityType = customEntities.register {
    name = "CustomArtists_SongRandomizerShrine",
    gameObject = {},
    position = {},
    friendlyName = { name = "Shrine of Shuffling" },
    worldLabel = { text = "Randomize\nSongs", alignY = 0, offsetY = 9 },
    worldLabelMaxWidth = {},
    interactable = {},
    sprite = {
        texture = "mods/CustomArtists/gfx/shrines/shrine_song_rando.png",
        width = 35,
        height = 52,
    },
    spriteSheet = { frameX = 1 },
    silhouette = {},
    collision = { mask = collision.Type.OBJECT },
    visibility = {},
    positionalSprite = { offsetX = -6, offsetY = -21 },
    rowOrder = { z = 20 },
    CustomArtists_interactableSongRandomizer = {},
    pingable = { type = ping.Type.CONTAINER },
    visualExtent = { width = 24, height = 36, offsetX = 0, offsetY = -3 },
    minimapStaticPixel = {
        color = minimapTheme.Color.SHRINE,
        depth = minimapTheme.Depth.SHRINE,
    },
}

local menuTurnID = -1

event.lobbyGenerate.add("addSongRandomizerShrine", { order = "characters", sequence = 2 }, function(ev)
    local roomData = ev.rooms and ev.rooms[lobbyGeneration.RoomType.CHARACTER_SELECT]

    if roomData and roomData.rect then
        object.spawn(shrineEntityType, roomData.rect[1] + roomData.rect[3] - 7, roomData.rect[2] + 2)
    end
end)

event.objectInteract.add("showSongRandomizerMenu",
    { order = "activate", filter = "CustomArtists_interactableSongRandomizer" }, function(ev)
        local playerID = ev.interactor and ev.interactor.controllable and ev.interactor.controllable.playerID or 0

        if playerID ~= 0 and localCoop.isLocal(playerID) and not menu.isOpen() then
            local turnID = turn.getCurrentTurnID()

            if menuTurnID < turnID then
                menuTurnID = turnID
                menu.suppressKeyControlForTick()
                menu.open("CustomArtists_songRandomizer")
                sound.playUI("minibossShake")
            end
        end

        ev.result = action.Result.INTERACT
    end)

event.updateVisuals.add("updateSongRandomizerShrine", { order = "equipmentSprite" }, function()
    if not currentLevel.isLobby() then
        return
    end

    local frame = MODE_FRAMES[songRandomizer.getMode()] or 1

    for entity in ecs.entitiesWithComponents { "CustomArtists_interactableSongRandomizer", "spriteSheet" } do
        entity.spriteSheet.frameX = frame
    end
end)

event.gameStateLevel.add("resetSongRandomizerMenuTurnID", "resetLevelVariables", function()
    menuTurnID = -1
end)
