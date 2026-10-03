module Ui exposing
    ( button
    , card
    , coin
    , coinAmount
    , empty
    , formatInt
    , gradeTag
    , itemIcon
    , label
    , plural
    , portrait
    , parseAmount
    , previewNote
    , primaryButton
    , priceText
    , secondaryButton
    , sectionLabel
    , segmented
    , sideBadge
    , testId
    , textInput
    , timeAgo
    , unverifiedTag
    , valueMeter
    )

{-| Shared building blocks styled after the Trailpost design.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Item exposing (Item)
import Time
import Types exposing (FrontendMsg, Listing, Payment(..), Side(..))


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


{-| Read a coin amount the way players type it: "9400", "9,400" or "9.4k".
-}
parseAmount : String -> Maybe Int
parseAmount s =
    let
        t =
            s |> String.replace "," "" |> String.replace " " "" |> String.toLower
    in
    if String.endsWith "k" t then
        String.toFloat (String.dropRight 1 t) |> Maybe.map (\f -> round (f * 1000))

    else
        String.toInt t


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
            Html.span [ Attr.class "absolute -top-1.5 -right-1.5 text-gold text-[13px] leading-none drop-shadow", Attr.title "Fine" ] [ Html.text "✦" ]

          else
            empty
        ]


gradeTag : Item -> Item.Variant -> Html msg
gradeTag item variant =
    Html.span
        [ Attr.class "font-bold text-[10px] tracking-widest uppercase"
        , Attr.style "color" (Item.gradeColor item variant)
        ]
        [ Html.text (Item.gradeLabel item variant) ]


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


unverifiedTag : Html msg
unverifiedTag =
    Html.span
        [ Attr.class "font-bold text-[10px] tracking-widest text-gold border border-gold/40 rounded px-1.5 py-0.5"
        , Attr.title "Verification isn't live yet, so nobody has proved they own this WalkScape name."
        ]
        [ Html.text "UNVERIFIED" ]


card : List (Html.Attribute msg) -> List (Html msg) -> Html msg
card attrs children =
    Html.div (Attr.class "bg-card border border-edge rounded-xl" :: attrs) children


sectionLabel : String -> Html msg
sectionLabel text =
    Html.div [ Attr.class "font-bold text-[11px] tracking-[0.14em] text-gold uppercase" ] [ Html.text text ]


label : String -> Html msg
label text =
    Html.div [ Attr.class "text-sm text-muted mb-1.5" ] [ Html.text text ]


button : String -> String -> msg -> String -> Html msg
button id cls msg text =
    Html.button [ Attr.id id, Attr.class cls, Events.onClick msg ] [ Html.text text ]


primaryButton : String -> msg -> String -> Html msg
primaryButton id msg text =
    button id
        "w-full rounded-xl bg-go hover:bg-gohi text-white font-bold tracking-wider uppercase py-3.5 px-6 border border-white/10 shadow-[inset_0_-2px_0_rgba(0,0,0,0.2)]"
        msg
        text


secondaryButton : String -> msg -> String -> Html msg
secondaryButton id msg text =
    button id
        "w-full rounded-xl bg-raised hover:bg-tab text-soft font-semibold py-3 px-5 border border-rule"
        msg
        text


textInput : List (Html.Attribute msg) -> String -> (String -> msg) -> Html msg
textInput attrs value onInput =
    Html.input
        ([ Attr.class "w-full rounded-xl bg-field border border-rule focus:border-gold outline-none px-4 py-3 text-ink placeholder:text-faint"
         , Attr.value value
         , Events.onInput onInput
         ]
            ++ attrs
        )
        []


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


previewNote : List (Html FrontendMsg) -> Html FrontendMsg
previewNote children =
    Html.div [ Attr.class "rounded-xl border border-[#2e4b75] bg-gradient-to-br from-[#121b26] to-[#0f1820] p-4 text-sm leading-relaxed text-[#b7cbe6]" ]
        children
