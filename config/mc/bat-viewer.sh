#!/bin/sh
exec bat --paging=always --style=numbers --pager="less -R" "$@"
