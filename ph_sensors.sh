#!/bin/bash
#
# ph_sensors.sh
# Copyright © 2017 Erik Baauw. All rights reserved.
#
# Create/configure sensors on the Hue bridge or deCONZ gateway.
# Note: be sure to re-create rules after re-creating sensors.

# ===== SENSOR ID ==============================================================

# To force (re-)creation of sensors with a pre-determined resource id, we create
# dummy sensor resources to fill up all the sensor resource slots.  Before
# creating a CLIP sensor, we delete the dummy sensor for the id we want the CLIP
# sensor to have.
#
# The same approach works for adding ZigBee sensors to the Hue bridge.  Before
# searching for a new sensor, we delete the dummy sensor for the id we want the
# ZigBee sensor to have.
# The Hue motion sensor requires special attention, since it uses three
# resources.  The following steps add a Hue Motion sensor with id xx for the
# ZLLPresence resource, yy for ZLLLightLevel, and zz for ZLLTemperature:
# - ph_sensors_init
# - ph_delete /sensors/zz (temperature)
# - ph_post /sensors
# - reset motion sensor
# - ph_delete /sensors/xx (presence)
# - ph_delete /sensors/yy (lightlevel)
# - ph_post /sensors
#
# For adding ZigBee sensors to deCONZ, it's probably easier just to let deCONZ
# assign sensor resource IDs, shutdown deCONZ and change the sensor IDs in the
# deCONZ database (in ~/.local/share/dresden-elektronik/deCONZ/zll.db).  I use
# sqlitebrowser for that.

# Create dummy sensors.
function ph_sensors_init() {
  local -i id

  # Clear names of existing sensors.
  for id in $(ph_get /sensors | json -al |
              grep /name: | cut -d / -f 2) ; do
    [ "${_ph_model}" != "deCONZ" -a ${id} -eq 1 ] && continue
    ph_put "/sensors/${id}" '{
      "name": "_dummy"
    }'
    ${ph_verbose} && echo "/sensors/${id}: turned to dummy sensor" >&2
  done

  # Create dummy sensors for unused sensor slots.
  while true ; do
    id=$(ph_post /sensors '{
      "name": "_dummy",
      "type": "CLIPGenericFlag",
      "modelid": "_dummy",
      "manufacturername": "_dummy",
      "swversion": "1",
      "uniqueid": "_dummy"
    }' 2>/dev/null)
    [ $? -eq 0 ] || break
    ${ph_verbose} && echo "/sensors/${id}: created dummy sensor" >&2
  done
  ${ph_verbose} && echo "/sensors/${id}: created dummy sensor" >&2

  # Delete existing Hue motion sensor resoucelinks.
  for id in $(ph_get /resourcelinks | json -al |
              grep /classid:10010 | cut -d / -f 2) ; do
    ph_delete /resourcelinks/${id}
    ${ph_verbose} && echo "/resourcelinks/${id}: deleted" >&2
  done
}

