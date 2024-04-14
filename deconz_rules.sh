#!/bin/bash
#
# deconz_rules.sh
# Copyright © 2017-2024 Erik Baauw. All rights reserved.
#
# Create/configure rules on a deCONZ gateway.
#
# Room Status:
# -2  Wakeup
# -1  Disabled
# 0   No presence
# 1   Presence
# 2   Pending no presence
# 3   Presence in adjacent room
# 4   TV

. deconz.sh
if [ $? -ne 0 ] ; then
  _deconz_error "cannot load deconz.sh"
fi

# Usage: deconz_rule name conditions actions
function deconz_rule() {
  local name="${1}"
  local conditions="${2}"
  local actions="${3}"
  local body="{
    \"name\": \"${name}\",
    \"status\": \"enabled\",
    \"conditions\": ${conditions},
    \"actions\": ${actions}
  }"
  local -i id=$(deconz_unquote $(deconz -t 10 post "/rules" "${body}"))
  if [ ${id} -eq 0 ] ; then
    _deconz_error "cannot create rule \"${name}\""
    json -c "${body}" >&2
    return 1
  fi
  _deconz_info "/rules/${id}: \"${name}\""
}

# Usage: deconz_rules_delete
function deconz_rules_delete() {
  local -i rule
  local rules="$(deconz get -al /rules | grep /name: | cut -d / -f 2)"
  local -i nrules=$(echo ${rules} | wc -w)
  _deconz_info "deleting ${nrules} rules..."
  for rule in ${rules}; do
    deconz delete /rules/${rule}
  done
  deconz_restart
}

# Usage: nrules=$(deconz_rules_count)
function deconz_rules_count() {
  local -i nrules=$(deconz get -al /rules | grep /name: | wc -l)
  echo ${nrules}
}

# ===== Conditions =============================================================

# Usage: condition="$(deconz_condition address [[operator] value | 'dx'])"
function deconz_condition() {
  if [ -z "${3}" ] ; then
    if [ "${2}" == dx ] ; then
      echo "{
        \"address\": \"${1}\",
        \"operator\": \"${2}\"
      }"
    else
      echo "{
        \"address\": \"${1}\",
        \"operator\": \"eq\",
        \"value\": \"${2}\"
      }"
    fi
  else
    echo "{
      \"address\": \"${1}\",
      \"operator\": \"${2}\",
      \"value\": \"${3}\"
    }"
  fi
}

# Usage: condition="$(deconz_condition_sensor id attribute [[operator] value | 'dx'])"
function deconz_condition_sensor() {
  deconz_condition "/sensors/${1}/state/${2}" "${3}" "${4}"
}

# Usage: condition="$(deconz_condition_sensor_config id attribute [[operator] value | 'dx'])"
function deconz_condition_sensor_config() {
  deconz_condition "/sensors/${1}/config/${2}" "${3}" "${4}"
}

# Usage: condition="$(deconz_condition_light id attribute [[operator] value | 'dx'])"
function deconz_condition_light() {
  deconz_condition "/lights/${1}/state/${2}" "${3}" "${4}"
}

# Usage: condition="$(deconz_condition_group id attribute [[operator] value | 'dx'])"
function deconz_condition_group() {
  deconz_condition "/groups/${1}/state/${2}" "${3}" "${4}"
}

# Usage: condition="$(deconz_condition_config attribute [[operator] value | 'dx'])"
function deconz_condition_config() {
  deconz_condition "/config/${1}" "${2}" "${3}"
}

# Usage: condition="$(deconz_condition_dx sensor [attribute])"
function deconz_condition_dx() {
  deconz_condition_sensor "${1}" "${2:-lastupdated}" dx
}

# Usage: condition="$(deconz_condition_ddx sensor [attribute] time)"
function deconz_condition_ddx() {
  if [ -z "${3}" ] ; then
    deconz_condition_sensor "${1}" lastupdated ddx "PT${2}"
  else
    deconz_condition_sensor "${1}" "${2}" ddx "PT${3}"
  fi
}

# Usage: condition="$(deconz_condition_on light [value])"
function deconz_condition_on() {
  deconz_condition_light "${1}" on eq "${2:-true}"
}

# Usage: condition="$(deconz_condition_allon group [value])"
function deconz_condition_allon() {
  deconz_condition_group  "${1}" all_on eq "${2:-true}"
}

# Usage: condition="$(deconz_condition_anyon group [value])"
function deconz_condition_anyon() {
  deconz_condition_group  "${1}" any_on eq "${2:-true}"
}

# Usage: condition="$(deconz_condition_flag sensor [value])"
function deconz_condition_flag() {
  deconz_condition_sensor "${1}" flag eq "${2:-true}"
}

# Usage: condition="$(deconz_condition_presence sensor [value])"
function deconz_condition_presence() {
  deconz_condition_sensor "${1}" presence eq "${2:-true}"
}

# Usage: condition="$(deconz_condition_vibration sensor [value])"
function deconz_condition_vibration() {
  deconz_condition_sensor "${1}" vibration eq "${2:-true}"
}

# Usage: condition="$(deconz_condition_dark sensor [value])"
function deconz_condition_dark() {
  deconz_condition_sensor "${1}" dark eq "${2:-true}"
}

# Usage: condition="$(deconz_condition_daylight sensor [value])"
function deconz_condition_daylight() {
  deconz_condition_sensor "${1}" daylight eq "${2:-true}"
}

# Usage: condition="$(deconz_condition_open sensor [value])"
function deconz_condition_open() {
  deconz_condition_sensor "${1}" open eq "${2:-true}"
}

# Usage: condition="$(deconz_condition_status sensor [op] value)"
function deconz_condition_status() {
  deconz_condition_sensor "${1}" status "${2}" "${3}"
}

