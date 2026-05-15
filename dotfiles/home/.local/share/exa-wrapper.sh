#!/bin/bash

# Source/credit: https://gist.github.com/eggbean/74db77c4f6404dd1f975bd6f048b86f8

## Change following to '0' for output to be like ls and '1' for exa defaults
# Don't list implied . and .. by default with -a
dot=1
# Show human readable file sizes by default
hru=1
# Don't show group column
fgp=0
# Don't show hardlinks column
lnk=0

help() {
    cat << EOF
  Options:
   -a  all
   -A  almost all
   -1  one file per line
   -k  bytes
   -h  human readable file sizes
   -F  classify
   -R  recurse
   -r  reverse
   -d  don't list directory contents
   -G  group directories first *
   -I  ignore [GLOBS]
   -i  show inodes
   -S  sort by file size
   -t  sort by modified time
   -u  sort by accessed time
   -U  sort by created time *
   -X  sort by extension
   -T  tree *
   -L  level [DEPTH] *
   -s  file system blocks
   -g  git status of files *
   -x  list by lines, not columns

    * not used in ls
EOF
    exit
}

[[ "$*" =~ --help ]] && help

exa_opts=()

while getopts ':aAt1lFRrdIiTkLsuUSrghxXG' arg; do
  case $arg in
    a) (( dot == 1 )) && exa_opts+=(-a) || exa_opts+=(-a -a) ;;
    A) exa_opts+=(-a) ;;
    t) exa_opts+=(-s modified); ((++rev)) ;;
    u) exa_opts+=(-us accessed); ((++rev)) ;;
    U) exa_opts+=(-Us created); ((++rev)) ;;
    S) exa_opts+=(-s size); ((++rev)) ;;
    G) exa_opts+=(--group-directories-first) ;;
    r) ((++rev)) ;;
    k) ((--hru)) ;;
    h) ((++hru)) ;;
    g) exa_opts+=(--git) ;;
    s) exa_opts+=(-S) ;;
    X) exa_opts+=(-s extension) ;;
    1|l|F|R|d|I|i|T|L|x) exa_opts+=(-"$arg") ;;
    *) printf "Error: ${0##*/}\n       --help for help\n" >&2; exit 1
       ;;
  esac
done

shift "$((OPTIND - 1))"

(( rev == 1 )) && exa_opts+=(-r)
(( hru <= 0 )) && exa_opts+=(-B)
(( fgp == 0 )) && exa_opts+=(-g)
(( lnk == 0 )) && exa_opts+=(-H)

dir="$@" || dir=.
[[ $(git -C "$dir" rev-parse --is-inside-work-tree) == true ]] 2> /dev/null && exa_opts+=(--git)

exa --color-scale --color=always --icons "${exa_opts[@]}" "$@"
