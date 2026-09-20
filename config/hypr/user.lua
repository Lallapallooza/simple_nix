-- WORKFLOW CHEATSHEET:
--
-- Apps:
--   Super+Q              = kitty
--   Super+R              = rofi launcher
--   Super+E              = file manager
--
-- Windows:
--   Super+C              = close window
--   Super+F              = zoom in (multi-window workspace)
--   Super+Shift+F        = true fullscreen (hides bar)
--   Super+V              = toggle floating
--   Super+J              = toggle split direction
--   Super+arrows         = move focus
--   Super+Shift+arrows   = swap tile positions
--   Super+Ctrl+arrows    = resize tiles
--   Super+drag           = move floating window
--   Super+right-drag     = resize floating window
--
-- Workspaces:
--   Super+1-9            = jump to workspace
--   Super+Shift+1-9      = move window to workspace
--   Super+scroll          = cycle workspaces
--   Super+S              = toggle scratchpad
--   Super+M              = toggle layout (dwindle/master)
--   Alt+Tab              = window picker (rofi)
--
-- Utilities:
--   Super+Space          = switch keyboard (US/RU)
--   Super+P              = toggle pseudo tiling
--   Super+L              = lock screen
--   Super+/              = keybind cheatsheet
--   Super+N              = notification history (full bodies)
--   Super+Ctrl+S         = move window to scratchpad
--   Print                = screenshot + annotate (flameshot)
--   Super+Shift+S        = screenshot region (grimblast, no UI)
--   Super+Print          = screenshot full monitor


local configDir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Catch-all so the scale applies to whatever output the monitor lands on.
-- Connector names (DP-1 vs DP-4) shuffle across reboots on this multi-GPU box,
-- so pinning to one port left the display at scale 1.0 after a reboot.
-- highrr keeps max refresh (4K panels often report 4K60 as preferred).
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = 1.666667,
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
    -- Essential services
    hl.exec_cmd("wayle shell")
    hl.exec_cmd("hyprpaper")
    -- hl.exec_cmd("hypridle")  -- autolock disabled
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")

    -- Polkit agent (for admin password prompts)
    hl.exec_cmd("lxqt-policykit-agent")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- NOTE: keep cursor size in sync with cursorSize in nixos/host.nix
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- NOTE: GDK_SCALE must be integer; GDK_DPI_SCALE = monitorScale / GDK_SCALE
-- Adjust both when changing monitor scale (hl.monitor above)
hl.env("GDK_SCALE", "2")
hl.env("GDK_DPI_SCALE", "0.8333")
-- NOTE: keep in sync with qt settings in nixos/home/theming.nix
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE", "breeze")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },

    cursor = {
        no_hardware_cursors = true,
    },

    render = {
        expand_undersized_textures = true,
    },
})


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission({ binary = "/usr/(bin|local/bin)/grim", type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(bin|local/bin)/hyprpm", type = "plugin", mode = "allow" })


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 7,

        border_size = 2,

        col = {
            active_border   = "rgb(FF8F40)",
            inactive_border = "rgb(1A1D23)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = true,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 0,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled        = true,
            range          = 12,
            render_power   = 2,
            color          = "rgba(FF8F4033)",
            color_inactive = "rgba(0B0E1400)",
        },

        blur = {
            enabled           = true,
            size              = 3,
            passes            = 4,
            new_optimizations = true,

            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
    dwindle = {
        preserve_split = true, -- You probably want this
    },

    misc = {
        force_default_wallpaper    = 0,
        disable_hyprland_logo      = true,
        vrr                        = 2,    -- G-Sync in fullscreen games only
        focus_on_activate          = true, -- clicking notifications switches to that workspace+window
        initial_workspace_tracking = 2,    -- open windows on the workspace they were launched from, including late child windows
        on_focus_under_fullscreen  = 0,    -- keep current window fullscreen when another window spawns; new one opens behind
    },

    input = {
        -- NOTE: keep in sync with services.xserver.xkb in nixos/desktop.nix
        kb_layout  = "us,ru",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:win_space_toggle",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        repeat_rate  = 35,
        repeat_delay = 400,

        touchpad = {
            natural_scroll = false,
        },
    },
})

-- Curves, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}  } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}  } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}     } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}  } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}   } })
hl.curve("overshot",       { type = "bezier", points = { {0.13, 0.99}, {0.29, 1.1} } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 2,    bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1,    bezier = "default" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1,    bezier = "default" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1,    bezier = "default" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })


---------------------
---- KEYBINDINGS ----
---------------------

-- See https://wiki.hypr.land/Configuring/Basics/Binds/
local mainMod = "SUPER" -- Sets "Windows" key as main modifier

