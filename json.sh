#!/bin/bash

# json.sh
# Copyright © 2017 Erik Baauw. All rights reserved.

# Bash library process Java Script Object Notation, JSON.
# See http://json.org/ for definition of JSON.

# Parse JSON.
# Usage: json [-njuakvtl] [-p path] [-c string | file]
function json() {
  local -i nlines=0    # Number lines output.
  local value=        # Last value parsed.
  local nvalue=        # Last value parsed w/o white space.

  # Parameters
  local nflag=false
  local jflag=false
  local uflag=false
  local aflag=false
  local kflag=false
  local vflag=false
  local tflag=false
  local lflag=false
  local patharg=
  local stringarg=
  local filearg=

  # Output configuration.
  local nl        # Newline.
  local sp        # Space.
  local o_b       # Object begin.
  local o_e       # Object end.
  local k_b       # Key begin.
  local k_v       # Key/value separator.
  local k_e       # Key end.
  local v_b       # Value begin.
  local echo      # Command for default output.
  local echoj     # Command for key/value output.

  # Print usage message on stderr
  # Usage: _json_usage
  function _json_usage() {
    cat >&2 <<+

Usage: json [-njuakvtl] [-p path] [-c string | file]

By default, json reads JSON from stdin, formats it, and echoes it to stdout.
The following parameters modify this behaviour:
  -n         Do not include spaces nor newlines in output.
  -j         Output JSON array of objects for each key/value pair.
             Each object contains two key/value pairs: key "key" with an array
             of keys as value and key "value" with the value as value.
  -u         Output JSON array of objects for each key/value pair.
             Each object contains one key/value pair: the path (concatenated
             keys separated by '/') as key and the value as value.
  -a         Output path:value in plain text instead of JSON.
  -k         Limit output to keys. With -u output JSON array of paths.
  -v         Limit output to values. With -u output JSON array of values.
  -t         Limit output to top-level key/values.
  -l         Limit output to leaf (non-array, non-object) key/values.
  -p path    Limit output to key/values under path. Set top level below path.
  -c string  Read JSON from string instead of from stdin
  file       Read JSON from file instead of from stdin
+
  }

  # Print error message on stderr.
  # Usage: _json_error message
  function _json_error() {
    echo "json: error: ${1}" >&2
  }

  # Process command line parameters.
  # Usage: _json_params [-njuakvtl] [-p path] [-c string | file]
  function _json_params() {
    local f

    # Parse options.
    unset OPTIND
    while getopts :njuakvtlp:c: f ; do
      case "${f}" in
        n)  nflag=true
            ;;
        j)  jflag=true
            ;;
        u)  uflag=true
            jflag=true
            ;;
        a)  aflag=true
            uflag=true
            jflag=true
            nflag=true
            ;;
        k)  ${vflag} || kflag=true
            jflag=true
            ;;
        v)  ${kflag} || vflag=true
            jflag=true
            ;;
        t)  tflag=true
            jflag=true
            ;;
        l)  lflag=true
            jflag=true
            ;;
        p)  case "${OPTARG}" in
              /*) patharg="${OPTARG:1}"
                  ;;
              *)  patharg="${OPTARG}"
                  ;;
            esac
            ;;
        c)  stringarg="${OPTARG}"
            ;;
        *)  _json_error "invalid option -${OPTARG}"
            _json_usage
            return 1
            ;;
      esac
    done
    shift $((${OPTIND} - 1))
    [ $# -gt 1 ] && _json_usage && return 1
    if [ $# -ge 1 ] ; then
      [ ! -z "${stringarg}" ] && _json_usage && return 1
      [ ! -r "${1}" ] && _json_error "${1}: cannot open" && return 1
      filearg="${1}"
    fi

    # Configure output.
    ${nflag} && nl= || nl=$'\n'
    ${nflag} && sp= || sp=" "
    o_b="${nl}${sp}${sp}{${sp}"
    o_e="${sp}}"
    if ${uflag} ; then
      k_b="\""
      k_e="\""
      v_b=
      k_v="\":${sp}"
      if ${kflag} || ${vflag} ; then
        o_b="${nl}${sp}${sp}"
        o_e=
      fi
    else
      k_b="\"key\":${sp}["
      k_e="]"
      v_b="\"value\":${sp}"
      k_v="],${sp}\"value\":${sp}"
    fi
  }

  # Break up input into tokens.
  # Usage: _json_analyse
  function _json_analyse() {
    local -r spc='[[:space:]]'
    local -r chr='[^[:cntrl:]"\\]'
    local -r esc='\\["\\/bfnrt]|\\u[0-9a-fA-F]{4}'
    local -r str="\"${chr}*(${esc}${chr}*)*\""
    local -r num='-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?'
    local -r wrd='[A-Za-z_][A-Za-z0-9_]*'

    if [ ! -z "${filearg}" ] ; then
      egrep -ao "${spc}|${str}|${num}|${wrd}|." <"${filearg}"
    elif [ ! -z "${stringarg}" ] ; then
      egrep -ao "${spc}|${str}|${num}|${wrd}|." <<<"${stringarg}"
    else
      egrep -ao "${spc}|${str}|${num}|${wrd}|."
    fi | egrep -v "^${spc}$"
  }

  # Parse JSON array.
  # Usage: _json_array path keylist indent depth
  function _json_array () {
    local path="${1}"
    local keylist="${2}"
    local indent="${3}"
    local -i depth=${4}
    local t           # Token.
    local -i n=0      # Number of elements.
    local v="["       # Array's value.
    local nv="["      # Array's value w/o white space.

    read -r t                                                       # matching [
    while [ "${t}" != "]" ] ; do
      if [ ${n} -gt 0 ] ; then
        if [ "${t}" != "," ] ; then                                 # matching [
          _json_error "expected ',' or ']', got '${t}'"
          return 1
        fi
        v="${v},"
        nv="${nv},"
        read -r t
      fi
      _json_value "${t}" "${path:+${path}/}${n}" \
                  "${keylist:+${keylist},${sp}}${n}" \
                  "${indent}${sp}${sp}" \
                  $((${depth} + 1)) || return 1
      v="${v}${nl}${indent}${sp}${sp}${value}"
      nv="${nv}${nvalue}"
      n="n + 1"
      read -r t
    done
    [ ${n} -gt 0 ] && v="${v}${nl}${indent}"
    value="${v}]"
    nvalue="${nv}]"
  }

  # Parse JSON object.
  # Usage: _json_object path keylist indent depth
  function _json_object() {
    local path="${1}"
    local keylist="${2}"
    local indent="${3}"
    local -i depth=${4}
    local t           # Token.
    local -i n=0      # Number of key/value pairs.
    local v="{"       # Object's value.
    local nv="{"      # Object's value w/o white space.
    local k           # Key element.
    local p           # Path element.

    read -r t                                                       # matching {
    while [ "${t}" != "}" ] ; do
      if [ ${n} -eq 0 ] ; then
        if [[ "${t}" != '"'*'"' ]] ; then                           # matching {
          _json_error "expected '\"' or '}', got '${t}'"
          return 1
        fi
      else
        if [ "${t}" != "," ] ; then    # matching {
          _json_error "expected ',' or '}', got '${t}'"
          return 1
        fi
        v="${v},"
        nv="${nv},"
        read -r t
        if [[ "${t}" != '"'*'"' ]] ; then
          _json_error "expected '\"', got '${t}'"
          return 1
        fi
      fi
      k="${t}"
      p="$(eval echo -n ${t})"
      read -r t
      if [ "${t}" != ":" ] ; then
        _json_error "expected ':', got '${t}'"
        return 1
      fi
      read -r t
      _json_value "${t}" "${path:+${path}/}${p}" \
                  "${keylist:+${keylist},${sp}}${k}" \
                  "${indent}${sp}${sp}" \
                  $((${depth} + 1)) || return 1
      v="${v}${nl}${indent}${sp}${sp}${k}:${sp}${value}"
      nv="${nv}${k}:${nvalue}"
      n="n + 1"
      read -r t
    done
    [ ${n} -gt 0 ] && v="${v}${nl}${indent}"
    value="${v}}"
    nvalue="${nv}}"
  }

  # Parse JSON value.
  # Usage: _json_value token path keylist indent depth
  # Precondition: token is (first token of) value
  function _json_value() {
    local t="${1}"    # Token
    local path="${2}"
    local keylist="${3}"
    local indent="${4}"
    local -i depth=${5}
    local isleaf=false
    local saved_patharg=
    local k

    if [ ! -z "${patharg}" -a "${path}" = "${patharg}" ] ; then
      # Set top level for -p path.
      saved_patharg="${patharg}"
      path=
      keylist=
      indent=
      depth=0
      patharg=
    fi
    if [ -z "${patharg}" -a ${depth} -eq 0 ] ; then
      # Top level.
      if ${jflag} ; then
        ${aflag} || echo -n "["
        indent="${sp}${sp}"
      fi
    fi
    case "${t}" in
      '"'*'"'|[0-9-]*|true|false|null)
        isleaf=true
        value="${t}"
        nvalue="${t}"
        ;;
      '{')                                                          # matching }
        _json_object "${path}" "${keylist}" "${indent}" \
              "${depth}" || return 1
        ;;
      '[')                                                          # matching ]
        _json_array "${path}" "${keylist}" "${indent}" \
              "${depth}" || return 1
        ;;
      '"')  read -r t
        _json_error "invalid string '\"${t}'"
        return 1
        ;;
      *)  _json_error "expected value, got '${t}'"
        return 1
        ;;
    esac
    if ${jflag} ; then
      ${uflag} && k="${path}" || k="${keylist}"
      if [[ "${path}" != "${patharg}"* ]] ; then
        # No match for -p path.
        :
      elif ${tflag} && [ ${depth} -ne 1 ] ; then
        # Not top level and -t.
        :
      elif ${lflag} && [ ${isleaf} = false ] ; then
        # Not leaf and -l.
        :
      elif ${aflag} ; then
        # Output line for -a.
        if [ -z "${patharg}" -a ${depth} -eq 0 -a \
              ${isleaf} = false ] ; then
          :
        elif ${kflag} ; then
          [ ! -z "${k}" ] && echo "/${k}"
        elif ${vflag} ; then
          echo "${nvalue}"
        else
          [ -z "${k}" ] && echo "${nvalue}" || \
              echo "/${k}:${nvalue}"
        fi
      else
        # Output line for -j, -u.
        [ ${nlines} -gt 0 ] && echo -n ","
        if ${kflag} ; then
          echo -n "${o_b}${k_b}${k}${k_e}${o_e}"
        elif ${vflag} ; then
          echo -n "${o_b}${v_b}${nvalue}${o_e}"
        else
          echo -n \
          "${o_b}${k_b}${k}${k_v}${nvalue}${o_e}"
        fi
        nlines="nlines + 1"
      fi
    fi
    if [ -z "${patharg}" -a ${depth} -eq 0 ] ; then
      # Top level.
      if ${jflag} ; then
        if ${aflag} ; then
          :
        else
          [ ${nlines} -gt 0 ] && echo
          echo "]"
        fi
      else
        echo "${value}"
      fi
    fi
    if [ ! -z "${saved_patharg}" ] ; then
      # Unset top level for -p path.
      patharg="${saved_patharg}"
    fi
  }

  # Usage: _json_parse
  function _json_parse() {
    local t

    read -r t
    _json_value "${t}" "" "" "" 0 || return 1
    read -r t
    if [ "${t}" != "" ] ; then
      _json_error "expected EOF, got '${t}'"
      return 1
    fi
  }

  _json_params "${@}" || return 1
  _json_analyse | _json_parse
}
