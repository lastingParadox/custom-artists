# Custom Artists - integration reference

Custom Artists registers every playlist as a `Soundtrack.Artist`, so an artist it adds behaves like a built-in one and
most mods need nothing from here. This lists the functions meant for other mods to call.

There is no separate API module; require the scripts directly, as you would `necro.*`. The namespace is
`CustomArtists` however the mod was installed. Depend on it in `mod.json` by its mod.io name,
`CustomArtists_io_6387365`.

---

## Referring to an artist

Three different strings name the same artist, and which one you need depends on what you are holding. Taking a
playlist imported into a folder called `Reanimated Remixes`:

| | Custom artist | Stock soundtrack |
| --- | --- | --- |
| **Artist ID** - what most of this API takes | `res_Reanimated Remixes` | `builtin:DANNY_B` |
| **`Soundtrack.Artist` name** | `CustomArtists_ARTIST_RES_REANIMATED_REMIXES` | `DANNY_B` |
| **Display name** - what the player sees | `Reanimated Remixes` | `Danny B` |

A playlist's ID is its asset mod name: `res_` followed by the folder name, spaces and all. Its enum name is derived
from that ID by uppercasing it and replacing every non-alphanumeric character with `_`, then prefixed with the mod
namespace, because `Enum.extend` namespaces every key it registers.

Do not hardcode any of the three. The ID follows the folder name, which changes if the playlist is renamed or
imported under a different name, and the enum name follows the ID. Convert from whatever you have instead:

```lua
-- from an artist value you already hold, e.g. off a music track or Change Soundtrack
local id = artists.toID(artist)              --> "res_Reanimated Remixes"
local info = artists.getMetadata(artist)     --> info.title == "Reanimated Remixes"

-- from the name the player sees
for _, id in ipairs(artists.listPlaylists()) do
    if artists.getTitle(id) == "Reanimated Remixes" then ... end
end

-- from an ID back to a Soundtrack.Artist value
local artist = artists.getArtistValue(id)
```

`getArtistValue` returns `nil` for a playlist created since scripts loaded, because enum entries are registered at
load time and a new playlist has none until a reload.

If you must name one statically, use the enum rather than the literal string. `Soundtrack.Artist` is `nil` for an
artist that is not installed, where a hardcoded string silently is not:

```lua
local artist = Soundtrack.Artist.CustomArtists_ARTIST_RES_REANIMATED_REMIXES
```

---

## Module ArtistRegistry

```lua
local artists = require "CustomArtists.scripts.ArtistRegistry"
```

### Listing

| Function | Description |
| --- | --- |
| `artists.listAll()` | Every artist ID, built-in soundtracks then playlists. |
| `artists.listBuiltIn()` | IDs of stock soundtracks that are installed and selectable. |
| `artists.listPlaylists()` | IDs of custom artists only. |
| `artists.listImportsOf(modName)` | Playlists imported from the given resource pack. |

### Identity

| Function | Description |
| --- | --- |
| `artists.toID(artist)` | ID for an ID or a `Soundtrack.Artist` value; `nil` if unknown. |
| `artists.getID(artist)` | ID for a `Soundtrack.Artist` value. |
| `artists.getArtistValue(id)` | `Soundtrack.Artist` value; `nil` for a playlist created since scripts loaded. |
| `artists.getPlaylist(artist)` | Playlist name behind a `Soundtrack.Artist` value; `nil` for a built-in. |
| `artists.isCustom(id)` | `true` for a playlist, `false` for a stock soundtrack. |

### Metadata

| Function | Description |
| --- | --- |
| `artists.getMetadata(id)` | Everything the menus show, for either kind of artist; `nil` if unknown. Accepts a `Soundtrack.Artist` value. |
| `artists.setMetadata(id, fields)` | Writes the fields the Custom Artists menu edits, ignoring any other key. `true` if all of them applied. |
| `artists.getTitle(id)` | Display name. |
| `artists.getAuthor(id)` | Author, or `nil`. |
| `artists.getDescription(id)` | Description text. |
| `artists.getIcon(id)` | Square image path ready to draw, or `nil`. |
| `artists.getBanner(id)` | Wide image path ready to draw, or `nil`. |
| `artists.listFolderImages(playlist)` | Image file names in a playlist's folder - the names `setMetadata` accepts. |

