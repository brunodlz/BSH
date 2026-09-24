#!/usr/bin/env bash

set -e

BSH_DIR="${BSH_DIR:-$HOME/.bsh}"

if [ ! -d "$BSH_DIR/.git" ]; then
    echo "❌ BSH doesn't seem to be a Git repository."
    echo "Please reinstall using:"
    echo "  git clone https://github.com/brunodlz/BSH.git ~/.bsh"
    exit 1
fi

echo "🔁 Updating BSH in $BSH_DIR..."

# Atualiza via git -C sem alterar o diretório atual do usuário
git -C "$BSH_DIR" pull origin master

# Apply install.sh --update if needed
if [ -f "$BSH_DIR/install.sh" ]; then
    echo "⚙️ Applying configuration changes..."
    bash "$BSH_DIR/install.sh" --update
fi

echo "✅ BSH updated successfully!"
