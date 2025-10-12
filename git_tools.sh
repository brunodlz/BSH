# ===== GIT ADVANCED =====

# branch local
git_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# --------------------------------
# Colors
# --------------------------------

green='\033[32m'
red='\033[31m'
yellow='\033[33m'
orange='\033[38;5;214m'
cyan='\033[36m'
reset='\033[0m'
bold="\033[1m"

# --------------------------------
# Git status
# --------------------------------

git_status() {
  local -a staged unstaged untracked
  local counter=1

  while IFS= read -r line; do
    local allStaged="${line:0:1}"    # staged
    local allUnstaged="${line:1:1}"  # unstaged
    local allUntracked="${line:0:2}" # untracked
    local file="${line:3}"           # file name

    # --- Staged ---
    if [[ "$allStaged" != " " && "$allStaged" != "?" ]]; then
      local label=""
      case "$allStaged" in
        'M') label="${green} modified:" ;;
        'A') label="${green} new file:" ;;
        'D') label="${red}  deleted:" ;;
        'R') label="${green}  renamed:" ;;
        'C') label="${green}   copied:" ;;
      esac
      staged+=("$counter|$label $reset$file")
      ((counter++))
    fi

    # --- Unstaged ---
    if [[ "$allUnstaged" == "M" || "$allUnstaged" == "D" ]]; then
      local label=""
      case "$allUnstaged" in
        'M') label="${orange} modified:" ;;
        'D') label="${red}  deleted:" ;;
      esac
      unstaged+=("$counter|$label $reset$file")
      ((counter++))
    fi

    # --- Untracked ---
    if [[ "$allUntracked" == "??" ]]; then
      untracked+=("$counter|${cyan} untracked:${reset} $file")
      ((counter++))
    fi
  done < <(git status --short)

  # --- Prints ---
  print_git_section "$green"  "Changes to be committed:"        "${staged[@]}"
  print_git_section "$orange" "Changes not staged for commit:"  "${unstaged[@]}"
  print_git_section "$cyan"   "Untracked files:"                "${untracked[@]}"
}

print_git_section() {
  local color="$1"
  local title="$2"
  shift 2
  local items=("$@")

  [[ ${#items[@]} -eq 0 ]] && return

  echo -e "${color}| ➤${reset} ${title}"
  echo -e "${color}|${reset}"

  for item in "${items[@]}"; do
    local num="${item%%|*}"
    local content="${item#*|}"
    echo -e "${color}|${reset}   [$num] $content"
  done

  echo -e "${color}|${reset}"
}

# ------------------------------------------
# Git add
# ------------------------------------------

git_add() {
  local staged_files unstaged_files files=()
  local indexes=()

  staged_files=("${(@f)$(git diff --cached --name-only | sed '/^$/d' | tr -d '\r')}")
  unstaged_files=("${(@f)$(git diff --name-only | sed '/^$/d' | tr -d '\r')}")

  for f in "${staged_files[@]}" "${unstaged_files[@]}"; do
    [[ -n "$f" ]] && files+=("$f")
  done

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "✅ No files to add"
    return 0
  fi

  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: ga <number(s) or interval(s)>"
    echo "Ex: ga 1 3 5-7"
    return 1
  fi

  for arg in "$@"; do
    if [[ "$arg" == *-* ]]; then
      local start end
      IFS='-' read -r start end <<< "$arg"
      if [[ ! "$start" =~ ^[0-9]+$ ]] || [[ ! "$end" =~ ^[0-9]+$ ]]; then
        echo "⚠️ Invalid interval: $arg"
        continue
      fi
      for ((i=start; i<=end; i++)); do
        indexes+=($i)
      done
    else
      if [[ ! "$arg" =~ ^[0-9]+$ ]]; then
        echo "⚠️ Invalid number: $arg"
        continue
      fi
      indexes+=($arg)
    fi
  done

  indexes=(${(nu)indexes})

  for i in "${indexes[@]}"; do
    if (( i >= 1 && i <= ${#files[@]} )); then
      local file="${files[$((i))]}"

      if [[ -z "$file" ]]; then
        echo "⚠️ Skipping empty entry at index $i"
        continue
      fi

      # If the file is unstaged, allow adding it again
      if git diff --name-only | grep -qx "$file"; then
        git add "$file"
        continue
      fi

      # If the file was unstaged and not yet staged
      if ! git diff --cached --name-only | grep -qx "$file"; then
        git add "$file"
        continue
      fi
    else
      echo "⚠️ Invalid number: $i (range: 1-${#files[@]})"
    fi
  done
}

# ----------------------------------------------------
# Git diff
# ----------------------------------------------------

git_diff() {
  local files=("${(@f)$(git status --short | awk '{print $2}')}")

  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: gd <number>"
    echo "Ex: gd 1"
    return 1
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "✅ No modified files"
    return 0
  fi

  local num="$1"

  # Validate single number
  if [[ ! "$num" =~ ^[0-9]+$ ]]; then
    echo "⚠️ Invalid argument: $num"
    return 1
  fi

  if (( num >= 1 && num <= ${#files[@]} )); then
    local file="${files[$num]}"
    git diff --color=always -- "$file" | less -R
  else
    echo "⚠️  Invalid number: $num (range: 1-${#files[@]})"
    return 1
  fi
}

# -----------------------------------------------
# Git reset
# -----------------------------------------------

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