# Usage: condition="$(deconz_condition_temperature sensor [op] value)"
function deconz_condition_temperature() {
  deconz_condition_sensor "${1}" temperature "${2}" "${3}"
}

# Usage: condition="$(deconz_condition_humidity sensor [op] value)"
function deconz_condition_humidity() {
  deconz_condition_sensor "${1}" humidity "${2}" "${3}"
}

# Usage: condition="$(deconz_condition_pressure sensor [op] value)"
function deconz_condition_pressure() {
  deconz_condition_sensor "${1}" pressure "${2}" "${3}"
}

# Usage: condition="$(deconz_condition_localtime [op] from to)"
function deconz_condition_localtime() {
  if [ -z "${3}" ] ; then
    deconz_condition_config localtime in "T${1}/T${2}"
  else
    deconz_condition_config localtime "${1}" "T${2}/T${3}"
  fi
}

# Usage: condition="$(deconz_condition_buttonevent sensor value [value])"
function deconz_condition_buttonevent() {
  if [ -z "${3}" ] ; then
    echo $(deconz_condition_sensor "${1}" buttonevent "${2}"),
  else
    echo $(deconz_condition_sensor "${1}" buttonevent gt "${2}"),
    echo $(deconz_condition_sensor "${1}" buttonevent lt "${3}"),
  fi
  deconz_condition_dx "${1}"
}

# ===== Actions ================================================================

# Usage: action="$(deconz_action address [method] [body])"
function deconz_action() {
  if [ -z "${3}" ] ; then
    if [ -z "${2}" -o "${2}" == PUT -o "${2}" == POST ] ; then
      echo "{
        \"address\": \"${1}\",
        \"method\": \"${2:-PUT}\"
      }"
    else
      echo "{
        \"address\": \"${1}\",
        \"method\": \"PUT\",
        \"body\": ${2}
      }"
    fi
  else
    echo "{
      \"address\": \"${1}\",
      \"method\": \"${2}\",
      \"body\": ${3}
    }"
  fi
}

# Usage: action="$(deconz_action_sensor_state id [method] [body])"
function deconz_action_sensor_state() {
  deconz_action "/sensors/${1}/state"  "${2}" "${3}"
}

# Usage: action="$(deconz_action_sensor_config id [method] [body])"
function deconz_action_sensor_config() {
  deconz_action "/sensors/${1}/config" "${2}" "${3}"
}

# Usage: action="$(deconz_action_light_state id [method] [body])"
function deconz_action_light_state() {
  deconz_action "/lights/${1}/state"   "${2}" "${3}"
}

# Usage: action="$(deconz_action_group_action id [method] [body])"
function deconz_action_group_action() {
  deconz_action "/groups/${1}/action"  "${2}" "${3}"
}

# Usage: condition="$(deconz_action_flag sensor [value])"
function deconz_action_flag() {
  deconz_action_sensor_state  "${1}" "{\"flag\": ${2:-true}}"
}

# Usage: action="$(deconz_action_status sensor value)"
function deconz_action_status() {
  deconz_action_sensor_state "${1}" "{\"status\": ${2}}"
}

# Usage: action="$(deconz_action_light_on light [value])"
function deconz_action_light_on() {
  deconz_action_light_state  "${1}" "{\"on\": ${2:-true}}"
}

# Usage: action="$(deconz_action_light_bri light [value])"
function deconz_action_light_bri() {
  deconz_action_light_state  "${1}" "{\"bri\": ${2:-254}}"
}

# Usage: condition="$(deconz_action_blind_open blind [value])"
# function deconz_action_blind_open() {
#   deconz_action_light_state  "${1}" "{\"open\": ${2:-true}}"
# }

# Usage: condition="$(deconz_action_blind_lift blind [value])"
function deconz_action_blind_lift() {
  deconz_action_light_state  "${1}" "{\"lift\": ${2:-100}}"
}

# Usage: condition="$(deconz_action_blind_stop blind)"
function deconz_action_blind_stop() {
  deconz_action_light_state  "${1}" "{\"stop\": true}"
}

# Usage: condition="$(deconz_action_group_on group [value])"
function deconz_action_group_on() {
  deconz_action_group_action  "${1}" "{\"on\": ${2:-true}}"
}

# Usage: action="$(deconz_action_group_alert group [value])"
function deconz_action_group_alert() {
  deconz_action_group_action  "${1}" "{\"alert\": \"${2:-select}\"}"
}

# Usage: action="$(deconz_action_sensor_alert sensor [value])"
function deconz_action_sensor_alert() {
  deconz_action_sensor_config "${1}" "{\"alert\": \"${2:-select}\"}"
}

# Usage: action=$(deconz_action_heatsetpoint sensor value)
function deconz_action_heatsetpoint() {
  deconz_action_sensor_config "${1}" "{\"heatsetpoint\": ${2}}"
}

# Usage: action="$(deconz_action_light_dim group [up|down|stop|wakeup])"
function deconz_action_group_dim() {
  local -i value
  local -i tt
  local -i hb

  case "${2}" in
    up)     value=254  ; tt=30   ;;
    down)   value=-254 ; tt=30   ;;
    stop)   value=0    ; tt=0    ;;
    wakeup) value=254  ; tt=6000 ;;
  esac
  deconz_action_group_action "${1}" "{\"bri_inc\": ${value}, \"transitiontime\": ${tt}}"
}

# Usage: action="$(deconz_action_scene group scene)"
function deconz_action_scene_recall() {
  deconz_action "/groups/${1}/scenes/${2}/recall"
}

# ===== Mirror =================================================================

