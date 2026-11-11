# DaVinci Resolve Linux Fix

A set of shell and Python scripts that makes DaVinci Resolve usable on Linux. It fixes the crash when typing in Fusion, the black 3D titles, the silent MP4 files, the file browser nobody asked for and the microscopic interface on HiDPI screens.

This repository does not contain or download Resolve. You install the application yourself from the official DaVinci Resolve website, then run one script from this project to fix it, and launch the app as usual.

This project is not affiliated with, endorsed by or sponsored by Blackmagic Design.

## A message to the DaVinci Resolve development team

Dear Blackmagic Design engineers,

Congratulations. You built a professional video editor that cannot play the audio of a video recorded by a phone. On Linux. In the year of our lord 2026. I assume the AAC decoder is being saved for a special occasion.

I also admire how your Linux build treats a missing `en_US.UTF-8` locale as a reason to abort the whole process the moment I press a key in Fusion. Who needs error handling when you have `std::terminate`?

The 3D titles deserve a special mention. Apparently a decimal comma is enough to make them render pure black, which must be a bold artistic choice for a color grading product.

Then there is the file browser. Your app bundles a Qt build with no platform theme plugin at all, so I get a home-made file browser that behaves like it was designed during a lunch break, while every other application on my desktop uses the system file chooser. And since the interface ignores the scaling my compositor offers, everything looks like it was printed for ants.

You are a company with the resources to ship Resolve to Mac and Windows in a polished state, and Linux gets what is left of the budget. I am sure that is a coincidence. Native Linux support is clearly a mysterious engineering challenge that no company of your size could possibly solve.

It is genuinely embarrassing that a user, without access to a single line of your source code, had to find out why your application crashes and write the workarounds that fix it. Every one of these problems was found with logs, backtraces and patience, the things your own QA department presumably has in storage.

A word of friendly advice: tools and launchers like ArtCraft are shipping working Linux builds while you are still deciding whether AAC counts as a standard codec. Keep ignoring Linux users and they will happily eat your lunch.

With love and a small amount of contempt,
A Linux user who just wanted to edit a video

P.S. For the record, the person who wrote these workarounds is a 16-year-old student who has not even started university yet. On the other side there is an entire team of professional developers, many of them with degrees, master's degrees and PhDs. And still, here we are, with the teenager shipping the fixes. I am sure the diplomas look wonderful on the office wall.

## What it fixes

| Problem on Linux | Cause | What this project does |
| --- | --- | --- |
| Resolve crashes when you type in the Inspector or in Fusion | Fusion constructs `std::locale("en_US.UTF-8")` while handling key presses and aborts when that locale is not installed | Generates the locale if needed and starts Resolve under it |
| 3D titles and other Fusion 3D nodes render black, with `material tree creation failed` in the log | The 3D materials fail under a locale with a decimal comma such as `es_ES`. Running under `en_US.UTF-8`, or just `LC_NUMERIC=C`, makes them render | Runs the whole application with an English locale. The interface language is not affected |
| Imported MP4 and MOV files play without sound | Resolve on Linux has no AAC decoder | Converts the audio of each imported clip to PCM and swaps the clip in the media pool automatically |
| Resolve uses its own awkward file browser | The bundled Qt has no platform theme plugin | Loads the system GTK platform theme plugin so the regular file chooser appears |
| The interface is tiny on HiDPI screens | The compositor runs XWayland unscaled and Resolve does not read the desktop scale | Starts Resolve with a Qt scale factor taken from the focused output. Hyprland is tested, Sway is not |
| A wrapper would lose the GPU selection of the stock launcher | The launcher shipped with Resolve sets the NVIDIA PRIME offload variables on hybrid laptops | Sets the same variables when an NVIDIA GPU and another GPU are present |

Not fixed: Resolve aborts with `close_nointr(fd) != -EBADF` in a systemd helper while it is closing. It happens after your project has been saved, and it needs a fix on Blackmagic's side.

## Requirements

* DaVinci Resolve, downloaded and installed from the official website: https://www.blackmagicdesign.com/products/davinciresolve. It goes to `/opt/resolve` by default. Follow Blackmagic's own installation notes for your distribution first, and make sure Resolve starts before you use this project. The audio helper needs Resolve Studio, because the free version does not expose the scripting API.
* `ffmpeg`, `ffprobe` and `python3`.
* The Qt5 GTK platform theme for the native file chooser: `qt5-gtk-platformtheme` on Debian and Ubuntu, `qt5-qtbase-gui` on Fedora, `qt5-base` on Arch.
* `libnotify` (`notify-send`) if you want error notifications.
* In Resolve, set Preferences > System > General > External scripting using > Local. The audio helper cannot reach Resolve otherwise. The doctor script tells you whether it is enabled.

## Install

Install DaVinci Resolve from the official website first, then:

```sh
git clone https://github.com/RaulSalasSahuquillo/davinci-resolve-linux-fix.git
cd davinci-resolve-linux-fix
./install.sh
```

The installer works inside your home directory. It asks for sudo only when the `en_US.UTF-8` locale has to be generated or when you pass `--system-launcher`.

Options:

| Option | Meaning |
| --- | --- |
| `--resolve-dir DIR` | Resolve is installed somewhere other than `/opt/resolve` |
| `--system-launcher` | Also patch the system-wide `.desktop` file, which docks and launchers read. A backup with the `.bak` suffix is kept |
| `--skip-locale` | Do not touch the system locales |
| `-y`, `--yes` | Do not ask before using sudo |

