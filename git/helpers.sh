# --------------------------------------
# Git root (cached)
# --------------------------------------

get_git_root() {
  if [[ -z "$__GIT_ROOT_CACHE" ]]; then
    __GIT_ROOT_CACHE=$(git rev-parse --show-toplevel 2>/dev/null)
  fi
  echo "$__GIT_ROOT_CACHE"
}

get_current_branch() {
  echo "$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)"
}

# --------------------------------------
# Relative path
# --------------------------------------

get_relative_path() {
  local file="$1"
  local git_root="$(get_git_root)"

  python3 -c "import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" \
    "$git_root/$file" "$PWD"
}