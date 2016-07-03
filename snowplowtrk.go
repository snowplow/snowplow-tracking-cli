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
  "os"
  "time"
  "errors"
  "encoding/json"
  "github.com/urfave/cli"
  gt "gopkg.in/snowplow/snowplow-golang-tracker.v1/tracker"
)

const (
  APP_VERSION = "0.1.0"
  APP_NAME  = "snowplowtrk"
  APP_USAGE = "Snowplow Analytics Tracking CLI"
  APP_COPYRIGHT = "(c) 2016 Snowplow Analytics, LTD"
)

type SelfDescJson struct {
  Schema string                 `json:"schema"`
  Data   map[string]interface{} `json:"data"`
}

func main() {
  app := cli.NewApp()

  app.Name = APP_NAME
  app.Usage = APP_USAGE
  app.Version = APP_VERSION
  app.Copyright = APP_COPYRIGHT
  app.Compiled = time.Now()
  app.Authors = []cli.Author{
    cli.Author{
      Name:  "Joshua Beemster",
      Email: "support@snowplowanalytics.com",
    },
    cli.Author{
      Name:  "Ronny Yabar",
    },
  }

  // Set CLI Flags
  app.Flags = []cli.Flag{
    cli.StringFlag{
      Name:  "collector, c",
      Usage: "Collector Domain (Required)",
    },
    cli.StringFlag{
      Name:  "appid, id",
      Usage: "Application Id (Optional)",
      Value: APP_NAME,
    },
    cli.StringFlag{
      Name:  "method, m",
      Usage: "Method[POST|GET] (Optional)",
      Value: "GET",
    },
    cli.StringFlag{
      Name:  "sdjson, sdj",
      Usage: "SelfDescribing JSON of the standard form { 'schema': 'iglu:xxx', 'data': { ... } }",
    },
    cli.StringFlag{
      Name:  "schema, s",
      Usage: "Schema URI, of the form iglu:xxx",
    },
    cli.StringFlag{
      Name:  "json, j",
      Usage: "Non-SelfDescribing JSON, of the form { ... }",
    },
    cli.StringFlag{
      Name:  "dbpath, db",
      Usage: "File path where the database should be created, e.g. /home/events.db",
      Value: "events.db",
    },
  }

  // Set CLI Action
  app.Action = func(c *cli.Context) error {
    collector := c.String("collector")
    appid := c.String("appid")
    method := c.String("method")
    sdjson := c.String("sdjson")
    schema := c.String("schema")
    jsonData := c.String("json")
    dbPath := c.String("dbpath")

    // Check that collector domain exists
    if collector == "" {
      return cli.NewExitError("FATAL: A --collector needs to be specified.", 1)
    }

    // Fetch the SelfDescribing JSON
    sdj, err := getSdJson(sdjson, schema, jsonData)
    if err != nil {
      return cli.NewExitError(err.Error(), 1)
    }

    // Create channel to block for events
    trackerChan := make(chan int, 1)

    // Send the event
    tracker := initTracker(collector, appid, method, dbPath, trackerChan)
    statusCode := trackSelfDescribingEvent(tracker, trackerChan, sdj)

    // Parse return code
    returnCode := parseStatusCode(statusCode)
    if returnCode != 0 {
      return cli.NewExitError("ERROR: Event failed to send, check your collector endpoint and try again...", returnCode)
    }
    return nil
  }

  app.Run(os.Args)
}

// --- CLI

// getSdJson takes the three applicable arguments
// and attempts to return a SelfDescribingJson.
func getSdJson(sdjson string, schema string, jsonData string) (*gt.SelfDescribingJson, error) {
  if sdjson == "" && schema == "" && jsonData == "" {
    return nil, errors.New("FATAL: A --sdjson or a --schema URI plus a --json needs to be specified.")
  } else if sdjson != "" {
    // Process SelfDescribingJson String
    res := SelfDescJson{}
    err := json.Unmarshal([]byte(sdjson), &res)
    if err != nil {
      return nil, err
    }
    return gt.InitSelfDescribingJson(res.Schema, res.Data), nil
  } else if schema != "" && jsonData == "" {
    return nil, errors.New("FATAL: A --json needs to be specified.")
  } else if schema == "" && jsonData != "" {
    return nil, errors.New("FATAL: A --schema URI needs to be specified.")
  } else {
    // Process Schema and Json Strings
    jsonDataMap, err := stringToMap(jsonData)
    if err != nil {
      return nil, err
    }
    return gt.InitSelfDescribingJson(schema, jsonDataMap), nil
  }
}

// --- Tracker

// initTracker creates a new Tracker ready for use
// by the application.
func initTracker(collector string, appid string, requestType string, dbPath string, trackerChan chan int) *gt.Tracker {

  // Create callback function
  callback := func(s []gt.CallbackResult, f []gt.CallbackResult) {
    status := 0

    if len(s) == 1 {
      status = s[0].Status
    } else if len(f) == 1 {
      status = f[0].Status
    }

    trackerChan <- status
  }

  // Create Tracker
  emitter := gt.InitEmitter(gt.RequireCollectorUri(collector),
    gt.OptionCallback(callback),
    gt.OptionRequestType(requestType),
    gt.OptionDbName(dbPath),
  )
  subject := gt.InitSubject()
  tracker := gt.InitTracker(
    gt.RequireEmitter(emitter),
    gt.OptionSubject(subject),
    gt.OptionAppId(appid),
  )

  return tracker
}

// trackSelfDescribingEvent will pass an event to
// the tracker for sending.
func trackSelfDescribingEvent(tracker *gt.Tracker, trackerChan chan int, sdj *gt.SelfDescribingJson) int {
  tracker.TrackSelfDescribingEvent(gt.SelfDescribingEvent{
    Event: sdj,
  })
  returnCode := <-trackerChan

  // Ensure that the event is removed
  tracker.Emitter.Storage.DeleteAllEventRows()
  return returnCode
}

// --- Utilities

// parseStatusCode gets the function return code
// based on the HTTP response of the event.
func parseStatusCode(statusCode int) int {
  var returnCode int
  result := statusCode / 100

  switch result {
  case 2, 3:
    returnCode = 0
  case 4:
    returnCode = 4
  case 5:
    returnCode = 5
  default:
    returnCode = 1
  }
  
  return returnCode
}

// stringToMap attempts to convert a string (assumed JSON)
// to a map.
func stringToMap(str string) (map[string]interface{}, error) {
  var jsonDataMap map[string]interface{}
  err := json.Unmarshal([]byte(str), &jsonDataMap)
  if err != nil {
    return nil, err
  } else {
    return jsonDataMap, nil
  }
}
