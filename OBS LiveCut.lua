obslua = require("obslua")

-- ➔ Tracking State Variables
local is_recording = false
local is_fake_paused = false
local start_time_sec = 0
local fake_pause_start_sec = 0
local cuts = {}

-- ➔ UI Feedback Trackers
local cut_10_count = 0
local cut_30_count = 0

-- ➔ Hotkey IDs
local hotkey_pause_id = obslua.OBS_INVALID_HOTKEY_ID
local hotkey_cut10_id = obslua.OBS_INVALID_HOTKEY_ID
local hotkey_cut30_id = obslua.OBS_INVALID_HOTKEY_ID

--------------------------------------------------
-- ➔ OBS Configuration Auto-Detector
--------------------------------------------------

function get_obs_settings()
    local profile = obslua.obs_frontend_get_profile_config()
    local mode = obslua.config_get_string(profile, "Output", "Mode")
    local path = ""
    local ext = ""

    if mode == "Advanced" then
        path = obslua.config_get_string(profile, "AdvOut", "RecFilePath")
        ext = obslua.config_get_string(profile, "AdvOut", "RecFormat")
    else
        path = obslua.config_get_string(profile, "SimpleOutput", "FilePath")
        ext = obslua.config_get_string(profile, "SimpleOutput", "RecFormat")
    end
    
    if not path or path == "" then path = os.getenv("USERPROFILE") .. "\\Videos" end
    if not ext or ext == "" then ext = "mp4" end
    if string.sub(ext, 1, 1) ~= "." then ext = "." .. ext end
    
    path = path:gsub("\\$", ""):gsub("/$", "")
    return path, ext
end

--------------------------------------------------
-- ➔ Time Engine 
--------------------------------------------------

function get_time_sec()
    return obslua.os_gettime_ns() / 1000000000.0
end

function get_video_time()
    if not is_recording then return 0 end
    return (get_time_sec() - start_time_sec)
end

--------------------------------------------------
-- ➔ Core Logic Functions
--------------------------------------------------

function mark_cut(seconds)
    if not is_recording then return false end
    
    local vid_time = get_video_time()
    local cut_start = vid_time - seconds
    if cut_start < 0 then cut_start = 0 end
    
    table.insert(cuts, {start_time = cut_start, end_time = vid_time})
    print(string.format("[Auto-Stitch] ✂️ CUT LOGGED: %.1fs to %.1fs", cut_start, vid_time))
    return true
end

-- ➔ Trigger Functions (Works for both Buttons and Hotkeys)

function trigger_cut_10(pressed)
    if not pressed then return end -- Only trigger on key down
    if mark_cut(10) then
        cut_10_count = cut_10_count + 1
        print("[Auto-Stitch] ✅ 10s Cut logged. Total: " .. cut_10_count)
    end
end

function trigger_cut_30(pressed)
    if not pressed then return end
    if mark_cut(30) then
        cut_30_count = cut_30_count + 1
        print("[Auto-Stitch] ✅ 30s Cut logged. Total: " .. cut_30_count)
    end
end

function trigger_pause(pressed)
    if not pressed then return end
    if not is_recording then return end
    
    if is_fake_paused then
        is_fake_paused = false
        local resume_time = get_video_time()
        table.insert(cuts, {start_time = fake_pause_start_sec, end_time = resume_time})
        print(string.format("[Auto-Stitch] ▶️ Resumed! Removed segment: %.1fs to %.1fs", fake_pause_start_sec, resume_time))
    else
        is_fake_paused = true
        fake_pause_start_sec = get_video_time()
        print(string.format("[Auto-Stitch] ⏸️ Fake Paused at %.1fs", fake_pause_start_sec))
    end
end

--------------------------------------------------
-- ➔ UI Button Callbacks
--------------------------------------------------

function on_cut_10_clicked(props, p) 
    trigger_cut_10(true)
    obslua.obs_property_set_description(p, string.format("✅ 10s Cut Logged! (Total: %d)", cut_10_count))
    return true 
end

function on_cut_30_clicked(props, p) 
    trigger_cut_30(true)
    obslua.obs_property_set_description(p, string.format("✅ 30s Cut Logged! (Total: %d)", cut_30_count))
    return true 
end

function on_pause_clicked(props, p) 
    trigger_pause(true)
    if is_fake_paused then
        obslua.obs_property_set_description(p, "▶️ PAUSED! Click to Unpause")
    else
        obslua.obs_property_set_description(p, "⏸️ Pause Recording")
    end
    return true 
end

--------------------------------------------------
-- ➔ FFmpeg Frame-Perfect Engine
--------------------------------------------------

