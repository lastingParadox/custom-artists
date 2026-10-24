local customMusic = require "necro.game.data.resource.CustomMusic"
local gameSong = require "necro.game.data.resource.GameSong"
local menu = require "necro.menu.Menu"
local textFormat = require "necro.config.i18n.TextFormat"

local enum = require "system.utils.Enum"

local registry = require "CustomArtists.scripts.ArtistRegistry"
local songVariants = require "CustomArtists.scripts.SongVariants"

-- Shows the SongVariants rows in the Custom Music editor, indented beneath the stock song they override

local INDENT = 24

-- Added rows only borrow their numeric song slot while the editor is open; see SongVariants.FILE_NAMES_KEY
local FILE_NAMES_KEY = songVariants.FILE_NAMES_KEY

local defaultText = textFormat.fade(L("Default", "songMapping.defaultPlaceholder"))

-- Set when "Reset to default" is chosen, until its confirmation opens
local resetPending = false

local function getSyncState(args)
    local metadata = args.metadata

    if type(metadata.songFileNames) ~= "table" then
        metadata.songFileNames = {}
    end

    if type(metadata[FILE_NAMES_KEY]) ~= "table" then
        metadata[FILE_NAMES_KEY] = {}
    end

    local state = args.CustomArtists_songVariants

    if not state then
        state = { borrowed = {}, placed = {} }

        for _, definition in ipairs(songVariants.list()) do
            state.borrowed[definition.songID] = metadata.songFileNames[definition.songID]
            state.placed[definition.songID] = metadata.songFileNames[definition.songID]
        end

        args.CustomArtists_songVariants = state
    end

    return state
end

--- Records the file names the editor set or cleared since the last menu update
local function collectFileNames(args)
    local state = getSyncState(args)
    local metadata = args.metadata

    for _, definition in ipairs(songVariants.list()) do
        local value = metadata.songFileNames[definition.songID]

        if value ~= state.placed[definition.songID] then
            metadata[FILE_NAMES_KEY][definition.id] = value
            state.placed[definition.songID] = value
        end
    end

    return state
end

local function lendFileNames(args)
    local state = collectFileNames(args)
    local metadata = args.metadata

    for _, definition in ipairs(songVariants.list()) do
        local value = metadata[FILE_NAMES_KEY][definition.id]
        metadata.songFileNames[definition.songID] = value
        state.placed[definition.songID] = value
    end

    songVariants.setEditorFileNames(metadata.songFileNames)
end

--- Puts back whatever the numeric slots held before, so the editor saves other mods' song file names unchanged
local function returnFileNames(args)
    local state = collectFileNames(args)
    local metadata = args.metadata

    for _, definition in ipairs(songVariants.list()) do
        metadata.songFileNames[definition.songID] = state.borrowed[definition.songID]
        state.placed[definition.songID] = state.borrowed[definition.songID]
    end

    songVariants.setEditorFileNames(nil)
end

local function replacePlain(text, old, new)
    local first, last = text:find(old, 1, true)

    if not first then
        return text
    end

    return text:sub(1, first - 1) .. new .. text:sub(last + 1)
end

local function endsWith(text, suffix)
    return #suffix <= #text and text:sub(- #suffix) == suffix
end

-- Runs before the stock editor builds its rows, which read the file names
event.menu.add("lendSongVariantFileNames", { key = "customMusic", sequence = -1 }, function(ev)
    ev.arg = ev.arg or {}
    ev.arg.metadata = ev.arg.metadata or customMusic.readMetadata(ev.arg.name) or {}

    lendFileNames(ev.arg)
end)

-- Resetting is the only time the editor removes a song's files, so mark it while its confirmation runs; shared
-- beatmaps other rows still use are kept.
event.menu.add("markSongReset", { key = "customMusicDetails", sequence = 1 }, function(ev)
    for _, entry in ipairs(ev.menu and ev.menu.entries or {}) do
        if entry.id == "resetToDefault" and type(entry.action) == "function" then
            local action = entry.action

            entry.action = function(...)
                resetPending = true

                return action(...)
            end
        end
    end
end)

