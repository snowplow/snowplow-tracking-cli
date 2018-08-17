//
// Copyright (c) 2016 Snowplow Analytics Ltd. All rights reserved.
//
// This program is licensed to you under the Apache License Version 2.0,
// and you may not use this file except in compliance with the Apache License Version 2.0.
// You may obtain a copy of the Apache License Version 2.0 at http://www.apache.org/licenses/LICENSE-2.0.
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the Apache License Version 2.0 is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the Apache License Version 2.0 for the specific language governing permissions and limitations there under.
//

package main

import (
  "testing"
  "github.com/stretchr/testify/assert"
  "github.com/jarcoal/httpmock"
  "net/http"
  gt "gopkg.in/snowplow/snowplow-golang-tracker.v1/tracker"
)

// --- CLI

func TestGetSdJson(t *testing.T) {
  assert := assert.New(t)

  sdj, err := getSdJson("", "", "")
  assert.Nil(sdj)
  assert.NotNil(err)
  assert.Equal("FATAL: A --sdjson or a --schema URI plus a --json needs to be specified.", err.Error())

  sdj, err = getSdJson("", "iglu:com.acme/event/jsonschema/1-0-0", "")
  assert.Nil(sdj)
  assert.NotNil(err)
  assert.Equal("FATAL: A --json needs to be specified.", err.Error())

  sdj, err = getSdJson("", "", "{\"e\":\"pv\"}")
  assert.Nil(sdj)
  assert.NotNil(err)
  assert.Equal("FATAL: A --schema URI needs to be specified.", err.Error())

  sdj, err = getSdJson("", "iglu:com.acme/event/jsonschema/1-0-0", "{\"e\":\"pv\"}")
  assert.Nil(err)
  assert.NotNil(sdj)
  assert.Equal("{\"data\":{\"e\":\"pv\"},\"schema\":\"iglu:com.acme/event/jsonschema/1-0-0\"}", sdj.String())

  sdj, err = getSdJson("", "iglu:com.acme/event/jsonschema/1-0-0", "{\"e\"}")
  assert.NotNil(err)
  assert.Nil(sdj)
  assert.Equal("invalid character '}' after object key", err.Error())

  sdj, err = getSdJson("{\"data\":{\"e\":\"pv\"},\"schema\":\"iglu:com.acme/event/jsonschema/1-0-0\"}", "", "")
  assert.Nil(err)
  assert.NotNil(sdj)
  assert.Equal("{\"data\":{\"e\":\"pv\"},\"schema\":\"iglu:com.acme/event/jsonschema/1-0-0\"}", sdj.String())

  sdj, err = getSdJson("{\"data\":{\"e\"},\"schema\":\"iglu:com.acme/event/jsonschema/1-0-0\"}", "", "")
  assert.NotNil(err)
  assert.Nil(sdj)
  assert.Equal("invalid character '}' after object key", err.Error())
}

// --- Tracker

func TestInitTracker(t *testing.T) {
  assert := assert.New(t)
  trackerChan := make(chan int, 1)

  tracker := initTracker("com.acme", "myapp", "POST", "/tmp/test-1.db", trackerChan)
  assert.NotNil(tracker)
  assert.NotNil(tracker.Emitter)
  assert.NotNil(tracker.Subject)
  assert.Equal("myapp", tracker.AppId)
}

func TestTrackSelfDescribingEventGood(t *testing.T) {
  assert := assert.New(t)

  // Setup HTTPMock
  httpmock.Activate()
  defer httpmock.DeactivateAndReset()
  requests := []*http.Request{}
  httpmock.RegisterResponder(
    "GET",
    "http://com.acme/i",
    func(req *http.Request) (*http.Response, error) {
      requests = append(requests, req)
      return httpmock.NewStringResponse(200, ""), nil
    },
  )

  // Setup Tracker
  trackerChan := make(chan int, 1)
  tracker := initTracker("com.acme", "myapp", "GET", "/tmp/test-2.db", trackerChan)
  assert.NotNil(tracker)

  // Make SDJ
  schemaStr := "iglu:com.acme/event/jsonschema/1-0-0"
  jsonDataMap, _ := stringToMap("{\"hello\":\"world\"}")
  sdj := gt.InitSelfDescribingJson(schemaStr, jsonDataMap)

  // Send an event
  statusCode := trackSelfDescribingEvent(tracker, trackerChan, sdj)
  assert.Equal(200, statusCode)
  assert.Equal(1, len(requests))
}

func TestTrackSelfDescribingEventBad(t *testing.T) {
  assert := assert.New(t)

  // Setup HTTPMock
  httpmock.Activate()
  defer httpmock.DeactivateAndReset()
  requests := []*http.Request{}
  httpmock.RegisterResponder(
    "POST",
    "http://com.acme/com.snowplowanalytics.snowplow/tp2",
    func(req *http.Request) (*http.Response, error) {
      requests = append(requests, req)
      return httpmock.NewStringResponse(404, ""), nil
    },
  )

  // Setup Tracker
  trackerChan := make(chan int, 1)
  tracker := initTracker("com.acme", "myapp", "POST", "/tmp/test-3.db", trackerChan)
  assert.NotNil(tracker)

  // Make SDJ
  schemaStr := "iglu:com.acme/event/jsonschema/1-0-0"
  jsonDataMap, _ := stringToMap("{\"hello\":\"world\"}")
  sdj := gt.InitSelfDescribingJson(schemaStr, jsonDataMap)

  // Send an event
  statusCode := trackSelfDescribingEvent(tracker, trackerChan, sdj)
  assert.Equal(404, statusCode)
  assert.Equal(1, len(requests))
}

// --- Utilities

func TestParseStatusCode(t *testing.T) {
  assert := assert.New(t)

  result := parseStatusCode(200)
  assert.Equal(0, result)
  result = parseStatusCode(300)
  assert.Equal(0, result)
  result = parseStatusCode(404)
  assert.Equal(4, result)
  result = parseStatusCode(501)
  assert.Equal(5, result)
  result = parseStatusCode(600)
  assert.Equal(1, result)
}

func TestStringToMap(t *testing.T) {
  assert := assert.New(t)

  m, err := stringToMap("{\"hello\":\"world\"}")
  assert.Nil(err)
  assert.NotNil(m)
  assert.Equal("world", m["hello"])
  assert.Equal(1, len(m))

  m, err = stringToMap("{\"hello\"}")
  assert.NotNil(err)
  assert.Nil(m)
}
