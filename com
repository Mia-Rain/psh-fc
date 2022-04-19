#!/bin/sh
# $1 = number
# $2 = operator 
# $3 = number
# $1 or increase or decrease while $3 will remain the same
set -e # exit 1 if any error
ceil() {
  # ceiling $1, compare to $2; return 1 if not the same
  [ -z "${1##*.*}" -o ! -z "${2##*.*}" ] && {
    [ ! -z "${1##*.*}" -a ! -z "${2##*.*}" -a "$1" -eq "$2" ] 2>/dev/null && exit 0
    set -- "${1%.*}" "${2%.*}"
    set -- "$(($1+1))" "$2"
    [ "$1" -eq "$2" ] 2>/dev/null && {
      exit 0
    } || return 1
  } || return 1
} # ceiling
floor() {
  # floor $1. compare to $2; return 1 if not the same
  [ -z "${1##*.*}" -o ! -z "${2##*.*}" ] && {
    [ ! -z "${1##*.*}" -a ! -z "${2##*.*}" -a "$1" -eq "$2" ] 2>/dev/null && exit 0
    set -- "${1%.*}" "${2%.*}"
    set -- "$(($1-1))" "$2"
    [ "$1" -eq "$2" ] 2>/dev/null && {
      exit 0
    } || return 1
  } || return 1
} # floor
gt() {
  : 
} 
n1="$1"; op="$2"; n2="$3"
case "$op" in
  '^~'|'~^'|'^='|'-cl') ceil "$n1" "$n2" || exit 1 ;;
  '~'|'≈'|'≅'|'-fl') floor "$n1" "$n2" || exit 1 ;;
  # '>'|'-gt') gt "$n1" "$n2" || exit 1 # wip
esac
exit 0 # exit 0 if done
