# ph.sh

## Shell commands for Philips Hue
Copyright © 2017 Erik Baauw. All rights reserved.

This `bash` script provides basic shell commands for interacting with a [Philips Hue](http://www2.meethue.com/) bridge, using the Philips Hue [API](https://developers.meethue.com/philips-hue-api).  These shell commands can be used to interact manually with the bridge, instead of the CLIP API debugger (see [Getting Started](https://developers.meethue.com/documentation/getting-started)).  They can also be used in other scripts to (re-)create your entire bridge configuration.

These shell commands might also be used for interacting with other bridges or gateways that provide a compatible API.  In particular, they work for with the dresden elektronik [deCONZ REST API](http://dresden-elektronik.github.io/deconz-rest-doc/) (except where noted).

### Commands
The following commands are provided by `ph.sh`:

Command | Description
-------- | -----------
`ph_host` [_host_[`:`_port_]] | Get or set the hostname or IP address (and port) of the bridge/gateway to use.  Without argument, the current host is written to the standard output.  With argument, the host is probed to check whether it's a valid bridge/gateway. <br>Set `ph_verbose=true` to get a message on the standard error with type and version of the bridge/gateway. <br>**Note:** You need to run this command before using any of the other commands.
`ph_get` _path_ | Retrieves _path_ from the bridge. <br>Resources as well as resource attributes can be specified as _path_. <br>The formatted response is written to the standard output.
`ph_put` _resource_ _body_ | Updates _resource_ on the bridge.
`ph_patch` _resource_ _body_ | Updates _resource_ on the bridge. <br>Not supported by Philips Hue bridges.
`ph_post` _resource_ _body_ | Creates _resource_ on the bridge. <br>The ID of the resource created is written to the standard output.
`ph_delete` _resource_ | Deletes _resource_ from the bridge.
`ph_linkbutton` | Simulates pressing the link button on the bridge, to allow an application to register. <br>Not currently supported by deCONZ gateways.
`ph_createuser` | Register `ph.sh` on the bridge. <br>The username created by the bridge is written to the standard output.
`ph_touchlink` | Initiate a touchlink on the bridge. <br>Not currently supported by deCONZ bridges.
`ph_reset_homekit` | Reset the HomeKit configuration for a v2 (square) Philips Hue bridge.
`ph_restart` | Restart the deCONZ gateway.
`ph_findhost` | Set the host (and port) of the bridge/gateway to use to the first bridge/gateway found on the localhost, the meethue portal, or the dresden elektronik portal. <br>The host is written to the standard output.
`ph_nupnp` | Query the meethue portal for registered Philips Hue bridges. <br>The formatted response is written to the standard output.
`ph_nupnp_deconz`| Query the dresden elektronik portal for registered deCONZ bridges. <br>The formatted response is written to the standard output.
`ph_description` | Retrieve the bridge device description in XML.
`ph_config` | Retrieve the bridge configuration using an unauthorised request. <br>The formatted response is written to the standard output.
`ph_light_values` _light_ | Discover range of values for `ct` and `xy` supported by _light_. <br>Note that this might take several minutes.  Set `ph_verbose=true` to see progress messages on standard error. <br>The formatted response is written to the standard output.

These commands depend on `curl`, to send HTTP requests to the bridge, and on `json`, to format the bridge responses into human readable or machine readable output.  A `bash` implementation of `json` is provided by `json.sh`.  See `json -h` for its usage.

### Configuration
The following shell variables are used by `ph.sh`:

Variable | Default | Description
-------- | -------| -----------
`ph_host` | -- | Deprecated. <br>Use the `ph_host` command to set the host (and port) of the bridge/gateway.
`ph_username` | _empty_ | The username on the bridge used to authenticate requests. <br>You can create a username using `ph_createuser`.
`ph_json_args` | _empty_ | Arguments to pass to `json` when formatting the output of `ph_get`, `ph_nupnp`, or `ph_nupnp_deconz`.
`ph_verbose` | `false` | When set to `true`, issue info messages to standard error.
`ph_debug` | `false` | When set to `true`, issue debug messages to standard error for requests sent to and responses received from the bridge/gateway, the meethue portal, and the deCONZ portal.

### Installation
To install, take the following steps:
- Copy `ph.sh` and `json.sh` to a directory in your `$PATH`, e.g. `~/bin` or `/usr/local/bin`;
- Load the commands by issuing `. ph.sh` from the command line;
- Run `ph_findhost` from the command line to find your bridge/gateway.  Alternatively run `ph_host` to set manually the hostname or IP address (and port) of the bridge/gateway to use;
- Create a username by issuing `ph_createuser` from the command line;
- Include the following lines in your `.bashrc`:
```sh
. ph.sh
ph_findhost
ph_username=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Caveats
I'm running `ph.sh` on my Apple Mac computers and on my Raspberry Pi, but it should work on any recent Linux or Unix system with `bash`.

While functional, the `bash` implementation of `json` is not very efficient, especially for large JSON responses.  Formatting the full bridge state for `ph_get /` takes 1m24s on my RaspPi (and 23s on my Mac).  When I use a binary implementation of `json` instead, it takes less than 2s on my Mac.  However, I've written this implementation in Swift, and I haven't ported it to other platforms.  I should probably have created a NodeJS implementation...

### Examples
Here are some examples how to use interactively the commands provided by `ph.sh`:

- Find the bridge/gateway:
  ```bash
  ph_findhost
  ```
  Set `ph_verbose` to `true` to see the progress on the standard error:
  ```bash
  ph_verbose=true ph_findhost
  ```
  ```
  ph.sh: probing localhost ... no bridge/gateway found
  ph.sh: contacting meethue portal ...
  ph.sh: probing 192.168.xxx.xxx ... ok
  192.168.xxx.xxx: BSB002 bridge v1707040932, api v1.20.0
  ```
- Check which bridge/gateway was found:
  ```bash
  ph_host
  ```
  The output is the IP address of the bridge/gateway:
  ```json
  "192.168.xxx.xxx"
  ```
- Create a username and store it in the `ph_username` variable:
  ```bash
  ph_username=$(ph_createuser)
  ```
- Switch off all lights:
  ```bash
  ph_put /groups/0/action '{"on":false}'
  ```
- Check whether light `1` is on:
  ```bash
  ph_get /lights/1/state/on
  ```
  The output is the value of the `state.on` attribute:
  ```json
  false
  ```
  Note that the Hue API doesn't allow a `GET` on `/lights/1/state/on`.  Internally, `ph_get` does the equivalent of:
  ```bash
  ph_get /lights/1 | json -p /state/on
  ```
- Get the state of light `1`:
  ```bash
  ph_get /lights/1/state
  ```
  The output is formatted for human readability:
  ```json
  {
    "on": false,
    "bri": 254,
    "hue": 13195,
    "sat": 210,
    "effect": "none",
    "xy": [
      0.5106,
      0.415
    ],
    "ct": 463,
    "alert": "none",
    "colormode": "xy",
    "reachable": true
  }
  ```
- Create a group:
  ```bash
  ph_post /groups '{"name": "My Group", "lights": ["1", "2", "3"]}'
  ```
  The output is the id of the newly created group:
  ```json
  2
  ```
  Delete the group we just created:
  ```bash
  ph_delete /groups/2
  ```
- Analyse a light:
  ```bash
  ph_light_values 1
  ```
  The output contains the result:
  ```json
  {
    "manufacturer": "Philips",
    "modelid": "LCT003",
    "type": "Extended color light",
    "bri": true,
    "ct": {
      "min": 153,
      "max": 500
    },
    "xy": {
      "r": [
        0.675,
        0.322
      ],
      "g": [
        0.409,
        0.518
      ],
      "b": [
        0.167,
        0.04
      ]
    }
  }
  ```

### Advanced Examples
Here are some examples how to use the commands provided by `ph.sh` in scripting:

- Use `json -al` to get text output, for further processing with with the likes of `grep` and `cut`:
  ```bash
  ph_get /lights/1/state | json -al
  ```
  This outputs:
  ```bash
  /on:false
  /bri:254
  /hue:13195
  /sat:210
  /effect:"none"
  /xy/0:0.5106
  /xy/1:0.415
  /ct:463
  /alert:"none"
  /colormode:"xy"
  /reachable:true
  ```
  However `ph_get` already runs `json` to format the bridge output.  It's more efficient to pass the `-al` trough `ph_get` and only run `json` once:
  ```bash
  ph_json_args=-al ph_get /lights/1/state
  ```
- Check for non-reachable lights
  ```bash
  ph_json_args=-al ph_get /lights | grep /reachable:false | cut -d / -f 2
  ```
  The output contains the ids of the lights for which the `state.reachable` attribute is `false`:
  ```json
  11
  36
  ```
  To see the names of these lights rather than their numbers, use:
  ```bash
  for light in $(ph_json_args=-al ph_get /lights | grep /reachable:false | cut -d / -f 2) ; do
    ph_get /lights/${light}/name
  done
  ```
- Delete the rules created by the Philips Hue app:
  ```bash
  for user in $(ph_json_args=-al ph_get /config/whitelist | grep /name:\"hue_ios_app# | cut -d / -f 2) ; do
    for rule in $(ph_json_args=-al ph_get /rules | grep "/owner:\"${user}\"" | cut -d / -f 2) ; do
      ph_delete "/rules/${rule}"
    done
  done
  ```
