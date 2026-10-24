local gameSong = require "necro.game.data.resource.GameSong"
local soundtrack = require "necro.game.data.Soundtrack"

local array = require "system.utils.Array"
local bitmap = require "system.game.Bitmap"
local enum = require "system.utils.Enum"
local fileIO = require "system.game.FileIO"
local json = require "system.utils.serial.JSON"

local songVariants = require "CustomArtists.scripts.SongVariants"

-- Installed resource packs, read straight from their folders. Workshop packs are never unpacked, so those are read
-- where the game mounts them, and only while it has them mounted.

local ResourcePacks = {}

local ICON_NAME = "CustomArtistsPackIcon"
local ICON_RESOURCE = "virtual/" .. ICON_NAME

local iconData = nil

event.loadVirtualResource.add(ICON_NAME, ICON_NAME, function(ev)
    if iconData then
        ev.data = array.fromString(array.Type.UINT8, iconData)
    end
end)

local SOURCES = {
    { prefix = "res_",   path = "ext/mods/",            kind = "Local" },
    { prefix = "resw_",  path = "downloadedAssetMods/", kind = "Workshop", mounted = true },
    { prefix = "resdl_", path = "ext/downloaded_mods/", kind = "Downloaded" },
}

-- A mounted pack sits one of these folders below its subscription (ModWorkshop.detectContentPrefix)
local MOUNTED_PACK_PARENTS = { "mods", "downloaded_mods" }

ResourcePacks.IMAGE_EXTENSIONS = { jpeg = true, jpg = true, png = true }

local SIBLING_ICON_EXTENSIONS = { ".png", ".jpg" }

local SONG_EXTENSIONS = { ogg = true }
local BEATMAP_EXTENSIONS = { txt = true }
local SPECIAL_TRACKS = { "lobby", "training", "tutorial" }
local DESCRIPTION_MAX_LENGTH = 2000

