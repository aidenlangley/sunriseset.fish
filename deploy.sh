#! /usr/bin/env sh

# Push to GitHub in the background.
git push gh && git push gh --tags &

# Push to git.sr.ht.
git push && git push --tags
