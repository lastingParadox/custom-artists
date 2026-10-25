local boss = require "necro.game.level.Boss"
local currentLevel = require "necro.game.level.CurrentLevel"
local customMusic = require "necro.game.data.resource.CustomMusic"
local gameDLC = require "necro.game.data.resource.GameDLC"
local gameSong = require "necro.game.data.resource.GameSong"
local gameState = require "necro.client.GameState"
local music = require "necro.audio.Music"
local player = require "necro.game.character.Player"
local playerList = require "necro.client.PlayerList"
local rng = require "necro.game.system.RNG"
local settings = require "necro.config.Settings"
local soundtrack = require "necro.game.data.Soundtrack"
local visualUpdate = require "necro.cycles.VisualUpdate"

local enum = require "system.utils.Enum"
local fileIO = require "system.game.FileIO"
local orderedSelector = require "system.events.OrderedSelector"
local timer = require "system.utils.Timer"
local utils = require "system.utils.Utilities"

local registry = require "CustomArtists.scripts.ArtistRegistry"
local songVariants = require "CustomArtists.scripts.SongVariants"

-- Randomizes the soundtrack across the artists picked in the Custom Artists menu. Other mods can change the settings
-- a track is resolved with through event.customArtistsSongRandomizer.

local SongRandomizer = {}

local LayerType = soundtrack.LayerType
local ZONE = soundtrack.TrackType.ZONE
local BOSS = soundtrack.TrackType.BOSS

SongRandomizer.Mode = {
    OFF = "OFF",
    RANDOM_ARTIST = "RANDOM_ARTIST",
    SHUFFLE_SONGS = "SHUFFLE_SONGS",
}

SongRandomizer.ArtistScope = {
    PER_RUN = "PER_RUN",
    PER_ZONE = "PER_ZONE",
    PER_FLOOR = "PER_FLOOR",
}

-- How much of the soundtrack may repeat within one shuffle
SongRandomizer.Duplicates = {
    MINIMAL = "MINIMAL",
    PARTIAL = "PARTIAL",
    COMPLETE = "COMPLETE",
}

SongRandomizer.Seeding = {
    PER_CHARACTER = "PER_CHARACTER",
    FULLY_RANDOM = "FULLY_RANDOM",
}

songRandomizerMode = settings.user.string({
    id = "songRandomizerMode",
    visibility = settings.Visibility.HIDDEN,
    default = SongRandomizer.Mode.OFF,
})

songRandomizerArtistScope = settings.user.string({
    id = "songRandomizerArtistScope",
    visibility = settings.Visibility.HIDDEN,
    default = SongRandomizer.ArtistScope.PER_RUN,
})

songRandomizerDuplicates = settings.user.string({
    id = "songRandomizerDuplicates",
    visibility = settings.Visibility.HIDDEN,
    default = SongRandomizer.Duplicates.MINIMAL,
})

songRandomizerSeeding = settings.user.string({
    id = "songRandomizerSeeding",
    visibility = settings.Visibility.HIDDEN,
    default = SongRandomizer.Seeding.PER_CHARACTER,
})

songRandomizerSeed = settings.user.number({
    id = "songRandomizerSeed",
    visibility = settings.Visibility.HIDDEN,
})

-- Excluded rather than included, so characters added later start out randomized
songRandomizerExcludedCharacters = settings.user.table({
    id = "songRandomizerExcludedCharacters",
    visibility = settings.Visibility.HIDDEN,
})

local function areaKey(track)
    if track.type == ZONE then
        return string.format("zone:%d:%d", track.zone or 1, track.floor or track.level or 1)
    elseif track.type == BOSS then
        local variant = track.variant or ""

        return string.format("boss:%d%s", track.boss or 0, variant ~= "" and ":" .. variant or "")
    end

    return track.type
end

local areas = {}
local areasByKey = {}

