-- Song titles and artists of the built-in soundtracks, from Lobby Jukebox 2

local boss = require "necro.game.level.Boss"
local levelSequence = require "necro.game.level.LevelSequence"
local soundtrack = require "necro.game.data.Soundtrack"

local Artist = soundtrack.Artist
local Boss = boss.Type
local TrackType = soundtrack.TrackType
local Variant = soundtrack.Variant
local Zone = levelSequence.Zone

local SongTitleTable = {}

-- Used by every soundtrack that doesn't list its own
SongTitleTable.shared = {
    titles = {
        [TrackType.LOBBY] = "Rhythmortis",
        [TrackType.TRAINING] = "Watch Your Step",
        [TrackType.TUTORIAL] = "Tombtorial",
        zones = {
            [Zone.ZONE_1] = { "Disco Descent", "Crypteque", "Mausoleum Mash" },
            [Zone.ZONE_2] = { "Fungal Funk", "Grave Throbbing", "Portabellohead" },
            [Zone.ZONE_3] = {
                { [Variant.COLD] = "Stone Cold", [Variant.HOT] = "Igneous Rock" },
                { [Variant.COLD] = "Dance of the Decorus", [Variant.HOT] = "March of the Profane" },
                { [Variant.COLD] = "A Cold Sweat", [Variant.HOT] = "A Hot Mess" },
            },
            [Zone.ZONE_4] = { "Styx and Stones", "Heart of the Crypt", "The Wight to Remain" },
            [Zone.ZONE_5] = { "Voltzwaltz", "Power Cords", "Six Feet Thunder" },
        },
        bosses = {
            [Boss.KING_CONGA] = "Konga Conga Kappa",
            [Boss.DEATH_METAL] = "Metalmancy",
            [Boss.DEEP_BLUES] = "Knight to C-Sharp",
            [Boss.CORAL_RIFF] = "Deep Sea Bass",
            [Boss.FORTISSIMOLE] = "Notorious D.I.G.",
            [Boss.DEAD_RINGER] = "For Whom the Knell Tolls",
            [Boss.NECRODANCER] = "Momentum Mori",
            [Boss.NECRODANCER_2] = "Momentum Mori (Melody ver.)",
            [Boss.GOLDEN_LUTE] = "Absolutetion",
            [Boss.FRANKENSTEINWAY] = "Steinway to Heaven",
            [Boss.CONDUCTOR] = "Vamplified",
        },
    },
    artists = {
        [TrackType.TRAINING] = "Danny Baranowsky",
        [TrackType.TUTORIAL] = "Danny Baranowsky",
        bosses = {
            [Boss.DEAD_RINGER] = "Danny Baranowsky",
            [Boss.NECRODANCER] = "Danny Baranowsky",
            [Boss.NECRODANCER_2] = "Danny Baranowsky",
            [Boss.GOLDEN_LUTE] = "Danny Baranowsky feat. FamilyJules",
            [Boss.FRANKENSTEINWAY] = "Danny Baranowsky",
            [Boss.CONDUCTOR] = "Danny Baranowsky",
        },
    },
}

