local customMusic = require "necro.game.data.resource.CustomMusic"
local gameSong = require "necro.game.data.resource.GameSong"
local music = require "necro.audio.Music"
local soundtrack = require "necro.game.data.Soundtrack"

local ecs = require "system.game.Entities"
local enum = require "system.utils.Enum"
local utils = require "system.utils.Utilities"

local registry = require "CustomArtists.scripts.ArtistRegistry"
local songVariants = require "CustomArtists.scripts.SongVariants"
local titleTable = require "CustomArtists.scripts.SongTitleTable"

-- Title and artist of each song. A custom artist's are set from the song editor's right-click menu and kept in
-- playlist.json under customArtist.songs, keyed by GameSong.Type name, the same IDs the editor gives its rows. The
-- stock soundtracks answer from SongTitleTable.
local SongInfo = {}

SongInfo.FIELDS = { "title", "artist" }

local function getSongTable(metadata, create)
    if type(metadata) ~= "table" then
        return nil
    end

    if type(metadata.customArtist) ~= "table" then
        if not create then
            return nil
        end

        metadata.customArtist = { description = "" }
    end

    local info = metadata.customArtist

    if type(info.songs) ~= "table" then
        if not create then
            return nil
        end

        info.songs = {}
    end

    return info.songs
end

--- Only the known fields, and only when at least one is set
local function copyInfo(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local result, found = {}, false

    for _, field in ipairs(SongInfo.FIELDS) do
        if type(entry[field]) == "string" and entry[field] ~= "" then
            result[field] = entry[field]
            found = true
        end
    end

    return found and result or nil
end

local function getTrackKey(track)
    if track.type == songVariants.TRACK_TYPE then
        local definition = songVariants.getDefinition(track.CustomArtists_songVariant)

        return definition and definition.id
    end

    -- Phase 2 and Fortissimole's other versions play as their fight's track with a variant
    if type(track.variant) == "string" and track.variant ~= "" then
        local file = songVariants.getStockSongFile(track)

        for _, definition in ipairs(songVariants.list()) do
            if (definition.kind == "phase2" or definition.kind == "version") and definition.file == file then
                return definition.id
            end
        end
    end

    local floor = track.floor or track.level or 1

    for songID, data in enum.dataPairs(gameSong.Type) do
        local songTrack = data.track
        local isZone = songTrack and songTrack.type == soundtrack.TrackType.ZONE
        local isBoss = songTrack and songTrack.type == soundtrack.TrackType.BOSS

        if type(songTrack) == "table" and songTrack.type == track.type
            and (not isZone or songTrack.zone == track.zone and songTrack.floor == floor)
            and (not isBoss or songTrack.boss == track.boss) then
            return gameSong.Type.names[songID]
        end
    end
end

--- The key a song is stored under, from a GameSong.Type name or value, or a track as Soundtrack.getTrack and
--- event.musicPlay pass them. Nil if no editor row matches.
function SongInfo.getSongKey(song)
    if type(song) == "number" then
        return gameSong.Type.names[song]
    elseif type(song) == "string" then
        return gameSong.Type[song] and song or nil
    elseif type(song) == "table" then
        return getTrackKey(song)
    end
end

--- Reads a song's info from a playlist.json table, such as the one the song editor holds while it is open
function SongInfo.fromMetadata(metadata, song)
    local songs = getSongTable(metadata)
    local key = SongInfo.getSongKey(song)

    return songs and key and copyInfo(songs[key]) or nil
end

--- Changes the given fields of a song in a playlist.json table without saving it. An empty string clears a field;
--- a field left out keeps its value.
function SongInfo.setInMetadata(metadata, song, fields)
    local key = SongInfo.getSongKey(song)
    local songs = key and type(fields) == "table" and getSongTable(metadata, true)

    if not songs then
        return false
    end

    local entry = copyInfo(songs[key]) or {}

    for _, field in ipairs(SongInfo.FIELDS) do
        if type(fields[field]) == "string" then
            entry[field] = fields[field]
        end
    end

    songs[key] = copyInfo(entry)

    return true
end

function SongInfo.clearInMetadata(metadata, song)
    local songs = getSongTable(metadata)
    local key = SongInfo.getSongKey(song)

    if songs and key then
        songs[key] = nil
    end
end

--- The name the song editor gives a song's row, such as "Zone 1-1", which stands in for a song's unset title
function SongInfo.getDefaultTitle(song)
    local key = SongInfo.getSongKey(song)
    local data = key and gameSong.Type.data[gameSong.Type[key]]

    if not data then
        return nil
    end

    local entity = data.entity and ecs.getEntityPrototype(data.entity)
    local name = data.name or entity and entity.friendlyName and entity.friendlyName.name

    return tostring(name or key)
end

--- A custom artist's own author, or its name without one, which stands in for a song's unset artist
function SongInfo.getDefaultArtist(metadata)
    if type(metadata) ~= "table" then
        return nil
    elseif type(metadata.author) == "string" and metadata.author ~= "" then
        return metadata.author
    end

    return type(metadata.displayName) == "string" and metadata.displayName ~= "" and metadata.displayName or nil
end

--- A song's info from a playlist.json table with its unset fields filled in
function SongInfo.withDefaults(metadata, song, info)
    local key = SongInfo.getSongKey(song)

    if not key then
        return nil
    end

    return copyInfo({
        title = info and info.title or SongInfo.getDefaultTitle(key),
        artist = info and info.artist or SongInfo.getDefaultArtist(metadata),
    })
end

local function readMetadata(artist)
    local id = registry.toID(artist)

    return id and registry.isCustom(id) and customMusic.readMetadata(id) or nil, id
end

--- The Soundtrack.Artist value of a stock soundtrack SongTitleTable covers, or nil
local function getBuiltInArtist(id)
    if id == nil or registry.isCustom(id) then
        return nil
    end

    local value = registry.getArtistValue(id)

    return value and titleTable.soundtracks[value] and value or nil
end

--- The track a song key plays, with the variant an added row stands for
local function getSongTrack(key)
    local definition = key and songVariants.getDefinitionByID(key)
    local songID = definition and definition.parentID or key and gameSong.Type[key]
    local data = songID and gameSong.Type.data[songID]

    if not (data and type(data.track) == "table") then
        return nil
    end

    local track = utils.fastCopy(data.track)
    track.variant = definition and definition.variant or track.variant

    return track
end

local function getBuiltInInfo(artist, track)
    return copyInfo(titleTable.get(artist, track))
end

local playing = nil

local function resolvePlayingInfo()
    if playing then
        playing.info = SongInfo.getForTrack(playing.artist, playing.track)
    end
end

--- Writes a playlist.json table back, and refreshes what getPlaying reports
local function save(id, metadata)
    customMusic.writeMetadata(id, metadata)
    resolvePlayingInfo()
end

--- A song's { title, artist }, or nil when neither is known. artist is an artist ID or Soundtrack.Artist value. A
--- custom artist answers from its playlist.json (see withDefaults), a stock soundtrack from SongTitleTable.
function SongInfo.get(artist, song)
    if type(song) == "table" then
        return SongInfo.getForTrack(artist, song)
    end

    local metadata, id = readMetadata(artist)
    local builtIn = getBuiltInArtist(id)

    if builtIn then
        local track = getSongTrack(SongInfo.getSongKey(song))

        return track and getBuiltInInfo(builtIn, track)
    end

    return metadata and SongInfo.withDefaults(metadata, song, SongInfo.fromMetadata(metadata, song))
end

--- Every song of the artist that has info, as { [song key] = { title, artist } }
function SongInfo.list(artist)
    local result = {}
    local metadata, id = readMetadata(artist)

    if getBuiltInArtist(id) then
        for songID in enum.dataPairs(gameSong.Type) do
            local key = gameSong.Type.names[songID]

            result[key] = SongInfo.get(id, key)
        end
    else
        for key, entry in pairs(getSongTable(metadata) or {}) do
            result[key] = SongInfo.withDefaults(metadata, key, copyInfo(entry))
        end
    end

    return result
end

--- Saves the given fields of a song (see setInMetadata). False for a built-in artist or an unknown song.
function SongInfo.set(artist, song, fields)
    local metadata, id = readMetadata(artist)

    if not (metadata and SongInfo.setInMetadata(metadata, song, fields)) then
        return false
    end

    save(id, metadata)

    return true
end

function SongInfo.clear(artist, song)
    local metadata, id = readMetadata(artist)

    if not (metadata and SongInfo.getSongKey(song)) then
        return false
    end

    SongInfo.clearInMetadata(metadata, song)
    save(id, metadata)

    return true
end

--- Info for a track an artist plays. Zone 3 floors play their Hot and Cold songs together, so either of those rows
--- answers for its floor when the floor's own row has none.
function SongInfo.getForTrack(artist, track)
    if type(track) ~= "table" then
        return nil
    end

    local metadata, id = readMetadata(artist)
    local builtIn = getBuiltInArtist(id)

    if builtIn then
        return getBuiltInInfo(builtIn, track)
    end

    local key = SongInfo.getSongKey(track)

    if not (metadata and key) then
        return nil
    end

    local info = SongInfo.fromMetadata(metadata, key)

    for _, mix in ipairs({ "HOT", "COLD" }) do
        local definition = songVariants.getDefinition(key .. "_" .. mix)

        info = info or definition and SongInfo.fromMetadata(metadata, definition.id)
    end

    return SongInfo.withDefaults(metadata, key, info)
end

--- The song info of the music playing now, then the artist ID and song key. Nil while the music is stopped; the info
--- alone is nil for a song nothing is known about.
function SongInfo.getPlaying()
    if playing and music.isActive() then
        return playing.info, playing.artist, playing.key
    end
end

--- Rereads the playing song's info, for code that saved playlist.json itself
SongInfo.refreshPlaying = resolvePlayingInfo

-- The track here has been through every event.musicTrack handler, so its artist is the one actually playing: the song
-- randomizer has picked it, and an artist without the song has fallen back to Danny B
event.musicPlay.add("trackCustomArtistSong", { order = "playAudio", sequence = 1 }, function(ev)
    local track = ev.track
    local artist = type(track) == "table" and (track.CustomArtists_playlist or registry.toID(track.artist))

    playing = artist and {
        artist = artist,
        key = SongInfo.getSongKey(track),
        track = track,
    } or nil

    resolvePlayingInfo()
end)

return SongInfo
