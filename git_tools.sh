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
  local files=("${(@f)$(git status --short | awk '{print $2}')}")

  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: ga <number(s) or interval(s)>"
    echo "Ex: ga 1 3 5-7"
    return
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "✅ No files to add"
    return
  fi

  local indexes=()

  # Expand intervals and multiple arguments
  for arg in "$@"; do
    if [[ "$arg" == *-* ]]; then
      local start end
      IFS='-' read -r start end <<< "$arg"

      # Validate interval
      if [[ ! "$start" =~ ^[0-9]+$ ]] || [[ ! "$end" =~ ^[0-9]+$ ]]; then
        echo "⚠️ Invalid interval: $arg"
        continue
      fi

      for ((i=start; i<=end; i++)); do
        indexes+=($i)
      done
    else
      # Validate single number
      if [[ ! "$arg" =~ ^[0-9]+$ ]]; then
        echo "⚠️ Invalid number: $arg"
        continue
      fi
      indexes+=($arg)
    fi
  done

  # Remove duplicate and order
  indexes=(${(nu)indexes})

  local added=0
  for i in "${indexes[@]}"; do
    if (( i >= 1 && i <= ${#files[@]} )); then
      local file="${files[$i]}"
      git add "$file"
      echo "✅ Added: $file"
      ((added++))
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