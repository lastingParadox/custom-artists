local boss = require "necro.game.level.Boss"
local gameSong = require "necro.game.data.resource.GameSong"
local music = require "necro.audio.Music"
local soundtrack = require "necro.game.data.Soundtrack"

local enum = require "system.utils.Enum"
local fileIO = require "system.game.FileIO"

-- Extra song rows for the Custom Music editor. Every row writes the file names the base game uses.
local SongVariants = {}

SongVariants.TRACK_TYPE = "CustomArtists_songVariant"

SongVariants.CORAL_RIFF_LAYERS = {
    soundtrack.LayerType.MAIN,
    soundtrack.LayerType.TENTACLE_DRUMS,
    soundtrack.LayerType.TENTACLE_HORNS,
    soundtrack.LayerType.TENTACLE_STRINGS,
    soundtrack.LayerType.TENTACLE_KEYTAR,
}

-- Two different encodes never share their first bytes (Ogg streams start with a random serial number)
local COPY_CHECK_BYTES = 65536

local definitions = {}
local registeredDefinitions = {}
local definitionsByKey = {}
local definitionsByID = {}

local function define(definition)
    definitions[#definitions + 1] = definition
end

for floor = 1, 3 do
    local parent = string.format("ZONE_3_%d", floor)
    local songName = string.format("zone3_%d", floor)

    for _, mix in ipairs({
        { key = "COLD", label = "Cold", variant = soundtrack.Variant.COLD, sibling = "HOT" },
        { key = "HOT",  label = "Hot",  variant = soundtrack.Variant.HOT,  sibling = "COLD" },
    }) do
        define({
            key = parent .. "_" .. mix.key,
            parent = parent,
            parentName = string.format("Zone 3-%d", floor),
            label = mix.label,
            kind = "mix",
            variant = mix.variant,
            sibling = parent .. "_" .. mix.sibling,
            file = string.format("music/%s%s.ogg", songName, mix.variant),
            beatmap = string.format("music/%s.txt", songName),
            sharesParentBeatmap = true,
        })
    end
end

define({
    key = "BOSS_NECRODANCER_PHASE_2",
    parent = "BOSS_NECRODANCER",
    parentName = "The NecroDancer",
    label = "Phase 2",
    kind = "phase2",
    variant = soundtrack.Variant.ALTERNATIVE,
    file = string.format("music/boss_%d%s.ogg", boss.Type.NECRODANCER, soundtrack.Variant.ALTERNATIVE),
    beatmap = string.format("music/boss_%d%s.txt", boss.Type.NECRODANCER, soundtrack.Variant.ALTERNATIVE),
})

for i, label in ipairs({ "Main instrument", "Drums", "Horns", "Strings", "Keytar" }) do
    local instrument = i - 1

    define({
        key = string.format("BOSS_CORAL_RIFF_INSTRUMENT_%d", instrument),
        parent = "BOSS_CORAL_RIFF",
        parentName = "Coral Riff",
        label = label,
        kind = "instrument",
        instrument = instrument,
        mainInstrument = "BOSS_CORAL_RIFF_INSTRUMENT_0",
        file = string.format("sounds_streaming/boss_%d_inst%d.ogg", boss.Type.CORAL_RIFF, instrument),
        beatmap = instrument == 0 and string.format("music/boss_%d.txt", boss.Type.CORAL_RIFF)
            or string.format("music/boss_%d_inst%d.txt", boss.Type.CORAL_RIFF, instrument),
        sharesParentBeatmap = instrument == 0,
        replacesParent = instrument == 0,
        ownFile = true,
    })
end

-- Fortissimole is the one fight the game has more than one song for: Girlfriend Records wrote three, and the game
-- rolls between them every time the fight starts. A playlist that brings its own extra versions is rolled the same
-- way (see ArtistPlayback), and packs that replace them import onto these rows.
for _, version in ipairs({
    { key = "VERSION_2", label = "Version 2", variant = soundtrack.Variant.ALTERNATIVE },
    { key = "VERSION_3", label = "Version 3", variant = soundtrack.Variant.ALTERNATIVE_2 },
}) do
    define({
        key = "BOSS_FORTISSIMOLE_" .. version.key,
        parent = "BOSS_FORTISSIMOLE",
        parentName = "Fortissimole",
        label = version.label,
        kind = "version",
        variant = version.variant,
        file = string.format("music/boss_%d%s.ogg", boss.Type.FORTISSIMOLE, version.variant),
        beatmap = string.format("music/boss_%d%s.txt", boss.Type.FORTISSIMOLE, version.variant),
        ownFile = true,
    })
end

define({
    key = "BOSS_FORTISSIMOLE_RAP",
    parent = "BOSS_FORTISSIMOLE",
    parentName = "Fortissimole",
    label = "Rap",
    kind = "rap",
    file = string.format("sounds_streaming/boss_%d_vocal.ogg", boss.Type.FORTISSIMOLE),
    beatmap = string.format("music/boss_%d_vocal.txt", boss.Type.FORTISSIMOLE),
    copyOf = string.format("music/boss_%d.ogg", boss.Type.FORTISSIMOLE),
    ownFile = true,
})

-- The editor lists songs in enum order; the rows are moved beneath their stock row when the menu is built
for _, definition in ipairs(definitions) do
    local parentID = gameSong.Type[definition.parent]
    local parentData = parentID and gameSong.Type.data[parentID]

    if parentData and parentData.track then
        if type(parentData.name) == "string" then
            definition.parentName = parentData.name
        end

        definition.parentID = parentID
        definition.name = string.format("%s (%s)", definition.parentName, definition.label)
        definition.songID = gameSong.Type.extend(definition.key, enum.data({
            entity = parentData.entity,
            groupID = parentData.groupID,
            name = definition.name,
            previewHeight = parentData.previewHeight,
            shortName = parentData.shortName,
            track = {
                type = SongVariants.TRACK_TYPE,
                CustomArtists_songVariant = definition.key,
            },
        }))
        definition.id = gameSong.Type.names[definition.songID]

        registeredDefinitions[#registeredDefinitions + 1] = definition
        definitionsByKey[definition.key] = definition
        definitionsByID[definition.id] = definition
    end
end

function SongVariants.list()
    return registeredDefinitions
end

function SongVariants.getDefinition(key)
    return definitionsByKey[key]
end

--- Looks up a row by its menu entry ID (the song enum name)
function SongVariants.getDefinitionByID(id)
    return definitionsByID[id]
end

-- Playlists store song file names by numeric song ID, and the IDs of added rows shift with the set of loaded mods.
-- These rows keep their file names by row ID under this playlist.json key instead.
SongVariants.FILE_NAMES_KEY = "songVariantFileNames"

-- A track the base game sings keeps its "Uses base game vocals" choice under this key, by the name of the lipmap the
-- track uses ("zone3_1", "boss_9"), so Zone 3's Hot and Cold rows share the one their floor plays. Absent means the
-- choice was never made, and the artist's own timing decides (see ArtistPlayback).
--
-- 1.0.0 stored a narrower "uses base lipmap" choice under "baseLipmap". That key is left alone rather than reused:
-- turning it off only dropped the lipmap, so reading it as "no vocals" would silence shopkeepers that sing today.
SongVariants.BASE_VOCALS_KEY = "baseVocals"

local STOCK_SPECIAL_TRACKS = { lobby = true, training = true, tutorial = true }

--- The song file a stock editor row writes (the hot song for zone 3 floors)
function SongVariants.getStockSongFile(track)
    if type(track) ~= "table" then
        return nil
    elseif track.type == soundtrack.TrackType.ZONE then
        local variant = track.zone == 3 and soundtrack.Variant.HOT or ""

        return string.format("music/zone%d_%d%s.ogg", track.zone or 1, track.floor or 1, variant)
    elseif track.type == soundtrack.TrackType.BOSS then
        return string.format("music/boss_%d%s.ogg", track.boss or 0, track.variant or "")
    elseif STOCK_SPECIAL_TRACKS[track.type] then
        return string.format("music/%s.ogg", track.type)
    end
end

--- The base game's lipmap for a track, without folder or extension ("zone3_1", "boss_9"), or nil where it has none.
--- The game records one per zone floor plus Fortissimole's rap, and shares them across every soundtrack.
function SongVariants.getLipmapName(track)
    if type(track) ~= "table" then
        return nil
    elseif track.type == soundtrack.TrackType.ZONE then
        return string.format("zone%d_%d", track.zone or 1, track.floor or 1)
    elseif track.type == soundtrack.TrackType.BOSS and track.boss == boss.Type.FORTISSIMOLE then
        return string.format("boss_%d", track.boss)
    end
end

--- The lipmap an editor row belongs to, following an added row up to the stock row it sits beneath, so the Hot, Cold
--- and Rap rows answer with their floor's or their fight's lipmap
function SongVariants.getSongLipmapName(songID)
    local data = gameSong.Type.data[songID]
    local definition = data and definitionsByID[gameSong.Type.names[songID]]

    if definition then
        local parentData = gameSong.Type.data[definition.parentID]

        return parentData and SongVariants.getLipmapName(parentData.track) or nil
    end

    return data and SongVariants.getLipmapName(data.track) or nil
end

--- Whether a track falls back to the base game's vocals, and with them its lipmap. Playlists that never made the
--- choice fall back to the given default.
function SongVariants.usesBaseVocals(metadata, lipmapName, default)
    local overrides = type(metadata) == "table" and metadata[SongVariants.BASE_VOCALS_KEY]
    -- Kept apart from the checks above: those yield false, not nil, and only nil means the choice was never made
    local override = nil

    if lipmapName and type(overrides) == "table" then
        override = overrides[lipmapName]
    end

    if override == nil then
        return default and true or false
    end

    return override and true or false
end

function SongVariants.setUsesBaseVocals(metadata, lipmapName, value)
    local overrides = type(metadata[SongVariants.BASE_VOCALS_KEY]) == "table" and metadata[SongVariants.BASE_VOCALS_KEY]
        or {}

    overrides[lipmapName] = value and true or false
    metadata[SongVariants.BASE_VOCALS_KEY] = overrides
end

-- Song file names of the open editor, by song ID, and whether it is removing a song's files right now
local editorFileNames = nil
local editorRemoving = false

function SongVariants.setEditorFileNames(fileNames)
    editorFileNames = fileNames
end

function SongVariants.setEditorRemoving(removing)
    editorRemoving = removing and true or false
end

--- The Custom Music editor resolves a song as a track to find out which files to write and remove
event.musicTrack.add("resolveSongVariant", { order = "zone", sequence = -2 }, function(ev)
    local definition = definitionsByKey[ev.CustomArtists_songVariant]

    if definition and not ev.beatmap then
        ev.beatmap = "ext/" .. definition.beatmap
        ev.layers[#ev.layers + 1] = {
            file = "ext/" .. definition.file,
            type = soundtrack.LayerType.MAIN,
        }
        ev.loop = true
    end
end)

-- Keeps the editor from overwriting or deleting files that belong to another row that is set
event.musicTrack.add("limitEditorSongFiles", { order = "extraLayers", sequence = 2 }, function(ev)
    if ev.artist ~= soundtrack.Artist.CUSTOM or not ev.disableSubstitutions or not ev.ignoreInstrumentLayers then
        return
    end

    local definition = definitionsByKey[ev.CustomArtists_songVariant]

    -- For playlists that aren't loaded, the stock Fortissimole row also writes a copy of the whole song as the rap.
    -- The Rap row sets that file now.
    if not definition and ev.boss == boss.Type.FORTISSIMOLE then
        for i = #ev.layers, 1, -1 do
            if ev.layers[i].type == soundtrack.LayerType.FORTISSIMOLE then
                table.remove(ev.layers, i)
            end
        end
    end

    if not editorFileNames then
        return
    end

    local claimedFiles = {}
    local claimedBeatmaps = {}

    for _, other in ipairs(registeredDefinitions) do
        if other ~= definition and editorFileNames[other.songID] then
            -- A stock row leaves the songs of the rows beneath it alone; those rows override it
            if not definition then
                claimedFiles["ext/" .. other.file] = true
            end

            claimedBeatmaps["ext/" .. other.beatmap] = true
        end
    end

    if definition and definition.sharesParentBeatmap and editorFileNames[definition.parentID] then
        claimedBeatmaps["ext/" .. definition.beatmap] = true
    end

    for i = #ev.layers, 1, -1 do
        if claimedFiles[ev.layers[i].file] then
            table.remove(ev.layers, i)
        end
    end

    if editorRemoving and ev.beatmap and claimedBeatmaps[ev.beatmap] then
        -- The editor removes a song's files together with its beatmap, so point it at a beatmap that doesn't exist
        ev.beatmap = ev.beatmap .. ".CustomArtists_inUse"
    end
end)

--- Returns a lookup for files in a playlist folder ("ext/mods/<folder>/")
function SongVariants.folderLookup(basePath)
    return function(path)
        local fullPath = basePath .. path

        return fileIO.exists(fullPath) and fullPath or nil
    end
end

--- Lookup for files of the globally loaded Custom Music playlist
function SongVariants.substitutionLookup(path)
    local fullPath = "ext/" .. path

    return fileIO.isSubstituted(fullPath) and fileIO.getSubstitute(fullPath) or nil
end

function SongVariants.hasBeats(path)
    local beats = path and music.parseBeatmap(fileIO.readFileToString(path))

    return beats ~= nil and #beats > 1
end

--- The first of the given beatmaps that exists and has beats
function SongVariants.firstBeatmap(...)
    for i = 1, select("#", ...) do
        local path = select(i, ...)

        if path and SongVariants.hasBeats(path) then
            return path
        end
    end
end

function SongVariants.isCopyOf(path, originalPath)
    if not path or not originalPath then
        return false
    end

    local data = fileIO.readFileToString(path, COPY_CHECK_BYTES)

    return data ~= nil and data == fileIO.readFileToString(originalPath, COPY_CHECK_BYTES)
end

--- The file a row provides on its own, if any. Rows whose files the stock row also writes never count.
function SongVariants.findFile(lookup, definition)
    if not definition.ownFile then
        return nil
    end

    local file = lookup(definition.file)

    if file and definition.copyOf and SongVariants.isCopyOf(file, lookup(definition.copyOf)) then
        return nil
    end

    return file
end

--- Hot and cold songs and the beatmap of a zone 3 floor. A floor with only one of the two plays it on both tile states.
function SongVariants.getZone3Songs(lookup, floor)
    local base = string.format("music/zone3_%d", floor)
    local hot = lookup(base .. soundtrack.Variant.HOT .. ".ogg")
    local cold = lookup(base .. soundtrack.Variant.COLD .. ".ogg")

    return hot or cold, cold or hot, SongVariants.firstBeatmap(lookup(base .. ".txt"))
end

--- The NecroDancer's second phase song and beatmap
function SongVariants.getPhase2Song(lookup, bossID)
    local name = string.format("music/boss_%d%s", bossID, soundtrack.Variant.ALTERNATIVE)
    local song = lookup(name .. ".ogg")

    return song, song and lookup(name .. ".txt")
end

--- Coral Riff's instrument layers, if the main instrument is there. The tentacle instruments are optional.
function SongVariants.getCoralRiffInstruments(lookup, bossID)
    local layers = {}

    for i, layerType in ipairs(SongVariants.CORAL_RIFF_LAYERS) do
        local file = lookup(string.format("sounds_streaming/boss_%d_inst%d.ogg", bossID, i - 1))

        if file then
            layers[#layers + 1] = {
                file = file,
                type = layerType,
            }
        elseif i == 1 then
            return nil
        end
    end

    return layers
end

--- The Fortissimole versions a playlist has a song for, as track variants, the default version first
function SongVariants.getFortissimoleVariants(lookup, bossID)
    local variants = {}

    for _, variant in ipairs({
        soundtrack.Variant.DEFAULT,
        soundtrack.Variant.ALTERNATIVE,
        soundtrack.Variant.ALTERNATIVE_2,
    }) do
        if lookup(string.format("music/boss_%d%s.ogg", bossID, variant)) then
            variants[#variants + 1] = variant
        end
    end

    return variants
end

--- Fortissimole's rap and its lipmap, ignoring copies of the whole song
function SongVariants.getFortissimoleRap(lookup, bossID)
    local rap = lookup(string.format("sounds_streaming/boss_%d_vocal.ogg", bossID))

    if rap and not SongVariants.isCopyOf(rap, lookup(string.format("music/boss_%d.ogg", bossID))) then
        return rap, lookup(string.format("music/boss_%d.lipmap", bossID))
    end
end

return SongVariants
