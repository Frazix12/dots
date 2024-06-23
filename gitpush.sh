#!/bin/bash

# Save the current date and time in a variable
comment="Saved on $(date '+%Y-%m-%d %H:%M:%S')"

# Check if a username was provided as an argument
if [ -n "$1" ]; then
  username="$1"
  comment="$comment by $username"
fi

# Output the comment
echo "$comment"

# Git operations
git checkout development
git add .
git commit -m "$comment"
git push origin
