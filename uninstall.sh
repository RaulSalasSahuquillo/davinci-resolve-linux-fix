#!/usr/bin/env bash
# Removes everything install.sh added. Converted media and your Resolve projects are untouched.
# Pass --purge to also delete the configuration and the logs.

set -euo pipefail

bin_target="$HOME/.local/bin"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/resolve-linux-fix"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/resolve-linux-fix"
apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

for script in resolve-launch resolve-audio-fix resolve-prep resolve-fix-doctor; do
  rm -f "$bin_target/$script"
done

rm -rf "$data_dir/qt-plugins"

for desktop in "$apps_dir"/*esolve*.desktop; do
  [ -f "$desktop" ] || continue
  if grep -q 'resolve-launch' "$desktop"; then
    rm -f "$desktop"
    echo "Removed $desktop"
  fi
done

for backup in /usr/share/applications/*esolve*.desktop.bak; do
  [ -f "$backup" ] || continue
  original="${backup%.bak}"
  # Only undo the system launcher if it still points at this user's fixed launcher.
  if grep -q "^Exec=$bin_target/resolve-launch" "$original" 2>/dev/null; then
    echo "Restoring $original from $backup (needs sudo)"
    sudo cp "$backup" "$original"
    sudo rm "$backup"
  fi
done

if [ "${1:-}" = "--purge" ]; then
  rm -rf "$config_dir" "$data_dir"
  echo "Configuration and logs removed."
fi

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$apps_dir" 2>/dev/null || true
echo "Uninstalled."