`getMetadata` returns `{ title, author, description, icon, banner, custom, randomized, hidden }`. A stock soundtrack
answers from the table inside this mod, a playlist from its `playlist.json`.

`setMetadata` takes `title`, `author`, `description`, `icon`, `banner`, `randomized` and `hidden`. **`icon` and
`banner` are file names inside the playlist folder here, while `getMetadata` returns resolved paths.** `randomized`
and `hidden` apply to stock soundtracks too, since this mod stores them; the rest belong to a playlist, so
`setMetadata` returns `false` if they are set on a stock soundtrack.

### Availability

| Function | Description |
| --- | --- |
| `artists.isRandomized(id)` | Whether the artist contributes to the song randomizer. |
| `artists.setRandomized(id, randomized)` | Sets that flag. |
| `artists.isHidden(id)` | Whether the artist is hidden from Change Soundtrack. |
| `artists.setHidden(id, hidden)` | Sets that flag, moving characters off the artist when hiding it. |
| `artists.isAlternateRhythm(playlist)` | Whether the playlist's songs use their own beatmaps rather than the game's timing. |
| `artists.hasOwnBeatmaps(playlist)` | Whether the playlist folder supplies beatmap files. |

### Playlists

| Function | Description |
| --- | --- |
| `artists.create(name)` | Creates an empty playlist and returns its ID. |
| `artists.getBasePath(playlist)` | Folder path of a playlist, with a trailing slash. |
| `artists.getImportLabel(playlist)` | Name of the resource pack a playlist was imported from, or `nil`. |
| `artists.addChangeListener(listener)` | Runs `listener` whenever an artist's availability changes. The randomizer uses this to drop its cached pool. |

### Which songs an artist has