# deconz_rules_mirror name flag host apikey
function deconz_rules_mirror() {
  local name="${1}"
  local -i flag="${2}"
  local host="${3}"
  local apikey = "${4}"

  deconz_rule "Mirror ${name} Off" "[
    $(deconz_condition_flag ${flag} false)
  ]" "[
    $(deconz_action http://${host}/api/${apikey}/sensors/${flag}/state PUT '{"flag": false}')
  ]"
  deconz_rule "Mirror ${name} On" "[
    $(deconz_condition_flag ${flag})
  ]" "[
    $(deconz_action http://${host}/api/${apikey}/sensors/${flag}/state PUT '{"flag": true}')
  ]"
}

# ===== Boot ===================================================================

# On startup, all CLIP sensors are initialised to 0.  Then the Hue bridge
# updates the built-in Daylight sensor.  We can use this to detect that the
# Hue bridge has booted.  We keep a CLIPGenericFlag sensor (boottime) which is
# set to true when the Daylight sensor changes while boottime is 0.  As we never
# change boottime afterwards, it's state.lastupdated attribute reflects boot
# time.
# Assuming the Hue bridge reboots because power has just been restored after a
# power outage, we'll also set the power restored flag turn off all lights.

# Usage: deconz_rules_boottime boottime [flag] [daylight]
function deconz_rules_boottime() {
  local -i boottime="${1}"
  local -i flag="${2}"
  local -i daylight="${3:-1}"

  if [ -z "${2}" ] ; then
    deconz_rule "Boot Time" "[
      $(deconz_condition_dx ${daylight}),
      $(deconz_condition_flag ${boottime} false)
    ]" "[
      $(deconz_action_flag ${boottime})
    ]"
  else
    deconz_rule "Boot Time" "[
      $(deconz_condition_dx ${daylight}),
      $(deconz_condition_flag ${boottime} false)
    ]" "[
      $(deconz_action_flag ${boottime}),
      $(deconz_action_flag ${flag})
    ]"
  fi
}

# ===== Night and Day ==========================================================

# Usage: deconz_rules_night night [daylight [morning evening]]
function deconz_rules_night() {
  local -i night=${1}
  local -i daylight=${2:-1}
  local morning="${3:-07:00:00}"
  local evening="${4:-23:00:00}"

  deconz_rule "Daylight On" "[
    $(deconz_condition_daylight ${daylight})
  ]" "[
    $(deconz_action_flag ${night} false)
  ]"

  deconz_rule "Night On" "[
    $(deconz_condition_localtime ${evening} ${morning})
  ]" "[
    $(deconz_action_flag ${night})
  ]"
}

# ===== Power Restore ==========================================================

# Usage: deconz_rules_power flag [group]
# Flag is true when power has been restored.
function deconz_rules_power() {
  local -i flag="${1}"
  local -i group="${2:-0}"

  deconz_rule "Power 1/5" "[
    $(deconz_condition_flag ${flag}),
    $(deconz_condition_dx ${flag})
  ]" "[
    $(deconz_action_group_on ${group} false)
  ]"

  deconz_rule "Power 2/5" "[
    $(deconz_condition_flag ${flag}),
    $(deconz_condition_ddx ${flag} "00:00:02")
  ]" "[
    $(deconz_action_group_on ${group} false)
  ]"

  deconz_rule "Power 3/5" "[
    $(deconz_condition_flag ${flag}),
    $(deconz_condition_ddx ${flag} "00:00:04")
  ]" "[
    $(deconz_action_group_on ${group} false)
  ]"

  deconz_rule "Power 4/5" "[
    $(deconz_condition_flag ${flag}),
    $(deconz_condition_ddx ${flag} "00:00:06")
  ]" "[
    $(deconz_action_group_on ${group} false)
  ]"

  deconz_rule "Power 5/5" "[
    $(deconz_condition_flag ${flag}),
    $(deconz_condition_ddx ${flag} "00:00:08")
  ]" "[
    $(deconz_action_group_on ${group} false),
    $(deconz_action_flag ${flag} false)
  ]"
}

# ===== Room Status ============================================================

# For each room, we keep a CLIPGenericFlag sensor (flag), as virtual master
# switch, and a CLIPGenericStatus sensor (status), to store the room state:
#
# status   state                       room  automation
# ======   =========================   ====  ==========
#    -2    wakeup in progress          off   off
#    -1    disabled                    off   off
#     0    no presence                 off   on
#     1    presence                    on    on
#     2    presence in adjacent room   on    on
#     3    pending no presence         on    on
#
# The status is maintained from motion sensors, door sensors, and switches.
# The flag is maintained automatically, from the status, or manually from
# HomeKit where the flag is exposed as switch.  The lights are controlled from
# the flag (in combination with the time of day and lightlevel).

# Usage: deconz_rules room status flag [group]
function deconz_rules_status() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i group=${4}

  deconz_rule "${room} Off" "[
    $(deconz_condition_flag ${flag} false),
    $(deconz_condition_dx ${flag}),
    $(deconz_condition_status ${status} gt 0)
  ]" "[
    $(deconz_action_status ${status} 0)
  ]"

  deconz_rule "${room} Status <1" "[
    $(deconz_condition_status ${status} lt 1),
    $(deconz_condition_dx ${status})
  ]" "[
    $(deconz_action_flag ${flag} false)
  ]"

  deconz_rule "${room} Status >0" "[
    $(deconz_condition_status ${status} gt 0),
    $(deconz_condition_dx ${status})
  ]" "[
    $(deconz_action_flag ${flag})
  ]"

  if [ ! -z "${4}" ] ; then
    deconz_rule "${room} Status 2" "[
      $(deconz_condition_status ${status} 2),
      $(deconz_condition_ddx ${status} "00:00:15")
    ]" "[
      $(deconz_action_status ${status} 1)
    ]"

    deconz_rule "${room} Status 3 (1/3)" "[
      $(deconz_condition_status ${status} 3),
      $(deconz_condition_ddx ${status} "00:04:00"),
      $(deconz_condition_flag ${flag})
    ]" "[
      $(deconz_action_group_alert ${group} breathe)
    ]"

    deconz_rule "${room} Status 3 (2/3)" "[
      $(deconz_condition_status ${status} 3),
      $(deconz_condition_ddx ${status} "00:04:01"),
      $(deconz_condition_flag ${flag})
    ]" "[
      $(deconz_action_group_alert ${group} finish)
    ]"

    deconz_rule "${room} Status 3 (3/3)" "[
      $(deconz_condition_status ${status} 3),
      $(deconz_condition_ddx ${status} "00:05:00")
    ]" "[
      $(deconz_action_status ${status} 0)
    ]"
  fi
}

