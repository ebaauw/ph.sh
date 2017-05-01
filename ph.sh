#!/bin/bash
#
# ph.sh
# Copyright © 2017 Erik Baauw. All rights reserved.
#
# Shell library for interacting with a Philips Hue or compatible bridge using
# the Philips Hue or compatible REST API.
# Currently tested on the following bridges:
# - Philips Hue v2 (square) bridge;
# - Philips Hue v1 (round) brudge;
# - dresden elektronik deCONZ REST API plugin.

# ===== CONFIGURATION ==========================================================

# Check whether json command is available, otherwise load json.sh.
json -c 0 >/dev/null 2>&1
[ $? -eq 0 ] || . json.sh

# Set default values.
: ${ph_host:=$(ph_findhost)}
: ${ph_username:=empty}
: ${ph_debug:=false}
: ${ph_sort:=""}

# ===== BASIC FUNCTIONS ========================================================

# Return value for path from Philips Hue bridge on standard output.
# Path can be a full path, e.g. /lights/1/state/on, even when Philips Hue bridge
# only supports GET on resources like /lights/1.
# Usage: body=$(ph_get path)
function ph_get() {
  local resource="${1#/}"
  local path=
  local p="${resource%%/*}"
  local response

  case "${p}" in
    lights|groups|schedules|scenes|sensors|rules|resourcelinks)
      path="${resource#${p}}"
      path="${path#/}"
      resource="${p}"
      p="${path%%/*}"
      if [[ "${p}" == [A-Za-z0-9-]* ]] ; then
        resource="${resource}/${p}"
        path="${path#${p}}"
        path="${path#/}"
      fi
      ;;
    config|capabilities)
      path="${resource#${p}}"
      path="${path#/}"
      resource="${p}"
      ;;
    *)
      ;;
  esac
  response=$(_ph_http GET "/${resource}")
  [ $? -eq 0 ] || return 1
  if [ -z "${path}" ] ; then
    json ${ph_sort} -c "${response}"
    return 0
  fi
  response=$(json ${ph_sort} -c "${response}" -p "${path}")
  if [ -z "${response}" ] ; then
    echo "error: '/${path}' not found in resource '/${resource}'" >&2
    return 1
  fi
  echo "${response}"
}

# Update resource on Philips Hue bridge.
# Usage: ph_put resource body
function ph_put() {
  local response

  response=$(_ph_http PUT "${1}" "${2}")
  [ $? -eq 0 ] || return 1
}

# Update resource on Philips Hue bridge.
# Usage: ph_patch resource body
function ph_patch() {
  local response

  response=$(_ph_http PATCH "${1}" "${2}")
  [ $? -eq 0 ] || return 1
}

# Create resource on the Philips Hue bridge.
# Usage: id=$(ph_post resource body)
function ph_post() {
  local response

  response=$(_ph_http POST "${1}" "${2}")
  [ $? -eq 0 ] || return 1
  ph_unquote "$(json -al -c "${response}" | cut -d : -f 2)"
}

# Delete resource from the Philips Hue Bridge.
# Usage: ph_delete resource
function ph_delete() {
  local response

  response=$(_ph_http DELETE "${1}")
  [ $? -eq 0 ] || return 1
}

# ===== LIGHT STATE ============================================================

# Power-on color temperature.
ph_ct_poweron=366       # 2,732 Kelvin

# Light recipe color temperatures.
ph_ct_relaxed=447       # 2,237 Kelvin
ph_ct_read=346          # 2,890 Kelvin
ph_ct_concentrate=233   # 4,292 Kelvin
ph_ct_energize=156      # 6,410 Kelvin

# ===== BRIDGE FUNCTIONS =======================================================

# Press bridge link button (Philips Hue bridge only).
# Usage: ph_linkbutton
function ph_linkbutton() {
  ph_put /config '{"linkbutton": true}'
}

# Register ph.sh application on the bridge and create a corresponding username.
# Usage ph_username=$(ph_createuser)
function ph_createuser() {
  ph_username= ph_post / "{\"devicetype\":\"ph.sh#$(hostname -s)\"}"
}

# Perform bridge touchlink (Philips Hue bridge only).
# Usage: ph_touchlink
function ph_touchlink() {
  ph_put /config '{"touchlink": true}'
}

# Reset bridge homekit status (Philips Hue v2 (square) bridge only).
# Usage: ph_reset_homekit
function ph_reset_homekit() {
  ph_put /config '{"homekit":{"factoryreset": true}}'
}

# ===== BRIDGE DISCOVERY =======================================================

# Find a bridge.
# Usage: ph_host="$(ph_findhost)"
function ph_findhost() {
  local host
  host=$(ph_unquote "$(ph_nupnp | json -avp /0/internalipaddress)")
  if [ ! -z "${host}" ] ; then
    echo "${host}"
    return 0
  fi
  local response="$(ph_nupnp_deconz)"
  host=$(ph_unquote "$(json -avc "${response}" -p /0/internalipaddress)")
  if [ ! -z "${host}" ] ; then
    local -i port=$(json -avc "${response}" -p /0/internalport)
    [ ${port} -eq 80 ] || host="${host}:${port}"
    echo ${host}
    return 0
  fi
}

