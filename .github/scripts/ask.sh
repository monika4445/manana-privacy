#!/usr/bin/env bash
# Sends the trends list of pull request $1 to Telegram with Publish and Skip
# buttons, then marks the pull request as asked. Needs TOKEN, CHAT, GH_TOKEN.
set -euo pipefail
pr=$1
api="https://api.telegram.org/bot$TOKEN"
info=$(gh pr view "$pr" --repo "$GITHUB_REPOSITORY" --json headRefOid,url)
head=$(jq -r .headRefOid <<<"$info")
url=$(jq -r .url <<<"$info")
gh api "repos/$GITHUB_REPOSITORY/contents/trends.json?ref=$head" -H "Accept: application/vnd.github.raw" > list.json
jq -e '.version == 1 and (.trends | length) >= 3' list.json > /dev/null
month=$(jq -r '.month' list.json)
lines=$(jq -r '.trends | to_entries[] | "\(.key + 1). \(.value.title.en)\n    \(.value.template)\(if .value.song then " · song: \(.value.song)" else "" end)\(if .value.sound then " · Instagram sound: \(.value.sound)" else "" end)"' list.json)
text=$(printf 'Manana: Top 5 for %s is ready\n\n%s\n\nPublish it to every phone? Your answer is acted on within an hour.' "$month" "$lines")
markup=$(jq -cn --arg pr "$pr" --arg url "$url" '{inline_keyboard: [[{text: "Publish", callback_data: ("publish:" + $pr)}, {text: "Skip", callback_data: ("skip:" + $pr)}], [{text: "See it on GitHub", url: $url}]]}')
answer=$(curl -s --max-time 60 -X POST "$api/sendMessage" \
  --data-urlencode "chat_id=$CHAT" \
  --data-urlencode "text=$text" \
  --data-urlencode "reply_markup=$markup")
if ! jq -e '.ok' <<<"$answer" > /dev/null; then
  echo "Telegram said: $(jq -r '.description // "no answer"' <<<"$answer")"
  exit 1
fi
gh label create asked-on-telegram --repo "$GITHUB_REPOSITORY" --color 0E8A16 --force > /dev/null
gh pr edit "$pr" --repo "$GITHUB_REPOSITORY" --add-label asked-on-telegram > /dev/null
echo "Asked about #$pr"
