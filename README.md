[![Build Status][travis-image]][travis] [![Coveralls][coveralls-image]][coveralls] [![Goreport][goreport-image]][goreport] [![Release][release-image]][releases] [![License][license-image]][license]

## Overview

The Snowplow Tracking CLI is a native app to make it easy to send an event to Snowplow from the command line. Use this to embed Snowplow tracking into your shell scripts and terminal sessions.

## Installing

You can download the binary for Linux and Windows directly from Bintray:

* [**Linux 64bit Binary**][linux-binary]
* [**Windows 64bit Binary**][windows-binary]
* [**macOS 64bit Binary**][darwin-binary]

## Usage

The command line interface is as follows:

```bash
snowplowtrk --collector={{COLLECTOR_DOMAIN}} --appid={{APP_ID}} --method=[POST|GET] --sdjson={{SELF_DESC_JSON}}
```
    
or:

```bash
snowplowtrk --collector={{COLLECTOR_DOMAIN}} --appid={{APP_ID}} --method=[POST|GET] --schema={{SCHEMA_URI}} --json={{JSON}}
```

where:

* `--collector` is the domain for your Snowplow collector, e.g. `snowplow-collector.acme.com`
* `--appid` is optional (not sent if not set)
* `--method` is optional. It defaults to `GET`
* `--protocol` is optional. It defaults to `https`
* `--sdjson` is a self-describing JSON of the standard form `{ "schema": "iglu:...", "data": { ... } }`
* `--schema` is a schema URI, most likely of the form `iglu:...`
* `--json` is a (non-self-describing) JSON, of the form `{ ... }`
* `--ipaddress` is optional. It defaults to an empty string

The idea here is that you can either send in a [**self-describing JSON**][sd-json], or pass in the constituent parts (i.e. a regular JSON plus a schema URI) and the Snowplow Tracking CLI will construct the final self-describing JSON for you.

## Examples

```bash
snowplowtrk --collector snowplow-collector.acme.com --appid myappid --method POST --schema iglu:com.snowplowanalytics.snowplow/event/jsonschema/1-0-0 --json "{\"hello\":\"world\"}"
```

```bash
snowplowtrk --collector snowplow-collector.acme.com --appid myappid --method POST --sdjson "{\"schema\":\"iglu:com.snowplowanalytics.snowplow/event/jsonschema/1-0-0\", \"data\":{\"hello\":\"world\"}}"
```

## Under the hood

There is no buffering in the Snowplow Tracking CLI - each event is sent as an individual payload whether `GET` or `POST`.

Under the hood, the app uses the [**Snowplow Golang Tracker**][golang-tracker].

The Snowplow Tracking CLI will exit once the Snowplow collector has responded. The return codes from `snowplowtrk` are as follows:

* 0 if the Snowplow collector responded with an OK status (2xx or 3xx)
* 4 if the Snowplow collector responded with a 4xx status
* 5 if the Snowplow collector responded with a 5xx status
* 1 for any other error

## Building

Add snowplowtrk and its package dependencies to your go src directory:

```
$ go get -v github.com/snowplow/snowplow-tracking-cli
```

Once the get completes, you should find your new `snowplowtrk` executable sitting inside `$GOPATH/bin/`.

To update snowplowtrk dependencies, use `go get` with the `-u` option.

```
$ go get -u -v github.com/snowplow/snowplow-tracking-cli
```

## Copyright and license

The Snowplow Tracking CLI is copyright 2016-2020 Snowplow Analytics Ltd.

Licensed under the **[Apache License, Version 2.0][license]** (the "License");
you may not use this software except in compliance with the License.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

[license]: http://www.apache.org/licenses/LICENSE-2.0

[travis-image]: https://travis-ci.org/snowplow/snowplow-tracking-cli.png?branch=master
[travis]: https://travis-ci.org/snowplow/snowplow-tracking-cli

[release-image]: http://img.shields.io/badge/release-0.4.0-6ad7e5.svg?style=flat
[releases]: https://github.com/snowplow/snowplow-tracking-cli/releases

[license-image]: http://img.shields.io/badge/license-Apache--2-blue.svg?style=flat
[license]: http://www.apache.org/licenses/LICENSE-2.0

[goreport-image]: https://goreportcard.com/badge/github.com/snowplow/snowplow-tracking-cli
[goreport]: https://goreportcard.com/report/github.com/snowplow/snowplow-tracking-cli

[coveralls-image]: https://coveralls.io/repos/github/snowplow/snowplow-tracking-cli/badge.svg?branch=master
[coveralls]: https://coveralls.io/github/snowplow/snowplow-tracking-cli?branch=master

[golang-tracker]: https://github.com/snowplow/snowplow-golang-tracker 
[sd-json]: http://snowplowanalytics.com/blog/2014/05/15/introducing-self-describing-jsons/

[linux-binary]: https://bintray.com/snowplow/snowplow-generic/download_file?file_path=snowplow_tracking_cli_0.4.0_linux_amd64.zip
[windows-binary]: https://bintray.com/snowplow/snowplow-generic/download_file?file_path=snowplow_tracking_cli_0.4.0_windows_amd64.zip
[darwin-binary]: https://bintray.com/snowplow/snowplow-generic/download_file?file_path=snowplow_tracking_cli_0.4.0_darwin_amd64.zip
