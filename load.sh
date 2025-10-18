#!/usr/bin/env bash
# Load all scripts in ~/.bsh dynamically

BSH_DIR="$HOME/.bsh"

# -------------------------------
# 1. Load all .sh files in root
# -------------------------------
for file in "$BSH_DIR"/*.sh; do
  filename=$(basename "$file")
  if [ "$filename" != "load.sh" ] && [ "$filename" != "install.sh" ] && [ "$filename" != "update.sh" ] && [ -f "$file" ]; then
    source "$file"
  fi
done

# -------------------------------
# 2. Load all modules (e.g git/)
# -------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_DIR="$SCRIPT_DIR/git"

for file in "$GIT_DIR"/*.sh; do
  source "$file"
done

# ------------------------
# 3. BSH Internal Commands
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