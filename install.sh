#!/usr/bin/env bash
# Installs the DaVinci Resolve Linux fix for the current user.
# Everything lives in the home directory. sudo is only asked for when a missing locale has
# to be generated or when --system-launcher is used.

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_target="$HOME/.local/bin"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/resolve-linux-fix"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/resolve-linux-fix"
apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

resolve_dir="/opt/resolve"
system_launcher=no
skip_locale=no
assume_yes=no
scripts=(resolve-launch resolve-audio-fix resolve-prep resolve-fix-doctor)

usage() {
  cat <<USAGE
Usage: ./install.sh [options]

  --resolve-dir DIR     Resolve installation directory (default /opt/resolve)
  --system-launcher     Also point the system-wide launcher at the fixed one (needs sudo)
  --skip-locale         Do not try to generate the en_US.UTF-8 locale
  -y, --yes             Do not ask before running sudo
  -h, --help            Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --resolve-dir) resolve_dir="$2"; shift 2 ;;
    --system-launcher) system_launcher=yes; shift ;;
    --skip-locale) skip_locale=yes; shift ;;
    -y|--yes) assume_yes=yes; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

confirm() {
  [ "$assume_yes" = yes ] && return 0
  printf '%s [y/N] ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

distro_family() {
  local id="" like=""
  if [ -r /etc/os-release ]; then
    id="$(. /etc/os-release; printf '%s' "${ID:-}")"
    like="$(. /etc/os-release; printf '%s' "${ID_LIKE:-}")"
  fi
  case " $id $like " in
    *" debian "*|*" ubuntu "*) echo debian ;;
    *" fedora "*|*" rhel "*) echo fedora ;;
    *" arch "*) echo arch ;;
    *) echo unknown ;;
  esac
}

family="$(distro_family)"

install_hint() {
  case "$family" in
    debian) say "  sudo apt install $1" ;;
    fedora) say "  sudo dnf install $2" ;;
    arch) say "  sudo pacman -S $3" ;;
    *) say "  install the packages that provide: $4" ;;
  esac
}

if [ ! -x "$resolve_dir/bin/resolve" ]; then
  say "DaVinci Resolve was not found in $resolve_dir."
  say "Download it from the official Blackmagic Design website, install it, and run this script again:"
  say "  https://www.blackmagicdesign.com/products/davinciresolve"
  say "If it lives somewhere else, pass --resolve-dir DIR."
  exit 1
fi

say "Desktop session: ${XDG_CURRENT_DESKTOP:-unknown} (${XDG_SESSION_TYPE:-unknown})"

missing=0
for tool in ffmpeg ffprobe python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    warn "$tool is required but missing"
    missing=1
  fi
done
if [ "$missing" -eq 1 ]; then
  say "Install the missing tools and run this script again:"
  install_hint "ffmpeg python3" "ffmpeg python3" "ffmpeg python" "ffmpeg python3"
  exit 1
fi
command -v notify-send >/dev/null 2>&1 || warn "notify-send is missing, error notifications will not be shown (libnotify)"

locale_name="en_US.UTF-8"
locale_key="en_US.utf8"
if locale -a 2>/dev/null | grep -qix "$locale_key"; then
  say "Locale $locale_name is available."
elif [ "$skip_locale" = yes ]; then
  warn "Locale $locale_name is missing. Resolve will abort when you type in Fusion until it exists."
else
  say "Locale $locale_name is missing, and Resolve needs it."
  case "$family" in
    debian|arch|unknown)
      if command -v locale-gen >/dev/null 2>&1 && confirm "Generate it now with sudo?"; then
        if [ -f /etc/locale.gen ]; then
          sudo sed -i "s/^# *\(${locale_name} UTF-8\)/\1/" /etc/locale.gen
          grep -q "^${locale_name} UTF-8" /etc/locale.gen || echo "${locale_name} UTF-8" | sudo tee -a /etc/locale.gen >/dev/null
          sudo locale-gen
        else
          sudo locale-gen "$locale_name"
        fi
      else
        warn "Skipped. Generate it manually: sudo locale-gen $locale_name"
      fi
      ;;
    fedora)
      say "On Fedora run: sudo dnf install glibc-langpack-en"
      ;;
  esac