event.menu.add("markSongResetConfirmation", { key = "confirm", sequence = -1 }, function(ev)
    local arg = ev.arg

    if not resetPending or type(arg) ~= "table" then
        return
    end

    resetPending = false

    if type(arg.yes) == "function" and not arg.CustomArtists_songReset then
        local yes = arg.yes
        arg.CustomArtists_songReset = true
        arg.yes = function(...)
            songVariants.setEditorRemoving(true)

            local success, err = pcall(yes, ...)

            songVariants.setEditorRemoving(false)

            if not success then
                error(err, 0)
            end
        end
    end
end)

-- "Uses base game vocals" beneath Half tempo, on the songs the base game sings: the shopkeeper on zone tracks and
-- Fortissimole's rap. Details rows carry no positions of their own, so the row only needs inserting. Manual beat mode
-- replaces the tempo rows.
event.menu.add("addBaseVocalsRow", { key = "customMusicDetails", sequence = 1 }, function(ev)
    local args = ev.arg
    local metadata = args and args.metadata
    local entries = ev.menu and ev.menu.entries

    if type(metadata) ~= "table" or type(entries) ~= "table" or args.manualBeatmap then
        return
    end

    local lipmapName = songVariants.getSongLipmapName(args.songID)
    local index = nil

    for i, entry in ipairs(entries) do
        if entry.id == "halfTempo" then
            index = i

            break
        end
    end

    if not lipmapName or not index then
        return
    end

    -- An artist playing on the game's beatmaps keeps its timing, so the game's vocals fit until told otherwise
    local default = not registry.isAlternateRhythm(args.modName)

    table.insert(entries, index + 1, {
        id = "CustomArtists_baseVocals",
        label = function()
            return string.format("Uses base game vocals %s",
                textFormat.checkbox(songVariants.usesBaseVocals(metadata, lipmapName, default)))
        end,
        action = function()
            songVariants.setUsesBaseVocals(metadata, lipmapName,
                not songVariants.usesBaseVocals(metadata, lipmapName, default))

            menu.update()
        end,
    })
end)

