<h1 align="center">randall-mpv-config</h1>
This is my MPV config. Mostly used by me, but I have linked it to friends in the past. This is mostly because of companies like Crunchyroll/sony continuing to make subtitles for anime ugly, cheap, and riddled with problems because they know the mass of their userbase does not care. But I sure do!!! <br><br>
Here is a rundown of what this includes:
<br><br>

# Profiles
There are three profiles I switch between depending on mood or vintage of show.

### Default

Main font is replaced by Gandhi Sans Bold `(size=48, border-size 3, shadow-offset 1.5, 0.25 blur (blur only affects shadow))`, a font designed by <a href="https://www.tipografiagandhi.com/">Librerias Gandhi S.A. de C.V.</a> It is, in my opinion, one of the best fonts you can possibly use for anime subtitles. Easy to read, good looking, and just the right thickness to make things readable but not overbearing.

<figure align=center>
<img src ="https://files.revuestarlight.net/sharex/mpv_S0N0GplaAb.jpg">
<figcaption><em>Clannad, Kyou Chapter (Subtitles by UDF) </em></figcaption>
</figure>


If you are Old like me and want yellow subtitles, you can simply hit `c` (strictly lowercase) to change the color to a more acceptable and widely expected `#EBEB50`, which is a nice pale, desaturated yellow color: 

<figure align=center>
<img src ="https://files.revuestarlight.net/sharex/mpv_iHS5AUkWxJ.jpg">
<figcaption><em>Vertex Force, episode 1.</em></figcaption>
</figure>


### Boomer Mode

This switches out the font with Arial Narrow. This is not included, because it should come with windows. If it does not, it surely can't be that hard to find and install yourself. Sorry. It changes the `sub-color` to `#FFFF00`, which is just full yellow. It also gives it a non-blurred, non-offset black border to replicate "Older" subtitles so that if you're watching something that would have that subtitle styling it doesn't feel as awkward. 


<figure align=center>
<img src ="https://files.revuestarlight.net/sharex/mpv_s2rTIb9GB2.jpg">
<figcaption><em>Mahou Shoujo Lyrical Nanoha, episode 3. (Subtitles by Fete Rider)</em></figcaption>
</figure>


**Note:** If you switch profiles again, the yellow color will stay. This is intentional. If you really wish, you can even change the color of the yellow subs to white by pressing `c`. 

### AAA Japanese Video Game

ok this one is a joke. sorry. i included it because i think it is funny. this is the mgsv/xenoblade x/whatever other game you can think of here font. i just think its funny man. I tried to replicate the MGSV subtitle style and I think I got close enough? You are free to remove this if you wish. Live free, baby.

<figure align=center>
<img src ="https://files.revuestarlight.net/sharex/mpv_cdCRwb0aem.jpg">
<figcaption><em>Mahou Shoujo Lyrical Nanoha, episode 3. (Subtitles by Fete Rider)</em></figcaption>
</figure>


# Custom Keybinds
<div align=center>

| Key | Action|
|:-----:|:-------:|
|c    |Toggles between white and yellow subs.|
|p|Toggles between the three profiles.|
|f2| Toggles `ass-override` between `yes` and `no`.


</div>

# restyle-dialogue.lua

**NOTE: THIS ONLY WORKS FOR .ASS SUBS.** if your show has SRT or PGS subs because it is old that is on you. eat your veggies.

This is the real big meat and potatoes. This handles the logic with "What do I restyle, and what do I leave alone?" The script:

1. Extracts the subs via ffmpeg. **You should have this installed.** 
- **Note:** If you load your anime over from a NAS or other local connection, this may take a little bit. For normal tv episodes, it's a couple of seconds, but for movies (8gb+) it'll probably take a little bit. If you're watching a movie the subtitles are probably good though. The progress of this task is shown in the bottom left of the screen (Very small). If the .ass file is next to the video file, this step is skipped. 
2. Looks through the most commonly used style, plus any subtitles that looks like it's a dialogue style (see: `default`, `main`, `italics`, `flashback`, etc, etc...). This leaves karaoke, signs, etc. untouched as long as the person who did the subs has a brain. 

3. For those styles only, it swaps in the settings from `mpv.conf`: font, size, colors, shadow, etc. It converts the sizes into the styles file itself so they should look the same. This also resets horizontal and vertical scaling/res, so releases that use squished fonts for effect don't affect our new dialogue font. It also removes scaling tags and also removes stray `\N` calls at the end of lines (which adds a newline to the end of the subtitle, making it higher for no good reason), which crunchyroll really likes doing for reasons that we will never truly understand.

4. Preserves sign typesetting by looking for positioning, movement, clipping, drawing, or rotation tags is switched to an untouched copy of the original style so that it doesn't look weird (in theory. results may vary. works on my machine.)

5. Strips all margins and uses `sub-margin-y` from our `mpv.conf`.

6: Cleans up temp files when the video ends or MPV closes. Leftovers from crashes are wiped the next time mpv starts.

### Examples

<figure align=center>
<img src ="https://files.revuestarlight.net/sharex/mpv_LJqvOQbkXm.jpg">
<figcaption><em>Shoujo☆Kageki Revue Starlight The Movie (Subtitles by Casual Tapir)</em></figcaption>
</figure>
<figure align=center>
<img src ="https://files.revuestarlight.net/sharex/mpv_9KfHVY7Zab.jpg">
<figcaption><em>The Disappearance of Haruhi Suzumiya (Subtitles by MTBB)</em></figcaption>
</figure>

In theory, this script should catch *most* cases, but as always, your mileage may vary. 