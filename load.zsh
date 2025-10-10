#!/usr/bin/env bash
# Load all scripts in ~/.bsh dynamically

BSH_DIR="$HOME/.bsh"

# Add bin folder to PATH
[ -d "$BSH_DIR/bin" ] && export PATH="$BSH_DIR/bin:$PATH"

# Source all .zsh files except this loader
for file in "$BSH_DIR"/*.zsh; do
  [ "$file" != "$BSH_DIR/load.zsh" ] && [ -f "$file" ] && source "$file"
done

echo "✅ BSH scripts loaded from $BSH_DIR"