local function addArea(track, amplified)
    local area = { key = areaKey(track), track = track, amplified = amplified or false }
    areas[#areas + 1] = area
    areasByKey[area.key] = area
end

for zone = 1, 5 do
    for floor = 1, 3 do
        addArea({ type = ZONE, zone = zone, floor = floor }, zone == 5)
    end
end

for _, bossID in ipairs({ boss.Type.KING_CONGA, boss.Type.DEATH_METAL, boss.Type.DEEP_BLUES, boss.Type.CORAL_RIFF,
    boss.Type.DEAD_RINGER, boss.Type.NECRODANCER }) do
    addArea({ type = BOSS, boss = bossID })
end

addArea({ type = BOSS, boss = boss.Type.NECRODANCER, variant = soundtrack.Variant.ALTERNATIVE })
addArea({ type = BOSS, boss = boss.Type.GOLDEN_LUTE })

for _, bossID in ipairs({ boss.Type.FORTISSIMOLE, boss.Type.FRANKENSTEINWAY, boss.Type.CONDUCTOR }) do
    addArea({ type = BOSS, boss = bossID }, true)
end

for _, trackType in ipairs({ soundtrack.TrackType.LOBBY, soundtrack.TrackType.TRAINING, soundtrack.TrackType.TUTORIAL }) do
    addArea({ type = trackType })
end

local NECRODANCER_KEY = areaKey({ type = BOSS, boss = boss.Type.NECRODANCER })
local PHASE_2_KEY = areaKey({ type = BOSS, boss = boss.Type.NECRODANCER, variant = soundtrack.Variant.ALTERNATIVE })

local function listAreas()
    local amplified = gameDLC.isAmplifiedLoaded()
    local result = {}

    for _, area in ipairs(areas) do
        if amplified or not area.amplified then
            result[#result + 1] = area
        end
    end

    return result
end

local stockSongIDs = {}

for songID, data in enum.dataPairs(gameSong.Type) do
    local key = type(data.track) == "table" and areaKey(data.track)

    if key and areasByKey[key] and not stockSongIDs[key] then
        stockSongIDs[key] = songID
    end
end

-- Editor rows beneath a stock row that give its area a song on their own
local SONG_ROWS = {
    [areaKey({ type = BOSS, boss = boss.Type.CORAL_RIFF })] = { "BOSS_CORAL_RIFF_INSTRUMENT_0" },
    [PHASE_2_KEY] = { "BOSS_NECRODANCER_PHASE_2" },
}

for floor = 1, 3 do
    SONG_ROWS[areaKey({ type = ZONE, zone = 3, floor = floor })] = {
        string.format("ZONE_3_%d_HOT", floor),
        string.format("ZONE_3_%d_COLD", floor),
    }
end

-- Rows left on Default or None store no file name
local function isSetInPlaylist(metadata, key)
    local fileNames = type(metadata.songFileNames) == "table" and metadata.songFileNames or {}
    local rowFileNames = metadata[songVariants.FILE_NAMES_KEY]

    if stockSongIDs[key] and fileNames[stockSongIDs[key]] then
        return true
    end

    for _, rowKey in ipairs(SONG_ROWS[key] or {}) do
        local definition = songVariants.getDefinition(rowKey)

        if definition and type(rowFileNames) == "table" and rowFileNames[definition.id] then
            return true
        end
    end

    return false
end

--- Unknown artist values share a placeholder table, so never index it directly
local function getSuffix(artist)
    local data = artist ~= nil and soundtrack.Artist.data[artist]

    return data and data.suffix or ""
end

local function hasBuiltInSong(artist, track)
    local suffix = getSuffix(artist)

    local function exists(name, variant)
        return fileIO.exists(string.format("ext/music/%s%s%s.ogg", name, suffix, variant or ""))
    end

    if track.type == ZONE then
        local name = string.format("zone%d_%d", track.zone, track.floor)

        if track.zone == 3 then
            return exists(name, soundtrack.Variant.HOT) or exists(name, soundtrack.Variant.COLD)
        end

        return exists(name)
    elseif track.type == BOSS then
        -- Danny B's Coral Riff is played from its instruments
        return exists(string.format("boss_%d", track.boss), track.variant)
            or track.boss == boss.Type.CORAL_RIFF and suffix == ""
            and fileIO.exists(string.format("ext/sounds_streaming/boss_%d_inst0.ogg", track.boss))
    end

    return exists(track.type)
end

--- The areas an artist has a song for
--- The areas an artist has a song for, from a playlist id or a Soundtrack.Artist value
function SongRandomizer.listSongs(artist)
    local playlist

    if type(artist) == "string" then
        -- A custom artist is its own playlist, and has its songs whether or not it has an artist value yet
        playlist = registry.isCustom(artist) and artist or nil
        artist = registry.getArtistValue(artist)
    else
        playlist = registry.getPlaylist(artist)
    end

    -- Without either, there is no artist to answer for, and a built-in lookup would fall back to Danny B's files
    if not playlist and artist == nil then
        return {}
    end

    local metadata = playlist and (customMusic.readMetadata(playlist) or {})
    local result = {}

    for _, area in ipairs(listAreas()) do
        local hasSong

        if metadata then
            hasSong = isSetInPlaylist(metadata, area.key)
        else
            hasSong = hasBuiltInSong(artist, area.track)
        end

        if hasSong then
            result[#result + 1] = area
        end
    end

    return result
end

--- Whether an artist has a song for a track, from a playlist id or a Soundtrack.Artist value. The track is shaped
--- like the ones in necro.game.data.Soundtrack, e.g. { type = TrackType.ZONE, zone = 1, floor = 2 }.
function SongRandomizer.hasSong(artist, track)
    if type(track) ~= "table" then
        return false
    end

    local key = areaKey(track)

    for _, area in ipairs(SongRandomizer.listSongs(artist)) do
        if area.key == key then
            return true
        end
    end

    return false
end

function SongRandomizer.countSongs(id)
    return #SongRandomizer.listSongs(id)
end

local function listRandomizedArtists()
    local result = {}

    for _, id in ipairs(registry.listAll()) do
        local artist = registry.getArtistValue(id)

        if artist and registry.isRandomized(id) and not registry.isDeleted(registry.isCustom(id) and id or nil) then
            result[#result + 1] = artist
        end
    end

    return result
end

local cachedArtists, cachedPool, cachedDeal, cachedDealKey = nil, nil, nil, nil
local revision = 0

function SongRandomizer.invalidate()
    cachedArtists, cachedPool, cachedDeal, cachedDealKey = nil, nil, nil, nil
end

local function changed()
    SongRandomizer.invalidate()
    revision = revision + 1
    -- Visuals refresh once a turn, so the shrine would keep its old frame until the next one
    visualUpdate.trigger()
end

-- Reaching the registry directly, as ArtistRegistry.setMetadata does, has to drop these caches as well
registry.addChangeListener(changed)

function SongRandomizer.setRandomized(id, randomized)
    registry.setRandomized(id, randomized)
end

function SongRandomizer.isCharacterRandomized(character)
    return not (type(songRandomizerExcludedCharacters) == "table" and character ~= nil
        and songRandomizerExcludedCharacters[character])
end

function SongRandomizer.setCharacterRandomized(character, randomized)
    local excluded = utils.fastCopy(type(songRandomizerExcludedCharacters) == "table" and
    songRandomizerExcludedCharacters or {})
    excluded[character] = not randomized or nil
    songRandomizerExcludedCharacters = excluded
    changed()
end

function SongRandomizer.getMode()
    return SongRandomizer.Mode[songRandomizerMode] and songRandomizerMode or SongRandomizer.Mode.OFF
end

function SongRandomizer.setMode(mode)
    songRandomizerMode = mode
    changed()
end

function SongRandomizer.getArtistScope()
    return SongRandomizer.ArtistScope[songRandomizerArtistScope] and songRandomizerArtistScope
        or SongRandomizer.ArtistScope.PER_RUN
end

function SongRandomizer.setArtistScope(scope)
    songRandomizerArtistScope = scope
    changed()
end

function SongRandomizer.getDuplicates()
    return SongRandomizer.Duplicates[songRandomizerDuplicates] and songRandomizerDuplicates
        or SongRandomizer.Duplicates.MINIMAL
end

function SongRandomizer.setDuplicates(duplicates)
    songRandomizerDuplicates = duplicates
    changed()
end

function SongRandomizer.getSeeding()
    return SongRandomizer.Seeding[songRandomizerSeeding] and songRandomizerSeeding or
    SongRandomizer.Seeding.PER_CHARACTER
end

function SongRandomizer.setSeeding(seeding)
    songRandomizerSeeding = seeding
    changed()
end

--- Gives every character a new per-character shuffle
function SongRandomizer.reshuffle()
    songRandomizerSeed = math.floor(timer.getGlobalTime() * 1000000) % 2147483647
    changed()
end

local configSelector = orderedSelector.new(event.customArtistsSongRandomizer, { "override" })

--- The settings a track is randomized with. Handlers may change any field.
function SongRandomizer.getConfig()
    local config = {
        mode = SongRandomizer.getMode(),
        artistScope = SongRandomizer.getArtistScope(),
        duplicates = SongRandomizer.getDuplicates(),
        seeding = SongRandomizer.getSeeding(),
        seed = songRandomizerSeed,
        allCharacters = false,
        -- A handler that changes any of the above can name itself here, for the menu to say who is responsible
        source = nil,
    }

    configSelector.fire(config)

    return config
end

--- True while another mod has changed the settings from the menu's, followed by the name that mod gave itself, if
--- it gave one. Naming itself alone is not an override; the settings have to differ.
function SongRandomizer.isOverridden()
    local config = SongRandomizer.getConfig()
    local overridden = config.mode ~= SongRandomizer.getMode() or config.seeding ~= SongRandomizer.getSeeding()
        or config.artistScope ~= SongRandomizer.getArtistScope() or config.duplicates ~= SongRandomizer.getDuplicates()
        or config.seed ~= songRandomizerSeed or config.allCharacters ~= false

    if not overridden or type(config.source) ~= "string" or config.source == "" then
        return overridden, nil
    end

    return true, config.source
end

local function hashChannel(...)
    local parts = {}

    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end

    local key = table.concat(parts, "-")
    local seed = 0

    for i = 1, #key do
        seed = (seed * 31 + key:byte(i)) % 2147483647
    end

    return rng.makeChannel(seed)
end

local function getCharacter()
    return player.getCharacterType() or playerList.getCharacter()
end

local function getArtists()
    if not cachedArtists then
        cachedArtists = listRandomizedArtists()
    end

    return cachedArtists
end

local function getPool()
    if not cachedPool then
        cachedPool = {}

        for _, artist in ipairs(getArtists()) do
            for _, area in ipairs(SongRandomizer.listSongs(artist)) do
                cachedPool[#cachedPool + 1] = { artist = artist, area = area }
            end
        end
    end

    return cachedPool
end

local function isZone3(track)
    return track.type == ZONE and track.zone == 3
end

local function hasMix(artist, track, variant)
    local playlist = registry.getPlaylist(artist)

    if playlist then
        local lookup = registry.getLookup(playlist)

        return lookup ~= nil and lookup(string.format("music/zone3_%d%s.ogg", track.floor, variant)) ~= nil
    end

    return fileIO.exists(string.format("ext/music/zone3_%d%s%s.ogg", track.floor, getSuffix(artist), variant))
end

--- Away from zone 3, a zone 3 song plays one of its two mixes
local function pickMix(entry, area, channel)
    if not isZone3(entry.area.track) or isZone3(area.track) then
        return nil
    end

    local hot = hasMix(entry.artist, entry.area.track, soundtrack.Variant.HOT)
    local cold = hasMix(entry.artist, entry.area.track, soundtrack.Variant.COLD)

    if hot and cold then
        return rng.int(2, channel) == 0 and soundtrack.Variant.HOT or soundtrack.Variant.COLD
    end

    return cold and soundtrack.Variant.COLD or soundtrack.Variant.HOT
end

--- Which song, by which artist, plays in each area
local function getDeal(config)
    local pool = getPool()

    if #pool == 0 then
        return nil
    end

    local dealKey

    if config.seeding == SongRandomizer.Seeding.FULLY_RANDOM then
        dealKey = "run-" .. tostring(rng.getDungeonSeed())
    else
        dealKey = string.format("character-%s-%s", tostring(config.seed), tostring(getCharacter()))
    end

    -- Allowing duplicates deals a different set of songs, so it can't reuse a deal made without them
    local allowDuplicates = config.duplicates == SongRandomizer.Duplicates.COMPLETE
    local oncePerSong = config.duplicates == SongRandomizer.Duplicates.MINIMAL

    -- Each setting deals a different set of songs, so a deal can't be reused across them
    dealKey = string.format("%s-%s", dealKey, tostring(config.duplicates))

    if not cachedDeal or cachedDealKey ~= dealKey then
        local channel = hashChannel(dealKey)
        local deal, deck, dealtSongs = {}, {}, {}

        -- One of each song until the pool runs out, then it is dealt again. Counting versions of a song as one card
        -- leaves cards nothing can be dealt to this round, which are discarded until the deck runs out and refills.
        local function draw()
            while true do
                if #deck == 0 then
                    for i = 1, #pool do
                        deck[i] = i
                    end

                    rng.shuffle(deck, channel)

                    dealtSongs = {}
                end

                local entry = pool[table.remove(deck)]

                if not oncePerSong then
                    return entry
                elseif not dealtSongs[entry.area.key] then
                    dealtSongs[entry.area.key] = true

                    return entry
                end
            end
        end

        for _, area in ipairs(listAreas()) do
            local entry

            if allowDuplicates then
                entry = pool[rng.int(#pool, channel) + 1]
            else
                entry = draw()
            end

            deal[area.key] = { artist = entry.artist, area = entry.area, mix = pickMix(entry, area, channel) }
        end

        cachedDeal, cachedDealKey = deal, dealKey
    end

    return cachedDeal
end

--- The areas that share one rolled artist: the whole run, the zone, or the area alone
local function getScopeKey(config, ev, key)
    local scope = config.artistScope

    if scope == SongRandomizer.ArtistScope.PER_RUN then
        return "run"
    elseif scope == SongRandomizer.ArtistScope.PER_ZONE then
        -- A boss fight belongs to the zone it is played in; the lobby and its kind stay on their own
        local zone = ev.type == ZONE and ev.zone or ev.type == BOSS and currentLevel.getZone()

        return zone and "zone:" .. zone or key
    end

    return key
end

local function pickArtist(config, ev, key)
    local artists = getArtists()

    if #artists == 0 then
        return nil
    end

    local channel = hashChannel(rng.getDungeonSeed(), getScopeKey(config, ev, key))

    return artists[rng.int(#artists, channel) + 1]
end

local function getActiveConfig(ev)
    if ev.deterministic or ev.disableSubstitutions or currentLevel.getBossType() == boss.Type.NECRODANCER_2 then
        return nil
    end

    local key = areaKey(ev)

    if not areasByKey[key] then
        return nil
    end

    local config = SongRandomizer.getConfig()

    if not SongRandomizer.Mode[config.mode] or config.mode == SongRandomizer.Mode.OFF
        or not config.allCharacters and not SongRandomizer.isCharacterRandomized(getCharacter())
    then
        return nil
    end

    return config, key
end

-- Runs before the stock custom music override and every handler that builds files from the track
event.musicTrack.add("randomizeCustomArtistsTrack", { order = "customMusic", sequence = -1 }, function(ev)
    local config, key = getActiveConfig(ev)

    if not config then
        return
    end

    if config.mode == SongRandomizer.Mode.SHUFFLE_SONGS then
        local deal = getDeal(config)
        local dealt = deal and deal[key]

        if not dealt then
            return
        end

        local track = dealt.area.track
        ev.CustomArtists_area = areasByKey[key]
        ev.CustomArtists_deal = deal
        ev.CustomArtists_dealt = dealt
        ev.type, ev.zone, ev.floor, ev.level, ev.boss = track.type, track.zone, track.floor, nil, track.boss
        ev.variant = track.variant or soundtrack.Variant.DEFAULT
        ev.artist = dealt.artist
    else
        ev.artist = pickArtist(config, ev, key) or ev.artist
    end

    ev.CustomArtists_randomArtist = ev.artist
end)

-- A loaded Custom Music playlist replaces every track's artist and files
event.musicTrack.add("keepRandomizedArtist", { order = "customMusic", sequence = 1 }, function(ev)
    if ev.CustomArtists_randomArtist then
        ev.artist = ev.CustomArtists_randomArtist

        if customMusic.isAnyPlaylistLoaded() then
            ev.disableSubstitutions = true
        end
    end
end)

--- A song's single file and beatmap, falling back to Danny B's
local function getSingleSong(dealt)
    local track = dealt.area.track
    local base, variant

    if track.type == ZONE then
        base = string.format("zone%d_%d", track.zone, track.floor)
        variant = isZone3(track) and (dealt.mix or soundtrack.Variant.HOT) or ""
    elseif track.type == BOSS then
        base, variant = string.format("boss_%d", track.boss), track.variant or ""
    else
        base, variant = track.type, ""
    end

    -- Both zone 3 mixes share the floor's beatmap
    local chart = track.type == ZONE and base or base .. variant
    local playlist = registry.getPlaylist(dealt.artist)

    if playlist then
        local lookup = registry.getLookup(playlist)
        local song = nil

        if lookup and isZone3(track) then
            local hot, cold = songVariants.getZone3Songs(lookup, track.floor)
            song = variant == soundtrack.Variant.COLD and cold or hot
        elseif lookup then
            song = lookup(string.format("music/%s%s.ogg", base, variant))
        end

        local beatmap = lookup and songVariants.firstBeatmap(lookup(string.format("music/%s.txt", chart)))

        if song and beatmap then
            return song, beatmap
        end
    else
        local suffix = getSuffix(dealt.artist)
        local chartWithSuffix = track.type == ZONE and base .. suffix or base .. suffix .. variant
        local song = string.format("ext/music/%s%s%s.ogg", base, suffix, variant)
        local beatmap = string.format("ext/music/%s.txt", chartWithSuffix)

        if fileIO.exists(song) then
            return song, fileIO.exists(beatmap) and beatmap or string.format("ext/music/%s.txt", chart)
        end
    end

    return string.format("ext/music/%s%s.ogg", base, variant), string.format("ext/music/%s.txt", chart)
end

-- The NecroDancer's second phase is an area of its own, so its layer plays the song dealt there
event.musicTrack.add("shuffleNecroDancerPhase2", { order = "extraLayers", sequence = 4 }, function(ev)
    local area = ev.CustomArtists_area

    if not area or area.key ~= NECRODANCER_KEY or currentLevel.getBossType() ~= boss.Type.NECRODANCER then
        return
    end

    local dealt = ev.CustomArtists_deal[PHASE_2_KEY]

    if not dealt then
        return
    end

    utils.removeIf(ev.layers, function(layer)
        return layer.type == LayerType.PHASE_2
    end)

    local song, beatmap = getSingleSong(dealt)

    ev.layers[#ev.layers + 1] = {
        file = song,
        beatmap = beatmap,
        timeOffset = 0,
        type = LayerType.PHASE_2,
    }
end)

local MIX_LAYERS = bit.bor(LayerType.HOT, LayerType.COLD)
local TENTACLE_LAYERS = {}

for i = 2, #songVariants.CORAL_RIFF_LAYERS do
    TENTACLE_LAYERS[songVariants.CORAL_RIFF_LAYERS[i]] = true
end

event.musicTrack.add("finalizeShuffledTrack", { order = "layerFallback", sequence = 1 }, function(ev)
    local dealt = ev.CustomArtists_dealt

    if not dealt then
        return
    end

    local playsIn = ev.CustomArtists_area and ev.CustomArtists_area.track or {}

    if playsIn.type == ZONE then
        ev.loop = nil
    elseif playsIn.type == BOSS then
        ev.loop = playsIn.boss ~= boss.Type.NECRODANCER_2
    else
        ev.loop = true
    end

    if dealt.mix then
        local keep = dealt.mix == soundtrack.Variant.HOT and LayerType.HOT or LayerType.COLD

        utils.removeIf(ev.layers, function(layer)
            local mixes = bit.band(layer.type or 0, MIX_LAYERS)

            if mixes == 0 then
                return false
            elseif bit.band(mixes, keep) == 0 then
                return true
            end

            layer.type = bit.band(layer.type, bit.bnot(MIX_LAYERS))
            layer.volume = 1

            return false
        end)

        ev.layerVolumeCorrection = nil
    end

    -- Away from the fight no tentacle unmutes its instrument, so every instrument plays as the main song
    if currentLevel.getBossType() ~= boss.Type.CORAL_RIFF then
        for _, layer in ipairs(ev.layers) do
            if TENTACLE_LAYERS[layer.type] then
                layer.type = LayerType.MAIN
            end
        end
    end

    if currentLevel.getBossType() ~= boss.Type.NECRODANCER then
        utils.removeIf(ev.layers, function(layer)
            return layer.type == LayerType.PHASE_2
        end)
    end
end)

local lastLobbySignature = nil

local function getLobbySignature()
    if not gameState.isInLobby() then
        return nil
    end

    local config = SongRandomizer.getConfig()

    return table.concat({
        tostring(config.mode),
        tostring(config.artistScope),
        tostring(config.duplicates),
        tostring(config.seeding),
        tostring(config.seed),
        tostring(config.allCharacters),
        tostring(SongRandomizer.isCharacterRandomized(getCharacter())),
        tostring(getCharacter()),
        tostring(revision),
    }, "/")
end

-- Only in the lobby: restarting a song during a run would drop players off the beat
event.tick.add("refreshSongRandomizerLobbyMusic", { order = "lobby", sequence = 5 }, function()
    local signature = getLobbySignature()

    if signature == lastLobbySignature then
        return
    end

    local wasInLobby = lastLobbySignature ~= nil
    lastLobbySignature = signature

    if signature and wasInLobby and music.isActive() and music.getParameters() then
        music.setMusic(music.getParameters(), 0.6)
    end
end)

event.dlcStatusChange.add("invalidateSongRandomizerPool", "clearCache", function()
    SongRandomizer.invalidate()
end)

-- Songs and artists are edited in these menus
event.menu.add("invalidateSongRandomizerPoolOnSongEdit", { key = "customMusic", sequence = 3 }, function()
    SongRandomizer.invalidate()
end)

event.menu.add("invalidateSongRandomizerPoolOnArtistGrid", { key = "CustomArtists_grid", sequence = 3 }, function()
    SongRandomizer.invalidate()
end)

return SongRandomizer
