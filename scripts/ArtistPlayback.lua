local boss = require "necro.game.level.Boss"
local customMusic = require "necro.game.data.resource.CustomMusic"
local soundtrack = require "necro.game.data.Soundtrack"

local rng = require "necro.game.system.RNG"

local fileIO = require "system.game.FileIO"

local registry = require "CustomArtists.scripts.ArtistRegistry"
local songVariants = require "CustomArtists.scripts.SongVariants"

local LayerType = soundtrack.LayerType

-- Custom artists play their own songs and beatmaps straight from their playlist folder

local reportedProblems = {}

local function reportOnce(key, message, ...)
    if not reportedProblems[key] then
        reportedProblems[key] = true

        log.warn("[CustomArtists] " .. message, ...)
    end
end

local function getTrackName(ev)
    if ev.type == soundtrack.TrackType.ZONE then
        return string.format("zone%d_%d", ev.zone or 1, ev.floor or ev.level or 1)
    elseif ev.type == soundtrack.TrackType.BOSS then
        return string.format("boss_%d%s", ev.boss or 0, ev.variant or "")
    elseif type(ev.type) == "string" then
        return ev.type
    end
end

--- Zone 3 plays hot and cold songs side by side; every other track has a single song
local function getLayerVariants(ev)
    if ev.type == soundtrack.TrackType.ZONE and ev.zone == 3 then
        return {
            { suffix = soundtrack.Variant.COLD, type = LayerType.COLD },
            { suffix = soundtrack.Variant.HOT,  type = LayerType.HOT },
        }
    end

    return {
        { suffix = "", type = LayerType.NONE },
    }
end

--- Looks up one of the game's own files, named the way the stock soundtrack names them
local function gameLookup(path)
    local fullPath = "ext/" .. path

    return fileIO.exists(fullPath) and fullPath or nil
end

--- True if the artist plays on the game's beatmaps, so the game's own vocals and rap still fit its songs
local function playsStockTiming(artist)
    if artist == nil then
        return false
    end

    local data = soundtrack.Artist.data[artist]

    return data ~= nil and not data.alternateRhythm
end

--- The selected vocalist's part, falling back to Frederick's part like the stock soundtrack does
local function findVocals(lookup, songName, vocals)
    return lookup(string.format("sounds_streaming/%s_%s.ogg", songName, vocals))
        or lookup(string.format("sounds_streaming/%s_%s.ogg", songName, soundtrack.Vocals.SHOPKEEPER))
end

local function usesBaseVocals(playlist, lipmapName, default)
    return songVariants.usesBaseVocals(customMusic.readMetadata(playlist), lipmapName, default)
end

local function findShopkeeperVocals(lookup, songName, vocals, allowStock)
    if not vocals or vocals == soundtrack.Vocals.NONE then
        return nil
    end

    return findVocals(lookup, songName, vocals) or (allowStock and findVocals(gameLookup, songName, vocals)) or nil
end

--- Song layers and beatmap of a track, or nil if the playlist has no song for it
local function getTrackLayers(ev, lookup, trackName)
    if ev.type == soundtrack.TrackType.ZONE and ev.zone == 3 then
        local hot, cold, beatmap = songVariants.getZone3Songs(lookup, ev.floor or ev.level or 1)

        if not hot then
            return nil
        end

        return {
            { file = cold, type = bit.bor(LayerType.COLD, LayerType.MAIN), volume = 0.5 },
            { file = hot,  type = bit.bor(LayerType.HOT, LayerType.MAIN),  volume = 0.5 },
        }, beatmap
    end

    local beatmap = lookup(string.format("music/%s.txt", trackName))

    -- Instruments take over from the full song when the main instrument is set
    if ev.type == soundtrack.TrackType.BOSS and ev.boss == boss.Type.CORAL_RIFF and not ev.ignoreInstrumentLayers then
        local instruments = songVariants.getCoralRiffInstruments(lookup, ev.boss)

        if instruments then
            return instruments, songVariants.firstBeatmap(beatmap)
        end
    end

    local song = lookup(string.format("music/%s.ogg", trackName))

    if not song then
        return nil
    end

    return {
        {
            file = song,
            type = LayerType.MAIN,
            volume = ev.type == soundtrack.TrackType.BOSS and (boss.Type.data[ev.boss].musicVolume or 1.1) or 1,
        },
    }, songVariants.firstBeatmap(beatmap)