# Usage: deconz_rules_wakeup room status flag group night scene
function deconz_rules_wakeup() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i group=${4}
  local -i night=${5}
  local scene="${6}"

  deconz_rule "${room} Wakeup 1/3" "[
    $(deconz_condition_status ${status} -2)
  ]" "[
    $(deconz_action_scene_recall ${group} ${scene}),
    $(deconz_action_flag ${night} false)
  ]"

  deconz_rule "${room} Wakeup 2/3" "[
    $(deconz_condition_status ${status} -2),
    $(deconz_condition_ddx ${status} status "00:00:10")
  ]" "[
    $(deconz_action_group_dim ${group} wakeup)
  ]"

  deconz_rule "${room} Wakeup 3/3" "[
    $(deconz_condition_status ${status} -2),
    $(deconz_condition_ddx ${status} status "00:10:10")
  ]" "[
    $(deconz_action_status ${status} 1)
  ]"
}

# ===== Motion Sensors =========================================================

# We use two different patterns for motion sensors:
# - For hallways (where you never sit still), the room status is set to no
#   presence when motion hasn't been detected for 1 minute;
# - For rooms (where you sit still), the room is set to no presence when
#   motion hasn't been detected for 5 minutes, after some-one has left the room.
#   This is detected by a sequence of motion detected in room (status 1), motion
#   detected in adjacent room (status 2), no more motion detected in room within
#   15 seconds (status 3).  A warning is given at 1 minute's notice before the
#   lights are turned off.

# Usage: deconz_rules_motion room status motion [timeout]
function deconz_rules_motion() {
  local room="${1}"
  local -i status=${2}
  local -i motion=${3}
  local timeout=${4}

  if [ -z "${timeout}" ] ; then
    deconz_rule "${room} Motion Clear" "[
      $(deconz_condition_presence ${motion} false),
      $(deconz_condition_dx ${motion} presence),
      $(deconz_condition_status ${status} 2)
    ]" "[
      $(deconz_action_status ${status} 3)
    ]"
    deconz_rule "${room} No Motion" "[
      $(deconz_condition_presence ${motion} false),
      $(deconz_condition_ddx ${motion} presence "00:55:00"),
      $(deconz_condition_status ${status} gt 0),
      $(deconz_condition_status ${status} lt 4)
    ]" "[
      $(deconz_action_status ${status} 3)
    ]"
  else
    deconz_rule "${room} Motion Clear" "[
      $(deconz_condition_presence ${motion} false),
      $(deconz_condition_ddx ${motion} presence ${timeout}),
      $(deconz_condition_status ${status} gt 0),
      $(deconz_condition_status ${status} lt 4)
    ]" "[
      $(deconz_action_status ${status} 0)
    ]"
  fi
  deconz_rule "${room} Motion Detected" "[
    $(deconz_condition_presence ${motion}),
    $(deconz_condition_dx ${motion} presence),
    $(deconz_condition_status ${status} gt -1),
    $(deconz_condition_status ${status} lt 4)
  ]" "[
    $(deconz_action_status ${status} 1)
  ]"
}

# Usage: deconz_rules_motion room status presence motion
function deconz_rules_presence() {
  local room="${1}"
  local -i status=${2}
  local -i presence=${3}
  local -i motion=${4}

  deconz_rule "${room} Motion Detected" "[
    $(deconz_condition_presence ${motion}),
    $(deconz_condition_dx ${motion} presence),
    $(deconz_condition_status ${status} gt -1),
    $(deconz_condition_status ${status} lt 4)
  ]" "[
    $(deconz_action_status ${status} 1)
  ]"

  # ddx condition as workaround for deCONZ DDF bug
  deconz_rule "${room} Presence Clear" "[
    $(deconz_condition_presence ${presence} false),
    $(deconz_condition_presence ${motion} false),
    $(deconz_condition_ddx ${motion} presence "00:00:45"),
    $(deconz_condition_status ${status} gt 0),
    $(deconz_condition_status ${status} lt 4)
  ]" "[
    $(deconz_action_status ${status} 0)
  ]"
}

# Usage: deconz_rules_vibration room status vibration [timeout]
function deconz_rules_vibration() {
  local room="${1}"
  local -i status=${2}
  local -i vibration=${3}
  local timeout=${4}

  deconz_rule "${room} Vibration Detected" "[
    $(deconz_condition_vibration ${vibration}),
    $(deconz_condition_dx ${vibration} vibration),
    $(deconz_condition_status ${status} gt 0),
    $(deconz_condition_status ${status} lt 4)
  ]" "[
    $(deconz_action_status ${status} 1)
  ]"
}

# Usage: deconz_rules_room room status room2 motion
function deconz_rules_leave_room() {
  local room="${1}"
  local -i status=${2}
  local room2="${3}"
  local -i motion=${4}

  deconz_rule "${room} to ${room2}" "[
    $(deconz_condition_presence ${motion}),
    $(deconz_condition_dx ${motion} presence),
    $(deconz_condition_status ${status} 1)
  ]" "[
    $(deconz_action_status ${status} 2)
  ]"
}

