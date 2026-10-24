local dropdownMenu = require "necro.menu.generic.DropdownMenu"
local gameSong = require "necro.game.data.resource.GameSong"
local menu = require "necro.menu.Menu"
local textFormat = require "necro.config.i18n.TextFormat"
local textPrompt = require "necro.render.ui.TextPrompt"
local ui = require "necro.render.UI"

local enum = require "system.utils.Enum"
local utils = require "system.utils.Utilities"

local songInfo = require "CustomArtists.scripts.SongInfo"

-- Right-click on a song row in the Custom Music editor to give the song a title and artist. Edits go into the editor's
-- own metadata table, which the editor saves when it closes.

local function formatInfo(info)
    if info.title and info.artist then
        return string.format("%s - %s", info.title, info.artist)
    end

    return info.title or info.artist
end

--- Shows a song's title where the editor shows its file name, keeping any status after it, with the artist faded
--- beside it. Rows without a file, or without a title, keep their label and get the info faded after it.
local function labelWithInfo(label, fileName, info)
    if not info then
        return label
    end

    local shownName = type(fileName) == "string" and fileName:match("[^/\\]*$") or ""
    local first, last = nil, nil

    if shownName ~= "" then
        first, last = label:find(shownName, 1, true)
    end

    if info.title and first then
        label = label:sub(1, first - 1) .. info.title .. label:sub(last + 1)

        return info.artist and label .. "  " .. textFormat.fade(string.format("(%s)", info.artist)) or label
    end

    return label .. "  " .. textFormat.fade(string.format("(%s)", formatInfo(info)))
end

event.menu.add("customArtistSongInfo", "CustomArtists_songInfo", function(ev)
    local arg = ev.arg or {}
    local metadata = arg.metadata
    local song = arg.song

    -- Unset fields show the song's default, and setting the default (or nothing) leaves the field unset
    local function field(id, label)
        local entry = textPrompt.menuEntry({
            id = id,
            label = label,
            uppercase = false,
            get = function()
                local info = songInfo.withDefaults(metadata, song, songInfo.fromMetadata(metadata, song))

                return info and info[id] or ""
            end,
            set = function(value)
                local default = songInfo.withDefaults(metadata, song) or {}

                songInfo.setInMetadata(metadata, song, { [id] = value ~= default[id] and value or "" })
            end,
        })
        entry.maxWidth = menu.getScreenWidth() - 60

        return entry
    end

    local function closePage()
        menu.close()
        menu.update()
    end

    local entries = {
        {
            label = arg.songName,
            selectableIf = false,
        },
        {
            height = 0,
        },
        field("title", "Title"),
        field("artist", "Artist"),
        {
            height = 0,
        },
        {
            id = "done",
            label = "Done",
            sound = "UIBack",
            action = closePage,
        },
    }

    entries[3].selected = true

    ev.menu = {
        label = "Song info",
        entries = entries,
        width = menu.getScreenWidth(),
        fixedWidth = true,
        escapeAction = closePage,
        -- Opened from a song's page, which mutes the game's music beneath its preview
        audioFilter = arg.audioFilter,
    }
end)

local function openSongInfo(metadata, song, songName, audioFilter)
    menu.open("CustomArtists_songInfo", {
        metadata = metadata,
        song = song,
        songName = songName,
        audioFilter = audioFilter,
    })
end