Afterwards, start Resolve from your application menu or run `resolve-launch`.

## Desktop environments

The launcher looks at the running session and only applies what makes sense there. Run `resolve-launch --print-env` to see exactly what it would set on your machine.

| Session | Interface scale | File chooser | Notes |
| --- | --- | --- | --- |
| Hyprland | Taken from the focused output | System GTK chooser | The only combination tested so far. See the window rule below |
| Sway | Taken from the focused output | System GTK chooser | Same logic as Hyprland, untested |
| GNOME, Wayland or X11 | Left alone, mutter scales XWayland clients itself | System GTK chooser | The locale, 3D and audio fixes apply as everywhere else. Use `--system-launcher` if your dock reads the system `.desktop` file |
| KDE Plasma | Left alone, KWin scales XWayland clients | System GTK chooser | Set `RESOLVE_UI_SCALE` yourself if the interface is still too small |
| Plain X11 session | Left alone | System GTK chooser | Nothing to scale |
| Anything else (River, labwc, niri and friends) | Not detected | System GTK chooser | Set `RESOLVE_UI_SCALE` to the factor of your screen |

Whatever the session, the launcher always starts Resolve through the xcb Qt plugin, which is the only one Resolve ships, so a session that exports `QT_QPA_PLATFORM=wayland` cannot break it.

## What gets installed

| Path | Purpose |
| --- | --- |
| `~/.local/bin/resolve-launch` | Starts Resolve with the fixes |
| `~/.local/bin/resolve-audio-fix` | Audio helper, started and stopped together with Resolve |
| `~/.local/bin/resolve-prep` | Manual audio conversion for files you convert yourself |
| `~/.local/bin/resolve-fix-doctor` | Reports the state of every fix |
| `~/.local/share/resolve-linux-fix/` | The linked GTK plugin, the helper log and its state |
| `~/.local/share/applications/` | A user launcher that overrides the system one |
| `~/.config/resolve-linux-fix/config` | Your settings |

## How the audio fix works

The helper does not poll Resolve. It follows Resolve's own log file. When the log reports that audio could not be decoded, or when the file chooser has been used, it makes a single pass over the media pool through the scripting API. For each clip with AAC audio it:

* writes a copy with the video stream copied untouched and the audio converted to PCM, which is fast and lossless,
* replaces the clip in the media pool, so bins and timelines keep working,
* leaves the original file alone.

The copies go to `~/Videos/Resolve audio converted/`. They take about as much space as the originals, and the helper skips a conversion when fewer than 3 GB would remain free. By default you are only notified when something goes wrong.

You can also convert files yourself without the helper:

```sh
resolve-prep clip1.mp4 clip2.mp4
resolve-prep -o /some/folder clip.mp4
```

## Configuration

Copy options from `config.example` into `~/.config/resolve-linux-fix/config`. The most useful ones:

| Setting | Default | Meaning |
| --- | --- | --- |
| `RESOLVE_DIR` | `/opt/resolve` | Resolve installation directory |
| `RESOLVE_UI_SCALE` | `auto` | `auto`, `off`, or a number such as `1.5` |
| `RESOLVE_NVIDIA_OFFLOAD` | `auto` | `auto`, `yes` or `no` |
| `RESOLVE_NATIVE_FILE_DIALOG` | `yes` | Use the system file chooser |
| `RESOLVE_AUDIO_FIX` | `yes` | Start the audio helper with Resolve |
| `NOTIFY` | `errors` | `errors`, `all` or `none` |
| `OUTPUT_DIR` | `~/Videos/Resolve audio converted` | Where converted copies are written |

## Notes for tiling window managers such as Hyprland and Sway

The scaled interface is wider than half of a screen, so give Resolve the whole workspace or maximize it. The native file chooser opens as a normal window and is better floated. On Hyprland a rule like this does it:

```
windowrule {
    name = float-resolve-filechooser
    match:class = ^resolve$
    match:xwayland = false
    float = yes
    size = 1000 650
    center = yes
}
```

The scale factor is fixed when Resolve starts. Start it on the screen you work on.

## Troubleshooting

Run `resolve-fix-doctor` first. It checks the binary, the locale, the file chooser plugin, the tools, the scripting preference and the helper.

* Typing still crashes Resolve: the locale is missing. Check `locale -a | grep -i en_US` and run `sudo locale-gen en_US.UTF-8`.
* The audio helper never converts anything: enable external scripting in the Resolve preferences. It also requires Resolve Studio.
* Look at `~/.local/share/resolve-linux-fix/audio-fix.log` to see what the helper did.
* If the file chooser looks wrong or Resolve fails to start, set `RESOLVE_NATIVE_FILE_DIALOG=no` in the config.

## Uninstall

```sh
./uninstall.sh
./uninstall.sh --purge
```

The second form also removes your configuration and the helper logs. Converted media and Resolve projects are never touched.

## Related work

The `davinci-resolve-audio-fix` package in the AUR solves the audio problem with a folder watcher that creates converted copies next to the originals. This project instead replaces the clips inside Resolve, so you import the file you already have.

## Contributing

Pull requests are welcome, especially support for more distributions and window managers. Keep the scripts POSIX shell where they can be.
