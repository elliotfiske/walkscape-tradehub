module Ui exposing
    ( ButtonSize(..)
    , ButtonStyle(..)
    , Tone(..)
    , backLink
    , bannedTag
    , button
    , buttonStyle
    , callout
    , card
    , coin
    , coinAmount
    , countdown
    , colorChip
    , discordHandle
    , discordIcon
    , empty
    , feedbackThreadUrl
    , formatInt
    , gradeTag
    , itemIcon
    , label
    , lookalikeWarning
    , nameGate
    , pageMessage
    , percentAboveBelow
    , plural
    , portrait
    , previewNote
    , priceText
    , sectionLabel
    , segmented
    , sideBadge
    , signedPercent
    , stat
    , testId
    , textArea
    , textInput
    , timeAgo
    , unverifiedTag
    , valueMeter
    , variantTag
    )

{-| Shared building blocks styled after the Trailpost design.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Item exposing (Item)
import Route exposing (Route)
import Svg
import Svg.Attributes as SA
import Time
import Types exposing (Listing, Payment(..), Side(..))


{-| "1 price", "3 prices".
-}
plural : Int -> String -> String -> String
plural n singular many =
    String.fromInt n
        ++ " "
        ++ (if n == 1 then
                singular

            else
                many
           )


testId : String -> Html.Attribute msg
testId id =
    Attr.attribute "data-testid" id


{-| Elliot's Trailpost feedback thread on the WalkScape Discord.
-}
feedbackThreadUrl : String
feedbackThreadUrl =
    "https://discord.com/channels/1037510064333926402/1556463172691689472"


empty : Html msg
empty =
    Html.text ""


formatInt : Int -> String
formatInt n =
    let
        digits =
            String.fromInt (abs n)

        groups s =
            if String.length s <= 3 then
                [ s ]

            else
                groups (String.dropRight 3 s) ++ [ String.right 3 s ]
    in
    (if n < 0 then
        "−"

     else
        ""
    )
        ++ String.join "," (groups digits)


{-| "+12%", "−8%" or "0%".
-}
signedPercent : Int -> String
signedPercent pct =
    if pct > 0 then
        "+" ++ String.fromInt pct ++ "%"

    else if pct < 0 then
        "−" ++ String.fromInt (abs pct) ++ "%"

    else
        "0%"


{-| "12% above" or "8% below".
-}
percentAboveBelow : Int -> String
percentAboveBelow pct =
    String.fromInt (abs pct)
        ++ "% "
        ++ (if pct >= 0 then
                "above"

            else
                "below"
           )


timeAgo : Time.Posix -> Time.Posix -> String
timeAgo now then_ =
    let
        minutes =
            (Time.posixToMillis now - Time.posixToMillis then_) // 60000
    in
    if minutes < 1 then
        "just now"

    else if minutes < 60 then
        String.fromInt minutes ++ "m ago"

    else if minutes < 60 * 24 then
        String.fromInt (minutes // 60) ++ "h ago"

    else
        String.fromInt (minutes // (60 * 24)) ++ "d ago"


{-| "14:32" until `target`, or "0:00" once it has passed.
-}
countdown : Time.Posix -> Time.Posix -> String
countdown now target =
    let
        seconds =
            max 0 ((Time.posixToMillis target - Time.posixToMillis now + 999) // 1000)

        pad n =
            String.padLeft 2 '0' (String.fromInt n)
    in
    String.fromInt (seconds // 60) ++ ":" ++ pad (modBy 60 seconds)


coin : String -> Html msg
coin size =
    Html.span [ Attr.class ("coin inline-block flex-none rounded-full " ++ size) ] []


coinAmount : Int -> Html msg
coinAmount amount =
    Html.span [ Attr.class "inline-flex items-center gap-1.5" ]
        [ coin "w-3.5 h-3.5"
        , Html.span [ Attr.class "font-bold text-gold" ] [ Html.text (formatInt amount) ]
        ]


{-| "1,150 ea" or "for 4x Iron bar".
-}
priceText : Listing -> Html msg
priceText listing =
    case listing.payment of
        Coins price ->
            Html.span [ Attr.class "inline-flex items-center gap-1.5 whitespace-nowrap" ]
                [ coinAmount price
                , if listing.quantity > 1 then
                    Html.span [ Attr.class "text-faint text-xs" ] [ Html.text "ea" ]

                  else
                    empty
                ]


{-| An item's icon, framed in its rarity/quality colour. Fine items get a
gold sparkle in the corner.
-}
itemIcon : String -> Item -> Item.Variant -> Html msg
itemIcon size item variant =
    Html.div
        [ Attr.class ("relative hatch flex-none grid place-items-center rounded-lg font-mono text-[10px] font-semibold text-muted " ++ size)
        , Attr.style "border" ("1.5px solid " ++ Item.gradeColor item variant)
        ]
        [ Html.img [ Attr.src item.icon, Attr.alt "", Attr.class "pixel w-4/5 h-4/5" ] []
        , if variant.fine then
            Html.span [ Attr.class "absolute -top-1.5 -right-1.5 text-fine text-[13px] leading-none drop-shadow", Attr.title "Fine" ] [ Html.text "✦" ]

          else
            empty
        ]


{-| A small teal "FINE" or red "RARE" tag, or nothing for a regular item. These
are tags on the item, not part of its name.
-}
variantTag : Item.Variant -> Html msg
variantTag variant =
    let
        tag name colors =
            Html.span
                [ Attr.class ("inline-block flex-none align-middle font-bold text-[10px] tracking-widest border rounded px-1.5 py-0.5 leading-none " ++ colors)
                , Attr.title name
                ]
                [ Html.text (String.toUpper name) ]
    in
    if variant.fine then
        tag "Fine" "text-fine border-fine/40"

    else if variant.rare then
        tag "Rare" "text-rareegg border-rareegg/50"

    else
        empty


{-| "FINE MATERIAL", "RARE EGG", "LEGENDARY"… in the grade's colour, with FINE
in teal.
-}
gradeTag : Item -> Item.Variant -> Html msg
gradeTag item variant =
    Html.span [ Attr.class "font-bold text-[10px] tracking-widest uppercase" ]
        [ if variant.fine then
            Html.span [ Attr.class "text-fine mr-1" ] [ Html.text "Fine" ]

          else
            empty
        , Html.span [ Attr.style "color" (Item.gradeColor item variant) ]
            [ Html.text (Item.gradeLabel item { variant | fine = False }) ]
        ]


sideBadge : Listing -> Html msg
sideBadge listing =
    let
        ( text, cls ) =
            case listing.side of
                Selling ->
                    ( "Selling", "bg-sell" )

                Buying ->
                    ( "Buying", "bg-buy" )
    in
    Html.span [ Attr.class ("flex-none font-bold text-[10px] tracking-wider px-1.5 py-0.5 rounded text-white " ++ cls) ]
        [ Html.text text ]


portrait : String -> Html msg
portrait size =
    Html.div [ Attr.class ("hatch flex-none overflow-hidden rounded-lg border border-edge " ++ size) ]
        [ Html.img [ Attr.src "/assets/portrait.svg", Attr.alt "", Attr.class "pixel block w-full h-full object-cover" ] [] ]


{-| Discord's logo (from discord.com/branding), filled with the current text
color. `cls` sets its size and color.
-}
discordIcon : String -> Html msg
discordIcon cls =
    Svg.svg [ SA.viewBox "0 0 126.644 96", SA.class ("shrink-0 fill-current " ++ cls), Attr.attribute "aria-hidden" "true" ]
        [ Svg.path [ SA.d "M81.15,0c-1.2376,2.1973-2.3489,4.4704-3.3591,6.794-9.5975-1.4396-19.3718-1.4396-28.9945,0-.985-2.3236-2.1216-4.5967-3.3591-6.794-9.0166,1.5407-17.8059,4.2431-26.1405,8.0568C2.779,32.5304-1.6914,56.3725.5312,79.8863c9.6732,7.1476,20.5083,12.603,32.0505,16.0884,2.6014-3.4854,4.8998-7.1981,6.8698-11.0623-3.738-1.3891-7.3497-3.1318-10.8098-5.1523.9092-.6567,1.7932-1.3386,2.6519-1.9953,20.281,9.547,43.7696,9.547,64.0758,0,.8587.7072,1.7427,1.3891,2.6519,1.9953-3.4601,2.0457-7.0718,3.7632-10.835,5.1776,1.97,3.8642,4.2683,7.5769,6.8698,11.0623,11.5419-3.4854,22.3769-8.9156,32.0509-16.0631,2.626-27.2771-4.496-50.9172-18.817-71.8548C98.9811,4.2684,90.1918,1.5659,81.1752.0505l-.0252-.0505ZM42.2802,65.4144c-6.2383,0-11.4159-5.6575-11.4159-12.6535s4.9755-12.6788,11.3907-12.6788,11.5169,5.708,11.4159,12.6788c-.101,6.9708-5.026,12.6535-11.3907,12.6535ZM84.3576,65.4144c-6.2637,0-11.3907-5.6575-11.3907-12.6535s4.9755-12.6788,11.3907-12.6788,11.4917,5.708,11.3906,12.6788c-.101,6.9708-5.026,12.6535-11.3906,12.6535Z" ] [] ]


{-| "@handle" with the Discord logo.
-}
discordHandle : String -> Html msg
discordHandle handle =
    Html.span [ Attr.class "flex items-center gap-1.5 text-[13px] text-[#b7bdf7]" ]
        [ discordIcon "w-3.5 h-3.5 text-discord", Html.text ("@" ++ handle) ]


{-| Shown wherever a trader's name is very close to an earlier trader's.
-}
lookalikeWarning : String -> Html msg
lookalikeWarning original =
    callout Bad
        [ Attr.class "px-3 py-2 text-[13px]", testId "lookalike-warning" ]
        [ Html.text ("This name is very close to " ++ original ++ ", who joined earlier. Make sure you're trading with who you think.") ]


unverifiedTag : Html msg
unverifiedTag =
    Html.span
        [ Attr.class "font-bold text-[10px] tracking-widest text-gold border border-gold/40 rounded px-1.5 py-0.5"
        , Attr.title "Verification isn't live yet, so nobody has proved they own this WalkScape name."
        ]
        [ Html.text "UNVERIFIED" ]


bannedTag : Html msg
bannedTag =
    Html.span
        [ Attr.class "font-bold text-[10px] tracking-widest text-warn border border-warn/50 rounded px-1.5 py-0.5"
        , testId "banned-tag"
        ]
        [ Html.text "BANNED" ]


card : List (Html.Attribute msg) -> List (Html msg) -> Html msg
card attrs children =
    Html.div (Attr.class "bg-card border border-edge rounded-xl" :: attrs) children


sectionLabel : String -> Html msg
sectionLabel text =
    Html.div [ Attr.class "font-bold text-[11px] tracking-[0.14em] text-gold uppercase" ] [ Html.text text ]


{-| A number with a label under it, like "3 / active listings".
`valueClass` colours the number.
-}
stat : String -> String -> String -> Html msg
stat valueClass value text =
    Html.div [ Attr.class "rounded-[10px] bg-raised border border-edge px-3 py-2.5" ]
        [ Html.div [ Attr.class ("font-bold text-lg " ++ valueClass) ] [ Html.text value ]
        , Html.div [ Attr.class "text-xs text-muted" ] [ Html.text text ]
        ]


{-| A centred message filling a page, for "not found" and "loading".
-}
pageMessage : List (Html.Attribute msg) -> List (Html msg) -> Html msg
pageMessage attrs children =
    Html.div (Attr.class "p-10 text-center text-muted" :: attrs) children


{-| The square "‹" button at the start of a page title.
-}
backLink : Route -> Html msg
backLink route =
    Html.a [ Attr.href (Route.toString route), Attr.class "w-9 h-9 rounded-lg bg-raised border border-rule grid place-items-center text-gold no-underline" ]
        [ Html.text "‹" ]


label : String -> Html msg
label text =
    Html.div [ Attr.class "text-sm text-muted mb-1.5" ] [ Html.text text ]


type ButtonStyle
    = Primary
    | Secondary
    | Danger


type ButtonSize
    = Compact
    | Small
    | Large
    | Block


{-| Button looks, for `<button>`s and for links that look like buttons.
-}
buttonStyle : ButtonStyle -> ButtonSize -> Html.Attribute msg
buttonStyle style size =
    Attr.class
        ((case style of
            Primary ->
                "bg-go hover:bg-gohi text-white hover:text-white font-bold tracking-wider uppercase border border-white/10 shadow-[inset_0_-2px_0_rgba(0,0,0,0.2)]"

            Secondary ->
                "bg-raised hover:bg-tab text-soft hover:text-ink font-semibold border border-rule"

            Danger ->
                "bg-[#a8403a] hover:bg-[#c0453b] text-white hover:text-white font-bold tracking-wider uppercase"
         )
            ++ " text-center no-underline "
            ++ (case size of
                    Compact ->
                        "rounded-lg text-xs px-3 py-1.5"

                    Small ->
                        "rounded-[10px] text-[13px] px-4 py-2.5"

                    Large ->
                        "rounded-xl px-7 py-3.5"

                    Block ->
                        "block w-full rounded-xl px-6 py-3.5"
               )
        )


{-| A button with an id (for the E2E tests). It never submits a form.
-}
button : ButtonStyle -> ButtonSize -> String -> msg -> String -> Html msg
button style size id msg text =
    Html.button [ Attr.id id, Attr.type_ "button", buttonStyle style size, Events.onClick msg ] [ Html.text text ]


fieldClass : String
fieldClass =
    "w-full rounded-xl bg-field border border-rule focus:border-gold outline-none px-4 py-3 text-ink placeholder:text-faint"


textInput : List (Html.Attribute msg) -> String -> (String -> msg) -> Html msg
textInput attrs value onInput =
    Html.input
        ([ Attr.class fieldClass
         , Attr.value value
         , Events.onInput onInput
         ]
            ++ attrs
        )
        []


textArea : List (Html.Attribute msg) -> String -> (String -> msg) -> Html msg
textArea attrs value onInput =
    Html.textarea
        ([ Attr.class fieldClass
         , Attr.value value
         , Events.onInput onInput
         ]
            ++ attrs
        )
        []


{-| Attributes for a chip drawn in a rarity or quality colour: outlined when
off, filled when on.
-}
colorChip : String -> Bool -> List (Html.Attribute msg)
colorChip color active =
    [ Attr.style "border" ("1px solid " ++ color)
    , Attr.style "color"
        (if active then
            "#0a1014"

         else
            color
        )
    , Attr.style "background"
        (if active then
            color

         else
            "transparent"
        )
    ]


{-| A row of mutually exclusive options, like ALL / SELLING / BUYING.
-}
segmented : List { id : String, label : String, active : Bool, msg : msg } -> Html msg
segmented options =
    Html.div [ Attr.class "flex border border-rule rounded-xl overflow-hidden font-semibold text-[13px] tracking-[0.06em]" ]
        (options
            |> List.indexedMap
                (\i opt ->
                    Html.button
                        [ Attr.id opt.id
                        , Events.onClick opt.msg
                        , Attr.class
                            ("flex-1 text-center py-2.5 px-2 uppercase "
                                ++ (if opt.active then
                                        "bg-tab text-gold shadow-[inset_0_-2px_0_#e3b54c]"

                                    else
                                        "text-muted hover:text-soft"
                                   )
                                ++ (if i > 0 then
                                        " border-l border-rule"

                                    else
                                        ""
                                   )
                            )
                        ]
                        [ Html.text opt.label ]
                )
        )


{-| Fair-value meter: −50% … median … +50%.
-}
valueMeter : Int -> Html msg
valueMeter pct =
    let
        clamped =
            toFloat (clamp -50 50 pct)

        left =
            String.fromFloat (50 + clamped) ++ "%"
    in
    Html.div [ Attr.class "relative h-2.5 rounded-full meter", testId "value-meter" ]
        [ Html.div [ Attr.class "absolute top-[-3px] w-0.5 h-4 bg-white/60 left-1/2" ] []
        , Html.div
            [ Attr.class "absolute top-[-5px] w-1.5 h-5 rounded-sm bg-white shadow -translate-x-1/2"
            , Attr.style "left" left
            ]
            []
        ]


type Tone
    = Info
    | Caution
    | Good
    | Bad


{-| A tinted, bordered box. Callers add padding and layout.
-}
callout : Tone -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
callout tone attrs children =
    Html.div
        (Attr.class
            ("rounded-xl border "
                ++ (case tone of
                        Info ->
                            "border-[#2e4b75] bg-gradient-to-br from-[#121b26] to-[#0f1820] text-[#b7cbe6]"

                        Caution ->
                            "border-[#6b5520] bg-[#1a1608] text-[#e9d9a6]"

                        Good ->
                            "border-[#2c4a3a] bg-[#0f1d17] text-body"

                        Bad ->
                            "border-[#7a3a34] bg-[#2a1412] text-warn"
                   )
            )
            :: attrs
        )
        children


{-| A blue note with a bold lead-in, e.g. "Goes live in 15 minutes."
-}
previewNote : String -> List (Html msg) -> Html msg
previewNote title body =
    callout Info
        [ Attr.class "p-4 text-sm leading-relaxed" ]
        (Html.b [ Attr.class "text-[#d6e4f7]" ] [ Html.text (title ++ " ") ] :: body)


{-| Shown instead of something that needs a linked WalkScape name. `next` is
where to go to link one (see `Derived.onboardingRoute`).
-}
nameGate : Route -> String -> Html msg
nameGate next why =
    previewNote "Link your WalkScape name first."
        [ Html.text (why ++ " ")
        , Html.a [ Attr.href (Route.toString next) ] [ Html.text "Continue" ]
        ]
