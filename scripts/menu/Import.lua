local menu = require "necro.menu.Menu"
local textFormat = require "necro.config.i18n.TextFormat"
local tick = require "necro.cycles.Tick"

local stringUtils = require "system.utils.StringUtilities"
local utils = require "system.utils.Utilities"

local fonts = require "CustomArtists.scripts.menu.Fonts"
local registry = require "CustomArtists.scripts.ArtistRegistry"
local resourcePacks = require "CustomArtists.scripts.ResourcePacks"
local stockActions = require "CustomArtists.scripts.menu.StockActions"

-- Importing copies a resource pack's songs into a new playlist. Mods can't write song files, but the stock
-- "Create new mod" screen copies a template of files into a new local pack. Its action closes the top menu and opens
-- the resource pack picker, which turns every resource pack off and back on again when closed.

local ID_DONE = "done"

-- Long enough for the game to fetch a pack icon from the workshop, and hidden behind the loading screen
local ICON_DOWNLOAD_SECONDS = 2

local importInProgress = false

-- The picker an import opens would otherwise open the new pack's folder when closed
event.menu.add("skipImportPickerFolder", { key = "assetModGenerator", sequence = -1 }, function(ev)
    if importInProgress and type(ev.arg) == "table" then
        ev.arg.openDirectoryOnExtract = nil
    end
end)

local function importResourcePack(modName)
    local plan = resourcePacks.planImport(modName)

    if not plan then
        log.warn("[CustomArtists] Resource pack %s has no music to import", tostring(modName))

        return
    end

    local author, icon = stockActions.findResourcePackInfo(modName)

    if not author or not icon then
        log.warn("[CustomArtists] Resource pack %s: author %s, picture %s", modName, tostring(author), tostring(icon))
    end

    plan.metadata.author = author

    resourcePacks.addPlanIcon(plan, icon)

    local foldersBefore = utils.listToSet(resourcePacks.listLocalFolders())

    importInProgress = true

    local success, err = pcall(stockActions.run, "assetModCreator", {
        modInfo = {
            displayName = plan.title,
            description = plan.description,
        },
        template = plan.template,
        openGenerator = true,
    }, stockActions.findCreateMod, "import " .. modName)

    importInProgress = false

    if not success then
        log.warn("[CustomArtists] Importing resource pack %s failed: %s", modName, tostring(err))
    end

    local playlist = nil

    for _, folder in ipairs(resourcePacks.listLocalFolders()) do
        if not foldersBefore[folder] then
            playlist = "res_" .. folder
        end
    end

    -- Finish before closing the picker, so turning resource packs back on leaves the new playlist off
    if playlist then
        registry.finishImport(playlist, plan.metadata)
    else
        log.warn("[CustomArtists] Importing resource pack %s didn't create a new playlist", modName)
    end

    local picker = menu.getCurrent()

    if picker and picker.name == "assetModGenerator" and type(picker.escapeAction) == "function" then
        picker.escapeAction()
    end

    if playlist then
        menu.open("CustomArtists_info", { playlist = playlist })
    end
end

local importDeferred = tick.registerDelay(function(modName)
    menu.closeNamed("loadingScreen")
    importResourcePack(modName)
end, "importResourcePack")

--- Shows a loading screen, then imports a moment later so the screen is drawn before the game freezes, and so a pack
--- icon that lives on the workshop has time to arrive
local function startImport(modName)
    stockActions.findResourcePackInfo(modName)
    menu.open("loadingScreen", {
        text = string.format("Importing %s...", resourcePacks.getTitle(modName)),
        persist = true,
    })
    importDeferred(modName, ICON_DOWNLOAD_SECONDS)
end