# ===== Door Sensors ===========================================================

# Usage: deconz_rules_room room status door [noclose]
function deconz_rules_door() {
  local room="${1}"
  local -i status=${2}
  local -i door=${3}
  local noclose="${4}"

  if [ -z "${noclose}" ] ; then
    deconz_rule "${room} Door Close" "[
      $(deconz_condition_open ${door} false),
      $(deconz_condition_dx ${door} open),
      $(deconz_condition_status ${status} gt -1)
    ]" "[
      $(deconz_action_status ${status} 0)
    ]"
  fi

  deconz_rule "${room} Door Open" "[
    $(deconz_condition_open ${door}),
    $(deconz_condition_dx ${door} open),
    $(deconz_condition_status ${status} gt -1)
  ]" "[
    $(deconz_action_status ${status} 1)
  ]"
}

# ===== Switches ===============================================================

# Usage: deconz_rules_dimmer_onoff room status flag dimmer motion group scene
function deconz_rules_dimmer_onoff() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i dimmer=${4}
  local -i motion=${5}
  local -i group=${6}
  local -i scene=${7}

  deconz_rule "${room} Dimmer Off Press" "[
    $(deconz_condition_buttonevent ${dimmer} 4002)
  ]" "[
    $(deconz_action_status ${status} 0)
  ]"

  # Disable room automation.  Flash motion sensor light as confirmation.
  deconz_rule "${room} Dimmer Off Hold" "[
    $(deconz_condition_buttonevent ${dimmer} 4001)
  ]" "[
    $(deconz_action_sensor_alert ${motion}),
    $(deconz_action_status ${status} -1)
  ]"

  deconz_rule "${room} Dimmer On Press" "[
    $(deconz_condition_buttonevent ${dimmer} 1002)
  ]" "[
    $(deconz_action_status ${status} 1)
  ]"

  # Set default scene.
  deconz_rule "${room} Dimmer On Hold" "[
  $(deconz_condition_buttonevent ${dimmer} 1001)
  ]" "[
    $(deconz_action_scene_recall ${group} ${scene})
  ]"
}

# Usage: deconz_rules_dimmer2_onoff room status flag dimmer group scene
function deconz_rules_dimmer2_onoff() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i dimmer=${4}
  local -i group=${5}
  local -i scene=${6}
  local -i offGroup=${7:-${5}}

  # Set room off after dimmer sends _Off_
  deconz_rule "${room} Dimmer OnOff Press Off" "[
    $(deconz_condition_sensor ${dimmer} buttonevent 1002),
    $(deconz_condition_ddx ${dimmer} buttonevent "00:00:01"),
    $(deconz_condition_allon ${group} false)
  ]" "[
    $(deconz_action_status ${status} 0)
  ]"

  # Set room on after dimmer sends _On_
  deconz_rule "${room} Dimmer OnOff Press On" "[
    $(deconz_condition_sensor ${dimmer} buttonevent 1002),
    $(deconz_condition_ddx ${dimmer} buttonevent "00:00:01"),
    $(deconz_condition_allon ${group})
  ]" "[
    $(deconz_action_status ${status} 1)
  ]"

  # Set group off off.
  deconz_rule "${room} Dimmer OnOff Hold Off" "[
    $(deconz_condition_buttonevent ${dimmer} 1001),
    $(deconz_condition_status ${status} lt 1)
  ]" "[
    $(deconz_action_group_action "${group}" "{\"on\": false}")
  ]"

  # Set default scene.
  deconz_rule "${room} Dimmer OnOff Hold On" "[
    $(deconz_condition_buttonevent ${dimmer} 1001),
    $(deconz_condition_status ${status} gt 0)
  ]" "[
    $(deconz_action_scene_recall ${group} ${scene})
  ]"
}

# Usage: deconz_rules_dimmer2_hue room status flag dimmer group scene
function deconz_rules_dimmer2_hue() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i dimmer=${4}
  local -i group=${5}
  local -i scene=${6}

  deconz_rule "${room} Dimmer Hue Press Off" "[
    $(deconz_condition_buttonevent ${dimmer} 4002),
    $(deconz_condition_status ${status} gt 0)
  ]" "[
    $(deconz_action_status ${status} 0)
  ]"

  deconz_rule "${room} Dimmer Hue Press On" "[
    $(deconz_condition_buttonevent ${dimmer} 4002),
    $(deconz_condition_status ${status} lt 1)
    ]" "[
    $(deconz_action_status ${status} 1)
  ]"

  # Set extended room off.
  deconz_rule "${room} Dimmer Hue Hold Off" "[
    $(deconz_condition_buttonevent ${dimmer} 4001),
    $(deconz_condition_status ${status} lt 1)
  ]" "[
    $(deconz_action_group_action "${group}" "{\"on\": false}")
  ]"

  # Set default scene.
  deconz_rule "${room} Dimmer Hue Hold On" "[
    $(deconz_condition_buttonevent ${dimmer} 4001),
    $(deconz_condition_status ${status} gt 0)
  ]" "[
    $(deconz_action_scene_recall ${group} ${scene})
  ]"
}

# Usage: deconz_rules_switch_toggle room status flag switch
function deconz_rules_switch_toggle() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i switch=${4}

  deconz_rule "${room} Switch On/Off Press (1/2)" "[
    $(deconz_condition_buttonevent ${switch} 1002),
    $(deconz_condition_status ${status} gt 0)
  ]" "[
    $(deconz_action_status ${status} 0)
  ]"

  deconz_rule "${room} Switch On/Off Press (2/2)" "[
    $(deconz_condition_buttonevent ${switch} 1002),
    $(deconz_condition_status ${status} lt 1)
  ]" "[
    $(deconz_action_status ${status} 1)
  ]"
}

