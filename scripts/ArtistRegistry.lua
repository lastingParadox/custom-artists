local customMusic = require "necro.game.data.resource.CustomMusic"
local player = require "necro.game.character.Player"
local settings = require "necro.config.Settings"
local soundtrack = require "necro.game.data.Soundtrack"

local enum = require "system.utils.Enum"
local fileIO = require "system.game.FileIO"
local json = require "system.utils.serial.JSON"
local utils = require "system.utils.Utilities"

local resourcePacks = require "CustomArtists.scripts.ResourcePacks"

local ArtistRegistry = {}

-- Local playlists ("res_<dir>") stay readable at this path even while unloaded (see AssetMod.Source.LOCAL)
local LOCAL_PLAYLIST_PREFIX = "res_"
local LOCAL_PLAYLIST_PATH = "ext/mods/"

-- Artist IDs are either a playlist name (custom) or this prefix plus a Soundtrack.Artist key (built-in)
local BUILT_IN_PREFIX = "builtin:"

local GFX_PATH = "mods/CustomArtists/gfx/"

local VANILLA_ORDER = {
    "DANNY_B",
    "A_RIVAL",
    "FAMILYJULES7X",
    "VIRT",
    "GIRLFRIEND_RECORDS",
    "OC_REMIX",
    "CHIPZEL",
    "HATSUNE_MIKU",
    "SHOVEL_KNIGHT",
    "DANGANRONPA",
    "GROOVE_COASTER",
}

local vanillaOrderIndex = {}

for index, key in ipairs(VANILLA_ORDER) do
    vanillaOrderIndex[key] = index
end