event.menu.add("customArtistsImportPack", "CustomArtists_importPack", function(ev)
    local entries = {}
    local packs = resourcePacks.list(stockActions.listAssetMods())

    -- Menus center each row's text on its y and place the next row at y + height + ENTRY_SPACING (with fonts drawn at
    -- twice their size), so these heights put each subtitle just under its title and keep packs apart
    local ENTRY_SPACING = 16
    local TITLE_SUBTITLE_GAP = 2
    local PACK_GAP = 24
    local titleSize = fonts.mediumLowercase.size * 2
    local subtitleSize = fonts.smallLowercase.size * 2
    local titleHeight = math.max(0, (titleSize + subtitleSize) * 0.5 + TITLE_SUBTITLE_GAP - ENTRY_SPACING)
    local subtitleHeight = math.max(0, (titleSize + subtitleSize) * 0.5 + PACK_GAP - ENTRY_SPACING)

    table.sort(packs, function(pack1, pack2)
        return stringUtils.compareIgnoreCase(resourcePacks.getTitle(pack1), resourcePacks.getTitle(pack2))
    end)

    for _, modName in ipairs(packs) do
        local _, artist, songCount = resourcePacks.detectSoundtrack(modName)
        local artistID = artist and registry.getID(artist)
        local details = {
            string.format("%s songs: %d", artistID and registry.getTitle(artistID) or "Danny B", songCount),
            resourcePacks.hasBeatmaps(modName) and "own beatmaps" or "game beatmaps",
            resourcePacks.getKind(modName),
        }

        if #registry.listImportsOf(modName) > 0 then
            details[#details + 1] = "already imported"
        end

        entries[#entries + 1] = {
            id = "pack_" .. modName,
            label = resourcePacks.getTitle(modName),
            font = fonts.mediumLowercase,
            fontSize = titleSize,
            height = titleHeight,
            padding = 0,
            -- Select the pack by its title or its subtitle
            boundingBoxInit = function(box, entry)
                return { box[1], entry.y - titleSize * 0.5 - 4, box[3], titleSize + TITLE_SUBTITLE_GAP + subtitleSize + 8 }
            end,
            -- The import closes this menu itself
            action = function()
                startImport(modName)
            end,
        }
        entries[#entries + 1] = {
            label = textFormat.fade(table.concat(details, ", ")),
            font = fonts.smallLowercase,
            fontSize = subtitleSize,
            height = subtitleHeight,
            selectableIf = false,
        }
    end

    if #packs == 0 then
        entries[#entries + 1] = {
            label = "No resource packs with music found",
            selectableIf = false,
        }
        entries[#entries + 1] = {
            label = textFormat.fade("Local and downloaded packs are always listed, workshop packs while they are mounted"),
            font = fonts.smallLowercase,
            selectableIf = false,
        }
    end

    entries[#entries + 1] = { height = 0 }
    entries[#entries + 1] = {
        id = ID_DONE,
        label = "Cancel",
        sound = "UIBack",
        action = function()
            menu.close()
        end,
    }

    local hintLine = fonts.smallLowercase.size * 2

    -- A workshop pack is mounted from its download rather than unpacked, so there is nothing to read from one the
    -- game has not mounted
    entries[#entries + 1] = {
        label = textFormat.fade(
        "A workshop pack is only listed while it is mounted. Right-click on the pack -> \"Open Directory\" to mount."),
        font = fonts.smallLowercase,
        sticky = 1,
        y = -12 - hintLine,
        selectableIf = false,
    }
    entries[#entries + 1] = {
        label = textFormat.fade(
        "Importing copies every song into a new custom music mod, which causes the game to load for a few seconds."),
        font = fonts.smallLowercase,
        sticky = 1,
        y = -12,
        selectableIf = false,
    }

    ev.menu = {
        label = "Import resource pack",
        entries = entries,
        -- Room for both hints, so they stay clear of Cancel
        footerSize = 15 + hintLine,
        escapeAction = function()
            menu.close()
        end,
    }
end)

-- "Import as custom artist" on the Manage mod page of resource packs with music, before "Change priority"
event.menu.add("addImportResourcePackOption", { key = "modConfig", sequence = 1 }, function(ev)
    local modName = type(ev.arg) == "table" and ev.arg.modName or ev.arg
    local entries = ev.menu and ev.menu.entries

    if type(modName) ~= "string" or type(entries) ~= "table" or not resourcePacks.hasMusic(modName) then
        return
    end

    local index = #entries

    for i, entry in ipairs(entries) do
        if entry.enableIf then
            index = i

            break
        end
    end

    table.insert(entries, index, {
        label = "Import as custom artist",
        action = function()
            startImport(modName)
        end,
    })
end)
