#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <post-slug>"
  exit 1
fi

slug="$1"

hugo new "content/posts/${slug}.en.md"
hugo new "content/posts/${slug}.id.md"

echo "Created: content/posts/${slug}.en.md"
echo "Created: content/posts/${slug}.id.md"
