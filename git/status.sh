git_status() {
  print_branch_header
  git_file_map_from_status

  local all_items=("${GIT_STAGED[@]}" "${GIT_UNSTAGED[@]}" "${GIT_UNTRACKED[@]}")
  local max_len=0
  local item type

  for item in "${all_items[@]}"; do
      type="${item%%|*}"
      (( ${#type} > max_len )) && max_len=${#type}
  done

  local total_files=$(( ${#GIT_STAGED[@]} + ${#GIT_UNSTAGED[@]} + ${#GIT_UNTRACKED[@]} ))
  local last_index=$((file_counter + total_files - 1))
  local max_index_width=${#last_index}
  local padding=$((max_index_width + 2))

  file_counter=1

  print_git_section "$git_staged_color"    "Changes to be committed:"        "$max_len" "$padding" "${GIT_STAGED[@]}"
  print_git_section "$git_unstaged_color"  "Changes not staged for commit:"  "$max_len" "$padding" "${GIT_UNSTAGED[@]}"
  print_git_section "$git_untracked_color" "Untracked files:"                "$max_len" "$padding" "${GIT_UNTRACKED[@]}"
}