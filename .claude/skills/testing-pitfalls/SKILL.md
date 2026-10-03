---
name: testing-pitfalls
description: Use when debugging test failures - covers common mistakes in lamdera/program-test
---

# Common Pitfalls in lamdera/program-test

## Pitfall 1: String Instead of HtmlId

**Wrong:**
```elm
actions.click 100 "my-button"  -- Type error!
```

**Correct:**
```elm
import Effect.Browser.Dom as Dom
actions.click 100 (Dom.id "my-button")
```

## Pitfall 2: Missing id Attribute

**Wrong** (element only has data-testid):
```elm
-- View:
Html.button [ Attr.attribute "data-testid" "submit-btn" ] [ Html.text "Submit" ]

-- Test (fails - can't find element):
actions.click 100 (Dom.id "submit-btn")
```

**Correct:**
```elm
-- View:
Html.button [ Attr.id "submit-btn" ] [ Html.text "Submit" ]

-- Test:
actions.click 100 (Dom.id "submit-btn")
```

## Pitfall 3: `containing` Matches Parents

**Unreliable:**
```elm
Test.Html.Query.find [ Test.Html.Selector.containing [ text "1/2" ] ]
    >> Test.Html.Query.has [ Test.Html.Selector.text "-" ]
```

This can match a parent element containing both "1/2" and "-" in different children.

**Reliable:**
```elm
Test.Html.Query.find
    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-02") ]
    >> Test.Html.Query.has [ Test.Html.Selector.text "-" ]
```

## Pitfall 4: Missing Constructor Imports

**Wrong:**
```elm
import Types exposing (FrontendMsg, BackendMsg)
-- Error: I cannot find a 'MyMsg' type
```

**Correct:**
```elm
import Types exposing (FrontendMsg(..), BackendMsg(..))
```

## Pitfall 5: Wrong Callback Parameter

**Wrong:**
```elm
Effect.Test.connectFrontend ... (\client1 -> ...)
```

**Correct:**
```elm
Effect.Test.connectFrontend ... (\actions -> ...)
```

The parameter is a `FrontendActions` record, not a "client" object.

## Pitfall 6: Insufficient Delays

**Too quick:**
```elm
actions.checkView 10 (...)  -- Might not render yet
```

**Better:**
```elm
actions.checkView 100 (...)  -- Or 200 for complex updates
```

## Pitfall 7: Forgetting clientId

When backend messages need a client reference:

**Wrong:**
```elm
Effect.Test.backendUpdate 100 (GotData (Ok data))
```

**Correct:**
```elm
Effect.Test.backendUpdate 100 (GotData actions.clientId (Ok data))
```

## Pitfall 8: Signature Mismatch

When message signatures change, update test calls:

```elm
-- If signature changed from:
GotData clientId result
-- To:
GotData clientId workspaceId projectId result

-- Update your test:
Effect.Test.backendUpdate 100
    (GotData actions.clientId mockWorkspace.id mockProject.id (Ok data))
```