fi

plugin_source=""
for candidate in \
  /usr/lib/x86_64-linux-gnu/qt5/plugins/platformthemes/libqgtk3.so \
  /usr/lib64/qt5/plugins/platformthemes/libqgtk3.so \
  /usr/lib/qt5/plugins/platformthemes/libqgtk3.so \
  /usr/lib/qt/plugins/platformthemes/libqgtk3.so; do
  if [ -e "$candidate" ]; then
    plugin_source="$candidate"
    break
  fi
done
if [ -z "$plugin_source" ]; then
  warn "The Qt5 GTK platform theme was not found, so Resolve keeps its own file browser."
  install_hint "qt5-gtk-platformtheme" "qt5-qtbase-gui" "qt5-base" "the Qt5 GTK platform theme (libqgtk3.so)"
fi

mkdir -p "$bin_target" "$config_dir" "$data_dir"
for script in "${scripts[@]}"; do
  install -m 0755 "$repo_dir/bin/$script" "$bin_target/$script"
done
say "Scripts installed in $bin_target."

if [ -n "$plugin_source" ]; then
  mkdir -p "$data_dir/qt-plugins/platformthemes"
  ln -sf "$plugin_source" "$data_dir/qt-plugins/platformthemes/libqgtk3.so"
  say "GTK file chooser plugin linked."
fi

if [ ! -e "$config_dir/config" ]; then
  install -m 0644 "$repo_dir/config.example" "$config_dir/config"
  if [ "$resolve_dir" != "/opt/resolve" ]; then
    printf 'RESOLVE_DIR=%s\n' "$resolve_dir" >> "$config_dir/config"
  fi
  say "Default configuration written to $config_dir/config."
fi

source_desktop=""
for dir in "$apps_dir" /usr/local/share/applications /usr/share/applications; do
  for candidate in "$dir"/com.blackmagicdesign.resolve.desktop "$dir"/*esolve*.desktop; do
    if [ -f "$candidate" ] && grep -q '^Exec=.*/bin/resolve' "$candidate" 2>/dev/null; then
      source_desktop="$candidate"
      break 2
    fi
  done
done

if [ -n "$source_desktop" ]; then
  mkdir -p "$apps_dir"
  target_desktop="$apps_dir/$(basename "$source_desktop")"
  if ! grep -q "^Exec=$bin_target/resolve-launch" "$source_desktop"; then
    sed "s#^Exec=.*/bin/resolve.*#Exec=$bin_target/resolve-launch %u#" "$source_desktop" > "$target_desktop.tmp"
    mv "$target_desktop.tmp" "$target_desktop"
    say "Launcher written to $target_desktop."
  fi
  if [ "$system_launcher" = yes ]; then
    system_desktop="/usr/share/applications/$(basename "$source_desktop")"
    if [ -f "$system_desktop" ] && ! grep -q "^Exec=$bin_target/resolve-launch" "$system_desktop"; then
      sudo cp -n "$system_desktop" "$system_desktop.bak"
      sudo sed -i "s#^Exec=.*/bin/resolve.*#Exec=$bin_target/resolve-launch %u#" "$system_desktop"
      say "System launcher patched, the original is saved as $system_desktop.bak."
    fi
  fi
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$apps_dir" 2>/dev/null || true
else
  warn "No Resolve desktop entry was found. Start Resolve with $bin_target/resolve-launch instead."
fi

case ":$PATH:" in
  *":$bin_target:"*) ;;
  *) warn "$bin_target is not in your PATH." ;;
esac

say ""
say "Done. Current state:"
"$bin_target/resolve-fix-doctor" || true
say ""
say "Start Resolve from your application menu or with resolve-launch."
