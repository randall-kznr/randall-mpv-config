-- restyle-dialogue.lua
-- Applies sub-font / sub-color / sub-font-size / etc. to common dialogue entires on a .ass level
-- styles of an ASS track only. Songs, karaoke, signs and typesetting keep the release's own styling.
-- Use with sub-ass-override=yes (not force).
--
-- Dialogue styles = the most-used style, plus any style sharing its font or
-- whose name looks like a dialogue style (Default, Main, Italics, Flashback...).
-- Per-line margins and trailing \N on dialogue lines are also removed.
-- Re-applies when you switch profiles. Requires ffmpeg on PATH for embedded subs.

local utils = require "mp.utils"
local opts = { keep_margins = "auto" }   -- auto | yes | no
require("mp.options").read_options(opts, "restyle-dialogue")
 
local TMP_PREFIX = "mpv-restyled-"
local TMPDIR = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
local DIALOGUE_NAMES = { "default", "main", "dialog", "italic", "flashback",
                         "overlap", "internal", "thought", "narrat" }
 
local state = nil   -- { raw, title, lang, orig, sid, tmp, stylesig }
local counter = 0
 
 
---------------------------------------------------------------- helpers
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
 
local function split(s, n)
    local t, pos = {}, 1
    for _ = 1, n - 1 do
        local c = s:find(",", pos, true)
        if not c then break end
        t[#t + 1] = s:sub(pos, c - 1)
        pos = c + 1
    end
    t[#t + 1] = s:sub(pos)
    return t
end
 
local function num(x)
    local s = string.format("%.2f", x):gsub("0+$", ""):gsub("%.$", "")
    return s
end
 
-- mpv "#RRGGBB" / "#AARRGGBB" -> ASS "&HAABBGGRR"
local function asscolor(c)
    if not c then return nil end
    c = c:gsub("^#", "")
    local a, r, g, b
    if #c == 8 then a, r, g, b = c:sub(1, 2), c:sub(3, 4), c:sub(5, 6), c:sub(7, 8)
    elseif #c == 6 then a, r, g, b = "FF", c:sub(1, 2), c:sub(3, 4), c:sub(5, 6)
    else return nil end
    return (string.format("&H%02X%s%s%s", 255 - tonumber(a, 16), b, g, r)):upper()
end
 
local function prop(...)
    for _, name in ipairs({ ... }) do
        local v = mp.get_property(name)
        if v and v ~= "" then return v end
    end
    return nil
end
 
local function user_style()
    return {
        font    = prop("sub-font"),
        size    = tonumber(prop("sub-font-size")) or 38,
        color   = asscolor(prop("sub-color")),
        outcol  = asscolor(prop("sub-outline-color", "sub-border-color")),
        shadcol = asscolor(prop("sub-back-color", "sub-shadow-color")),
        bold    = prop("sub-bold") == "yes",
        outline = tonumber(prop("sub-outline-size", "sub-border-size")) or 3,
        shadow  = tonumber(prop("sub-shadow-offset")) or 0,
        spacing = tonumber(prop("sub-spacing")) or 0,
        margin  = tonumber(prop("sub-margin-y")) or 22,
        blur    = tonumber(prop("sub-blur")) or 0,
        mode    = prop("sub-ass-override"),
    }
end
 
---------------------------------------------------------------- core
local function restyle(text, u)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do lines[#lines + 1] = line end
 
    local section, playresy = "", 288
    local sfmt, efmt = nil, nil
    local styles = {}      -- name -> { idx = line index, f = fields }
    local events = {}      -- { idx, f }
 
    for i, line in ipairs(lines) do
        local sec = line:match("^%s*%[(.-)%]%s*$")
        if sec then section = sec:lower()
        elseif section == "script info" then
            local v = line:match("^PlayResY:%s*(%d+)")
            if v then playresy = tonumber(v) end
        elseif section:match("styles") then
            local f = line:match("^Format:%s*(.*)")
            if f then
                sfmt = {}
                for k in f:gmatch("[^,]+") do sfmt[#sfmt + 1] = trim(k) end
            elseif sfmt then
                local v = line:match("^Style:%s*(.*)")
                if v then
                    local fields = split(v, #sfmt)
                    styles[trim(fields[1])] = { idx = i, f = fields }
                end
            end
        elseif section == "events" then
            local f = line:match("^Format:%s*(.*)")
            if f then
                efmt = {}
                for k in f:gmatch("[^,]+") do efmt[#efmt + 1] = trim(k) end
            elseif efmt then
                local v = line:match("^Dialogue:%s*(.*)")
                if v then events[#events + 1] = { idx = i, f = split(v, #efmt) } end
            end
        end
    end
    if not sfmt or not efmt then return nil end
 
    local si, ei = {}, {}
    for k, name in ipairs(sfmt) do si[name] = k end
    for k, name in ipairs(efmt) do ei[name] = k end
 
    -- find the main dialogue style: most-used among plain lines
    local count, top, topn = {}, nil, 0
    for _, e in ipairs(events) do
        local t = e.f[ei.Text] or ""
        if not t:find("\\pos", 1, true) and not t:find("\\move", 1, true)
           and not t:find("\\[kK]") then
            local s = trim(e.f[ei.Style] or "")
            count[s] = (count[s] or 0) + 1
            if count[s] > topn then top, topn = s, count[s] end
        end
    end
    if not top or not styles[top] then return nil end
 
    local topfont = trim(styles[top].f[si.Fontname] or "")
    local dlg = {}
    for name, s in pairs(styles) do
        local lname = name:lower()
        -- same style, same font, a variant of it ("Default - Top"), or a
        -- numbered sibling ("Font2_Outline" next to "Font1_Outline")
        local function stem(n) return (n:gsub("%d+", ""):lower()) end
        local match = name == top or trim(s.f[si.Fontname] or "") == topfont
                      or stem(name) == stem(top)
                      or name:sub(1, #top + 1):lower() == (top .. " "):lower()
                      or name:sub(1, #top + 1):lower() == (top .. "-"):lower()
        for _, p in ipairs(DIALOGUE_NAMES) do
            if lname:find(p, 1, true) then match = true end
        end
        if match then dlg[name] = true end
    end
 
    -- decide whether to keep the release's margins.
    -- auto: keep them, unless nearly every dialogue line has the same hardcoded
    -- per-line MarginV (auto-converted streaming subs) -> use sub-margin-y.
    local replace = opts.keep_margins == "no"
    if opts.keep_margins == "auto" and ei.MarginV then
        local total, vals, n = 0, {}, 0
        for _, e in ipairs(events) do
            if dlg[trim(e.f[ei.Style] or "")] then
                total = total + 1
                local v = tonumber(e.f[ei.MarginV]) or 0
                if v ~= 0 then n = n + 1; vals[v] = true end
            end
        end
        local distinct = 0
        for _ in pairs(vals) do distinct = distinct + 1 end
        replace = total > 0 and n / total >= 0.9 and distinct == 1
    end
 
    -- rewrite dialogue styles (keeping an untouched copy for typeset lines)
    local sc = playresy / 720
    for name in pairs(dlg) do
        local s = styles[name]
        local f = s.f
        local orig = { table.unpack(f) }
        orig[1] = name .. " (orig)"
        s.origline = "Style: " .. table.concat(orig, ",")
        local function set(key, val) if si[key] and val then f[si[key]] = val end end
        set("Fontname", u.font)
        set("Fontsize", num(u.size * sc))
        set("PrimaryColour", u.color)
        set("OutlineColour", u.outcol)
        set("BackColour", u.shadcol)
        set("Bold", u.bold and "-1" or "0")
        set("BorderStyle", "1")
        set("Outline", num(u.outline * sc))
        set("Shadow", num(u.shadow * sc))
        set("Spacing", num(u.spacing * sc))
        local floor = u.margin * sc
        if replace then
            set("MarginV", num(floor))
        elseif opts.keep_margins == "auto" and si.MarginV
               and (tonumber(f[si.MarginV]) or 0) < floor then
            set("MarginV", num(floor))      -- release margin too low: raise to yours
        end
        set("ScaleX", "100")
        set("ScaleY", "100")
        set("Angle", "0")
        lines[s.idx] = "Style: " .. table.concat(f, ",") .. "\n" .. s.origline
    end
 
    -- clean dialogue events
    local blurtag = u.blur > 0 and ("{\\blur" .. num(u.blur) .. "}") or ""
    for _, e in ipairs(events) do
        local f = e.f
        local sname = trim(f[ei.Style] or "")
        local text = f[ei.Text] or ""
        local typeset = text:find("\\pos") or text:find("\\move") or text:find("\\org")
                        or text:find("\\i?clip") or text:find("\\p[1-9]")
                        or text:find("\\fr[xyz]?[%-%d]") or text:find("\\fa[xy]")
        if dlg[sname] and typeset then
            -- signs typeset in the dialogue style keep the original look
            f[ei.Style] = sname .. " (orig)"
            lines[e.idx] = "Dialogue: " .. table.concat(f, ",")
        elseif dlg[sname] then
            if replace then
                for _, k in ipairs({ "MarginL", "MarginR", "MarginV" }) do
                    if ei[k] then f[ei[k]] = "0" end
                end
            elseif opts.keep_margins == "auto" and ei.MarginV then
                -- per-line margin set but below your minimum: raise it
                local v = tonumber(f[ei.MarginV]) or 0
                if v > 0 and v < u.margin * sc then f[ei.MarginV] = num(u.margin * sc) end
            end
            -- strip trailing \N (blank extra line); \N mid-line and all \n are kept
            local t, prev = f[ei.Text], nil
            repeat prev = t; t = t:gsub("%s*\\N%s*$", "") until t == prev
            -- drop inline font / scale overrides so your font isn't squished
            t = t:gsub("\\fsc[xy][%d%.]*", ""):gsub("\\fn[^\\}]*", ""):gsub("{}", "")
            f[ei.Text] = blurtag .. t
            lines[e.idx] = "Dialogue: " .. table.concat(f, ",")
        end
    end
 
    return table.concat(lines, "\n"), top .. (replace and " (margins -> sub-margin-y)" or "")
end
 
---------------------------------------------------------------- mpv glue
-- calls done(raw) when the subs are available. Extraction runs in the
-- background with a live percentage on screen, since ffmpeg has to read
-- through the whole file to collect the subtitle packets.
local extract = nil   -- { handle, timer, prog, out }
 
-- small, semi-transparent status text in the bottom-left corner
local status = mp.create_osd_overlay("ass-events")
local status_timer = nil
local function set_status(text, secs)
    if status_timer then status_timer:kill(); status_timer = nil end
    if not text then status:remove(); return end
    status.data = "{\\an1\\fs13\\bord1\\shad0\\1a&H50&\\3a&H80&\\pos(12,708)}" .. text
    status:update()
    if secs then
        status_timer = mp.add_timeout(secs, function() status:remove() end)
    end
end
 
local function stop_extract(abort)
    if not extract then return end
    if abort and extract.handle then mp.abort_async_command(extract.handle) end
    if extract.timer then extract.timer:kill() end
    if abort then set_status(nil) end
    os.remove(extract.prog)
    os.remove(extract.out)
    extract = nil
end
 
local function progress_pct(progfile, dur)
    local fh = io.open(progfile, "rb")
    if not fh then return nil end
    local t = fh:read("*a"); fh:close()
    local last
    for us in t:gmatch("out_time_us=(%d+)") do last = us end
    if not last or not dur or dur <= 0 then return nil end
    return math.min(100, math.floor(tonumber(last) / 1e6 / dur * 100))
end
 
local function load_raw(track, done)
    if track.external then
        local fn = track["external-filename"] or ""
        if fn:find(TMP_PREFIX, 1, true) then return end
        local fh = io.open(fn, "rb")
        if not fh then return end
        local t = fh:read("*a"); fh:close()
        return done(t)
    end
 
    stop_extract(true)
    local path = mp.get_property("path")
    local base = utils.join_path(TMPDIR, TMP_PREFIX .. (mp.get_property("pid") or "0") .. "-extract")
    extract = { prog = base .. ".progress", out = base .. ".ass" }
    local job = extract
 
    local dur = mp.get_property_number("duration")
    local function show()
        local pct = progress_pct(job.prog, dur)
        set_status("restyling subs " .. (pct and (pct .. "%") or "..."))
    end
    show()
    job.timer = mp.add_periodic_timer(0.5, show)
 
    job.handle = mp.command_native_async({
        name = "subprocess", playback_only = false, capture_stderr = true,
        args = { "ffmpeg", "-v", "error", "-nostats", "-y",
                 "-progress", job.prog, "-i", path,
                 "-map", "0:" .. track["ff-index"], "-c", "copy", "-f", "ass", job.out },
    }, function(ok, res)
        if extract ~= job then return end          -- cancelled / superseded
        local raw
        if ok and res and res.status == 0 then
            local fh = io.open(job.out, "rb")
            if fh then raw = fh:read("*a"); fh:close() end
        end
        stop_extract(false)
        if mp.get_property("path") ~= path then return end
        if raw and raw ~= "" then
            set_status("subs restyled", 1.5)
            done(raw)
        else
            local why = (res and res.error_string ~= "" and res.error_string)
                        or (res and res.stderr and res.stderr:match("[^\r\n]+"))
                        or "unknown error"
            if why == "init" then why = "ffmpeg not found on PATH" end
            set_status("restyle failed: " .. why, 6)
            mp.msg.warn("ffmpeg extraction failed: " .. why)
        end
    end)
end
 
local function signature(u, skip)
    local t = {}
    for k, v in pairs(u) do
        if k ~= skip then t[#t + 1] = k .. "=" .. tostring(v) end
    end
    table.sort(t)
    return table.concat(t, ";")
end
 
local track_info = nil   -- the file's ASS track, remembered until we need it
local last_mode = nil
 
local function active()
    return mp.get_property("sub-ass-override") == "yes"
end
 
-- show the restyled track, rebuilding it only if your style changed
local function apply()
    if not state then return end
    local u = user_style()
    local ssig = signature(u, "mode")
    local switched_on = last_mode ~= "yes"
    last_mode = "yes"
 
    if state.sid and ssig == state.stylesig then
        if switched_on then mp.set_property_number("sid", state.sid) end
        return
    end
    state.stylesig = ssig
 
    local out, top = restyle(state.raw, u)
    if not out then mp.msg.info("no dialogue style found, leaving track alone"); return end
 
    counter = counter + 1
    local tmp = utils.join_path(TMPDIR, TMP_PREFIX .. (mp.get_property("pid") or "0")
                                .. "-" .. counter .. ".ass")
    local fh = io.open(tmp, "wb")
    if not fh then return end
    fh:write(out); fh:close()
 
    local old = state.sid
    mp.commandv("sub-add", tmp, "select", (state.title or "Subs") .. " (restyled)", state.lang or "")
    state.sid = mp.get_property_number("sid")
    if old then mp.commandv("sub-remove", old) end
    if state.tmp then os.remove(state.tmp) end
    state.tmp = tmp
    mp.msg.info("restyled dialogue style: " .. top)
end
 
-- sub-ass-override is anything but yes: step aside and show the original
local function deactivate()
    last_mode = mp.get_property("sub-ass-override")
    if extract then stop_extract(true) end
    if state and state.sid and mp.get_property_number("sid") == state.sid then
        mp.set_property_number("sid", state.orig)
    end
end
 
local function update()
    if not track_info then return end
    if not active() then return deactivate() end
    if state then return apply() end
    if extract then return end                  -- extraction already running
    local track = track_info
    load_raw(track, function(raw)
        if track_info ~= track then return end
        state = { raw = raw, title = track.title, lang = track.lang, orig = track.id }
        last_mode = nil
        if active() then apply() end
    end)
end
 
-- sweep leftovers from crashed sessions (older than a day, so other running
-- mpv windows keep their files)
do
    local now = os.time()
    for _, name in ipairs(utils.readdir(TMPDIR, "files") or {}) do
        if name:sub(1, #TMP_PREFIX) == TMP_PREFIX then
            local path = utils.join_path(TMPDIR, name)
            local info = utils.file_info(path)
            if info and now - info.mtime > 86400 then os.remove(path) end
        end
    end
end
 
local function cleanup()
    stop_extract(true)
    if state and state.tmp then os.remove(state.tmp) end
    state, track_info, last_mode = nil, nil, nil
end
mp.register_event("end-file", cleanup)
mp.register_event("shutdown", cleanup)
 
mp.register_event("file-loaded", function()
    state, last_mode = nil, nil
    local track = mp.get_property_native("current-tracks/sub")
    track_info = (track and track.codec == "ass") and track or nil
    update()
end)
 
-- react to sub-ass-override and style changes (profiles, keybinds)
local pending = false
local function changed()
    if not track_info or pending then return end
    pending = true
    mp.add_timeout(0.15, function() pending = false; update() end)
end
for _, p in ipairs({ "sub-ass-override", "sub-font", "sub-font-size", "sub-color", "sub-bold",
                     "sub-border-size", "sub-border-color", "sub-shadow-offset",
                     "sub-shadow-color", "sub-spacing", "sub-margin-y", "sub-blur" }) do
    mp.observe_property(p, "string", changed)
end
 