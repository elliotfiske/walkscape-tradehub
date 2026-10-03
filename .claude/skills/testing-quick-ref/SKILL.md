---
name: testing-quick-ref
description: Quick reference for lamdera/program-test - use this first for common testing patterns
---

# lamdera/program-test Quick Reference

## Basic Test Structure

```elm
Effect.Test.start
    "Test description"
    (Effect.Time.millisToPosix 1767225600000)  -- Jan 1, 2026
    config
    [ Effect.Test.connectFrontend
        1000
        (Effect.Lamdera.sessionIdFromString "sessionId0")
        "/"
        { width = 800, height = 600 }
        (\actions ->
            [ -- test actions here
            ]
        )
    ]
```

## Config Record

```elm
config =
    { frontendApp = Frontend.app_
    , backendApp = Backend.app_
    , handleHttpRequest = handleHttpRequest  -- or: always NetworkErrorResponse
    , handlePortToJs = always Nothing
    , handleFileUpload = always Effect.Test.UnhandledFileUpload
    , handleMultipleFilesUpload = always Effect.Test.UnhandledMultiFileUpload
    , domain = safeUrl
    }
```

## Common Actions

```elm
-- Click a button (requires Attr.id on element)
import Effect.Browser.Dom as Dom
actions.click 100 (Dom.id "button-id")

-- Enter text (requires Attr.id on element)
actions.input 100 (Dom.id "input-id") "text value"

-- Check the view (prefer data-testid for assertion-only hooks; an
-- element's existing id works too)
actions.checkView 200
    (Test.Html.Query.find
        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "my-element") ]
        >> Test.Html.Query.has [ Test.Html.Selector.text "expected" ]
    )

-- Trigger backend message directly
Effect.Test.backendUpdate 100
    (MyBackendMsg actions.clientId someData)
```

## Key Rules

1. **click/input** require `Attr.id` on elements (not data-testid) — this
   is a hard Effect.Test requirement, so buttons/inputs must have an `id`
2. **checkView** — prefer a `data-testid` for assertion-only hooks; an
   element's existing `id` is also a valid selector (reuse it rather than
   adding a redundant attribute)
3. **Delays are cumulative** - each action waits relative to previous
4. Use `actions.clientId` when backend messages need a client reference

## More Details

For specific topics, use these skills:
- `/testing-http-mocking` - mocking API requests
- `/testing-user-interaction` - click, input, forms
- `/testing-view-assertions` - checkView, selectors
- `/testing-timing` - delays and timing
- `/testing-pitfalls` - common mistakes
