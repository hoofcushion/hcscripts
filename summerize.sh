#!/bin/bash

# 配置参数
REPO_OWNER="${1:-neovim}"    # 默认neovim
REPO_NAME="${2:-neovim}"     # 默认neovim
SINCE_DATE="${3:-$(date -d "1 month ago" +%Y-%m-%dT%H:%M:%SZ)}"  # 默认1个月前
PAGE=1
PER_PAGE=100

echo "获取仓库: $REPO_OWNER/$REPO_NAME"
echo "时间范围: $SINCE_DATE 至今"
echo "----------------------------------------"

while true; do
  response=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/commits?since=$SINCE_DATE&page=$PAGE&per_page=$PER_PAGE" \
    -H "Accept: application/vnd.github.v3+json")
  
  # 检查API限制或错误
  if echo "$response" | jq -e 'type=="object" and has("message")' >/dev/null 2>&1; then
    echo "错误: $(echo "$response" | jq -r '.message')"
    exit 1
  fi
  
  commits=$(echo "$response" | jq -r '.[] | "Date: \(.commit.author.date)\nAuthor: \(.commit.author.name)\nTitle: \(.commit.message | split("\n")[0])\nDescription: \(.commit.message)\n---"')
  
  if [ -z "$commits" ] || [ "$commits" = "null" ]; then
    break
  fi
  
  echo "$commits"
  ((PAGE++))
done

echo "获取完成"
