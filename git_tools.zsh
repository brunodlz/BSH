# ===== GIT ADVANCED =====

# branch local
git_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# ---------------------------------------
# Git numbered staging helpers
# ---------------------------------------

# List files with numeric indexes

git_list() {
  git status --short | awk '{printf "[%d] %s %s\n", NR, $1, $2}'
}

# Add files to staging area by index number

git_add() {
  files=("${(@f)$(git status --short | awk '{print $2}')}")
  for i in "$@"; do
    if (( i >= 1 && i <= ${#files[@]} )); then
      file="${files[$((i))]}"
      git add "$file"
      echo "✅ Added: $file"
    else
      echo "⚠️ Number invalid: $i"
    fi
  done
}

# Remove files from staging area by index number

git_reset() {
  files=("${(@f)$(git status --short | awk '{print $2}')}")
  for i in "$@"; do
    if (( i >= 1 && i <= ${#files[@]} )); then
      file="${files[$((i))]}"
      git reset HEAD -- "$file" >/dev/null 2>&1
      echo "🧹 Removed from stage: $file"
    else
      echo "⚠️ Number invalid: $i"
    fi
  done
}