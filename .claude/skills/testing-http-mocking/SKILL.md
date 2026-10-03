---
name: testing-http-mocking
description: Use when mocking HTTP requests in lamdera/program-test tests
---

# HTTP Request Mocking in lamdera/program-test

## Handler Signature

```elm
handleHttpRequest : { data : Effect.Test.Data FrontendModel BackendModel, currentRequest : HttpRequest } -> HttpResponse
```

## HttpRequest Type

```elm
type alias HttpRequest =
    { requestedBy : RequestedBy  -- RequestedByFrontend ClientId | RequestedByBackend
    , method : String            -- "GET", "POST", "PATCH", etc.
    , url : String               -- Full URL
    , body : HttpBody            -- EmptyBody, StringBody, JsonBody, etc.
    , headers : List ( String, String )
    , sentAt : Time.Posix
    }
```

## HttpResponse Type

```elm
type HttpResponse
    = BadUrlResponse String
    | TimeoutResponse
    | NetworkErrorResponse
    | BadStatusResponse Effect.Http.Metadata String
    | StringHttpResponse Effect.Http.Metadata String
    | JsonHttpResponse Effect.Http.Metadata Json.Encode.Value
    | UnhandledHttpRequest
```

## Creating Response Metadata

```elm
okMetadata : String -> Effect.Http.Metadata
okMetadata url =
    { url = url
    , statusCode = 200
    , statusText = "OK"
    , headers = Dict.empty
    }
```

## Example Handler

```elm
import Dict
import Effect.Http
import Effect.Test exposing (HttpRequest, HttpResponse(..))
import Json.Encode as E

handleHttpRequest : { data : Effect.Test.Data FrontendModel BackendModel, currentRequest : HttpRequest } -> HttpResponse
handleHttpRequest { currentRequest } =
    let
        url = currentRequest.url
    in
    if String.contains "api.example.com/workspaces" url then
        JsonHttpResponse (okMetadata url) (E.list encodeWorkspace [ mockWorkspace ])

    else if String.contains "api.example.com/projects" url then
        JsonHttpResponse (okMetadata url) (E.list encodeProject [ mockProject ])

    else
        NetworkErrorResponse
```

## Triggering HTTP Requests

**Via UI (most realistic):**
```elm
actions.click 100 (Dom.id "connect-button")
actions.checkView 500 (Test.Html.Query.has [ Test.Html.Selector.text "Connected" ])
```

**Via direct message:**
```elm
actions.sendToBackend 100 FetchData
actions.checkView 500 (...)
```

## HTTP Mocking vs backendUpdate

| Approach | Use Case |
|----------|----------|
| `handleHttpRequest` | Full request/response flow, testing HTTP layer |
| `backendUpdate` | Quick setup, bypassing HTTP, testing handlers directly |
