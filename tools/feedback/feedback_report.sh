#!/bin/bash
# Lists open player feedback from the private feedback repo. Claude Code runs this at session start
# (.claude/settings.json SessionStart hook) so new reports show up while you work. Safe to run by hand.
# Needs the GitHub CLI signed in with access to the repo; prints nothing if it can't reach GitHub.
REPO="AGD3SIGN/daemons-feedback"
command -v gh >/dev/null 2>&1 || exit 0
out=$(gh issue list -R "$REPO" --state open --limit 25 --json number,title,labels,createdAt \
  --jq '.[] | "#\(.number) \(.title)  [\([.labels[].name] | map(select(. != "feedback")) | join(", "))]  \(.createdAt[:10])"' 2>/dev/null) || exit 0
if [ -z "$out" ]; then
  echo "Player feedback ($REPO): no open reports."
  exit 0
fi
count=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
echo "Player feedback ($REPO): $count open report(s)."
echo "Read one: gh issue view <number> -R $REPO   Close when fixed: gh issue close <number> -R $REPO -c \"Fixed in <commit>\""
printf '%s\n' "$out"
