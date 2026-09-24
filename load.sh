#!/usr/bin/env bash
# Load all scripts in ~/.bsh dynamically

BSH_DIR="${BSH_DIR:-$HOME/.bsh}"

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
GIT_DIR="$BSH_DIR/git"

if [ -d "$GIT_DIR" ]; then
  for file in "$GIT_DIR"/*.sh; do
    [ -f "$file" ] && source "$file"
  done
fi

# ------------------------
# 3. BSH Internal Commands
# ------------------------

bsh_update() {
  bash "$BSH_DIR/update.sh"
}

bsh_reload() {
  echo "🔁 Reloading BSH..."
  source "$BSH_DIR/load.sh"
  echo "✅ BSH reloaded!"
}

bsh_info() {
  echo "📦 BSH Directory: $BSH_DIR"
  echo "🔢 Git version: $(git -C "$BSH_DIR" rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
}
