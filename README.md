# ph.sh

## Shell commands for Philips Hue
Copyright © 2017 Erik Baauw. All rights reserved.

These `bash` scripts provide basic commands for interacting with the [Philips Hue](http://www2.meethue.com/) bridge using the [Philips Hue API](https://developers.meethue.com/philips-hue-api).  These commands can be used to interact manually with your bridge, instead of the CLIP API debugger (see [Getting Started](https://developers.meethue.com/documentation/getting-started)).  They can also be used in scripts to (re-)create your entire Hue bridge configuration (see e.g. [Philips Hue Configuration](http://github.com/ebaauw)).

### Commands
The following commands are provided by `ph.sh`:

Command | Description
-------- | -----------
`ph_get` _path_ | Retrieves _path_ from the bridge.  Resources as well as resource attributes can be specified as _path_.  The formatted response is written to the standard output.
`ph_put` _resource_ _body_ | Updates _resource_ on the bridge.
`ph_post` _resource_ _body_ | Creates _resource_ on the bridge.  The ID of the resource is written to the standard output.
`ph_delete` _resource_ | Deletes _resource_ from the bridge.
`ph_linkbutton` | Simulates pressing the link button on the bridge, to allow an application to create a username.
`ph_createuser` | Create a username for `ph.sh`.  The username is written to the standard output.
`ph_touchlink` | Initiate a touchlink on the Hue bridge.
`ph_reset_homekit` | Reset the HomeKit configuration for a v2 (square) Hue bridge
`ph_nupnp` | Query the meethue portal for registered bridges.  The formatted response is written to the standard output.
`ph_nupnp_deconz` | Query the dresden elektronik portal for registered deCONZ virtual bridges.  The formatted response is written to the standard output.
`ph_description` | Retrieve the bridge device description in XML
`ph_config` | Retrieve the bridge configuration using an unauthorised request.  The formatted response is written to the standard output.

These commands depend on `curl`, to call the Hue bridge, and on `json`, to format the Hue bridge responses into human readable or machine readable output.  A `bash` implementation of `json` is provided by `json.sh`.  See `json -h` for its usage.

### Configuation
The following shell variables are used by `ph.sh`:

Variable | Default | Description
-------- | -------| -----------
`ph_host` | _discovered_ | Hostname or IP address of the Hue bridge.  When not specified, the meethue portal is queried and the first bridge registered is used.
`ph_username` | _empty_ | Username of the Hue bridge.  You can create a username using `ph_createuser`.
`ph_verbose` | `false` | When set to `true`, write the formatted bridge response to standard output for `ph_put`, `ph_post`, and `ph_delete`.
`ph_debug` | `false` | When set to `true`, issue debug messages to standard error for requests sent to and responses received from the Hue bridge.

### Installation
To install, take the following steps:
- Copy `ph.sh` and `json.sh` to a directory in your `$PATH`, e.g. `~/bin` or `/usr/local/bin`;
- Load the commands by issuing `. ph.sh` from the command line;
- Check that your bridge can be reached by issuing `ph_config` from the command line;
- Create a username by issuing `ph_createuser` from the command line;
- Include the following lines in your `.bashrc`:
```sh
ph_username=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
. ph.sh
```

### Caveats
I'm running `ph.sh` on my Apple Mac computers and on my Raspberry Pi, but it should work on any recent Linux or Unix system with `bash`.

While functional, the `bash` implementation of `json` is not very efficient, especially for large JSON responses.  Formatting the full bridge state for `ph_get /` takes 1m24s on my RaspPi (and 23s on my Mac).  When I use a binary implementation of `json` instead, it takes less than 2s on my Mac.  However, I've written this implementation in Swift, and I haven't ported it to other platforms.  I should probably have created a NodeJS implementation...

### Examples
Here are some examples how to use the commands provided by `ph.sh`:

Create a username and store it in the `ph_username` variable:
```
$ ph_username=$(ph_createuser)
```
Switch off all lights:
```
$ ph_put /groups/0/action '{"on":false}'
```
Check whether light `1` is on:
```
$ ph_get /lights/1/state/on
false
```
Note that the Hue API doesn't allow a `get` on `/lights/1/state/on`.  Internally, `ph_get` does the equivalent of:
```
$ ph_get /lights/1 | json -p /state/on
false
```
Check for non-reachable lights, the output contains the ids of the lights for which the `reachable` attribute is `false`:
```
$ ph_get /lights | json -al | grep /reachable:false | cut -f 2 -d /
11
36
```
Start a search for new lights:
```
$ ph_post /lights
Searching for new devices
$ ph_get /lights/new
{
  "lastscan": "active"
}
```
Create a group, the output is the id of the newly created group:
```
$ ph_post /groups '{"name": "My Group", "lights": ["1", "2", "3"]}'
2
```
Delete the group we just created:
```
$ ph_delete /groups/2
```