# Find Philips Hue bridges through the meethue portal (nupnp method).
# Usage: ph_nupnp
function ph_nupnp() {
  local cmd
  local response

  cmd="curl -s -H \"Content-Type: application/json\""
  cmd="${cmd} \"https://www.meethue.com/api/nupnp\""
  ${ph_debug} && echo "debug: meethue portal command: ${cmd}" >&2
  response=$(eval ${cmd})
  if [ $? -ne 0 ] ; then
    echo "error: meethue portal not found" >&2
    return 1
  fi
  ${ph_debug} && echo "debug: meethue portal response: ${response}" >&2
  json ${ph_sort} -c "${response}"
}

# Find deCONZ bridges through the dresden elektronik portal (nupnp method).
# Usage: ph_nupnp_deconz
function ph_nupnp_deconz() {
  local cmd
  local response

  cmd="curl -s -H \"Content-Type: application/json\""
  cmd="${cmd} \"https://dresden-light.appspot.com/discover\""
  ${ph_debug} && echo "debug: deCONZ portal command: ${cmd}" >&2
  response=$(eval ${cmd})
  if [ $? -ne 0 ] ; then
    echo "error: deCONZ portal not found" >&2
    return 1
  fi
  ${ph_debug} && echo "debug: deCONZ portal response: ${response}" >&2
  json ${ph_sort} -c "${response}"
}

# Show bridge UPnP description.
# Usage: ph_description
function ph_description {
  local cmd
  local response

  cmd="curl -s \"http://${ph_host}/description.xml\""
  ${ph_debug} && echo "debug: hue bridge command: ${cmd}" >&2
  response=$(eval ${cmd})
  if [ $? -ne 0 ] ; then
    echo "error: hue bridge not found" >&2
    return 1
  fi
  ${ph_debug} && echo "debug: hue bridge response: ${response}" >&2
  echo "${response}"
}

# Unauthorised config (Philips Hue bridge only).
# Usage: ph_config
function ph_config() {
  ph_username= ph_get /config
}

# ===== UTILITY FUNCTIONS ======================================================

# Issue a HTTP command to the bridge and return response.
# Note response is returned only when bridge command succeeded.  Otherwise a
# message is printed on standard error and a non-zero status is returned.
# Usage: response=$(ph_http GET|PUT|PATCH|POST|DELETE resource [body])
function _ph_http() {
  local resource
  local method
  local data
  local cmd
  local response
  local responselines
  local errorlines

  # Check parameters
  case "${1}" in
    GET)
      method=
      data=
      ;;
    PUT|PATCH|POST)
      method=" -X ${1}"
      if [ -z "${3}" ] ; then
        data=
      else
        data=$(json -nc "${3}" 2>/dev/null)
        if [[ $? -ne 0 || "${data}" != {*} ]] ; then
          echo "error: invalid body '${3}'" >&2
          return 1
        fi
        data=" -d '${3}'"
      fi
      ;;
    DELETE)
      method=" -X ${1}"
      data=
      ;;
    *)
      echo "error: invalid method '${1}'" >&2
      return 1
      ;;
  esac
  if [[ "${2}" != /* ]] ; then
    echo "error: invalid resource '${2}'" >&2
    return 1
  fi
  if [ "${ph_username}" == empty ] ; then
    echo "error: ph_username not set" >&2
    return 1
  elif [ -z "${ph_username}" ] ; then
    resource="/api${2}"
  else
    resource="/api/${ph_username}${2}"
  fi
  if [ -z "${ph_host}" ] ; then
    echo "error: ph_host not set" >&2
    return 1
  fi

  # Send HTTP request to the Hue bridge.
  cmd="curl -s${method} -H \"Content-Type: application/json\"${data}"
  cmd="${cmd} \"http://${ph_host}${resource}\""
  ${ph_debug} && echo "debug: hue bridge command: ${cmd}" >&2
  response=$(eval ${cmd})
  if [ $? -ne 0 ] ; then
    echo "error: hue bridge '${ph_host}' not found" >&2
    return 1
  fi
  ${ph_debug} && echo "debug: hue bridge response: ${response}" >&2

  # Check response for errors.
  responselines=$(json -al -c "${response}" 2>/dev/null)
  if [ $? -ne 0 -o "${response}" == '[]' ] ; then
    echo "error: invalid method ${1} for resource ${2}" >&2
    return 1
  fi
  errorlines=$(echo "${responselines}" | grep /error/type: | cut -d / -f 2)
  if [ ! -z "${errorlines}" ] ; then
    for i in ${errorlines} ; do
      local -i errno=$(json -avp /${i}/error/type -c "${response}")
      local error=$(json -avp /${i}/error/description -c "${response}")
      error=$(ph_unquote "${error}")
      echo "error: hue bridge error ${errno}: ${error}" >&2
    done
    return 1
  fi

  # Output response.
  echo "${response}"
}

# Return quoted string from string.
# Usage: s=$(ph_quote string)
function ph_quote() {
  [[ "${1}" == '"'*'"' ]] && echo "${1}" || echo "\"${1}\""
}

# Remove quotes from string; return unquoted string from string.
# Usage: s=$(ph_unquote string)
function ph_unquote() {
  [[ "${1}" == '"'*'"' ]] && eval echo "${1}" || echo "${1}"
}