end

local function getMainSong(ev)
    for _, layer in ipairs(ev.layers) do
        if layer.type == LayerType.MAIN then
            return layer.file
        end
    end
end

local function findLayer(layers, layerType)
    for _, layer in ipairs(layers) do
        if layer.type == layerType then
            return layer
        end
    end
end

-- Fortissimole is the one fight the game rolls a song for, and stock only rolls for Girlfriend Records' three
-- versions. A playlist with versions of its own is rolled the same way, between the versions it actually has.
event.musicTrack.add("pickCustomArtistFortissimoleVersion", { order = "variant", sequence = 1 }, function(ev)
    if ev.boss ~= boss.Type.FORTISSIMOLE or ev.deterministic then
        return
    end

    local playlist = registry.getPlaylist(ev.artist)
    local lookup = playlist and registry.getLookup(playlist)
    local variants = lookup and songVariants.getFortissimoleVariants(lookup, ev.boss)

    if variants and #variants > 1 then
        ev.variant = rng.choice(variants, rng.Channel.SOUNDTRACK)
    end
end)

-- Runs before the stock zone, boss and special track handlers, which skip tracks that already have a beatmap
event.musicTrack.add("resolveCustomArtistTrack", { order = "zone", sequence = -1 }, function(ev)
    local playlist = registry.getPlaylist(ev.artist)

    if not playlist or ev.beatmap then
        return
    end

    local basePath = registry.getBasePath(playlist)
    local trackName = getTrackName(ev)
    local lookup = registry.getLookup(playlist)
    local layers, beatmap = nil, nil

    if lookup and trackName then
        layers, beatmap = getTrackLayers(ev, lookup, trackName)
    end

    if not layers then
        ev.artist = soundtrack.Artist.DANNY_B

        return
    end

    if not beatmap then
        reportOnce(basePath .. trackName,
            "%s has a song for %s but no beatmap with beats, playing Danny B for this track instead", playlist, trackName)

        ev.artist = soundtrack.Artist.DANNY_B

        return
    end

    ev.CustomArtists_playlist = playlist
    ev.beatmap = beatmap
    ev.originalBeatmap = beatmap

    for _, layer in ipairs(layers) do
        ev.layers[#ev.layers + 1] = layer
    end

    if ev.type == soundtrack.TrackType.ZONE then
        local variants = getLayerVariants(ev)
        local baseVocals = usesBaseVocals(playlist, trackName, playsStockTiming(ev.artist))
        local hasVocals = false

        for _, variant in ipairs(variants) do
            local vocals = findShopkeeperVocals(lookup, trackName .. variant.suffix, ev.vocals, baseVocals)

            if vocals then
                hasVocals = true
                ev.layers[#ev.layers + 1] = {
                    file = vocals,
                    type = bit.bor(variant.type, LayerType.SHOPKEEPER),
                    volume = 1 / #variants,
                }
            end
        end

        -- Whoever is singing needs a lipmap, so the game's stands in when the playlist has none of its own
        if hasVocals then
            local lipmap = string.format("music/%s.lipmap", trackName)

            ev.lipmap = lookup(lipmap) or lipmap
        end
    elseif ev.type == soundtrack.TrackType.BOSS then
        ev.ignoreSkip = ev.boss == boss.Type.KING_CONGA
        ev.loop = ev.boss ~= boss.Type.NECRODANCER_2
    else
        ev.loop = true
    end
end)

-- Stock extra layers are built around the Danny B songs, so swap in the artist's own files or drop them
event.musicTrack.add("adjustCustomArtistExtraLayers", { order = "extraLayers", sequence = 1 }, function(ev)
    local playlist = ev.CustomArtists_playlist
    local lookup = playlist and registry.getLookup(playlist)

    if not lookup then
        return
    end

    for i = #ev.layers, 1, -1 do
        local layer = ev.layers[i]

        if layer.type == LayerType.FORTISSIMOLE then
            local rap = songVariants.getFortissimoleRap(lookup, ev.boss)
            local baseVocals = usesBaseVocals(playlist, string.format("boss_%d", ev.boss), playsStockTiming(ev.artist))
            local silent = not rap and not baseVocals

            if rap then
                layer.file = rap
            elseif silent then
                table.remove(ev.layers, i)
            end

            -- Whoever is rapping needs a lipmap, so the game's is left in place when the playlist has none of its own
            local ownLipmap = lookup(string.format("music/boss_%d.lipmap", ev.boss))

            if silent then
                ev.lipmap = nil
            elseif ownLipmap then
                ev.lipmap = ownLipmap
            end
        elseif layer.type == LayerType.PHASE_2 and ev.boss == boss.Type.NECRODANCER then
            local song, beatmap = songVariants.getPhase2Song(lookup, ev.boss)

            -- Without a second phase song the first phase song continues, like the stock editor sets it up
            layer.file = song or getMainSong(ev) or layer.file
            layer.beatmap = song and songVariants.firstBeatmap(beatmap) or ev.beatmap
        end
    end
end)

-- The same rows work for a Custom Music playlist loaded the stock way. Runs before lipsync, which reads the lipmap.
event.musicTrack.add("applyLoadedPlaylistSongVariants", { order = "extraLayers", sequence = 3 }, function(ev)
    if ev.artist ~= soundtrack.Artist.CUSTOM or ev.disableSubstitutions or ev.CustomArtists_songVariant
        or not customMusic.isAnyPlaylistLoaded()
    then
        return
    end

    local lookup = songVariants.substitutionLookup

    if ev.type == soundtrack.TrackType.ZONE and ev.zone == 3 then
        local floorName = string.format("music/zone3_%d", ev.floor or ev.level or 1)
        local hasHot = lookup(floorName .. soundtrack.Variant.HOT .. ".ogg") ~= nil
        local hasCold = lookup(floorName .. soundtrack.Variant.COLD .. ".ogg") ~= nil

        if hasHot ~= hasCold then
            local hot, cold = songVariants.getZone3Songs(lookup, ev.floor or ev.level or 1)

            for _, layer in ipairs(ev.layers) do
                if layer.type == bit.bor(LayerType.HOT, LayerType.MAIN) then
                    layer.file = hot
                elseif layer.type == bit.bor(LayerType.COLD, LayerType.MAIN) then
                    layer.file = cold
                end
            end
        end
    elseif ev.type == soundtrack.TrackType.BOSS and ev.boss == boss.Type.CORAL_RIFF and not ev.ignoreInstrumentLayers then
        local instruments = songVariants.getCoralRiffInstruments(lookup, ev.boss)

        if instruments then
            local instrumentTypes = {}

            for _, layerType in ipairs(songVariants.CORAL_RIFF_LAYERS) do
                instrumentTypes[layerType] = true
            end

            for i = #ev.layers, 1, -1 do
                if instrumentTypes[ev.layers[i].type] then
                    table.remove(ev.layers, i)
                end
            end

            for i, layer in ipairs(instruments) do
                table.insert(ev.layers, i, layer)
            end
        end
    elseif ev.type == soundtrack.TrackType.BOSS and ev.boss == boss.Type.FORTISSIMOLE then
        local rap, lipmap = songVariants.getFortissimoleRap(lookup, ev.boss)

        if rap then
            local layer = findLayer(ev.layers, LayerType.FORTISSIMOLE)

            if not layer then
                layer = { type = LayerType.FORTISSIMOLE }
                ev.layers[#ev.layers + 1] = layer
            end

            layer.file = rap

            ev.lipmap = lipmap or ev.lipmap
        end
    elseif ev.type == soundtrack.TrackType.BOSS and ev.boss == boss.Type.NECRODANCER then
        -- Without a second phase song the first phase song continues, instead of switching to Danny B's
        local layer = findLayer(ev.layers, LayerType.PHASE_2)
        local firstPhase = lookup(string.format("music/boss_%d.ogg", ev.boss))

        if layer and firstPhase and not songVariants.getPhase2Song(lookup, ev.boss) then
            layer.file = firstPhase
            layer.beatmap = ev.beatmap
        end
    end
end)
