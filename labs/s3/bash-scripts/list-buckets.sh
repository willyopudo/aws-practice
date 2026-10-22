#!/usr/bin/env bash

source "$(dirname "$0")/_common.sh"

guard_account

aws s3api list-buckets | jq -r '.Buckets | sort_by(.CreationDate) | reverse | .[].Name'