hl.bind(mainMod .. " + Q",         hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C",         hl.dsp.window.close())
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("ALT + Tab",               hl.dsp.exec_cmd("rofi -show window"))
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + slash",     hl.dsp.exec_cmd(configDir .. "/cheatsheet.sh"))
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())                    -- dwindle
hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))              -- dwindle
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd(configDir .. "/toggle-layout.sh"))
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("kitty --class=notif-log sh -c 'wayle notify list | less -R'"))

-- Screenshots
-- Print opens flameshot's annotation UI (draw/blur/arrow, then copy or save).
-- grimblast stays on the other two keys as the headless path: it is a single
-- grim+slurp call with no Qt surface, so it still works if flameshot's overlay
-- misbehaves under this monitor's 1.666667 fractional scale.
hl.bind("Print",                   hl.dsp.exec_cmd("flameshot gui"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grimblast copysave area"))
hl.bind(mainMod .. " + Print",     hl.dsp.exec_cmd("grimblast copysave output"))

-- Move focus with mainMod + arrow keys
-- Swap window positions with mainMod + SHIFT + arrow keys
-- Resize tiles with mainMod + CTRL + arrow keys
for _, arrow in ipairs({
    { key = "left",  dir = "l", dx = -40, dy =   0 },
    { key = "right", dir = "r", dx =  40, dy =   0 },
    { key = "up",    dir = "u", dx =   0, dy = -40 },
    { key = "down",  dir = "d", dx =   0, dy =  40 },
}) do
    hl.bind(mainMod .. " + " .. arrow.key,           hl.dsp.focus({ direction = arrow.dir }))
    hl.bind(mainMod .. " + SHIFT + " .. arrow.key,   hl.dsp.window.move({ direction = arrow.dir }))
    hl.bind(mainMod .. " + CTRL + " .. arrow.key,
        hl.dsp.window.resize({ x = arrow.dx, y = arrow.dy, relative = true }), { repeating = true })
end

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad (hidden overlay workspace)
hl.bind(mainMod .. " + S",        hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Blur the floating panel bar
hl.layer_rule({
    name  = "wayle-bar",
    match = { namespace = "^wayle-bar-" },
    blur  = true,
    xray  = true,
})

-- Rofi launcher -- blur behind
hl.layer_rule({
    name         = "rofi",
    match        = { namespace = "^rofi$" },
    blur         = true,
    ignore_alpha = 0.3,
})

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/ for more
-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/ for workspace rules

-- Smart gaps - single window fills screen
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
hl.window_rule({
    name        = "no-gaps-wtv1",
    match       = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding    = 0,
})
hl.window_rule({
    name        = "no-gaps-f1",
    match       = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})

-- General window rules
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "fullscreen maximize",
})

-- Float utility windows
for _, class in ipairs({
    "^(pavucontrol)$",
    "^(blueman-manager)$",
    "^(nm-connection-editor)$",
    "^(wdisplays)$",
    "^(org.gnome.seahorse.Application)$",
    "^(lxqt-policykit-agent)$",
}) do
    hl.window_rule({ match = { class = class }, float = true })
end

-- Float file dialogs
for _, title in ipairs({
    "^(Open File)$",
    "^(Select a File)$",
    "^(Open Folder)$",
    "^(Save As)$",
    "^(File Upload)$",
    "^(Choose Files)$",
}) do
    hl.window_rule({ match = { title = title }, float = true })
end

-- Flameshot overlay -- the capture UI is a normal Qt window, so without these
-- it tiles into the layout and the annotation canvas lands offset from the
-- screen it is drawing over. no_anim keeps the open animation from being
-- captured into the next shot.
hl.window_rule({
    name    = "flameshot",
    match   = { class = "^(flameshot)$" },
    float   = true,
    pin     = true,
    move    = { "0", "0" },
    no_anim = true,
})

-- Picture-in-Picture
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture in Picture)$" },
    float = true,
    pin   = true,
    size  = { "monitor_w*0.25", "monitor_h*0.25" },
    move  = { "monitor_w*0.73", "monitor_h*0.72" },
})

-- Steam
-- RE2 does not support negative lookahead, so the old "not Steam" matcher
-- spammed the journal continuously. Keep Steam's main window tiled; add exact
-- utility/dialog titles here if one needs forced floating.
-- hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List|Settings|Properties)$" }, float = true })

-- Gaming - tearing for reduced input latency
hl.window_rule({ match = { class = "^(steam_app_.*)$" }, immediate = true })
hl.window_rule({ match = { class = [[^(.*\.exe)$]] },    immediate = true })

-- XWayland fix
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})