--- Position of a built-in artist in the vanilla music pack order; artists added by other mods sort last
function ArtistRegistry.getVanillaOrder(id)
    return vanillaOrderIndex[tostring(id):sub(#BUILT_IN_PREFIX + 1)] or #VANILLA_ORDER + 1
end

-- Descriptions summarized from https://necrodancer.miraheze.org; image is the base name of gfx/<image>.png and gfx/<image>_banner.png
local BUILT_IN_ARTISTS = {
    DANNY_B = {
        title = "Danny B",
        author = "Danny Baranowsky",
        image = "danny_b",
        description =
        "Crypt of the NecroDancer OST. The game's original \"Spookhouse Rock\" soundtrack, and the base that most other soundtracks remix. Cadence's default soundtrack.",
    },
    A_RIVAL = {
        title = "A Rival",
        author = "Luke Alex \"A_Rival\" Esquivel",
        image = "a_rival",
        description =
        "Crypt of the NecroDancer: The Melody Mixes. This album reimagines the original soundtrack with an EDM focus. Melody's default soundtrack.",
    },
    FAMILYJULES7X = {
        title = "FamilyJules",
        author = "Jules \"FamilyJules7x\" Conroy",
        image = "family_jules_7x",
        description =
        "Aria's Ascent. Metal remixes of the original soundtrack, with new names for its tracks and a rare polka easter egg song for Death Metal. Aria's default soundtrack.",
    },
    VIRT = {
        title = "Virt",
        author = "Jake \"Virt\" Kaufman",
        image = "virt",
        description =
        "Crypt of the NecroDancer: Freestyle Retro. Chiptune remixes of the original soundtrack where every melody, solo and bass line was improvised and played by hand. Eli's default soundtrack.",
    },
    GIRLFRIEND_RECORDS = {
        title = "Girlfriend Records",
        author = "Johnatron, Sferro & Tommy '86",
        image = "girlfriend_records",
        description =
        "Crypt of the NecroDancer: The Synthwave Cuts. Synthwave remixes of the original soundtrack by three members of the Girlfriend Records label, with a different Fortissimole version from each. Bard's default soundtrack.",
    },
    OC_REMIX = {
        title = "OC ReMix",
        author = "Various OC ReMix artists",
        image = "oc_remix",
        description =
        "Crypt of the NecroDancer: OverClocked. Remixes of the original soundtrack by members of the OC ReMix community, released with the Amplified DLC. Nocturna's default soundtrack.",
    },
    CHIPZEL = {
        title = "Chipzel",
        author = "Niamh \"Chipzel\" Houston",
        image = "chipzel",
        description =
        "Chipped of the NecroDancer. Chiptune remixes of the original soundtrack made primarily on a Game Boy using LSDj. Dorian's default soundtrack.",
    },
    DANGANRONPA = {
        title = "Danganronpa",
        author = "Masafumi Takada",
        image = "danganronpa",
        description =
        "Crypt of the NecroDancer: Danganronpa. Remixes of the original soundtrack using Danganronpa songs that fit its BPMs and song lengths, so they work with leaderboards and multiplayer. Does not natively support AMPLIFIED soundtracks.",
    },
    GROOVE_COASTER = {
        title = "Groove Coaster",
        author = "ZUNTATA & various artists",
        image = "groove_coaster",
        description =
        "Crypt of the NecroDancer: Groove Coaster. Edited versions of songs from or featured in the Japanese arcade game Groove Coaster to fit with the original soundtrack's BPMs and song lengths. The only soundtrack to be exclusively available on Playstation and Switch versions of Crypt of the NecroDancer. Does not natively support AMPLIFIED soundtracks."
    },
    HATSUNE_MIKU = {
        title = "Hatsune Miku",
        author = "Hatsune Miku & various artists",
        image = "hatsune_miku",
        description =
        "Crypt of the NecroDancer: Hatsune Miku. Classic songs featuring Hatsune Miku, plus original tracks by Danny Baranowsky. The songs don't fit the original BPMs, so they count as alternate rhythm. Hatsune Miku's default soundtrack.",
    },
    SHOVEL_KNIGHT = {
        title = "Shovel Knight",
        author = "Jake \"Virt\" Kaufman & Manami Matsumae",
        image = "shovel_knight",
        description =
        "Songs from the Shovel of Hope and King of Cards soundtracks by Jake Kaufman. The songs don't fit the original BPMs and loop, so they count as alternate rhythm. Shovel Knight's default soundtrack.",
    },
}

-- Artists left out of the Song Randomizer
disabledArtists = settings.user.table({
    id = "disabledArtists",
    visibility = settings.Visibility.HIDDEN,
})

-- Artists left out of the Change Soundtrack menu
hiddenArtists = settings.user.table({
    id = "hiddenArtists",
    visibility = settings.Visibility.HIDDEN,
})

local artistByPlaylist = {}

-- Enum data lookups for unknown values return a shared placeholder table that must never be written to
local emptyArtistData = soundtrack.Artist.data[-1000000]

local function getArtistData(value)
    local data = value ~= nil and soundtrack.Artist.data[value]

    return data ~= emptyArtistData and data or nil
end

local function getArtistInfo(metadata)
    return type(metadata) == "table" and type(metadata.customArtist) == "table" and metadata.customArtist or nil
end

function ArtistRegistry.isCustom(id)
    return type(id) == "string" and id:sub(1, #BUILT_IN_PREFIX) ~= BUILT_IN_PREFIX
end

local function getBuiltInKey(id)
    return tostring(id):sub(#BUILT_IN_PREFIX + 1)
end

local function getBuiltInInfo(id)
    return not ArtistRegistry.isCustom(id) and BUILT_IN_ARTISTS[getBuiltInKey(id)] or nil
end

--- Every local Custom Music playlist is a custom artist
function ArtistRegistry.listPlaylists()
    return customMusic.listPlaylists()
end

local function getOriginalExcludeFromOptions(data)
    if data.CustomArtists_originalExclude == nil then
        data.CustomArtists_originalExclude = data.excludeFromOptions or false
    end

    return data.CustomArtists_originalExclude
end

--- The artist's own order, kept from before applyChangeSoundtrackOverrides moved it. False stands for "no order",
--- which is not the same as never having been recorded.
local function getOriginalOrder(data)
    if data.CustomArtists_originalOrder == nil then
        data.CustomArtists_originalOrder = data.order or false
    end

    return data.CustomArtists_originalOrder or nil
end

--- Where the stock Change Soundtrack menu sorts an artist: its order, or its enum value when it has none
local function getMenuOrder(artist, data)
    return tonumber(getOriginalOrder(data) or artist) or 0
end

function ArtistRegistry.listBuiltIn()
    local result = {}

    for _, value in ipairs(soundtrack.Artist.valueList) do
        local data = getArtistData(value)

        if data and not data.internal and not getOriginalExcludeFromOptions(data) and not data.CustomArtists_playlist and soundtrack.isArtistAvailable(value) then
            result[#result + 1] = BUILT_IN_PREFIX .. soundtrack.Artist.names[value]
        end
    end

    return result
end

function ArtistRegistry.listAll()
    return utils.concatArrays(ArtistRegistry.listBuiltIn(), ArtistRegistry.listPlaylists())
end

function ArtistRegistry.getTitle(id)
    if ArtistRegistry.isCustom(id) then
        local metadata = customMusic.readMetadata(id)

        return tostring(metadata and metadata.displayName or id)
    end

    local key = getBuiltInKey(id)
    local info = BUILT_IN_ARTISTS[key]

    return info and info.title or tostring(soundtrack.Artist.prettyNames[soundtrack.Artist[key]] or key)
end

function ArtistRegistry.getDescription(id)
    if ArtistRegistry.isCustom(id) then
        local info = getArtistInfo(customMusic.readMetadata(id))

        return tostring(info and info.description or "")
    end

    local info = getBuiltInInfo(id)

    return info and info.description or "Built-in soundtrack"
end

function ArtistRegistry.getAuthor(id)
    if ArtistRegistry.isCustom(id) then
        local metadata = customMusic.readMetadata(id)

        return type(metadata) == "table" and type(metadata.author) == "string" and metadata.author or nil
    end

    local info = getBuiltInInfo(id)

    return info and info.author
end

local function getExistingPath(path)
    return type(path) == "string" and fileIO.exists(path) and path or nil
end

--- Returns the path of an image inside the playlist folder, if it exists
local function getFolderImage(playlist, fileName)
    local basePath = ArtistRegistry.getBasePath(playlist)

    if basePath and type(fileName) == "string" and fileName ~= "" then
        return getExistingPath(basePath .. fileName)
    end
end

--- The "icon" entry of workshop.json, which the stock mod grid uses for resource pack and playlist icons
local function getWorkshopIcon(playlist)
    local basePath = ArtistRegistry.getBasePath(playlist)
    local data = basePath and fileIO.readFileToString(basePath .. "workshop.json")
    local success, workshop = pcall(json.decode, data)

    return success and type(workshop) == "table" and getFolderImage(playlist, workshop.icon) or nil
end

--- An image named after the playlist folder and placed next to it, the stock grid's other icon source
local function getSiblingImage(playlist)
    local basePath = ArtistRegistry.getBasePath(playlist)

    if basePath then
        local folder = basePath:sub(1, -2)

        return getExistingPath(folder .. ".png") or getExistingPath(folder .. ".jpg")
    end
end

--- Lists the image files directly inside a playlist folder, for picking an icon or banner
function ArtistRegistry.listFolderImages(playlist)
    local basePath = ArtistRegistry.getBasePath(playlist)

    return basePath and resourcePacks.listFileNames(basePath, resourcePacks.IMAGE_EXTENSIONS) or {}
end

-- metadata optionally replaces the saved playlist.json contents, e.g. to preview unsaved edits.
function ArtistRegistry.getIcon(id, metadata)
    if ArtistRegistry.isCustom(id) then
        local info = getArtistInfo(metadata or customMusic.readMetadata(id))

        return getFolderImage(id, info and info.icon) or getWorkshopIcon(id) or getSiblingImage(id)
            or getFolderImage(id, "icon.png")
    end

    local info = getBuiltInInfo(id)

    return info and info.image and GFX_PATH .. info.image .. ".png"
end

--- Returns a banner image path for the artist, or nil if it has none (metadata as in getIcon)
function ArtistRegistry.getBanner(id, metadata)
    if ArtistRegistry.isCustom(id) then
        local info = getArtistInfo(metadata or customMusic.readMetadata(id))

        return getFolderImage(id, info and info.banner) or getFolderImage(id, "banner.png")
    end

    local info = getBuiltInInfo(id)

    return info and info.image and GFX_PATH .. info.image .. "_banner.png"
end

function ArtistRegistry.isRandomized(id)
    return not (type(disabledArtists) == "table" and disabledArtists[id])
end

function ArtistRegistry.isHidden(id)
    return type(hiddenArtists) == "table" and hiddenArtists[id] == true
end

--- Maps an artist ID to its Soundtrack.Artist value (nil for custom artists created after scripts loaded)
function ArtistRegistry.getArtistValue(id)
    if ArtistRegistry.isCustom(id) then
        return artistByPlaylist[id]
    end

    return soundtrack.Artist[getBuiltInKey(id)]
end

--- Moves characters and the default choice off an artist, same as picking "Default" in Change Soundtrack
local function unassignArtist(artist)
    if not artist then
        return
    end

    for _, character in ipairs(player.getPlayableCharacterTypes()) do
        if soundtrack.getCharacterArtist(character) == artist then
            soundtrack.setCharacterArtist(character, nil)
        end
    end

    if soundtrack.getDefaultArtist() == artist then
        soundtrack.setDefaultArtist(soundtrack.Artist.DANNY_B)
    end
end

local changeListeners = {}

--- Registers a function to run whenever an artist's availability changes. The randomizer uses this to drop its cache
--- of which artists contribute songs.
function ArtistRegistry.addChangeListener(listener)
    changeListeners[#changeListeners + 1] = listener
end

local function notifyChanged()
    for _, listener in ipairs(changeListeners) do
        listener()
    end
end

function ArtistRegistry.setRandomized(id, randomized)
    local disabled = utils.fastCopy(type(disabledArtists) == "table" and disabledArtists or {})
    disabled[id] = not randomized or nil
    disabledArtists = disabled

    notifyChanged()
end

--- Hiding an artist also moves characters off it, since Change Soundtrack can no longer show it
function ArtistRegistry.setHidden(id, hidden)
    local hiddenCopy = utils.fastCopy(type(hiddenArtists) == "table" and hiddenArtists or {})
    hiddenCopy[id] = hidden or nil
    hiddenArtists = hiddenCopy

    if hidden then
        unassignArtist(ArtistRegistry.getArtistValue(id))
    end
end

--- The artist ID for either an ID or a Soundtrack.Artist value, so a caller holding an enum value needs no lookup
function ArtistRegistry.toID(artist)
    if type(artist) == "string" then
        return artist
    end

    return artist ~= nil and ArtistRegistry.getID(artist) or nil
end

--- Everything the menus show for an artist. A built-in soundtrack answers from the table in this file, a playlist
--- from its playlist.json, so both kinds read the same way. icon and banner are image paths ready to draw; the names
--- setMetadata takes are file names inside the playlist folder (see listFolderImages).
function ArtistRegistry.getMetadata(id)
    id = ArtistRegistry.toID(id)

    if id == nil then
        return nil
    end

    return {
        title = ArtistRegistry.getTitle(id),
        author = ArtistRegistry.getAuthor(id),
        description = ArtistRegistry.getDescription(id),
        icon = ArtistRegistry.getIcon(id),
        banner = ArtistRegistry.getBanner(id),
        custom = ArtistRegistry.isCustom(id),
        randomized = ArtistRegistry.isRandomized(id),
        hidden = ArtistRegistry.isHidden(id),
    }
end

--- Changes the fields the Custom Artists menu itself edits, ignoring any other key. A built-in soundtrack's title,
--- author, description and images belong to this mod, so only randomized and hidden apply to one; false is returned
--- when the rest were asked for anyway.
function ArtistRegistry.setMetadata(id, fields)
    id = ArtistRegistry.toID(id)

    if id == nil or type(fields) ~= "table" then
        return false
    end

    if fields.randomized ~= nil then
        ArtistRegistry.setRandomized(id, fields.randomized)
    end

    if fields.hidden ~= nil then
        ArtistRegistry.setHidden(id, fields.hidden)
    end

    local edits = fields.title or fields.author or fields.description or fields.icon or fields.banner

    if not edits then
        return true
    end

    local metadata = ArtistRegistry.isCustom(id) and customMusic.readMetadata(id)

    if type(metadata) ~= "table" then
        return false
    end

    if type(metadata.customArtist) ~= "table" then
        metadata.customArtist = {}
    end

    local info = metadata.customArtist

    metadata.displayName = type(fields.title) == "string" and fields.title or metadata.displayName
    metadata.author = type(fields.author) == "string" and fields.author or metadata.author
    info.description = type(fields.description) == "string" and fields.description or info.description
    info.icon = type(fields.icon) == "string" and fields.icon or info.icon
    info.banner = type(fields.banner) == "string" and fields.banner or info.banner

    customMusic.writeMetadata(id, metadata)

    return true
end

--- Maps a Soundtrack.Artist value to its artist ID
function ArtistRegistry.getID(artist)
    local data = getArtistData(artist)

    if not data then
        return nil
    end

    if data.CustomArtists_playlist then
        return data.CustomArtists_playlist
    end

    local name = soundtrack.Artist.names[artist]

    return name and BUILT_IN_PREFIX .. name
end

function ArtistRegistry.isArtistHidden(artist)
    local id = ArtistRegistry.getID(artist)

    return id ~= nil and ArtistRegistry.isHidden(id)
end

local swappedArtistNames = nil

--- Puts every custom artist's title in place of its enum name, and returns the names to put back afterwards
local function swapArtistTitles()
    local swapped = {}

    for _, artist in ipairs(soundtrack.Artist.valueList) do
        local data = getArtistData(artist)

        if data and data.CustomArtists_playlist then
            swapped[artist] = soundtrack.Artist.names[artist]
            soundtrack.Artist.names[artist] = ArtistRegistry.getTitle(data.CustomArtists_playlist)
        end
    end

    return swapped
end

local function restoreArtistNames(swapped)
    for artist, name in pairs(swapped) do
        soundtrack.Artist.names[artist] = name
    end
end

--- Calls fn with the artist titles in place, then puts the enum names back. Stock menu labels that name an artist
--- resolve while the menu draws rather than while it is built, long after the overrides below were restored.
function ArtistRegistry.withArtistTitles(fn, ...)
    local swapped = swapArtistTitles()
    local success, result = pcall(fn, ...)

    restoreArtistNames(swapped)

    if not success then
        error(result, 0)
    end

    return result
end

--- Restores the enum names, option flags and menu order changed by applyChangeSoundtrackOverrides
function ArtistRegistry.restoreChangeSoundtrackOverrides()
    if swappedArtistNames then
        restoreArtistNames(swappedArtistNames)

        swappedArtistNames = nil
    end

    for _, artist in ipairs(soundtrack.Artist.valueList) do
        local data = getArtistData(artist)

        if data then
            if data.CustomArtists_originalExclude ~= nil then
                data.excludeFromOptions = data.CustomArtists_originalExclude
            end

            if data.CustomArtists_originalOrder ~= nil then
                data.order = getOriginalOrder(data)
            end
        end
    end
end

--- Hides disabled artists, gives custom artists readable names, and keeps Random last while the stock Change
-- Soundtrack menu is built. The names must be restored afterwards, since settings serialize artists by enum name.
function ArtistRegistry.applyChangeSoundtrackOverrides()
    ArtistRegistry.restoreChangeSoundtrackOverrides()

    for _, artist in ipairs(soundtrack.Artist.valueList) do
        local data = getArtistData(artist)

        if data then
            data.excludeFromOptions = getOriginalExcludeFromOptions(data) or ArtistRegistry.isArtistHidden(artist) or
                ArtistRegistry.isDeleted(data.CustomArtists_playlist)
        end
    end

    swappedArtistNames = swapArtistTitles()

    -- Random sorts on its enum value, which custom artists are ordered past, so it needs a place beyond them to stay
    -- at the bottom of the menu
    local randomData = getArtistData(soundtrack.Artist.RANDOM)

    if randomData then
        local highest = 0

        for _, artist in ipairs(soundtrack.Artist.valueList) do
            local data = getArtistData(artist)

            if data and artist ~= soundtrack.Artist.RANDOM then
                highest = math.max(highest, getMenuOrder(artist, data))
            end
        end

        -- Records Random's own order first, so restoring puts it back
        getOriginalOrder(randomData)

        randomData.order = highest + 1
    end
end

--- True if a custom artist's playlist no longer exists (deleted since scripts loaded)
function ArtistRegistry.isDeleted(playlist)
    if not playlist then
        return false
    end

    local basePath = ArtistRegistry.getBasePath(playlist)

    return not (basePath and fileIO.exists(basePath .. "playlist.json"))
end

--- Moves characters and the default choice off artists whose playlists were deleted
function ArtistRegistry.unassignDeletedArtists()
    for playlist, artist in pairs(artistByPlaylist) do
        if ArtistRegistry.isDeleted(playlist) then
            unassignArtist(artist)
        end
    end
end

--- The cached alternate rhythm flag, kept current by refreshAlternateRhythm. Reading this avoids the file scan
--- hasOwnBeatmaps does, so menus can ask per frame.
function ArtistRegistry.isAlternateRhythm(playlist)
    local data = getArtistData(artistByPlaylist[playlist])

    return data ~= nil and data.alternateRhythm == true
end

function ArtistRegistry.getPlaylist(artist)
    local data = getArtistData(artist)

    return data and data.CustomArtists_playlist
end

function ArtistRegistry.getBasePath(playlist)
    if type(playlist) == "string" and playlist:sub(1, #LOCAL_PLAYLIST_PREFIX) == LOCAL_PLAYLIST_PREFIX then
        return LOCAL_PLAYLIST_PATH .. playlist:sub(#LOCAL_PLAYLIST_PREFIX + 1) .. "/"
    end
end

--- "Imported from <resource pack>" for artists created by importing a resource pack
function ArtistRegistry.getImportLabel(playlist)
    local info = ArtistRegistry.isCustom(playlist) and getArtistInfo(customMusic.readMetadata(playlist))
    local title = info and info.importedFromTitle

    return type(title) == "string" and string.format("Imported from %s", title) or nil
end

function ArtistRegistry.listImportsOf(modName)
    local result = {}

    for _, playlist in ipairs(ArtistRegistry.listPlaylists()) do
        local info = getArtistInfo(customMusic.readMetadata(playlist))

        if info and info.importedFrom == modName then
            result[#result + 1] = playlist
        end
    end

    return result
end

--- Looks up a file in the playlist folder (relative to it, e.g. "music/zone1_1.ogg")
function ArtistRegistry.getLookup(playlist)
    local basePath = ArtistRegistry.getBasePath(playlist)

    return basePath and function(path)
        return getExistingPath(basePath .. path)
    end or nil
end

--- True if the artist has beatmaps of its own. Beatmaps an import copied from the game don't count, unless they
--- were edited since (e.g. with the editor's tempo options).
function ArtistRegistry.hasOwnBeatmaps(playlist)
    local basePath = ArtistRegistry.getBasePath(playlist)

    if not basePath then
        return false
    end

    local info = getArtistInfo(customMusic.readMetadata(playlist))
    local gameBeatmaps = info and type(info.gameBeatmaps) == "table" and info.gameBeatmaps or {}

    for _, fileName in ipairs(resourcePacks.listFileNames(basePath .. "music", { txt = true })) do
        local lower = fileName:lower()
        -- Instrument and rap rows keep a beatmap only for their details page
        local isRowOnly = lower:match("_inst%d+%.txt$") or lower:match("_vocal%.txt$")
        local gameBeatmap = gameBeatmaps["music/" .. fileName]
        local isGameCopy = type(gameBeatmap) == "string"
            and fileIO.readFileToString(basePath .. "music/" .. fileName) == fileIO.readFileToString(gameBeatmap)

        if not isRowOnly and not isGameCopy then
            return true
        end
    end

    return false
end

--- Artists with beatmaps of their own play at their own tempo and count as alternate rhythm, like Hatsune Miku and
--- Shovel Knight. Artists that only play on the game's beatmaps behave like any built-in soundtrack.
function ArtistRegistry.refreshAlternateRhythm(playlist)
    local data = getArtistData(artistByPlaylist[playlist])

    if data then
        data.alternateRhythm = ArtistRegistry.hasOwnBeatmaps(playlist)
    end
end

function ArtistRegistry.refreshAllAlternateRhythm()
    for playlist in pairs(artistByPlaylist) do
        ArtistRegistry.refreshAlternateRhythm(playlist)
    end
end

--- Turns the local pack an import copied files into into a playlist (see ResourcePacks.planImport)
function ArtistRegistry.finishImport(playlist, metadata)
    customMusic.writeMetadata(playlist, metadata)
    -- The stock resource pack creator loads the new pack, and a loaded playlist replaces every character's soundtrack.
    -- Playlists can only be unloaded all at once, the same as when the stock editor creates a new playlist.
    customMusic.unloadAll()
end

function ArtistRegistry.create(name)
    -- createPlaylist only creates the asset mod; unlike createAndEdit it does not load it as global custom music
    local playlist = customMusic.createPlaylist(name or "My artist")

    if playlist then
        local metadata = customMusic.readMetadata(playlist) or {}
        metadata.customArtist = {
            description = "",
        }
        customMusic.writeMetadata(playlist, metadata)
    end

    return playlist
end

local function getEnumKey(playlist)
    return "ARTIST_" .. (playlist:gsub("[^%w]", "_")):upper()
end

-- Enum extensions must happen while scripts load, so artists created later need a script reload
local success, playlists = pcall(ArtistRegistry.listPlaylists)

if success then
    for index, playlist in ipairs(playlists) do
        artistByPlaylist[playlist] = soundtrack.Artist.extend(getEnumKey(playlist), enum.entry(nil, {
            CustomArtists_playlist = playlist,
            -- Updated by refreshAlternateRhythm as beatmaps are added or removed
            alternateRhythm = ArtistRegistry.hasOwnBeatmaps(playlist),
            excludeFromRandom = true,
            order = 100 + index,
            -- shopkeeper is left unset: the soundtracks that turn it off have no vocals at all, while a custom
            -- artist sings with the playlist's own vocals or the game's (see ArtistPlayback)
            suffix = "",
            tileLayersCorrelated = true,
        }))
    end
else
    log.warn("Failed to register custom artists: %s", tostring(playlists))
end

return ArtistRegistry
