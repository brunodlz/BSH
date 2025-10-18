print_branch_header() {
  local current_branch

  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  printf "%b⦿ - On branch: %b%b%s%b\n" "$white" "$reset" "$bold" "$current_branch" "$reset"
  printf "%b║%b\n" "$white" "$reset"
}

print_git_section() {
  local color="$1"
  local title="$2"
  local max_len="$3"
  local bracket_width="$4"
  shift 4
  local items=("$@")
  local pipe="${color}║${reset}"

  [[ ${#items[@]} -eq 0 ]] && return

  local buffer=""
  buffer+="${color}⦿ - ${title}${reset}\n"
  buffer+="${pipe}\n"

  local item type file display_file index_width space_padding

  local git_root=$(get_git_root)

  for item in "${items[@]}"; do
    type="${item%%|*}"
    file="${item#*|}"

    display_file="${file#$git_root/}"
    if [[ "$PWD" != "$git_root" ]]; then
      local rel_from_pwd="${PWD#$git_root/}"
      if [[ -n "$rel_from_pwd" ]]; then
        local ups=""
        IFS='/' read -rA dirs <<< "$rel_from_pwd"
        for _ in "${dirs[@]}"; do
          ups="../$ups"
        done
        display_file="${ups}${display_file}"
      fi
    fi

    index_width=${#file_counter}
    space_padding=$((bracket_width - index_width - 2))

    buffer+=$(printf "%b\t%*s%b[%b%d%b] %s%-*s%s : %s%b\n" \
      "$pipe" "$space_padding" "" "$white" "$reset" "$file_counter" "$white" \
      "$color" "$max_len" "$type" "$reset" "$display_file" "$reset")
    buffer+="\n"

    ((file_counter++))
  done

  buffer+="${pipe}\n"

  printf "%b" "$buffer"
}