local function getSource(modName)
    if type(modName) == "string" then
        for _, source in ipairs(SOURCES) do
            if modName:sub(1, #source.prefix) == source.prefix then
                return source, modName:sub(#source.prefix + 1)
            end
        end
    end
end

local function getFolderName(path)
    return (path:gsub("[/\\]$", "")):match("[^/\\]+$")
end


local function findSiblingIcon(path)
    for _, extension in ipairs(SIBLING_ICON_EXTENSIONS) do
        local sibling = path:gsub("/$", "") .. extension

        if fileIO.exists(sibling) then
            return sibling, "icon" .. extension
        end
    end
end

--- Remembered because finding a mounted pack means listing folders
local mountedPaths = {}

local function findMountedPath(source, folder)
    if mountedPaths[folder] then
        return mountedPaths[folder]
    end

    for _, parent in ipairs(MOUNTED_PACK_PARENTS) do
        local base = source.path .. folder .. "/" .. parent
        local first = (fileIO.listFiles(base, fileIO.List.DIRECTORIES) or {})[1]
        local name = first and getFolderName(first)

        if name then
            mountedPaths[folder] = base .. "/" .. name .. "/"

            return mountedPaths[folder]
        end
    end
end

--- The folder of a resource pack, with a trailing slash
function ResourcePacks.getPath(modName)
    local source, folder = getSource(modName)

    if not source then
        return nil
    end

    if source.mounted then
        return findMountedPath(source, folder)
    end

    return source.path .. folder .. "/"
end

--- "Local", "Downloaded" or "Workshop"
function ResourcePacks.getKind(modName)
    local source = getSource(modName)

    return source and source.kind
end

--- File names directly inside a folder whose extension is in the given set
function ResourcePacks.listFileNames(folder, extensions)
    local result = {}

    for _, path in ipairs(fileIO.listFiles((folder:gsub("/$", "")), fileIO.List.FILES, fileIO.List.SORTED) or {}) do
        local fileName = path:match("[^/\\]+$")
        local extension = fileName and fileName:match("%.(%w+)$")

        if extension and extensions[extension:lower()] then
            result[#result + 1] = fileName
        end
    end

    return result
end

--- Folder names of every local asset mod (resource packs and playlists)
function ResourcePacks.listLocalFolders()
    local result = {}

    for _, path in ipairs(fileIO.listFiles("ext/mods", fileIO.List.DIRECTORIES, fileIO.List.SORTED) or {}) do
        result[#result + 1] = getFolderName(path)
    end

    return result
end

local function readWorkshop(modName)
    local path = ResourcePacks.getPath(modName)
    local success, workshop = pcall(json.decode, path and fileIO.readFileToString(path .. "workshop.json"))

    return success and type(workshop) == "table" and workshop or {}
end

function ResourcePacks.isPlaylist(modName)
    local path = ResourcePacks.getPath(modName)

    return path ~= nil and fileIO.exists(path .. "playlist.json")
end

--- True for installed resource packs (not Custom Music playlists) with at least one song
function ResourcePacks.hasMusic(modName)
    local path = ResourcePacks.getPath(modName)

    return path ~= nil and not ResourcePacks.isPlaylist(modName) and
    #ResourcePacks.listFileNames(path .. "music", SONG_EXTENSIONS) > 0
end

function ResourcePacks.hasBeatmaps(modName)
    local path = ResourcePacks.getPath(modName)

    return path ~= nil and #ResourcePacks.listFileNames(path .. "music", BEATMAP_EXTENSIONS) > 0
end

--- Resource packs with music, from the given mod names plus every pack that has a folder of its own. Workshop packs
--- are mounted rather than unpacked, so they only appear in the names the game supplies.
function ResourcePacks.list(modNames)
    local result = {}
    -- Turning workshop packs on mounts them and leaves any earlier unpacked copy behind, so list a pack once
    local listed = {}

    local function add(modName)
        local packFolder = modName and getFolderName(ResourcePacks.getPath(modName) or "")

        if packFolder and not listed[packFolder] and ResourcePacks.hasMusic(modName) then
            listed[packFolder] = true
            result[#result + 1] = modName
        end
    end

    for _, modName in ipairs(modNames or {}) do
        add(modName)
    end

    for _, source in ipairs(SOURCES) do
        for _, path in ipairs(fileIO.listFiles(source.path:sub(1, -2), fileIO.List.DIRECTORIES, fileIO.List.SORTED) or {}) do
            local folder = getFolderName(path)

            add(folder and source.prefix .. folder)
        end
    end

    return result
end

function ResourcePacks.getTitle(modName)
    local displayName = readWorkshop(modName).displayName

    if type(displayName) == "string" and displayName ~= "" then
        return displayName
    end

    local _, folder = getSource(modName)

    return folder or tostring(modName)
end

--- The first paragraph of the Steam description, without its formatting tags
function ResourcePacks.getDescription(modName)
    local text = tostring(readWorkshop(modName).description or "")
    text = text:gsub("\r", "")
    text = text:gsub("%[url=[^%]]*%](.-)%[/url%]", "%1")
    text = text:gsub("%[/?[%w%*]+[^%]]*%]", "")
    text = text:match("^%s*(.-)%s*$") or ""

    local paragraph = text:match("^(.-)\n%s*\n") or text

    if #paragraph > DESCRIPTION_MAX_LENGTH then
        paragraph = paragraph:sub(1, DESCRIPTION_MAX_LENGTH):gsub("%s+%S*$", "") .. "..."
    end

    return paragraph
end

--- Icon and banner file names inside the pack folder, picked from workshop.json and the images' names
function ResourcePacks.findImages(modName)
    local path = ResourcePacks.getPath(modName)

    if not path then
        return nil, nil
    end

    local images = ResourcePacks.listFileNames(path, ResourcePacks.IMAGE_EXTENSIONS)
    local workshopIcon = readWorkshop(modName).icon
    local icon = type(workshopIcon) == "string" and fileIO.exists(path .. workshopIcon) and workshopIcon or nil
    local banner = nil

    for _, fileName in ipairs(images) do
        local lower = fileName:lower()

        if lower:find("banner", 1, true) then
            banner = banner or fileName
        elseif lower:find("icon", 1, true) or lower:find("thumbnail", 1, true) then
            icon = icon or fileName
        end
    end

    for _, fileName in ipairs(images) do
        if not icon and fileName ~= banner then
            icon = fileName
        end
    end

    return icon, banner
end

--- Soundtrack file suffixes of the built-in artists ("" is Danny B)
local function getKnownSuffixes()
    local suffixes = { [""] = soundtrack.Artist.DANNY_B }

    for _, artist in ipairs(soundtrack.Artist.valueList) do
        local data = soundtrack.Artist.data[artist]

        if type(data.suffix) == "string" and data.suffix ~= "" and not data.CustomArtists_playlist and suffixes[data.suffix] == nil then
            suffixes[data.suffix] = artist
        end
    end

    return suffixes
end

--- The artist suffix in a song name, e.g. "zone3_1_3h" -> "_3", "boss_6a" -> ""
local function getSongSuffix(songName)
    local rest = songName:match("^zone%d_%d(.*)$") or songName:match("^boss_%d+(.*)$")

    if rest then
        -- The variant letter follows the suffix
        return (rest:gsub("[hcab]$", ""))
    end

    for _, track in ipairs(SPECIAL_TRACKS) do
        if songName:sub(1, #track) == track then
            return songName:sub(#track + 1)
        end
    end
end

--- The soundtrack whose songs a pack replaces: its file suffix, its artist, and how many of the pack's songs use it
function ResourcePacks.detectSoundtrack(modName)
    local path = ResourcePacks.getPath(modName)
    local suffixes = getKnownSuffixes()
    local counts = {}

    for _, fileName in ipairs(path and ResourcePacks.listFileNames(path .. "music", SONG_EXTENSIONS) or {}) do
        local suffix = getSongSuffix(fileName:sub(1, -5))

        if suffix and suffixes[suffix] then
            counts[suffix] = (counts[suffix] or 0) + 1
        end
    end

    local best, bestCount = "", counts[""] or 0

    for suffix, count in pairs(counts) do
        if count > bestCount then
            best, bestCount = suffix, count
        end
    end

    return best, suffixes[best], bestCount
end

--- Inserts a soundtrack suffix into a music file name the way the game names artist files, e.g. with "_3":
--- "music/zone3_1h.ogg" -> "music/zone3_1_3h.ogg", "music/lobby.txt" -> "music/lobby_3.txt"
function ResourcePacks.withSuffix(path, suffix)
    if suffix == "" then
        return path
    end

    local name, variant, extension = path:match("^music/(.-%d)([hcab]?)%.(%w+)$")

    if not name then
        name, extension = path:match("^music/(.-)%.(%w+)$")
        variant = ""
    end

    return name and string.format("music/%s%s%s.%s", name, suffix, variant, extension) or path
end

--- The playlist song name of one of the pack's song files, e.g. "zone3_1_3h.ogg" -> "zone3_1h" for suffix "_3".
--- Returns nil for files that belong to another soundtrack.
local function toPlaylistSongName(fileName, suffix)
    local escapedSuffix = suffix:gsub("%p", "%%%0")
    local base, variant = fileName:match("^(zone%d_%d)" .. escapedSuffix .. "([hc]?)%.[oO][gG][gG]$")

    if not base then
        base, variant = fileName:match("^(boss_%d+)" .. escapedSuffix .. "([ab]?)%.[oO][gG][gG]$")
    end

    if not base then
        for _, track in ipairs(SPECIAL_TRACKS) do
            base = fileName:match("^(" .. track .. ")" .. escapedSuffix .. "%.[oO][gG][gG]$")
            variant = ""

            if base then
                break
            end
        end
    end

    return base and base .. variant
end

--- Zone 3's hot and cold songs share their floor's beatmap
local function getBeatmapName(songName)
    return songName:match("^(zone3_%d)[hc]$") or songName
end

--- Everything needed to import a pack as a custom artist
function ResourcePacks.planImport(modName)
    local path = ResourcePacks.getPath(modName)

    if not path or not ResourcePacks.hasMusic(modName) then
        return nil
    end

    local suffix = ResourcePacks.detectSoundtrack(modName)
    local title = ResourcePacks.getTitle(modName)
    local description = ResourcePacks.getDescription(modName)
    local template = { { directory = true, target = "music" } }
    local sources = {}
    local beatmapNames = {}
    local gameBeatmaps = {}

    local function copy(source, target)
        if not sources[target] then
            sources[target] = source
            template[#template + 1] = { source = source, target = target }
        end
    end

    -- Songs, renamed from the replaced soundtrack's names to the playlist names
    for _, fileName in ipairs(ResourcePacks.listFileNames(path .. "music", SONG_EXTENSIONS)) do
        local songName = toPlaylistSongName(fileName, suffix)

        if songName then
            copy(path .. "music/" .. fileName, string.format("music/%s.ogg", songName))
            beatmapNames[getBeatmapName(songName)] = true
        end
    end

    -- Shopkeeper vocals, Coral Riff instruments and Fortissimole's rap use the same names for every soundtrack
    local streamingSounds = ResourcePacks.listFileNames(path .. "sounds_streaming", SONG_EXTENSIONS)

    if #streamingSounds > 0 then
        template[#template + 1] = { directory = true, target = "sounds_streaming" }

        for _, fileName in ipairs(streamingSounds) do
            copy(path .. "sounds_streaming/" .. fileName, "sounds_streaming/" .. fileName)

            -- Instruments play on their fight's beatmap, even without a full song for it
            local bossID = fileName:lower():match("^boss_(%d+)_inst0%.ogg$")

            if bossID then
                beatmapNames["boss_" .. bossID] = true
            end
        end
    end

    -- Beatmaps: the pack's own, or the game's beatmaps of the soundtrack the pack replaces
    for beatmapName in pairs(beatmapNames) do
        local target = string.format("music/%s.txt", beatmapName)
        local suffixed = ResourcePacks.withSuffix(target, suffix)

        if fileIO.exists(path .. suffixed) then
            copy(path .. suffixed, target)
        else
            local gameBeatmap = (fileIO.exists("ext/" .. suffixed) and "ext/" .. suffixed)
                or (fileIO.exists("ext/" .. target) and "ext/" .. target) or nil

            if gameBeatmap then
                copy(gameBeatmap, target)
                gameBeatmaps[target] = gameBeatmap
            end
        end
    end

    local iconFile, bannerFile = ResourcePacks.findImages(modName)
    local iconSource, icon = nil, nil

    if iconFile then
        iconSource, icon = path .. iconFile, iconFile
    else
        iconSource, icon = findSiblingIcon(path)
    end

    if iconSource then
        copy(iconSource, icon)
    end

    local banner = bannerFile

    if banner then
        copy(path .. banner, banner)
    end

    -- Editor rows show where each song came from, the same way they show the file picked for them
    local songFileNames, variantFileNames = {}, {}

    for songID, song in enum.dataPairs(gameSong.Type) do
        local definition = songVariants.getDefinitionByID(gameSong.Type.names[songID])
        local file = definition and definition.file or songVariants.getStockSongFile(song.track)
        local source = file and sources[file]
        -- Packs have separate hot and cold songs, which belong to the Hot and Cold rows rather than the stock zone 3 row
        local isStockZone3Row = not definition and type(song.track) == "table"
            and song.track.type == soundtrack.TrackType.ZONE and song.track.zone == 3

        if source and not isStockZone3Row then
            if definition then
                variantFileNames[definition.id] = source
            else
                songFileNames[songID] = source
            end
        end
    end

    return {
        title = title,
        description = description,
        template = template,
        metadata = {
            displayName = title,
            songFileNames = songFileNames,
            [songVariants.FILE_NAMES_KEY] = variantFileNames,
            customArtist = {
                description = description,
                icon = icon,
                banner = banner,
                importedFrom = modName,
                importedFromTitle = title,
                -- Beatmaps copied from the game don't make an artist alternate rhythm (see ArtistRegistry.hasOwnBeatmaps)
                gameBeatmaps = gameBeatmaps,
            },
        },
    }
end

--- The picture inside a letterboxed image. The workshop pads a pack's picture onto a wider canvas with a solid
--- color, so the bars are the rows and columns along the edges that match the corner.
local function trimBars(image)
    local width, height = image.getSize()
    local bar = image.getPixel(0, 0)

    local function isBarColumn(x)
        for y = 0, height - 1 do
            if image.getPixel(x, y) ~= bar then
                return false
            end
        end

        return true
    end

    local function isBarRow(y)
        for x = 0, width - 1 do
            if image.getPixel(x, y) ~= bar then
                return false
            end
        end

        return true
    end

    local left, right = 0, width - 1
    local top, bottom = 0, height - 1

    while left < right and isBarColumn(left) do
        left = left + 1
    end

    while right > left and isBarColumn(right) do
        right = right - 1
    end

    while top < bottom and isBarRow(top) do
        top = top + 1
    end

    while bottom > top and isBarRow(bottom) do
        bottom = bottom - 1
    end

    return { left, top, right - left + 1, bottom - top + 1 }
end

--- The pack's picture as PNG data, trimmed of its bars; nil if there is nothing in it to keep
local function readTrimmedIcon(path)
    local loaded = bitmap.load(path)

    if not loaded then
        return nil
    end

    local rect = trimBars(loaded)
    local png = nil

    -- One solid color trims away to nothing, which is what a picture the game has not finished downloading looks
    -- like, so there is nothing worth storing
    if rect[3] > 1 and rect[4] > 1 then
        local trimmed = bitmap.crop(loaded, rect)

        png = bitmap.imageToPNG(array.toString(trimmed.getArray()))

        array.release(trimmed.getArray())
    end

    array.release(loaded.getArray())

    return png
end

--- Stores a picture the pack keeps outside its folder, such as the one the game shows for a workshop pack, in the
--- playlist being imported, so it stays after the pack is gone. A pack with an icon of its own keeps that one.
function ResourcePacks.addPlanIcon(plan, image)
    local info = plan.metadata.customArtist

    if info.icon or type(image) ~= "string" then
        return
    end

    -- Trimming needs the picture decoded, which only works once the game has finished downloading it
    local success, png = pcall(readTrimmedIcon, image)

    if not success or not png then
        return
    end

    iconData = png
    info.icon = "icon.png"
    plan.template[#plan.template + 1] = { source = ICON_RESOURCE, target = info.icon }
end

return ResourcePacks