# Usage: deconz_rules_switch_foh room status switch group [left|right|both]
function deconz_rules_switch_foh() {
  local room="${1}"
  local -i status=${2}
  local -i switch=${3}
  local -i group=${4}
  case "${5}" in
    "left")  up=1; down=2; name=" Left" ;;
    "right") up=3; down=4; name=" Right" ;;
    "both")  up=5; down=6; name=" Both" ;;
    "")      up=1; down=2; name="" ;;
  esac

  deconz_rule "${room} Switch Up${name} Press" "[
    $(deconz_condition_buttonevent ${switch} ${up}002)
  ]" "[
    $(deconz_action_status ${status} 1)
  ]"

  deconz_rule "${room} Switch Up${name} Hold" "[
    $(deconz_condition_buttonevent ${switch} ${up}001)
  ]" "[
    $(deconz_action_group_on "${group}"),
    $(deconz_action_group_dim "${group}" up)
  ]"

  deconz_rule "${room} Switch Up${name} Release" "[
    $(deconz_condition_buttonevent ${switch} ${up}003)
  ]" "[
    $(deconz_action_group_dim ${group} stop)
  ]"

  deconz_rule "${room} Switch Down${name} Press" "[
    $(deconz_condition_buttonevent ${switch} ${down}002)
  ]" "[
    $(deconz_action_status ${status} 0)
  ]"

  deconz_rule "${room} Switch Down${name} Hold" "[
    $(deconz_condition_buttonevent ${switch} ${down}001)
  ]" "[
    $(deconz_action_group_dim "${group}" down)
  ]"

  deconz_rule "${room} Switch Down${name} Release" "[
    $(deconz_condition_buttonevent ${switch} ${down}003)
  ]" "[
    $(deconz_action_group_dim ${group} stop)
  ]"
}

# Usage: deconz_rules_foh_blind room switch blind [left|right|both]
function deconz_rules_foh_blind() {
  local room="${1}"
  local -i switch=${2}
  local -i blind=${3}
  case "${4}" in
    "left")  up=1; down=2; name=" Left" ;;
    "right") up=3; down=4; name=" Right" ;;
    "both")  up=5; down=6; name=" Both" ;;
    "")      up=1; down=2; name="" ;;
  esac

  deconz_rule "${room} Switch Up${name} Press" "[
    $(deconz_condition_buttonevent ${switch} ${up}000 ${up}003)
  ]" "[
    $(deconz_action_blind_lift ${blind} 0)
  ]"

  deconz_rule "${room} Switch Up${name} Release" "[
    $(deconz_condition_buttonevent ${switch} ${up}003)
  ]" "[
    $(deconz_action_blind_stop ${blind})
  ]"

  deconz_rule "${room} Switch Down${name} Press" "[
    $(deconz_condition_buttonevent ${switch} ${down}000 ${down}003)
  ]" "[
    $(deconz_action_blind_lift ${blind} 100)
  ]"

  deconz_rule "${room} Switch Down${name} Release" "[
    $(deconz_condition_buttonevent ${switch} ${down}003)
  ]" "[
    $(deconz_action_blind_stop ${blind} stop)
  ]"
}

# Usage: deconz_rules_dimmer_updown room dimmer group
function deconz_rules_dimmer_updown() {
  local room="${1}"
  local -i dimmer=${2}
  local -i group=${3}

  deconz_rule "${room} Dimmer Up Press" "[
    $(deconz_condition_buttonevent ${dimmer} 2000)
  ]" "[
    $(deconz_action_group_dim ${group} up)
  ]"

  deconz_rule "${room} Dimmer Up Release" "[
    $(deconz_condition_buttonevent ${dimmer} 2001 2004)
  ]" "[
    $(deconz_action_group_dim ${group} stop)
  ]"

  deconz_rule "${room} Dimmer Down Press" "[
    $(deconz_condition_buttonevent ${dimmer} 3000)
  ]" "[
    $(deconz_action_group_dim ${group} down)
  ]"

  deconz_rule "${room} Dimmer Down Release" "[
    $(deconz_condition_buttonevent ${dimmer} 3001 3004)
  ]" "[
    $(deconz_action_group_dim ${group} stop)
  ]"
}

# ===== Lights =================================================================