function execute_auto_trim()
    obslua.timer_remove(execute_auto_trim)
    if #cuts == 0 then return end
    
    print("[Auto-Stitch] ⏳ Starting FFmpeg Stitcher...")
    local record_folder, file_extension = get_obs_settings()
    
    table.sort(cuts, function(a, b) return a.start_time < b.start_time end)
    
    local merged_cuts = {}
    table.insert(merged_cuts, cuts[1])
    for i = 2, #cuts do
        local last = merged_cuts[#merged_cuts]
        local curr = cuts[i]
        if curr.start_time <= last.end_time then
            last.end_time = math.max(last.end_time, curr.end_time)
        else
            table.insert(merged_cuts, curr)
        end
    end
    
    local keep_segments = {}
    local current_pos = 0.0
    for i, cut in ipairs(merged_cuts) do
        if cut.start_time > current_pos then
            table.insert(keep_segments, {start_time = current_pos, end_time = cut.start_time})
        end
        current_pos = cut.end_time
    end
    table.insert(keep_segments, {start_time = current_pos, end_time = -1})
    
    local filter_str = ""
    for i, seg in ipairs(keep_segments) do
        if i > 1 then filter_str = filter_str .. "+" end
        if seg.end_time == -1 then
            filter_str = filter_str .. string.format("gte(t,%.3f)", seg.start_time)
        else
            filter_str = filter_str .. string.format("between(t,%.3f,%.3f)", seg.start_time, seg.end_time)
        end
    end

    local ps_script = string.format([[
        $folder = "%s"
        $ext = "%s"
        $latest_file = Get-ChildItem -Path $folder -Filter "*$ext" | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName -First 1
        if (-not $latest_file) { exit }
        $out_file = $latest_file.Replace($ext, "_FinalTrimmed$ext")
        $vf = "select='%s',setpts=N/FRAME_RATE/TB"
        $af = "aselect='%s',asetpts=N/SR/TB"
        ffmpeg -y -v error -i $latest_file -vf $vf -af $af -c:v libx264 -preset veryfast -crf 18 -c:a aac $out_file
    ]], record_folder, file_extension, filter_str, filter_str)

    local temp_ps1 = os.getenv("TEMP") .. "\\obs_trimmer.ps1"
    local f = io.open(temp_ps1, "w")
    if f then
        f:write(ps_script)
        f:close()
        os.execute('powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. temp_ps1 .. '"')
        print("[Auto-Stitch] 🎬 SUCCESS! Final video created.")
    end
end

--------------------------------------------------
-- ➔ Hotkey & Event System
--------------------------------------------------

function script_load(settings)
    -- 1. Register Hotkeys with OBS
    hotkey_pause_id = obslua.obs_hotkey_register_frontend("stitcher_pause", "OBS LiveCut: Toggle Pause/Resume", trigger_pause)
    hotkey_cut10_id = obslua.obs_hotkey_register_frontend("stitcher_cut10", "OBS LiveCut: Cut Last 10s", trigger_cut_10)
    hotkey_cut30_id = obslua.obs_hotkey_register_frontend("stitcher_cut30", "OBS LiveCut: Cut Last 30s", trigger_cut_30)

    -- 2. Load saved hotkey data so they persist
    local hotkey_save_array_pause = obslua.obs_data_get_array(settings, "stitcher_pause")
    local hotkey_save_array_10 = obslua.obs_data_get_array(settings, "stitcher_cut10")
    local hotkey_save_array_30 = obslua.obs_data_get_array(settings, "stitcher_cut30")

    obslua.obs_hotkey_load(hotkey_pause_id, hotkey_save_array_pause)
    obslua.obs_hotkey_load(hotkey_cut10_id, hotkey_save_array_10)
    obslua.obs_hotkey_load(hotkey_cut30_id, hotkey_save_array_30)

    obslua.obs_data_array_release(hotkey_save_array_pause)
    obslua.obs_data_array_release(hotkey_save_array_10)
    obslua.obs_data_array_release(hotkey_save_array_30)

    -- 3. Add event callback
    obslua.obs_frontend_add_event_callback(on_event)
end

function script_save(settings)
    -- Save hotkeys to OBS settings
    local hotkey_save_array_pause = obslua.obs_hotkey_save(hotkey_pause_id)
    local hotkey_save_array_10 = obslua.obs_hotkey_save(hotkey_cut10_id)
    local hotkey_save_array_30 = obslua.obs_hotkey_save(hotkey_cut30_id)

    obslua.obs_data_set_array(settings, "stitcher_pause", hotkey_save_array_pause)
    obslua.obs_data_set_array(settings, "stitcher_cut10", hotkey_save_array_10)
    obslua.obs_data_set_array(settings, "stitcher_cut30", hotkey_save_array_30)

    obslua.obs_data_array_release(hotkey_save_array_pause)
    obslua.obs_data_array_release(hotkey_save_array_10)
    obslua.obs_data_array_release(hotkey_save_array_30)
end

function on_event(event)
    if event == obslua.OBS_FRONTEND_EVENT_RECORDING_STARTED then
        is_recording = true
        is_fake_paused = false
        start_time_sec = get_time_sec()
        cuts = {}
        cut_10_count = 0
        cut_30_count = 0
        print("[Auto-Stitch] 🔴 Recording Started.")
    elseif event == obslua.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
        if is_fake_paused then
            table.insert(cuts, {start_time = fake_pause_start_sec, end_time = get_video_time()})
            is_fake_paused = false
        end
        is_recording = false
        print("[Auto-Stitch] 🛑 Stopped. Stitching in 5 seconds...")
        obslua.timer_add(execute_auto_trim, 5000)
    end
end

--------------------------------------------------
-- ➔ UI Properties
--------------------------------------------------

function script_properties()
    local props = obslua.obs_properties_create()
    obslua.obs_properties_add_button(props, "btn_pause", "⏸️ Pause Recording", on_pause_clicked)
    obslua.obs_properties_add_button(props, "btn_c10", "✂️ Cut Last 10s", on_cut_10_clicked)
    obslua.obs_properties_add_button(props, "btn_c30", "✂️ Cut Last 30s", on_cut_30_clicked)
    return props
end

function script_description()
    return "<b>OBS LiveCut</b><br/><br/>Click the cut buttons during a recording to mark mistakes. The script automatically detects your OBS Output Folder and Format to build a perfectly edited video when you stop recording."
end