git_file_map_from_status() {
  local staged_items=()
  local unstaged_items=()
  local untracked_items=()

  git_file_map=()

  local git_root
  git_root=$(get_git_root) || {
    echo "⚠️ Not inside a Git repository."
    return 1
  }

  local label file
  local staged unstaged

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    staged="${line:0:1}"
    unstaged="${line:1:1}"
    file="${line:3}"

    [[ -z "$file" ]] && continue

    # Staged
    if [[ "$staged" != " " && "$staged" != "?" ]]; then
      case "$staged" in
        M) label="modified" ;;
        A) label="new file" ;;
        D) label="deleted" ;;
        R) label="renamed" ;;
        C) label="copied" ;;
        *) label="changed" ;;
      esac
      staged_items+=("$label|$file")
    fi

    # Unstaged
    if [[ "$unstaged" == "M" || "$unstaged" == "D" ]]; then
      case "$unstaged" in
        M) label="modified" ;;
        D) label="deleted" ;;
      esac
      unstaged_items+=("$label|$file")
    fi

    # Untracked
    if [[ "$staged$unstaged" == "??" ]]; then
      untracked_items+=("untracked|$file")
    fi
  done < <(git -C "$git_root" status --porcelain 2>/dev/null)

  file_counter=1
  local item

  for item in "${staged_items[@]}" "${unstaged_items[@]}" "${untracked_items[@]}"; do
    git_file_map[$file_counter]="${item#*|}"
    ((file_counter++))
  done

  GIT_STAGED=("${staged_items[@]}")
  GIT_UNSTAGED=("${unstaged_items[@]}")
  GIT_UNTRACKED=("${untracked_items[@]}")
}