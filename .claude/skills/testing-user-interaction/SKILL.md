---
name: testing-user-interaction
description: Use when testing click, input, and form interactions in lamdera/program-test
---

# User Interaction Testing in lamdera/program-test

## Required Import

```elm
import Effect.Browser.Dom as Dom
```

## Clicking Elements

```elm
-- Signature: click : Int -> HtmlId -> Action
actions.click 100 (Dom.id "my-button-id")
```

**Element must have `Attr.id`:**
```elm
Html.button
    [ Attr.id "submit-form"  -- Required for click
    , Events.onClick SubmitForm
    ]
    [ Html.text "Submit" ]
```

## Entering Text

```elm
-- Signature: input : Int -> HtmlId -> String -> Action
actions.input 100 (Dom.id "email-input") "user@example.com"
```

**Element must have `Attr.id`:**
```elm
Html.input
    [ Attr.id "email-input"  -- Required for input
    , Attr.type_ "email"
    , Attr.value model.email
    , Events.onInput EmailChanged
    ]
    []
```

## Complete Form Example

```elm
(\actions ->
    [ -- Open modal
      actions.click 100 (Dom.id "open-modal-btn")

    -- Fill form
    , actions.input 100 (Dom.id "name-input") "My Calendar"

    -- Submit
    , actions.click 100 (Dom.id "submit-btn")

    -- Verify result
    , actions.checkView 200
        (Test.Html.Query.has [ Test.Html.Selector.text "My Calendar" ])
    ]
)
```

## id vs data-testid

| Attribute | Used For | Example |
|-----------|----------|---------|
| `Attr.id` | click, input actions | `actions.click 100 (Dom.id "btn")` |
| `data-testid` | checkView selectors | `Test.Html.Selector.attribute (...)` |

**When you need both:**
```elm
Html.button
    [ Attr.id "delete-calendar-123"              -- For click
    , Attr.attribute "data-testid" "delete-123"  -- For checkView
    , Events.onClick (DeleteCalendar id)
    ]
    [ Html.text "Delete" ]
```

## Common Mistake

**Wrong** (uses string instead of HtmlId):
```elm
actions.click 100 "my-button"  -- Type error!
```

**Correct:**
```elm
actions.click 100 (Dom.id "my-button")
```