SongTitleTable.soundtracks = {
    [Artist.DANNY_B] = {
        artist = "Danny Baranowsky",
        artists = {
            zones = {
                [Zone.ZONE_3] = {
                    { [Variant.HOT] = "Danny Baranowsky feat. FamilyJules" },
                    { [Variant.HOT] = "Danny Baranowsky feat. FamilyJules" },
                    { [Variant.HOT] = "Danny Baranowsky feat. FamilyJules" },
                },
            },
            bosses = {
                [Boss.DEATH_METAL] = "Danny Baranowsky feat. FamilyJules",
            },
        },
    },
    [Artist.A_RIVAL] = {
        artist = "A_Rival",
    },
    [Artist.FAMILYJULES7X] = {
        artist = "FamilyJules",
        titles = {
            [TrackType.LOBBY] = "Breath Before the Chaos",
            zones = {
                [Zone.ZONE_1] = { "Infernal Descent", "The Deranged", "Spectral Storm" },
                [Zone.ZONE_2] = { "Blaze Hazard", "Undead Desperation", "Dark Means" },
                [Zone.ZONE_3] = {
                    { [Variant.COLD] = "Frozen in Panic", [Variant.HOT] = "Scorched Volcanic" },
                    { [Variant.COLD] = "Anguish of the Frost", [Variant.HOT] = "Heart of the Flame" },
                    { [Variant.COLD] = "A Glacial Death", [Variant.HOT] = "A Dragon's Breath" },
                },
                [Zone.ZONE_4] = { "Apex and Bones", "Fury of the Crypt", "A Shadow to Prevail" },
                [Zone.ZONE_5] = { "Tesla Toil", "Power Corpse", "Trial of Thunder" },
            },
            bosses = {
                [Boss.KING_CONGA] = "Stronger Konga",
                [Boss.DEATH_METAL] = {
                    [Variant.DEFAULT] = "Pyrodancer",
                    [Variant.ALTERNATIVE] = "Pyrodancer (Polka ver.)",
                },
                [Boss.DEEP_BLUES] = "Knight Fall",
                [Boss.CORAL_RIFF] = "Deep Fear Octobass",
                [Boss.FORTISSIMOLE] = "Molevolence",
            },
        },
    },
    [Artist.VIRT] = {
        artist = "Jake Kaufman",
    },
    [Artist.GIRLFRIEND_RECORDS] = {
        artistPrefix = "Girlfriend Records - ",
        artists = {
            [TrackType.LOBBY] = "Johnatron",
            zones = {
                [Zone.ZONE_1] = { "Johnatron", "Johnatron", "Johnatron" },
                [Zone.ZONE_2] = { "Sferro", "Sferro", "Sferro" },
                [Zone.ZONE_3] = {
                    { [Variant.COLD] = "Sferro", [Variant.HOT] = "Tommy '86" },
                    { [Variant.COLD] = "Sferro", [Variant.HOT] = "Tommy '86" },
                    { [Variant.COLD] = "Sferro", [Variant.HOT] = "Tommy '86" },
                },
                [Zone.ZONE_4] = { "Tommy '86", "Tommy '86", "Tommy '86" },
                [Zone.ZONE_5] = { "Tommy '86", "Sferro", "Johnatron" },
            },
            bosses = {
                [Boss.KING_CONGA] = "Johnatron",
                [Boss.DEATH_METAL] = "Sferro",
                [Boss.DEEP_BLUES] = "Johnatron",
                [Boss.CORAL_RIFF] = "Tommy '86",
                [Boss.FORTISSIMOLE] = {
                    [Variant.DEFAULT] = "Johnatron",
                    [Variant.ALTERNATIVE] = "Sferro",
                    [Variant.ALTERNATIVE_2] = "Tommy '86",
                },
            },
        },
    },
    [Artist.OC_REMIX] = {
        artistPrefix = "OC ReMix - ",
        titles = {
            [TrackType.LOBBY] = "Funky Morty",
            zones = {
                [Zone.ZONE_1] = { [1] = "9-bit Cryptography", [3] = "Sepulchre Soirée" },
            },
        },
        artists = {
            [TrackType.LOBBY] = "Flexstyle",
            [TrackType.TRAINING] = "Ben Briggs",
            zones = {
                [Zone.ZONE_1] = { "DDRKirby(ISQ)", "RoboRob", "Chimpazilla" },
                [Zone.ZONE_2] = { "bLiNd", "Phonetic Hero", "Funk Fiction" },
                [Zone.ZONE_3] = {
                    { [Variant.COLD] = "Flexstyle feat. Nabeel Ansari", [Variant.HOT] = "Sir_NutS" },
                    { [Variant.COLD] = "bLiNd", [Variant.HOT] = "Kruai" },
                    { [Variant.COLD] = "bLiNd", [Variant.HOT] = "Phonetic Hero" },
                },
                [Zone.ZONE_4] = { "RoBKTA", "Funk Fiction", "Flexstyle feat. DjjD" },
                [Zone.ZONE_5] = { "Chimpazilla", "PrototypeRaptor", "Funk Fiction" },
            },
            bosses = {
                [Boss.KING_CONGA] = "RoboRob",
                [Boss.DEATH_METAL] = "Flexstyle",
                [Boss.DEEP_BLUES] = "James Landino",
                [Boss.CORAL_RIFF] = "PrototypeRaptor",
                [Boss.FORTISSIMOLE] = "RoboRob",
            },
        },
    },
    [Artist.CHIPZEL] = {
        artist = "Chipzel",
    },
    [Artist.DANGANRONPA] = {
        artist = "Masafumi Takada",
        titles = {
            [TrackType.LOBBY] = "DANGANRONPA",
            zones = {
                [Zone.ZONE_1] = { "Last VERSUS", "Junk Food for a Dashing Youth", "Discussion -HEAT UP-" },
                [Zone.ZONE_2] = { "5th Island Theme", "Wonderful Dead", "Alice in the Children's Land" },
                [Zone.ZONE_3] = {
                    { [Variant.COLD] = "BOX 15", [Variant.HOT] = "BOX 16" },
                    "It's a Monokuma World",
                    {
                        [Variant.COLD] = "Supplementary Lessons for the Unlucky",
                        [Variant.HOT] = "Supplementary Lessons for the Mysterious",
                    },
                },
                [Zone.ZONE_4] = { "DISTRUST", "Kill Command", "Class Trial (Future Edition)" },
            },
            bosses = {
                [Boss.KING_CONGA] = "Mr. Monokuma's Extracurricular Lesson",
                [Boss.DEATH_METAL] = "Monster That Shouts Its Love in the Center of Hell",
                [Boss.DEEP_BLUES] = "Punishment",
                [Boss.CORAL_RIFF] = "Trial Underground",
            },
        },
        artists = {
            zones = {
                [Zone.ZONE_5] = { "Danny Baranowsky", "Danny Baranowsky", "Danny Baranowsky" },
            },
            bosses = {
                [Boss.FORTISSIMOLE] = "Danny Baranowsky",
            },
        },
    },
    [Artist.GROOVE_COASTER] = {
        artist = "COSIO",
        titles = {
            [TrackType.LOBBY] = "Groove Prayer",
            zones = {
                [Zone.ZONE_1] = { "Thrash Beat", "I CANNOT APE", "It's a pit world" },
                [Zone.ZONE_2] = { "Static Const Void", "SKYSCRAPER", "QLWA" },
                [Zone.ZONE_3] = { "Invader Disco", "BEFORE TEN ORB", "VELVET" },
                [Zone.ZONE_4] = { "Maiami Sound Remix", "Five to Seven", "Fess Up!" },
            },
            bosses = {
                [Boss.KING_CONGA] = "カンナンシンク(Mortification of the Flesh)",
                [Boss.DEATH_METAL] = "Satisfaction",
                [Boss.DEEP_BLUES] = "FAKE (ALR Remix) (ダライアス外伝)",
                [Boss.CORAL_RIFF] = "Protocol Signal Generation",
            },
        },
        artists = {
            [TrackType.LOBBY] = "COSIO feat. ChouCho",
            zones = {
                [Zone.ZONE_1] = { [3] = "Shohei Tsuchiya feat. SATOMI" },
                [Zone.ZONE_2] = { [2] = "Dr. ARM (IOSYS)", [3] = "t+pazolite" },
                [Zone.ZONE_3] = { [3] = "Massive New Krew" },
                [Zone.ZONE_4] = { "Mitsuto Suzuki", "Sampling Masters AYA", "Shohei Tsuchiya" },
                [Zone.ZONE_5] = { "Tommy '86", "Sferro", "Johnatron" },
            },
            bosses = {
                [Boss.KING_CONGA] = "Shohei Tsuchiya",
                [Boss.DEATH_METAL] = "t+pazolite",
                [Boss.DEEP_BLUES] = "Masayoshi Minoshima",
                [Boss.FORTISSIMOLE] = "Johnatron",
            },
        },
    },
    [Artist.HATSUNE_MIKU] = {
        artist = "Danny Baranowsky",
        artistSuffix = " & Hatsune Miku",
        titles = {
            zones = {
                [Zone.ZONE_1] = { "Too Real", "Wonder Style", "SURVIVE (Foxsky Remix)" },
                [Zone.ZONE_2] = { "Ten Thousand Stars", "Lucky Orb (Clean Tears Remix)", "UNDERWATER (Rexium Remix)" },
                [Zone.ZONE_3] = { "Highlight", "Intergalactic Bound", "Hello Builder" },
                [Zone.ZONE_4] = { "MikuFiesta", "Can't Make A Song!!", "Be Furious (Reno Remix)" },
                [Zone.ZONE_5] = { "sweety glitch", "Thousand Little Voices", "My One and Oni" },
            },
        },
        artists = {
            zones = {
                [Zone.ZONE_1] = { [2] = "colatte", [3] = "Umetora" },
                [Zone.ZONE_2] = { "CircusP", "emon(Tes.)", "Hylen" },
                [Zone.ZONE_3] = { "KIRA", "CircusP & Yunosuke", "UtsuP" },
                [Zone.ZONE_4] = { "AlexTrip Sands", "beat_shobon", "Ocelot" },
                [Zone.ZONE_5] = { "gaburyu & nyankobrq", "Vault Kid & FlangerMoose" },
            },
        },
    },
    [Artist.SHOVEL_KNIGHT] = {
        artist = "Jake Kaufman",
        titles = {
            zones = {
                [Zone.ZONE_1] = {
                    "La Dance Macabre (Lich Yard)",
                    "An Underlying Problem (The Lost City)",
                    "In the Halls of the Usurper (Pridemoor Keep)",
                },
                [Zone.ZONE_2] = {
                    "The Buzz in the Grotto (Troupple Pond)",
                    "The Betrayer (Enchantress Final Form)",
                    "The Defender (Black Knight Battle)",
                },
                [Zone.ZONE_3] = {
                    "Main Theme",
                    "High Above the Land (The Flying Machine)",
                    "The Rival (Black Knight - First Battle)",
                },
                [Zone.ZONE_4] = {
                    "Flowers of Antimony (The Explodatorium)",
                    "Strike the Earth! (Plains of Passage)",
                    "A Thousand Leagues Below (Iron Whale)",
                },
                [Zone.ZONE_5] = {
                    "Of Devious Machinations (Clockwork Tower)",
                    "The Vital Vitriol (Plague Knight Battle)",
                    "Fighting with All of Our Might (Wandering Traveler Battle)",
                },
            },
        },
        artists = {
            zones = {
                [Zone.ZONE_4] = { [1] = "Manami Matsumae", [3] = "Manami Matsumae" },
            },
        },
    },
}