-- Runs after the stock editor and the "Artist info..." row
event.menu.add("layoutSongVariantRows", { key = "customMusic", sequence = 2 }, function(ev)
    local args = ev.arg
    local metadata = args and args.metadata
    local entries = ev.menu and ev.menu.entries

    if type(metadata) ~= "table" or type(entries) ~= "table" then
        return
    end

    local function returnBeforeClosing(action)
        return function(...)
            returnFileNames(args)
            registry.refreshAlternateRhythm(args.name)

            return action(...)
        end
    end

    for _, entry in ipairs(entries) do
        if entry.id == "done" and type(entry.action) == "function" then
            entry.action = returnBeforeClosing(entry.action)
        end
    end

    if type(ev.menu.escapeAction) == "function" then
        ev.menu.escapeAction = returnBeforeClosing(ev.menu.escapeAction)
    end

    local songIDs = {}

    for songID in enum.dataPairs(gameSong.Type) do
        songIDs[gameSong.Type.names[songID]] = songID
    end

    local rows, slots, rowsByID = {}, {}, {}
    local firstY = nil

    for index, entry in ipairs(entries) do
        if type(entry.id) == "string" and type(entry.y) == "number" and songIDs[entry.id] then
            rows[#rows + 1] = entry
            slots[#slots + 1] = index
            rowsByID[entry.id] = entry
            firstY = firstY and math.min(firstY, entry.y) or entry.y
        end
    end

    if not firstY then
        return
    end

    local fileNames = metadata.songFileNames or {}
    local basePath = registry.getBasePath(args.name)
    local lookup = basePath and songVariants.folderLookup(basePath)

    local function isSet(definition)
        return definition ~= nil and fileNames[definition.songID] ~= nil
    end

    local function hasOwnFile(definition)
        return lookup ~= nil and songVariants.findFile(lookup, definition) ~= nil
    end

    local function getPlaceholder(definition)
        if hasOwnFile(definition) then
            return "File in playlist folder"
        elseif definition.kind == "mix" then
            local sibling = songVariants.getDefinition(definition.sibling)

            if isSet(sibling) and not fileNames[definition.parentID] then
                return string.format("Same as %s", sibling.label)
            end

            return string.format("Same as %s", definition.parentName)
        elseif definition.kind == "phase2" then
            return string.format("Same as %s", definition.parentName)
        elseif definition.kind == "instrument" and definition.instrument == 0 then
            return string.format("Not set, the full %s song plays", definition.parentName)
        elseif definition.kind == "instrument" then
            local mainInstrument = songVariants.getDefinition(definition.mainInstrument)

            return (isSet(mainInstrument) or hasOwnFile(mainInstrument)) and "None" or "Needs the main instrument"
        end

        return "None"
    end

    -- Order: every stock row followed by its added rows
    local childrenByParent = {}

    for _, definition in ipairs(songVariants.list()) do
        if rowsByID[definition.id] then
            childrenByParent[definition.parent] = childrenByParent[definition.parent] or {}
            table.insert(childrenByParent[definition.parent], definition)
        end
    end

    local ordered, isPlaced = {}, {}

    local function place(row)
        if not isPlaced[row] then
            isPlaced[row] = true
            ordered[#ordered + 1] = row
        end
    end

    for _, row in ipairs(rows) do
        if not songVariants.getDefinitionByID(row.id) then
            place(row)

            for _, definition in ipairs(childrenByParent[row.id] or {}) do
                place(rowsByID[definition.id])
            end
        end
    end

    -- Added rows whose stock row isn't listed
    for _, row in ipairs(rows) do
        place(row)
    end

    -- Positions go to visible rows only, so hidden rows leave no gap
    local rowHeight = 20 + menu.getPadding()
    local y = firstY

    for index, row in ipairs(ordered) do
        entries[slots[index]] = row

        if not (row.enableIf == false and row.hideIfDisabled) then
            row.y = y
            y = y + rowHeight
        end
    end

    -- Labels, and disabling stock rows that are fully replaced
    for parent, children in pairs(childrenByParent) do
        local parentRow = rowsByID[parent]
        local mixCount, setMixes = 0, 0
        local instrumentsSet, instrumentsInFolder = false, false
        local missingMix = nil

        for _, definition in ipairs(children) do
            local row = rowsByID[definition.id]

            if definition.kind == "mix" then
                mixCount = mixCount + 1

                if isSet(definition) then
                    setMixes = setMixes + 1
                elseif lookup and fileNames[definition.parentID] and not lookup(definition.file) then
                    -- Resetting a Hot or Cold row removes the song the stock row had put there as well
                    missingMix = definition.label
                end
            elseif definition.replacesParent then
                instrumentsSet = isSet(definition)
                instrumentsInFolder = hasOwnFile(definition)
            end

            if type(row.label) == "string" then
                local label = row.label

                if not isSet(definition) and endsWith(label, defaultText) then
                    label = label:sub(1, #label - #defaultText) .. textFormat.fade(getPlaceholder(definition))
                end

                row.label = replacePlain(label, definition.name, definition.label)
            end

            row.x = ((parentRow and parentRow.x) or row.x or 0) + INDENT

            if type(row.maxWidth) == "number" then
                row.maxWidth = row.maxWidth - INDENT
            end
        end

        if parentRow then
            local note, replaced = nil, false
            local mixesReplace = mixCount > 0 and setMixes == mixCount

            -- Its files belong to the rows beneath it now; resetting one of those enables it again
            if mixesReplace or instrumentsSet then
                parentRow.enableIf = false
            end

            if mixesReplace then
                note, replaced = "Replaced by Hot and Cold", true
            elseif instrumentsSet or instrumentsInFolder then
                note, replaced = "Replaced by instruments", true
            elseif missingMix then
                note = string.format("%s song missing, select this song again", missingMix)
            end

            if note and type(parentRow.label) == "string" then
                local label = parentRow.label

                -- Nothing plays from a replaced row, so the note takes the "Default" placeholder's place
                if replaced and endsWith(label, defaultText) then
                    parentRow.label = label:sub(1, #label - #defaultText) .. textFormat.fade(note)
                else
                    parentRow.label = label .. "  " .. textFormat.fade(string.format("(%s)", note))
                end
            end
        end
    end
end)
