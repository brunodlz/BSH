#!/usr/bin/env bash
# Load all scripts in ~/.bsh dynamically

BSH_DIR="$HOME/.bsh"

# Add bin folder to PATH
[ -d "$BSH_DIR/bin" ] && export PATH="$BSH_DIR/bin:$PATH"

# Source all .sh files except this loader and installer
for file in "$BSH_DIR"/*.sh; do
  filename=$(basename "$file")
  if [ "$filename" != "load.sh" ] && [ "$filename" != "install.sh" ] && [ -f "$file" ]; then
    source "$file"
  fi
done