# Usage: deconz_rules_light room flag group night default nightmode [lightlevel [tv tvscene]]
function deconz_rules_light() {
  local room="${1}"
  local -i flag=${2}
  local -i group=${3}
  local -i night=${4}
  local default="${5}"
  local nightmode="${6}"
  local -i lightlevel=${7}
  local -i tv=${8}
  local tvscene="${9}"

  deconz_rule "${room} Off" "[
    $(deconz_condition_flag ${flag} false)
  ]" "[
    $(deconz_action_group_on ${group} false)
  ]"

  if [ -z "${7}" ] ; then
    if [ -z "${8}" ] ; then
      deconz_rule "${room} On, Day" "[
        $(deconz_condition_flag ${flag}),
        $(deconz_condition_flag ${night} false)
      ]" "[
        $(deconz_action_scene_recall ${group} ${default})
      ]"

      deconz_rule "${room} On, Night" "[
        $(deconz_condition_flag ${flag}),
        $(deconz_condition_flag ${night})
      ]" "[
        $(deconz_action_scene_recall ${group} ${nightmode})
      ]"
    else
      deconz_rule "${room} On, TV Off, Day" "[
        $(deconz_condition_flag ${flag}),
        $(deconz_condition_flag ${tv} false),
        $(deconz_condition_flag ${night} false)
      ]" "[
        $(deconz_action_scene_recall ${group} ${default})
      ]"

      deconz_rule "${room} On, TV On, Day" "[
        $(deconz_condition_flag ${flag}),
        $(deconz_condition_flag ${tv}),
        $(deconz_condition_flag ${night} false)
      ]" "[
        $(deconz_action_scene_recall ${group} ${tvscene})
      ]"

      deconz_rule "${room} On, TV Off, Night" "[
        $(deconz_condition_flag ${flag}),
        $(deconz_condition_flag ${tv} false),
        $(deconz_condition_flag ${night})
      ]" "[
        $(deconz_action_scene_recall ${group} ${nightmode})
      ]"

      deconz_rule "${room} On, TV On, Night" "[
        $(deconz_condition_flag ${flag}),
        $(deconz_condition_flag ${tv}),
        $(deconz_condition_flag ${night})
      ]" "[
        $(deconz_action_scene_recall ${group} ${tvscene})
      ]"
    fi

    return
  fi

  local type=$(deconz_unquote $(deconz get "/sensors/${lightlevel}/type"))
  if [ "${type}" == "Daylight" ] ; then
    # lightlevel is Daylight sensor on deCONZ gateway
    deconz_rule "${room} On, Not Dark" "[
      $(deconz_condition_flag ${flag}),
      $(deconz_condition_status ${lightlevel} gt 125),
      $(deconz_condition_status ${lightlevel} lt 205)
    ]" "[
      $(deconz_action_group_on ${group} false)
    ]"

    deconz_rule "${room} On, Dark 1, Day" "[
      $(deconz_condition_flag ${flag}),
      $(deconz_condition_status ${lightlevel} lt 125),
      $(deconz_condition_flag ${night} false)
    ]" "[
      $(deconz_action_scene_recall ${group} ${default})
    ]"

    deconz_rule "${room} On, Dark 2, Day" "[
      $(deconz_condition_flag ${flag}),
      $(deconz_condition_status ${lightlevel} gt 205),
      $(deconz_condition_flag ${night} false)
    ]" "[
      $(deconz_action_scene_recall ${group} ${default})
    ]"

    deconz_rule "${room} On, Dark 1, Night" "[
      $(deconz_condition_flag ${flag}),
      $(deconz_condition_status ${lightlevel} lt 125),
      $(deconz_condition_flag ${night})
    ]" "[
      $(deconz_action_scene_recall ${group} ${nightmode})
    ]"

    deconz_rule "${room} On, Dark 2, Night" "[
      $(deconz_condition_flag ${flag}),
      $(deconz_condition_status ${lightlevel} gt 205),
      $(deconz_condition_flag ${night})
    ]" "[
      $(deconz_action_scene_recall ${group} ${nightmode})
    ]"
  else
    # lightlevel is a ZHALightLevel sensor
    deconz_rule "${room} On, Daylight" "[
      $(deconz_condition_flag ${flag}),
      $(deconz_condition_daylight ${lightlevel})
    ]" "[
      $(deconz_action_group_on ${group} false)
    ]"

    if [ -z "${8}" ] ; then
      deconz_rule "${room} On, Dark, Day" "[
        $(deconz_condition_flag ${flag}),
        $(deconz_condition_dark ${lightlevel}),
        $(deconz_condition_flag ${night} false)
      ]" "[
        $(deconz_action_scene_recall ${group} ${default})
      ]"
    else
      deconz_rule "${room} On, TV Off, Dark, Day" "[
        $(deconz_condition_flag ${flag}),
        $(deconz_condition_flag ${tv} false),
        $(deconz_condition_dark ${lightlevel}),
        $(deconz_condition_flag ${night} false)
      ]" "[
        $(deconz_action_scene_recall ${group} ${default})
      ]"

      deconz_rule "${room} On, TV On, Dark, Day" "[
        $(deconz_condition_flag ${flag}),
        $(deconz_condition_flag ${tv}),
        $(deconz_condition_dark ${lightlevel}),
        $(deconz_condition_flag ${night} false)
      ]" "[
        $(deconz_action_scene_recall ${group} ${tvscene})
      ]"

      deconz_rule "${room} On, TV On, Not Daylight, Day" "[
        $(deconz_condition_flag ${flag}),
        $(deconz_condition_flag ${tv}),
        $(deconz_condition_dx ${tv} flag),
        $(deconz_condition_daylight ${lightlevel} false),
        $(deconz_condition_flag ${night} false)
      ]" "[
        $(deconz_action_scene_recall ${group} ${tvscene})
      ]"
    fi

    deconz_rule "${room} On, Dark, Night" "[
      $(deconz_condition_flag ${flag}),
      $(deconz_condition_dark ${lightlevel}),
      $(deconz_condition_flag ${night})
    ]" "[
      $(deconz_action_scene_recall ${group} ${nightmode})
    ]"

    deconz_rule "${room} On, Not Daylight, Night" "[
      $(deconz_condition_flag ${flag}),
      $(deconz_condition_daylight ${lightlevel} false),
      $(deconz_condition_flag ${night}),
      $(deconz_condition_dx ${night} flag)
    ]" "[
      $(deconz_action_scene_recall ${group} ${nightmode})
    ]"
  fi
}

# ===== Fan ====================================================================

# Usage: deconz_rules_fan room flag fan temperature
function deconz_rules_fan() {
  local room="${1}"
  local -i flag=${2}
  local -i fan=${3}
  local -i temperature=${4}

  deconz_rule "${room} Off" "[
    $(deconz_condition_flag ${flag} false)
  ]" "[
    $(deconz_action_light_on ${fan} false)
  ]"

  deconz_rule "${room} Cool" "[
    $(deconz_condition_temperature ${temperature} lt 2250)
  ]" "[
    $(deconz_action_light_on ${fan} false)
  ]"

  deconz_rule "${room} Hot" "[
    $(deconz_condition_flag ${flag}),
    $(deconz_condition_temperature ${temperature} gt 2300)
  ]" "[
    $(deconz_action_light_on ${fan})
  ]"
}

