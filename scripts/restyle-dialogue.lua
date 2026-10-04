-- restyle-dialogue.lua
-- Applies sub-font / sub-color / sub-font-size / etc. to common dialogue entires on a .ass level
-- styles of an ASS track only. Songs, karaoke, signs and typesetting keep the release's own styling.
-- Use with sub-ass-override=yes (not force).
--
-- Dialogue styles = the most-used style, plus any style sharing its font or
-- whose name looks like a dialogue style (Default, Main, Italics, Flashback...).
-- Per-line margins and trailing \N on dialogue lines are also removed.
-- Re-applies when you switch profiles. Requires ffmpeg on PATH for embedded subs.

local TMP_PREFIX = "mpv-restyled-"
local DIALOGUE_NAMES = { "default", "main", "dialog", "italic", "flashback",
                         "overlap", "internal", "thought", "narrat", "top", "alt" }

local state = nil   -- { raw, title, lang, sid, tmp, sig }
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

    -- find the main dialogue style
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
        local match = name == top or trim(s.f[si.Fontname] or "") == topfont
        for _, p in ipairs(DIALOGUE_NAMES) do
            if lname:find(p, 1, true) then match = true end
        end
        if match then dlg[name] = true end
    end

    -- rewrite dialogue styles
    local sc = playresy / 720
    for name in pairs(dlg) do
        local s = styles[name]
        local f = s.f
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
        set("MarginV", num(u.margin * sc))
        lines[s.idx] = "Style: " .. table.concat(f, ",")
    end

    -- clean dialogue events
    local blurtag = u.blur > 0 and ("{\\blur" .. num(u.blur) .. "}") or ""
    for _, e in ipairs(events) do
        local f = e.f
        if dlg[trim(f[ei.Style] or "")] then
            for _, k in ipairs({ "MarginL", "MarginR", "MarginV" }) do
                if ei[k] then f[ei[k]] = "0" end
            end
            local t, prev = f[ei.Text], nil
            repeat prev = t; t = t:gsub("%s*\\[Nn]%s*$", "") until t == prev
            f[ei.Text] = blurtag .. t
            lines[e.idx] = "Dialogue: " .. table.concat(f, ",")
        end
    end

    return table.concat(lines, "\n"), top
end

---------------------------------------------------------------- mpv glue
local function load_raw(track)
    if track.external then
        local fn = track["external-filename"] or ""
        if fn:find(TMP_PREFIX, 1, true) then return nil end
        local fh = io.open(fn, "rb")
        if not fh then return nil end
        local t = fh:read("*a"); fh:close()
        return t
    end
    local res = mp.command_native({
        name = "subprocess", playback_only = false, capture_stdout = true,
        args = { "ffmpeg", "-v", "error", "-i", mp.get_property("path"),
                 "-map", "0:" .. track["ff-index"], "-c", "copy", "-f", "ass", "-" },
    })
    if res and res.status == 0 and res.stdout ~= "" then return res.stdout end
    mp.msg.warn("ffmpeg extraction failed")
end

local function signature(u)
    local t = {}
    for k, v in pairs(u) do t[#t + 1] = k .. "=" .. tostring(v) end
    table.sort(t)
    return table.concat(t, ";")
end

local function apply()
    if not state then return end
    local u = user_style()
    local sig = signature(u)
    if sig == state.sig then return end
    state.sig = sig
    local out, top = restyle(state.raw, u)
    if not out then mp.msg.info("no dialogue style found, leaving track alone"); return end

    counter = counter + 1
    local tmp = (os.getenv("TEMP") or "/tmp") .. "/" .. TMP_PREFIX .. counter .. ".ass"
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

local function cleanup()
    if state and state.tmp then os.remove(state.tmp) end
    state = nil
end
mp.register_event("end-file", cleanup)
mp.register_event("shutdown", cleanup)

mp.register_event("file-loaded", function()
    state = nil
    local track = mp.get_property_native("current-tracks/sub")
    if not track or track.codec ~= "ass" then return end
    local raw = load_raw(track)
    if not raw then return end
    state = { raw = raw, title = track.title, lang = track.lang }
    apply()
end)

-- re-apply when profiles change sub options
local pending = false
local function changed()
    if not state or pending then return end
    pending = true
    mp.add_timeout(0.15, function() pending = false; apply() end)
end
for _, p in ipairs({ "sub-font", "sub-font-size", "sub-color", "sub-bold",
                     "sub-border-size", "sub-border-color", "sub-shadow-offset",
                     "sub-shadow-color", "sub-spacing", "sub-margin-y", "sub-blur" }) do
    mp.observe_property(p, "string", changed)
end