Answered by [Module SongRandomizer](#module-songrandomizer): `randomizer.listSongs(id)`, `randomizer.countSongs(id)`
and `randomizer.hasSong(id, track)` all take an artist ID as readily as a `Soundtrack.Artist` value. They live there
because they are built on the randomizer's map of areas, not because they are only useful for randomizing. An
imported pack usually covers part of the game, so anything about to play one should ask first.

---

## Enumerations

Custom Artists defines no enum of its own for mods to extend. It extends two of the game's, and a mod that walks
either one will meet the entries below.

### Soundtrack.Artist

One entry per playlist, named as described under [Referring to an artist](#referring-to-an-artist). Entries are
added while scripts load, so a playlist created later needs a script reload before it has one.

```lua
local playlist = Soundtrack.Artist.data[artist].CustomArtists_playlist
```

Everything else is a stock artist field, set the way Hatsune Miku or Shovel Knight set theirs. Two are worth knowing
because they change how other code should treat a custom artist:

| Stock field | Value | Consequence |
| --- | --- | --- |
| `excludeFromRandom` | `true` | Code respecting this flag leaves them out of its own artist randomization. |
| `alternateRhythm` | `true` when the playlist supplies its own beatmaps | Its songs do not keep stock timing. |

`suffix`, `order` and `tileLayersCorrelated` are set as well, but only to place custom artists sensibly in the stock
machinery; nothing outside this mod needs to read them.

`shopkeeper` is deliberately left unset, so a custom artist reads as having a shopkeeper. It does: this mod resolves
the shopkeeper layer itself in `event.musicTrack`, using the playlist's own vocals if it has them and the game's
otherwise. Set `params.vocals` for a custom artist as for Danny B.

### GameSong.Type

One entry per song variant, so the Custom Music editor can hold a file name for a song the base game addresses as a
variant of another. Each is registered only if its parent song exists, so a game without the matching DLC has fewer.

Extending an enum namespaces the name, so these appear in `GameSong.Type.names` with a `CustomArtists_` prefix.

| Name | Covers |
| --- | --- |
| `CustomArtists_ZONE_3_1_HOT`, `..._COLD` | Zone 3-1's hot and cold mixes; likewise `ZONE_3_2_*` and `ZONE_3_3_*`. |
| `CustomArtists_BOSS_NECRODANCER_PHASE_2` | The NecroDancer's second phase. |
| `CustomArtists_BOSS_CORAL_RIFF_INSTRUMENT_0` … `_4` | Coral Riff's main instrument, drums, horns, strings and keytar. |
| `CustomArtists_BOSS_FORTISSIMOLE_VERSION_2`, `..._VERSION_3` | Fortissimole's second and third songs, rolled between at the start of the fight like Girlfriend Records' three versions. |
| `CustomArtists_BOSS_FORTISSIMOLE_RAP` | Fortissimole's rap vocal track. |

Their `track` is `{ type = SongVariants.TRACK_TYPE, CustomArtists_songVariant = <key> }` rather than a stock zone or
boss track, so code switching on `track.type` should ignore types it does not recognise instead of assuming a song
is a zone or a boss.

### Randomizer constants

`randomizer.Mode`, `ArtistScope`, `Duplicates` and `Seeding` are plain string tables, not extendable enums. The
randomizer switches on the values it knows, so adding a key to one has no effect. To change how a track is resolved,
handle `event.customArtistsSongRandomizer` instead.

---

## Module SongInfo

```lua
local songInfo = require "CustomArtists.scripts.SongInfo"
```

The title and artist of individual songs, for custom artists and the stock soundtracks alike.

- **Custom artists:** players set them by right-clicking a song row in the Custom Artists song editor (or pressing
  the secondary select button on it). They are stored in `playlist.json` under `customArtist.songs`, keyed by the
  song's `GameSong.Type` name. A song with a title shows it in the editor in place of its file name.
- **Stock soundtracks:** read-only, from `scripts/SongTitleTable.lua` (data from Lobby Jukebox 2, keyed by
  `Soundtrack.Artist`, `LevelSequence.Zone`, `Boss.Type` and `Soundtrack.Variant`). It covers only the songs of the
  eleven soundtracks of the base game and its DLC: soundtracks, zones and bosses added by other mods return `nil`.

Info is `{ title = <string>, artist = <string> }`, with either field absent when unknown, and `nil` when neither is.
A custom artist's songs always have both: an unset title is the name the song editor gives the row (`Zone 1-1`), and
an unset artist is the custom artist's author, or its name when it has no author.

### Which song

Functions taking `song` accept any of:

- a `GameSong.Type` name, such as `ZONE_1_2`, `BOSS_KING_CONGA`, `LOBBY` or `CustomArtists_BOSS_FORTISSIMOLE_VERSION_2`;
- a `GameSong.Type` value;
- a track, shaped as `Soundtrack.getTrack` returns it and `event.musicPlay` passes it as `ev.track`. Phase 2 and
  Fortissimole's other versions resolve to their own rows from `track.variant`.

| Function | Description |
| --- | --- |
| `songInfo.getSongKey(song)` | The name a song is stored under; `nil` if no editor row matches. |

### Reading

| Function | Description |
| --- | --- |
| `songInfo.getPlaying()` | Info of the music playing now, then the artist ID and song key. Nothing while music is stopped; `info` alone is `nil` for a song nothing is known about. |
| `songInfo.get(artist, song)` | Info for one song. `artist` is an ID or a `Soundtrack.Artist` value. |
| `songInfo.getForTrack(artist, track)` | Like `get`, but for a track. Zone 3 floors play their Hot and Cold songs at once, so the Hot song answers for its floor, then the Cold one. |
| `songInfo.list(artist)` | `{ [song key] = info }` for every song that has info. |

`getPlaying` reports the artist actually heard: it reads the track after every `event.musicTrack` handler has run,
so the song randomizer has picked its artist and an artist missing the song has already fallen back to Danny B.
It is cached when the track starts, so it is cheap to call every frame. `get`, `getForTrack` and `list` read
`playlist.json` on every call.

To react when a song starts, for example to show a "now playing" banner, handle `event.musicPlay` after this mod has
recorded the track:

```lua
event.musicPlay.add("showSongTitle", { order = "playAudio", sequence = 2 }, function(ev)
    local info = songInfo.getPlaying()

    if info and info.title then
        ...
    end
end)
```

### Writing

| Function | Description |
| --- | --- |
| `songInfo.set(artist, song, fields)` | Saves `fields.title` and/or `fields.artist` for a custom artist. An empty string clears a field and a field left out keeps its value. `false` for a stock soundtrack, whose info is fixed, or an unknown song. |
| `songInfo.clear(artist, song)` | Removes both fields. |
| `songInfo.refreshPlaying()` | Rereads `getPlaying`'s info, if you wrote `playlist.json` yourself. `set` and `clear` already do this. |

`fromMetadata(metadata, song)`, `setInMetadata(metadata, song, fields)` and `clearInMetadata(metadata, song)` do the
same on a `playlist.json` table without reading or saving the file; the song editor uses them on the table it holds
open. `fromMetadata` returns only what was set; `withDefaults(metadata, song, info)` fills in the rest, and
`getDefaultTitle(song)` and `getDefaultArtist(metadata)` give the defaults alone. Don't call `set` for a playlist that is open in the song editor, which saves its own copy when it closes.

---

## Module SongVariants

```lua
local variants = require "CustomArtists.scripts.SongVariants"
```

Interprets the `GameSong.Type` entries above.

| Member | Description |
| --- | --- |
| `variants.TRACK_TYPE` | The `track.type` value shared by every song variant. |
| `variants.list()` | Every registered variant definition. |
| `variants.getDefinition(key)` | Definition for an unprefixed key such as `BOSS_FORTISSIMOLE_RAP`; `nil` if unregistered. |
| `variants.getDefinitionByID(id)` | Definition for a prefixed `GameSong.Type` name such as `CustomArtists_BOSS_FORTISSIMOLE_RAP`. |

A definition carries `key` (unprefixed), `id` (the prefixed enum name), `songID`, `parent`, `parentID`,
`parentName`, `label`, `kind` (`mix`, `phase2`, `instrument`, `version` or `rap`), `file` and `beatmap`. `mix`,
`phase2` and `version` rows also carry the `variant` their parent's track plays them with (`soundtrack.Variant`).

---

## Module SongRandomizer

```lua
local randomizer = require "CustomArtists.scripts.randomizer.Randomizer"
```

### Constants

| Constant | Values |
| --- | --- |
| `randomizer.Mode` | `OFF`, `RANDOM_ARTIST`, `SHUFFLE_SONGS` |
| `randomizer.ArtistScope` | `PER_RUN`, `PER_ZONE`, `PER_FLOOR` |
| `randomizer.Duplicates` | `MINIMAL` (default), `PARTIAL`, `COMPLETE` |
| `randomizer.Seeding` | `PER_CHARACTER`, `FULLY_RANDOM` |

### Songs

| Function | Description |
| --- | --- |
| `randomizer.listSongs(artist)` | Areas the artist has a song for. Takes an ID or a `Soundtrack.Artist` value. |
| `randomizer.countSongs(artist)` | How many areas it covers. |
| `randomizer.hasSong(artist, track)` | Whether one specific track is covered. |

An area is `{ key = "zone:1:2", track = <track>, amplified = <boolean> }`. A `track` is shaped like the tables in
`necro.game.data.Soundtrack`, which is also what `Music.getParameters()` and `Music.setMusic` use, so a track you are
about to play can be passed straight to `hasSong`:

```lua
if randomizer.hasSong(artist, { type = Soundtrack.TrackType.ZONE, zone = 1, floor = 2 }) then
```

This matters more for custom artists than stock ones: an imported pack often covers only part of the game, and asking
it for an area it lacks falls back to another artist.

### Settings

| Function | Description |
| --- | --- |
| `randomizer.getConfig()` | The settings a track is resolved with, after event handlers have run. |
| `randomizer.isOverridden()` | Whether another mod changed those settings from what the menu shows, then the name that mod gave itself, or `nil`. |
| `randomizer.getMode()` / `setMode(mode)` | Randomizer mode. |
| `randomizer.getArtistScope()` / `setArtistScope(scope)` | How often `RANDOM_ARTIST` picks again. |
| `randomizer.getDuplicates()` / `setDuplicates(duplicates)` | How much of the soundtrack may repeat: `MINIMAL` deals each song once whichever artist plays it, `PARTIAL` lets another artist's version return, `COMPLETE` lets anything return. |
| `randomizer.getSeeding()` / `setSeeding(seeding)` | What the shuffle is keyed on. |
| `randomizer.setRandomized(id, randomized)` | Sets whether an artist contributes songs. |
| `randomizer.isCharacterRandomized(character)` / `setCharacterRandomized(character, randomized)` | Per-character opt-in. |
| `randomizer.reshuffle()` | Gives every character a new shuffle. |
| `randomizer.invalidate()` | Drops cached pools, if you changed something behind this mod's back. |

Prefer the event below over the setters: setters change what the player chose in the menu and persist, while the event
only changes what this run resolves to.

---

## Events

### `event.customArtistsSongRandomizer`

Fired every time the randomizer resolves a track, with the settings the menu would use. Handlers may change any field.
Use `order = "override"`.

```lua
event.customArtistsSongRandomizer.add("myMod", { order = "override" }, function(ev)
    ev.mode = randomizer.Mode.SHUFFLE_SONGS
    ev.seeding = randomizer.Seeding.PER_CHARACTER
    ev.seed = "my-seed"
    ev.allCharacters = true
    ev.source = "AP Redux"
end)
```

| Field | Values | Meaning |
| --- | --- | --- |
| `ev.mode` | `randomizer.Mode` | `OFF` disables randomization entirely. |
| `ev.artistScope` | `randomizer.ArtistScope` | How often `RANDOM_ARTIST` picks again. |
| `ev.duplicates` | `randomizer.Duplicates` | How much of the soundtrack may repeat within one shuffle. |
| `ev.seeding` | `randomizer.Seeding` | What the shuffle is keyed on. |
| `ev.seed` | any value | Used only by `PER_CHARACTER`; converted with `tostring`. |
| `ev.allCharacters` | boolean | Ignore the per-character opt-in in the menu. |
| `ev.source` | string | Your mod's name, for the randomizer menu to say who is responsible instead of "Another mod". Setting it alone does not count as an override. |

**`FULLY_RANDOM` ignores `ev.seed`**, keying the shuffle on `RNG.getDungeonSeed()` instead. A mod supplying its own
seed must use `PER_CHARACTER`, which keys the shuffle on `ev.seed` **and the current character**. One seed still
deals each character a different set of songs, consistently, across restarts. (This is mainly applicable for AP Redux in the future, but is kept here for consistency.)

---

## Playing a custom artist

Nothing special is required. `Music.setMusic(params)` calls `Soundtrack.getTrack(params)`, which fires
`event.musicTrack`, and this mod resolves a custom artist's files there. Set `params.artist` and the playlist's songs
play like any other soundtrack.

Set `params.vocals` as you would for any artist; custom artists sing, and their `shopkeeper` flag is unset to say so.

A mod that only needs to *recognise* a custom artist need not require anything; test for `CustomArtists_playlist` as
shown there. Beware of the inverse: code like `MY_NAMES[Soundtrack.Artist.names[artist]]` returns `nil` once any
custom artist exists, which is a crash if the result is concatenated into a label.
