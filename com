#!/bin/sh
# $1 = number
# $2 = operator 
# $3 = number
# $1 or increase or decrease while $3 will remain the same
set -e # exit 1 if any error
ceil() {
  # ceiling $1, compare to $2; return 1 if not the same
  [ -z "${1##*.*}" -o ! -z "${2##*.*}" ] && {
    [ ! -z "${1##*.*}" -a ! -z "${2##*.*}" -a "$1" -eq "$2" ] 2>/dev/null && return 0
    set -- "${1%.*}" "${2%.*}"
    set -- "$(($1+1))" "$2"
    [ "$1" -eq "$2" ] 2>/dev/null && {
      return 0
    } || return 1
  } || return 1
} # ceiling
floor() {
  # floor $1. compare to $2; return 1 if not the same
  [ -z "${1##*.*}" -o ! -z "${2##*.*}" ] && {
    [ ! -z "${1##*.*}" -a ! -z "${2##*.*}" -a "$1" -eq "$2" ] 2>/dev/null && return 0
    set -- "${1%.*}" "${2%.*}"
    [ "$1" -eq "$2" ] 2>/dev/null && {
      return 0
    } || return 1
  } || return 1
} # floor
gt() {
  w1="${1%.*}"; w2="${2%.*}"
  d1="${1#*.}"; d2="${2#*.}"
  [ "$w1" -gt "$w2" ] && exit 0 # if whole number is greator no need to compare decimals
  # now compare $d1 to $d2
  # 0.10 > 0.01
  # 100 > 1
  until [ "${d1#0}" = "${d1}" ]; do
    d1="${d1#0}"; d2="${d2}0"
  done
  until [ "${d2#0}" = "${d2}" ]; do 
    d2="${d2#0}"; d1="${d1}0"
  done
  [ "$3" ] && {
    [ "${d1:-0}" -gt "${d2:-0}" -o "${d1:-0}" -eq "${d2:-0}" -a "${w1:-0}" -eq "${w2:-0}" ] && {
      return 0
    } || return 1
  } || {
    [ "${d1:-0}" -gt "${d2:-0}" ] && { 
      return 0
    } || return 1
  } # or equal to (-ge)
} # test if $1 is > $2
lt() { 
  w1="${1%.*}"; w2="${2%.*}"
  d1="${1#*.}"; d2="${2#*.}"
  [ "$w1" -lt "$w2" ] && exit 0
  until [ "${d1#0}" = "${d1}" ]; do
    d1="${d1#0}"; d2="${d2}0"
  done
  until [ "${d2#0}" = "${d2}" ]; do
    d2="${d2#0}"; d1="${d1}0"
  done
  [ "$3" ] && {
    [ "${d1:-0}" -lt "${d2:-0}" -o "${d1:-0}" -eq "${d2:-0}" -a "${w1:-0}" -eq "${w2:-0}" ] && {
      return 0
    } || return 1
  } || {
    [ "${d1:-0}" -lt "${d2:-0}" ] && {
      return 0
    } || return 1
  }
} # test if $1 is < $2
eq() { # use $3 for -ne
  w1="${1%.*}"; w2="${2%.*}"
  d1="${1#*.}"; d2="${2#*.}"
  until [ "${d1#0}" = "${d1}" ]; do
    d1="${d1#0}"; d2="${d2}0"
  done
  until [ "${d2#0}" = "${d2}" ]; do
    d2="${d2#0}"; d1="${d1}0"
  done
  [ "$3" ] && {
    [ "${w1:-0}" -ne "${w2:-0}" -a "${d1:-0}" -ne "${d2:-0}" ] && {
      return 0
    } || return 1
  } || {
    [ "${w1:-0}" -eq "${w2:-0}" -a "${d1:-0}" -eq "${d2:-0}" ] && { 
      return 0
    } || return 1
  }
}
hexit() { # handle exits 
# allow for ! handling
  ecode="$1"
  [ "$FALSE" ] && case "$ecode" in
      0) ecode=1 ;;
      1) ecode=0
    esac
  unset FALSE
  case "$@" in
    *'-a'*) [ "$ecode" -eq 0 ] && {
      args="${@}"; args="${args##*:}"
      ${0} ${args##? $op ? -a }; ecode=$? 
    } || exit $ecode ;;
    # if exit code is != 0 then all other calls for -a don't matter
    # as a single 1 will cause the final result to be 1
    *'-o'*) [ "$ecode" -eq 1 ] && {
      args="${@}"; args="${args##*:}" 
      ${0} ${args##? $op ? -o }; ecode=$?
    } || exit $ecode
    # as above
    ##
    # this could easily cause a runaway loop if one tried to use an excessive amount of -a/-o calls
    # but I don't think thats really worth creating an exception for
  esac
  exit $ecode
}
com() { # this allows for recusion for -a/-o handling
  n1="$1"; op="$2"; n2="$3"
  [ "$1" ] || exit 1
  if [ "$1" = '!' ] && [ "$2" ]; then
    FALSE=0; shift 1
    n1="$1"; op="$2"; n2="$3"
    [ "$1" ] || exit 1
  fi # -a breaks here ??
  [ ! "$3" ] && {
    [ "$FALSE" ] && {
      [ "$2" ] && hexit 0 ":$@"
      hexit 1 ":$@"
    } || {
      [ "$1" ] && hexit 0 ":$@"
      hexit 1 ":$@"
    }
  }
  # [ ! ] causes exit code to swap
  [ ! -z "${n1##*.*}" ] && n1="${n1}.0"
  [ ! -z "${n2##*.*}" ] && n2="${n2}.0"
  case "$op" in
    '^~'|'~^'|'^='|'-cl') ceil "$n1" "$n2" || hexit 1 ":$@";;
    '~'|'≈'|'≅'|'-fl') floor "$n1" "$n2" || hexit 1 ":$@";;
    '>'|'-gt') gt "$n1" "$n2" || hexit 1 ":$@";;
    '<'|'-lt') lt "$n1" "$n2" || hexit 1 ":$@";;
    '-ge'|'>='|'=>') gt "$n1" "$n2" "-" || hexit 1 ":$@";;
    '-le'|'<='|'=<') lt "$n1" "$n2" "-" || hexit 1 ":$@";;
    # or equal to is set via $3
    '-eq'|'=='|'=') eq "$n1" "$n2" || hexit 1 ":$@";;
    '-ne'|'!=='|'!=') eq "$n1" "$n2" "-" || hexit 1 ":$@"
    # -ne uses $3 with -eq
  esac
  hexit 0 ":$@" # exit 0 if done
  echo "$? --"
}
args="$@"; args="${args##[}"; args="${args%%]}"; set -- $args
com "$@"
