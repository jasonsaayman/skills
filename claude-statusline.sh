#!/usr/bin/env bash
# Claude Code status line script
# Reads JSON from stdin, outputs a styled one-line status string.

input=$(cat)

# ── helpers ──────────────────────────────────────────────────────────────────
jq_get() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

# ── ANSI colours (these work fine inside Claude's dimmed status area) ─────────
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Soft palette — stands out without screaming
C_PURPLE='\033[38;5;141m'   # model
C_CYAN='\033[38;5;117m'     # effort / thinking
C_GREEN='\033[38;5;114m'    # context
C_YELLOW='\033[38;5;221m'   # rate limit
C_BLUE='\033[38;5;111m'     # git branch
C_SEP='\033[38;5;240m'      # separator (muted grey)

SEP="${C_SEP} · ${RESET}"

# ── 1. Model ──────────────────────────────────────────────────────────────────
model=$(jq_get '.model.display_name')
if [ -n "$model" ]; then
  model_seg="${C_PURPLE}${BOLD} ${model}${RESET}"
fi

# ── 2. Effort level ───────────────────────────────────────────────────────────
effort=$(jq_get '.effort.level')
if [ -n "$effort" ]; then
  # Capitalise first letter
  effort_label="$(tr '[:lower:]' '[:upper:]' <<< "${effort:0:1}")${effort:1}"
  effort_seg="${C_CYAN}⚡ ${effort_label}${RESET}"
fi

# ── 3. Context used (%) ───────────────────────────────────────────────────────
used_pct=$(jq_get '.context_window.used_percentage')
if [ -n "$used_pct" ]; then
  # Round to nearest integer
  used_int=$(printf '%.0f' "$used_pct")
  context_seg="${C_GREEN}◐ ${used_int}%${RESET}"
fi

# ── 4. 5-hour rate limit (show % remaining, derived from used) ────────────────
five_used=$(jq_get '.rate_limits.five_hour.used_percentage')
if [ -n "$five_used" ]; then
  five_remaining=$(printf '%.0f' "$(echo "100 - $five_used" | bc)")
  rate_seg="${C_YELLOW}⏱ ${five_remaining}% left${RESET}"
fi

# ── 5. Git branch ─────────────────────────────────────────────────────────────
cwd=$(jq_get '.cwd')
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
fi
if [ -n "$branch" ]; then
  branch_seg="${C_BLUE} ${branch}${RESET}"
fi

# ── Assemble ──────────────────────────────────────────────────────────────────
parts=()
[ -n "$model_seg"   ] && parts+=("$model_seg")
[ -n "$effort_seg"  ] && parts+=("$effort_seg")
[ -n "$context_seg" ] && parts+=("$context_seg")
[ -n "$rate_seg"    ] && parts+=("$rate_seg")
[ -n "$branch_seg"  ] && parts+=("$branch_seg")

output=""
for i in "${!parts[@]}"; do
  if [ "$i" -eq 0 ]; then
    output="${parts[$i]}"
  else
    output="${output}${SEP}${parts[$i]}"
  fi
done

printf "%b\n" "$output"