--- The right-click menu of a song row
local function openDropdown(entries)
    local width = 300

    for _, entry in ipairs(entries) do
        local text = tostring(utils.eval(entry.label, ""))
        width = math.max(width, (ui.measureText({ font = ui.Font.MEDIUM, text = text }).width or 0) * 2 + 60)
    end

    local entryHeight = 30 + menu.getPadding()
    local subScreen, screenAlignY = dropdownMenu.getSubScreen(width, #entries * entryHeight + 36)

    menu.open("dropdown", {
        entries = entries,
        subScreen = subScreen,
        screenAlignY = screenAlignY,
        width = width,
    })
end

local function openContextMenu(metadata, song, songName)
    local function close()
        menu.closeNamed("dropdown")
        menu.update()
    end

    local entries = {
        {
            label = "Song info...",
            action = function()
                close()
                openSongInfo(metadata, song, songName)
            end,
        },
    }

    if songInfo.fromMetadata(metadata, song) then
        entries[#entries + 1] = {
            label = "Clear song info",
            action = function()
                songInfo.clearInMetadata(metadata, song)
                close()
            end,
        }
    end

    openDropdown(entries)
end

-- Runs after the song variant rows are laid out and labelled (SongRows)
event.menu.add("addSongInfoActions", { key = "customMusic", sequence = 3 }, function(ev)
    local args = ev.arg
    local metadata = args and args.metadata
    local entries = ev.menu and ev.menu.entries

    if type(metadata) ~= "table" or type(entries) ~= "table" then
        return
    end

    -- Song info of the music playing now is read when a track starts, so reread it once the editor has saved
    local function refreshAfter(action)
        return function(...)
            local result = action(...)

            songInfo.refreshPlaying()

            return result
        end
    end

    for _, entry in ipairs(entries) do
        if entry.id == "done" and type(entry.action) == "function" then
            entry.action = refreshAfter(entry.action)
        end
    end

    if type(ev.menu.escapeAction) == "function" then
        ev.menu.escapeAction = refreshAfter(ev.menu.escapeAction)
    end

    local songIDs = {}

    for songID in enum.dataPairs(gameSong.Type) do
        songIDs[gameSong.Type.names[songID]] = songID
    end

    for _, entry in ipairs(entries) do
        local songID = type(entry.id) == "string" and songIDs[entry.id]

        if songID and not entry.specialAction then
            local song = entry.id
            local songName = songInfo.getDefaultTitle(song)

            if type(entry.label) == "string" then
                local fileName = type(metadata.songFileNames) == "table" and metadata.songFileNames[songID]

                entry.label = labelWithInfo(entry.label, fileName, songInfo.fromMetadata(metadata, song))
            end

            entry.specialAction = function()
                openContextMenu(metadata, song, songName)
            end
        end
    end
end)

-- The song's page in the editor opens with the song name and its file name, and lists its options from "Select new
-- song" down
event.menu.add("showSongInfoOnDetails", { key = "customMusicDetails", sequence = 1 }, function(ev)
    local args = ev.arg
    local metadata = args and args.metadata
    local entries = ev.menu and ev.menu.entries
    local titleRow = type(entries) == "table" and entries[1]
    local fileRow = titleRow and entries[2]

    if type(metadata) ~= "table" or not (fileRow and titleRow.label == args.songName) then
        return
    end

    local song = gameSong.Type.names[args.songID]
    local label = fileRow.label

    titleRow.label = function()
        local info = songInfo.fromMetadata(metadata, song)

        return info and info.title or args.songName
    end

    -- Manual beat mode blanks the other options while it runs
    if not args.manualBeatmap then
        for i, entry in ipairs(entries) do
            if entry.id == "changeSong" then
                table.insert(entries, i, {
                    id = "CustomArtists_songInfo",
                    label = "Song info...",
                    action = function()
                        openSongInfo(metadata, song, args.songName, ev.menu.audioFilter)
                    end,
                })

                break
            end
        end
    end

    -- With a title in the heading, the file row still says which song it fills in for
    fileRow.label = function()
        local text = type(label) == "function" and label() or label
        local info = songInfo.fromMetadata(metadata, song)

        if type(text) ~= "string" or not (info and info.title) then
            return text
        end

        return string.format("%s - %s", args.songName, text)
    end
end)

-- Rarely changed options move off the song's page into "More options...", so its list ends above the beat bar
local MORE_OPTIONS = { doubleTempo = true, halfTempo = true, CustomArtists_baseVocals = true }

event.menu.add("customArtistSongOptions", "CustomArtists_songOptions", function(ev)
    local arg = ev.arg or {}
    local entries = {}

    local function closePage()
        menu.close()
        menu.update()
    end

    -- Menus write their layout (position, height, bounding box) into their entries, so each build lays out copies
    for _, entry in ipairs(arg.entries or {}) do
        local copy = {}

        for key, value in pairs(entry) do
            copy[key] = value
        end

        entries[#entries + 1] = copy
    end

    entries[#entries + 1] = {
        height = 0,
    }
    entries[#entries + 1] = {
        id = "done",
        label = "Done",
        sound = "UIBack",
        action = closePage,
    }

    ev.menu = {
        label = arg.songName,
        entries = entries,
        escapeAction = closePage,
        width = menu.getScreenWidth(),
        fixedWidth = true,
        -- The song's page mutes the game's music beneath its preview
        audioFilter = arg.audioFilter,
    }
end)

-- After "Uses base game vocals" is added (SongRows)
event.menu.add("moveSongOptions", { key = "customMusicDetails", sequence = 2 }, function(ev)
    local args = ev.arg
    local metadata = args and args.metadata
    local entries = ev.menu and ev.menu.entries

    -- Manual beat mode takes over these rows while it runs
    if type(metadata) ~= "table" or type(entries) ~= "table" or args.manualBeatmap then
        return
    end

    local songID = args.songID
    local moved, firstIndex = {}, nil

    for i = #entries, 1, -1 do
        local entry = entries[i]

        if MORE_OPTIONS[entry.id] then
            table.insert(moved, 1, table.remove(entries, i))
            firstIndex = i
        end
    end

    if not firstIndex then
        return
    end

    -- The stock tempo labels are fixed when the song's page is built, and that page doesn't rebuild while this one is
    -- open
    local function tempo()
        return type(metadata.tempo) == "table" and metadata.tempo[songID] or 1
    end

    for _, entry in ipairs(moved) do
        if entry.id == "doubleTempo" then
            entry.label = function()
                return L.format("Double tempo %s", textFormat.checkbox(tempo() > 1))
            end
        elseif entry.id == "halfTempo" then
            entry.label = function()
                return L.format("Half tempo %s", textFormat.checkbox(tempo() < 1))
            end
        end
    end

    table.insert(entries, firstIndex, {
        id = "CustomArtists_moreOptions",
        label = "More options...",
        action = function()
            menu.open("CustomArtists_songOptions", {
                entries = moved,
                songName = args.songName,
                audioFilter = ev.menu.audioFilter,
            })
        end,
    })
end)
