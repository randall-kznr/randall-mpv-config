<h1 align="center">randall-mpv-config</h1>
This is my MPV config. Mostly used by me, but I have linked it to friends in the past. This is mostly because of companies like Crunchyroll/sony continuing to make subtitles for anime ugly, cheap, and riddled with problems because they know the mass of their userbase does not care. But I sure do!!! <br><br>

**TL;DR:** If you load a file and the substitles fucking suck press F2 and wait a few seconds. If you want subtitles to always change, set line 6 in `mpv.conf` to `yes`.

Here is a rundown of what this includes:
<br><br>

# Profiles
There are three profiles I switch between depending on mood or vintage of show.

### Modern Override

Main font is replaced by Gandhi Sans Bold `(size=48, border-size 3, shadow-offset 1.5, 0.25 blur (blur only affects shadow))`, a font designed by <a href="https://www.tipografiagandhi.com/">Librerias Gandhi S.A. de C.V.</a> It is, in my opinion, one of the best fonts you can possibly use for anime subtitles. Easy to read, good looking, and just the right thickness to make things readable but not overbearing.

<p align="center">
  <img src="https://files.revuestarlight.net/sharex/mpv_S0N0GplaAb.jpg" width="80%"><br>
  <em>Clannad, Kyou Chapter (Subtitles by UDF)</em>
</p>

If you are Old like me and want yellow subtitles, you can simply hit `c` (strictly lowercase) to change the color to a more acceptable and widely expected `#EBEB50`, which is a nice pale, desaturated yellow color: 

<p align="center">
  <img src="https://files.revuestarlight.net/sharex/mpv_iHS5AUkWxJ.jpg" width="80%"><br>
  <em>Vertex Force, episode 1.</em>
</p>

### Boomer Mode

This switches out the font with Arial Narrow. This is not included, because it should come with windows. If it does not, it surely can't be that hard to find and install yourself. Sorry. It changes the `sub-color` to `#FFFF00`, which is just full yellow. It also gives it a non-blurred, non-offset black border to replicate "Older" subtitles so that if you're watching something that would have that subtitle styling it doesn't feel as awkward. 

<p align="center">
  <img src="https://files.revuestarlight.net/sharex/mpv_s2rTIb9GB2.jpg" width="80%"><br>
  <em>Mahou Shoujo Lyrical Nanoha, episode 3. (Subtitles by Fete Rider)</em>
</p>

**Note:** If you switch profiles again, the yellow color will stay. This is intentional. If you really wish, you can even change the color of the yellow subs to white by pressing `c`. 

### AAA Japanese Video Game

ok this one is a joke. sorry. i included it because i think it is funny. this is the mgsv/xenoblade x/whatever other game you can think of here font. i just think its funny man. I tried to replicate the MGSV subtitle style and I think I got close enough? You are free to remove this if you wish. Live free, baby.

<p align="center">
  <img src="https://files.revuestarlight.net/sharex/mpv_cdCRwb0aem.jpg" width="80%"><br>
  <em>Black Lagoon The Second Barrage, Episode 3 (Subtitles by Judas)</em>
</p>


# Custom Keybinds

You can switch between color, profiles, and original subs quickly and easily. 

<div align=center>

| Key | Action|
|:-----:|:-------:|
|c    |Toggles between white and yellow subs.|
|p|Toggles between the three profiles.|
|f2| Toggles `ass-override` between `yes` and `no`.|


</div>

`ass-override` is what controls the font replacement. By switching it to `off`, it goes back to the original intended font set by the original subtitle styling. This is off by default, as the font replacement is meant to be only used for subtitles that are gross and bad. 

# restyle-dialogue.lua

**NOTE: THIS ONLY WORKS FOR .ASS SUBS.** if your show has SRT or PGS subs because it is old that is on you. eat your veggies.

This is the real big meat and potatoes. It only loads when you press `f2`, switching `ass-subtitle-override` to `yes`. This handles the logic with "What do I restyle, and what do I leave alone?" The script:

1. Extracts the subs via ffmpeg. **You should have this installed.** It reads from your PATH, so have that set up too.
- **Note:** If you load your files from a NAS or other local connection, this may take a little bit. For normal tv episodes, it's a couple of seconds, but for movies (8gb+) it'll probably take up to a minute or longer. It really depends on the file size. If you're watching a movie the subtitles are probably good though. The progress of this task is shown in the bottom left of the screen (Very small). If the .ass file is next to the video file, this step is skipped. 
2. Looks through the most commonly used style, plus any subtitles that looks like it's a dialogue style (see: `default`, `main`, `italics`, `flashback`, etc, etc...). This leaves karaoke, signs, etc. untouched as long as the person who did the subs has a brain. 

3. For those styles only, it swaps in the settings from `mpv.conf`: font, size, colors, shadow, etc. It converts the sizes into the styles file itself so they should look the same. This also resets horizontal and vertical scaling/res, so releases that use squished fonts for effect don't affect our new dialogue font. It also removes scaling tags and also removes stray `\N` calls at the end of lines (which adds a newline to the end of the subtitle, making it higher for no good reason), which crunchyroll really likes doing for reasons that we will never truly understand.

4. Preserves sign typesetting by looking for positioning, movement, clipping, drawing, or rotation tags is switched to an untouched copy of the original style so that it doesn't look weird (in theory. results may vary. works on my machine.)

5. Strips all margins and uses `sub-pos` from our `mpv.conf`. This is so if subs are too low or too high, it always brings it to the same level (by default, `sub-pos=99`)

6: Cleans up temp files when the video ends or MPV closes. Leftovers from crashes are wiped the next time mpv starts.

### Examples

<p align="center">
  <img src="https://files.revuestarlight.net/sharex/mpv_LJqvOQbkXm.jpg" width="80%"><br>
  <em>Shoujo☆Kageki Revue Starlight The Movie (Subtitles by Casual Tapir)</em>
</p>

<p align="center">
  <img src="https://files.revuestarlight.net/sharex/mpv_9KfHVY7Zab.jpg" width="80%"><br>
  <em>The Disappearance of Haruhi Suzumiya (Subtitles by MTBB)</em>
</p>

In theory, this script should catch *most* cases, but as always, your mileage may vary. If it doesn't work, its on the subgroup. Sorry!

# Also Included / Credits

`autoload.lua` - Loads the next files in the folder automatically after a file is done playing. This is pre-set up so it only loads video files next, and ignores audio and image files. You can disable this by setting line 36 in `\scripts\autoload.lua` to `true`. (Script created by MPV)

`cycle-profile.lua` - Script that enables the ability to switch between profiles, which we use for our different font setups. From: https://github.com/CogentRedTester/mpv-scripts