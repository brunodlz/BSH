# ===== GIT ADVANCED =====

# branch local
git_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# --------------------------------
# List files with numeric indexes
# --------------------------------

git_list() {
  local staged=()
  local unstaged=()
  local untracked=()
  local counter=1

  # ANSI color codes
  local green='\033[32m'
  local red='\033[31m'
  local yellow='\033[33m'
  local orange='\033[38;5;214m'
  local cyan='\033[36m'
  local reset='\033[0m'
  local bold="\033[1m"

  while IFS= read -r line; do
    local git_status="${line:0:2}"
    local file="${line:3}"
    local first_char="${git_status:0:1}"
    local second_char="${git_status:1:1}"

    # Check first character (staged changes)
    if [[ "$first_char" != " " && "$first_char" != "?" ]]; then
      local status_text=""
      local file_color="$reset"

      case "$first_char" in
        'M') status_text="${green} modified:${reset}" ;;
        'A') status_text="${green} new file:${reset}" ;;
        'D') status_text="${red}  deleted:${reset}" ;;
        'R') status_text="${green}  renamed:${reset}" ;;
        'C') status_text="${green}   copied:${reset}" ;;
      esac

      staged+=("$counter|$status_text $file_color$file$reset")
      ((counter++))
    fi

    # Check second character (unstaged changes)
    if [[ "$second_char" == "M" || "$second_char" == "D" ]]; then
      local status_text=""
      local file_color="$reset"

      case "$second_char" in
        'M') status_text="${orange} modified:${reset}" ;;
        'D') status_text="${red}  deleted:${reset}" ;;
      esac

      unstaged+=("$counter|$status_text $file_color$file$reset")
      ((counter++))
    fi

    # Check for untracked files
    if [[ "$git_status" == "??" ]]; then
      untracked+=("$counter|${cyan}untracked:${reset} $file")
      ((counter++))
    fi
  done < <(git status --short)

  # Print staged

  # echo -e "${orange}| ➤${reset} Current branch: ${bold}$(git_current_branch)${reset}"
  # echo "${orange}|${reset}"

  if [[ ${#staged[@]} -gt 0 ]]; then
    echo -e "${green}| ➤${reset} Changes to be committed:"
    echo "${green}|${reset}"
    for item in "${staged[@]}"; do
      local num="${item%%|*}"
      local content="${item#*|}"
      echo -e "${green}|${reset}   [$num] $content"
    done
    echo "${green}|${reset}"
  fi

  # Print unstaged
  if [[ ${#unstaged[@]} -gt 0 ]]; then
    echo -e "${orange}| ➤${reset} Changes not staged for commit:"
    echo "${orange}|${reset}"
    for item in "${unstaged[@]}"; do
      local num="${item%%|*}"
      local content="${item#*|}"
      echo -e "${orange}|${reset}   [$num] $content"
    done
    echo "${orange}|${reset}"
  fi

  # Print untracked
  if [[ ${#untracked[@]} -gt 0 ]]; then
    echo -e "${cyan}| ➤${reset} Untracked files:"
    echo "${cyan}|${reset}"
    for item in "${untracked[@]}"; do
      local num="${item%%|*}"
      local content="${item#*|}"
      echo -e "${cyan}|${reset}   [$num] $content"
    done
    echo "${cyan}|${reset}"
  fi
}

# ------------------------------------------
# Add files to staging area by index number
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
# Diff files outside the staging area by index number
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
# Remove files from staging area by index number
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
