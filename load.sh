#!/usr/bin/env bash
# Load all scripts in ~/.bsh dynamically

BSH_DIR="$HOME/.bsh"

# ----------------------------------------------------------
# Load all .sh files in ~/.bsh except loader and installer
# ----------------------------------------------------------
for file in "$BSH_DIR"/*.sh; do
  filename=$(basename "$file")
  if [ "$filename" != "load.sh" ] && [ "$filename" != "install.sh" ] && [ "$filename" != "update.sh" ] && [ -f "$file" ]; then
    source "$file"
  fi
done

# ------------------------
# BSH Internal Commands
# ------------------------

# Update BSH to the latest version
bsh_update() {
  bash "$BSH_DIR/update.sh"
}

# Reload BSH without restarting the shell
bsh_reload() {
  echo "🔁 Reloading BSH..."
  source "$BSH_DIR/load.sh"
  echo "✅ BSH reloaded!"
}

# Show information about the current BSH installation
bsh_info() {
  echo "📦 BSH Directory: $BSH_DIR"
  echo "🔢 Git version: $(cd "$BSH_DIR" && git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
}