# ===== GIT ADVANCED =====

# branch local
git_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# --------------------------------
# Colors
# --------------------------------

green=$'\033[32m'
red=$'\033[31m'
orange=$'\033[38;5;214m'
cyan=$'\033[36m'
reset=$'\033[0m'

# --------------------------------
# Git status
# --------------------------------

declare -A git_file_map

git_status() {
  file_counter=1
  git_file_map=()

  local -a staged unstaged untracked

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
      staged+=("$label $reset$file")
    fi

    # --- Unstaged ---
    if [[ "$allUnstaged" == "M" || "$allUnstaged" == "D" ]]; then
      local label=""
      case "$allUnstaged" in
        'M') label="${orange} modified:" ;;
        'D') label="${red}  deleted:" ;;
      esac
      unstaged+=("$label $reset$file")      
    fi

    # --- Untracked ---
    if [[ "$allUntracked" == "??" ]]; then
      untracked+=("${cyan} untracked:${reset}$file")
    fi
    
  done < <(git status --short)

  # --- Prints ---
  print_git_section "$green"  "Changes to be committed:"        "${staged[@]}"
  print_git_section "$orange" "Changes not staged for commit:"  "${unstaged[@]}"
  print_git_section "$cyan"   "Untracked files:"                "${untracked[@]}"
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
  local num="$1"

  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: gd <number>"
    echo "Ex: gd 1"
    return 1
  fi

  if [[ -z "${git_file_map[$num]}" ]]; then
    echo "⚠️ Number out of range: $index (1-${#git_file_map[@]})" >&2
    return 1
  fi

  local file="${git_file_map[$num]#*${reset}}"

  git diff --color=always -- "$file" | less -R
}

# -----------------------------------------------
# Git reset
# -----------------------------------------------

git_reset() {
  local files=($(git_get_files))
  local file

  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: gr <numbers>"
    echo "Ex: gr 1 2 3"
    return 1
  fi

  for i in "$@"; do
    file=$(git_get_file_by_index "$i" "${files[@]}") || continue
    git reset HEAD -- "$file" >/dev/null 2>&1
    echo "🧹 Removed from stage: $file"
  done
}

# -----------------------------------------------
# Helpers
# -----------------------------------------------

print_git_section() {
  local color="$1"
  local title="$2"
  shift 2
  local items=("$@")
  local showPipe="${color}|${reset}"

  [[ ${#items[@]} -eq 0 ]] && return

  printf "%b ➤ %s\n" "$showPipe" "$title"
  printf "%b\n" "$showPipe"

  for item in "${items[@]}"; do
    printf "%b   [%d] %s%b\n" "$showPipe" "$file_counter" "$item" "$reset"
    git_file_map[$file_counter]="$item"
    ((file_counter++))
  done

  printf "%b\n" "$showPipe"
}

git_get_files() {
  git status --short | awk '{print $2}'
}

git_get_file_by_index() {
  local index=$1
  shift
  local -a files=("$@")

  if [[ ! "$index" =~ ^[0-9]+$ ]]; then
    echo "⚠️ Invalid number: $index" >&2
    return 1
  fi

  if (( index < 1 || index > ${#files[@]} )); then
    echo "⚠️ Number out of range: $index (1-${#files[@]})" >&2
    return 1
  fi

  echo "${files[$((index))]}"
}