# ===== Curtains ===============================================================

# TODO:
# - Change way of detecting room is too hot because of sun shining into it;
# - Prevent motion sensor from turning on room when curtains close.  Probably
#   need an additional status or flag for that.

# Usage: deconz_rules_curtains room status curtains motion temperature [daylight]
function deconz_rules_curtains() {
  local room="${1}"
  local -i status=${2}
  local -i curtains=${3}
  local -i motion=${4}
  local -i temperature=${5}
  local -i daylight="${6:-1}"

  deconz_rule "${room} Curtains Sunset" "[
    $(deconz_condition_daylight ${daylight} false)
  ]" "[
    $(deconz_action_sensor_config ${motion} '{"on": false}'),
    $(deconz_action_blind_lift ${curtains} 100)
  ]"

  deconz_rule "${room} Curtains Sunrise" "[
    $(deconz_condition_status ${status} gt -1),
    $(deconz_condition_daylight ${daylight}),
    $(deconz_condition_localtime "23:00:00" "13:00:00")
  ]" "[
    $(deconz_action_sensor_config ${motion} '{"on": false}'),
    $(deconz_action_blind_lift ${curtains} 0)
  ]"

  # TODO: change time to lightlevel when sun shines into room
  deconz_rule "${room} Curtains Cool, Daylight" "[
    $(deconz_condition_temperature ${temperature} lt 2250),
    $(deconz_condition_daylight ${daylight}),
    $(deconz_condition_localtime "13:00:00" "23:00:00")
  ]" "[
    $(deconz_action_sensor_config ${motion} '{"on": false}'),
    $(deconz_action_blind_lift ${curtains} 0)
  ]"

  # TODO: change time to lightlevel when sun shines into room
  deconz_rule "${room} Curtains Hot, Daylight" "[
    $(deconz_condition_temperature ${temperature} gt 2300),
    $(deconz_condition_daylight ${daylight}),
    $(deconz_condition_localtime "13:00:00" "23:00:00")
  ]" "[
    $(deconz_action_sensor_config ${motion} '{"on": false}'),
    $(deconz_action_blind_lift ${curtains} 100)
  ]"

  deconz_rule "${room} Curtains Reset Motion" "[
    $(deconz_condition_sensor_config ${motion} on eq false),
    $(deconz_condition_sensor_config ${motion} on ddx "PT00:00:15")
  ]" "[
    $(deconz_action_sensor_config ${motion} '{"on": true}')
  ]"
}

# ===== Thermostat =============================================================

# Usage: deconz_rules_thermo_display room thermostat
function deconz_rules_thermo_display() {
  local room="${1}"
  local -i thermostat=${2}

  deconz_rule "${room} Thermostat Display" "[
    $(deconz_condition_sensor_config ${thermostat} displayflipped false)
  ]" "[
    $(deconz_action_sensor_config ${thermostat} '{"displayflipped": true}')
  ]"
}

# Usage: deconz_rules_thermo_home room thermostat flag [high [low]]
function deconz_rules_thermo_home() {
  local room="${1}"
  local -i thermostat=${2}
  local -i flag=${3}
  local -i high=${4:-2100}
  local -i low=${5:-1500}

  deconz_rule "${room} Away" "[
    $(deconz_condition_flag ${flag} false),
    $(deconz_condition_ddx ${flag} "00:05:00")
  ]" "[
    $(deconz_action_heatsetpoint ${thermostat} ${low})
  ]"

  deconz_rule "${room} Home" "[
    $(deconz_condition_flag ${flag}),
    $(deconz_condition_ddx ${flag} "00:05:00")
  ]" "[
    $(deconz_action_heatsetpoint ${thermostat} ${high})
  ]"
}

# Usage: deconz_rules_thermo_day room thermostat flag status [high [low]]
function deconz_rules_thermo_day() {
  local room="${1}"
  local -i thermostat=${2}
  local -i night=${3}
  local -i status=${4}
  local -i high=${5:-2100}
  local -i low=${6:-1500}

  deconz_rule "${room} Night On" "[
    $(deconz_condition_flag ${night}),
    $(deconz_condition_ddx ${night} "00:05:00")
  ]" "[
    $(deconz_action_heatsetpoint ${thermostat} ${low})
  ]"

  deconz_rule "${room} Wakeup 3/3" "[
    $(deconz_condition_status ${status} -2),
    $(deconz_condition_ddx ${status} status "00:10:00")
  ]" "[
    $(deconz_action_heatsetpoint ${thermostat} ${high})
  ]"
}

# Usage: deconz_rules_thermo_night room thermostat [high [low]]
function deconz_rules_thermo_night() {
  local room="${1}"
  local -i thermostat=${2}
  local -i high=${3:-2100}
  local -i low=${4:-1500}

  deconz_rule "${room} Night On, Week" "[
    $(deconz_condition_config localtime in "W120/T21:00:00/T08:00:00")
  ]" "[
    $(deconz_action_heatsetpoint ${thermostat} ${high})
  ]"

  deconz_rule "${room} Night Off, Week" "[
    $(deconz_condition_config localtime in "W120/T08:00:00/T21:00:00")
  ]" "[
    $(deconz_action_heatsetpoint ${thermostat} ${low})
  ]"

  deconz_rule "${room} Night On, Weekend" "[
    $(deconz_condition_config localtime in "W7/T21:00:00/T09:00:00")
  ]" "[
    $(deconz_action_heatsetpoint ${thermostat} ${high})
  ]"

  deconz_rule "${room} Night Off, Weekend" "[
    $(deconz_condition_config localtime in "W7/T09:00:00/T21:00:00")
  ]" "[
    $(deconz_action_heatsetpoint ${thermostat} ${low})
  ]"
}