--- A whole Zone 3 floor plays Hot and Cold at once, so it answers with Hot
local function pickVariant(value, variant)
    if type(value) ~= "table" then
        return value
    elseif value[variant] then
        return value[variant]
    elseif variant == Variant.DEFAULT then
        return value[Variant.HOT] or value[Variant.COLD]
    end

    return value[Variant.DEFAULT]
end

local function lookUp(map, track)
    if type(map) ~= "table" then
        return nil
    end

    local value = nil

    if track.type == TrackType.ZONE then
        local floors = map.zones and map.zones[track.zone]

        value = floors and floors[track.floor or track.level or 1]
    elseif track.type == TrackType.BOSS then
        value = map.bosses and map.bosses[track.boss]
    else
        value = map[track.type]
    end

    return pickVariant(value, type(track.variant) == "string" and track.variant or Variant.DEFAULT)
end

function SongTitleTable.get(artist, track)
    local own = SongTitleTable.soundtracks[artist]

    if not own or type(track) ~= "table" then
        return nil
    end

    local shared = SongTitleTable.shared
    local title = lookUp(own.titles, track) or lookUp(shared.titles, track)

    -- Every song in the game has a shared title
    if not title then
        return nil
    end

    local function decorate(text)
        return text and (own.artistPrefix or "") .. text .. (own.artistSuffix or "")
    end

    return {
        title = title,
        artist = decorate(lookUp(own.artists, track)) or lookUp(shared.artists, track) or decorate(own.artist),
    }
end

return SongTitleTable