# Remove dummy sensors.
function ph_sensors_cleanup() {
  local -i id
  for id in $(ph_get /sensors | json -al |
              grep /name:\"_dummy\" | cut -d / -f 2) ; do
    ph_delete "/sensors/${id}"
    ${ph_verbose} && echo "/sensors/${id}: deleted dummy sensor" >&2
  done
}

# ===== CLIP SENSORS ===========================================================

# Create CLIPGenericFlag sensor.
# Usage: ph_sensor_clip_flag id name [readonly]
function ph_sensor_clip_flag() {
  local id="$(echo "${1}" | cut -d - -f 1)"
  local version=1
  [ -z "${3}" ] || version=0
  ph_delete "/sensors/${id}"
  id=$(ph_post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"CLIPGenericFlag\",
    \"modelid\": \"CLIPGenericFlag\",
    \"manufacturername\": \"homebridge-hue\",
    \"swversion\": \"${version}\",
    \"uniqueid\": \"/sensors/${1}\"
  }")
  ${ph_verbose} && echo "/sensors/${id}: CLIPGenericFlag ${2}" >&2
  echo ${id}
}

# Create CLIPGenericStatus sensor.
# Usage: ph_sensor_clip_status id name [min max]]
function ph_sensor_clip_status() {
  local id="$(echo "${1}" | cut -d - -f 1)"
  ph_delete "/sensors/${1}"
  id=$(ph_post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"CLIPGenericStatus\",
    \"modelid\": \"CLIPGenericStatus\",
    \"manufacturername\": \"homebridge-hue\",
    \"swversion\": \"${3:-0},${4:-2}\",
    \"uniqueid\": \"/sensors/${1}\"
  }")
  ${ph_verbose} && echo "/sensors/${id}: CLIPGenericStatus ${2}" >&2
  echo ${id}
}

# Create CLIPTemperature sensor.
# Usage: ph_sensor_clip_lightlevel id name
function ph_sensor_clip_presence() {
  local id="$(echo "${1}" | cut -d - -f 1)"
  ph_delete "/sensors/${1}"
  id=$(ph_post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"CLIPPresence\",
    \"modelid\": \"CLIPPresence\",
    \"manufacturername\": \"homebridge-hue\",
    \"swversion\": \"0\",
    \"uniqueid\": \"/sensors/${1}\"
  }")
  ${ph_verbose} && echo "/sensors/${id}: CLIPPresence ${2}" >&2
  echo ${id}
}

# Create CLIPTemperature sensor.
# Usage: ph_sensor_clip_lightlevel id name
function ph_sensor_clip_lightlevel() {
  local id="$(echo "${1}" | cut -d - -f 1)"
  ph_delete "/sensors/${1}"
  id=$(ph_post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"CLIPLightLevel\",
    \"modelid\": \"CLIPLightLevel\",
    \"manufacturername\": \"homebridge-hue\",
    \"swversion\": \"0\",
    \"uniqueid\": \"/sensors/${1}\"
  }")
  ${ph_verbose} && echo "/sensors/${id}: CLIPLightLevel ${2}" >&2
  echo ${id}
}

# Create CLIPTemperature sensor.
# Usage: ph_sensor_clip_temperature id name
function ph_sensor_clip_temperature() {
  local id="$(echo "${1}" | cut -d - -f 1)"
  ph_delete "/sensors/${1}"
  id=$(ph_post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"CLIPTemperature\",
    \"modelid\": \"CLIPTemperature\",
    \"manufacturername\": \"homebridge-hue\",
    \"swversion\": \"0\",
    \"uniqueid\": \"/sensors/${1}\"
  }")
  ${ph_verbose} && echo "/sensors/${id}: CLIPTemperature ${2}" >&2
  echo ${id}
}

# Create CLIPHumidity sensor.
# Usage: ph_sensor_clip_humidity id name
function ph_sensor_clip_humidity() {
  local id="$(echo "${1}" | cut -d - -f 1)"
  ph_delete "/sensors/${1}"
  id=$(ph_post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"CLIPHumidity\",
    \"modelid\": \"CLIPHumidity\",
    \"manufacturername\": \"homebridge-hue\",
    \"swversion\": \"0\",
    \"uniqueid\": \"/sensors/${1}\"
  }")
  ${ph_verbose} && echo "/sensors/${id}: CLIPHumidity ${2}" >&2
  echo ${id}
}

# Create CLIPPressure sensor.
# Usage: ph_sensor_clip_pressure id name
function ph_sensor_clip_pressure() {
  local id="$(echo "${1}" | cut -d - -f 1)"
  ph_delete "/sensors/${1}"
  id=$(ph_post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"CLIPPressure\",
    \"modelid\": \"CLIPPressure\",
    \"manufacturername\": \"homebridge-hue\",
    \"swversion\": \"0\",
    \"uniqueid\": \"/sensors/${1}\"
  }")
  ${ph_verbose} && echo "/sensors/${id}: CLIPPressure ${2}" >&2
  echo ${id}
}

# Create CLIPOpenClose sensor.
# Usage: ph_sensor_clip_pressure id name
function ph_sensor_clip_openclose() {
  local id="$(echo "${1}" | cut -d - -f 1)"
  ph_delete "/sensors/${1}"
  id=$(ph_post "/sensors" "{
    \"name\": \"${2}\",
    \"type\": \"CLIPOpenClose\",
    \"modelid\": \"CLIPOpenClose\",
    \"manufacturername\": \"homebridge-hue\",
    \"swversion\": \"0\",
    \"uniqueid\": \"/sensors/${1}\"
  }")
  ${ph_verbose} && echo "/sensors/${id}: CLIPOpenClose ${2}" >&2
  echo ${id}
}

# ===== ZIGBEE SENSORS =========================================================

# Set sensor name.
# Usage: ph_sensor_name id name
function ph_sensor_name() {
  ph_put "/sensors/${1}" "{
    \"name\": \"${2}\"
  }"
  ${ph_verbose} && echo "/sensors/${id}: $(ph_get "/sensors/${1}/type") ${2}" >&2
}

# Set Hue Motion presence sensor name, sensitivity, and resourcelink.
# Hue app v2 expects a resourcelink before it shows Hue Motion status.
# Usage: ph_sensor_presence id name [sensitivity]
function ph_sensor_presence() {
  ph_sensor_name "${1}" "${2}"
  ph_put "/sensors/${1}/config" "{
    \"sensitivity\": ${3:-2}
  }"
  if [ "${_ph_model}" != "deCONZ" ] ; then
    id=$(ph_post /resourcelinks "{
      \"name\": \"${2}\",
      \"type\": \"Link\",
      \"classid\": 10010,
      \"links\": [ \"/sensors/${1}\" ]
    }")
    ${ph_verbose} && echo "/resourcelinks/${id}: ${2}" >&2
  fi
}

# Set Hue Motion lightlevel sensor name and thresholds.
# Usage: ph_sensor_lightlevel id name [tholddark tholdoffset]
function ph_sensor_lightlevel() {
  ph_sensor_name "${1}" "${2}"
  ph_put "/sensors/${1}/config" "{
    \"tholddark\": ${3:-12000},
    \"tholdoffset\": ${4:-4000}
  }"
}
