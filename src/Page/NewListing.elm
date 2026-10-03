module Page.NewListing exposing (toDraft, view)

import Derived
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Item
import Market
import Pricing
import Types exposing (FrontendModel, FrontendMsg(..), ListingDraft, ListingForm, Payment(..), Side(..))
import Ui


{-| The fine flag and quality the form describes for this item. A fine
choice left over from another item is dropped if this one can't be fine.
-}
variantFor : Item.Item -> ListingForm -> Item.Variant
variantFor item form =
    { fine = form.fine && item.canBeFine
    , quality =
        case item.kind of
            Item.Crafted ->
                Just form.quality

            _ ->
                Nothing
    }


{-| Check the form and turn it into what the backend expects.
-}
toDraft : ListingForm -> Result String ListingDraft
toDraft form =
    case form.itemId |> Maybe.andThen Item.byId of
        Nothing ->
            Err "Pick an item first."

        Just item ->
            let
                payment =
                    case Ui.parseAmount form.price of
                        Just price ->
                            if price > 0 then
                                Ok (Coins price)

                            else
                                Err "Enter a price above zero."

                        Nothing ->
                            Err "Enter a price in coins, like 1200 or 1.2k."
            in
            case String.toInt (String.trim form.quantity) of
                Just quantity ->
                    if quantity <= 0 then
                        Err "Enter a quantity above zero."

                    else
                        payment
                            |> Result.map
                                (\p ->
                                    { itemId = item.id
                                    , variant = variantFor item form
                                    , side = form.side
                                    , payment = p
                                    , quantity = quantity
                                    , note = form.note
                                    }
                                )

                Nothing ->
                    Err "Enter a quantity, like 1 or 50."


view : FrontendModel -> Html FrontendMsg
view model =
    let
        activeCount =
            case Derived.myName model of
                Just name ->
                    Market.activeListingCount name (Dict.values model.listings)

                Nothing ->
                    0
    in
    Html.div [ Attr.class "w-full max-w-xl mx-auto flex flex-col gap-4 px-4 py-5" ]
        [ Html.div [ Attr.class "flex items-center gap-3" ]
            [ Html.a [ Attr.href "/market", Attr.class "w-9 h-9 rounded-lg bg-raised border border-rule grid place-items-center text-gold no-underline" ] [ Html.text "‹" ]
            , Html.h1 [ Attr.class "flex-1 font-display font-extrabold text-[26px] text-gold" ] [ Html.text "New listing" ]
            , Html.span [ Attr.class "text-[13px] text-muted" ] [ Html.text (String.fromInt activeCount ++ " of " ++ String.fromInt Market.maxActiveListings ++ " active") ]
            ]
        , if Derived.isReady model then
            viewForm model

          else
            Ui.previewNote
                [ Html.b [ Attr.class "text-[#d6e4f7]" ] [ Html.text "Link your WalkScape name first. " ]
                , Html.text "You need to sign in and claim the name you play under before you can post a listing. "
                , Html.a
                    [ Attr.href
                        (if model.me == Nothing then
                            "/signin"

                         else
                            "/welcome"
                        )
                    ]
                    [ Html.text "Continue" ]
                ]
        ]


viewForm : FrontendModel -> Html FrontendMsg
viewForm model =
    let
        form =
            model.listingForm

        selected =
            form.itemId |> Maybe.andThen Item.byId

    in
    Html.div [ Attr.class "flex flex-col gap-4" ]
        [ Html.div []
            [ Ui.label "Item"
            , case selected of
                Just item ->
                    Ui.card [ Attr.class "flex items-center gap-3 p-3", Ui.testId "picked-item" ]
                        [ Ui.itemIcon "w-11 h-11" item (variantFor item form)
                        , Html.div [ Attr.class "flex-1" ]
                            [ Html.div [ Attr.class "font-bold text-lg" ] [ Html.text (item.name) ]
                            , Ui.gradeTag item { fine = (variantFor item form).fine, quality = Nothing }
                            ]
                        , Ui.button "change-item" "text-soft text-sm" ListingItemCleared "Change"
                        ]

                Nothing ->
                    itemPicker "item" form.itemQuery ListingItemQueryChanged ListingItemPicked
            ]
        , case selected of
            Just item ->
                if item.canBeFine then
                    Html.div []
                        [ Ui.segmented
                            [ { id = "variant-regular", label = "Regular", active = not form.fine, msg = ListingFineToggled False }
                            , { id = "variant-fine", label = "✦ Fine", active = form.fine, msg = ListingFineToggled True }
                            ]
                        , Html.p [ Attr.class "text-xs text-faint mt-1.5" ] [ Html.text "Fine items are priced separately from regular ones." ]
                        ]

                else
                    Ui.empty

            Nothing ->
                Ui.empty
        , case selected |> Maybe.map .kind of
            Just Item.Crafted ->
                Html.div []
                    [ Ui.label "Quality"
                    , Html.div [ Attr.class "grid grid-cols-3 sm:grid-cols-6 gap-1.5" ]
                        (Item.allQualities
                            |> List.map
                                (\q ->
                                    let
                                        active =
                                            q == form.quality

                                        color =
                                            Item.qualityColor q
                                    in
                                    Html.button
                                        [ Attr.id ("pick-quality-" ++ Item.qualityToString q)
                                        , Events.onClick (ListingQualityPicked q)
                                        , Attr.class "rounded-lg py-2 text-[13px] font-semibold"
                                        , Attr.style "border" ("1.5px solid " ++ color)
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
                                        [ Html.text (Item.qualityLabel q) ]
                                )
                        )
                    , Html.p [ Attr.class "text-xs text-faint mt-1.5" ] [ Html.text "Buyers see this quality and get a reminder to check the outline colour in-game." ]
                    ]

            _ ->
                Ui.empty
        , Ui.segmented
            [ { id = "side-sell", label = "Sell", active = form.side == Selling, msg = ListingSidePicked Selling }
            , { id = "side-buy", label = "Buy", active = form.side == Buying, msg = ListingSidePicked Buying }
            ]
        , Html.div [ Attr.class "grid grid-cols-[110px_1fr] gap-3" ]
            [ Html.div []
                [ Ui.label "Quantity"
                , Ui.textInput [ Attr.id "quantity", Attr.attribute "inputmode" "numeric", Attr.class "text-leaf font-bold" ] form.quantity ListingQuantityChanged
                ]
            , Html.div []
                [ Ui.label "Price each"
                , Ui.textInput
                    [ Attr.id "price"
                    , Attr.attribute "inputmode" "numeric"
                    , Attr.placeholder "48,000"
                    ]
                    form.price
                    ListingPriceChanged
                ]
            ]
        , medianCheck model form
        , Html.div []
            [ Ui.label "Note (optional)"
            , Html.textarea
                [ Attr.id "note"
                , Attr.class "w-full rounded-xl bg-field border border-rule focus:border-gold outline-none px-4 py-3 text-ink placeholder:text-faint h-20"
                , Attr.placeholder "Usually online evenings EU. I check a mailbox most days."
                , Attr.value form.note
                , Events.onInput ListingNoteChanged
                ]
                []
            ]
        , Ui.previewNote
            [ Html.b [ Attr.class "text-[#d6e4f7]" ] [ Html.text "Goes live in 15 minutes. " ]
            , Html.text "Every listing waits the same amount of time, so no deal ever disappears in seconds."
            ]
        , case form.error of
            Just err ->
                Html.p [ Attr.class "text-sm text-warn", Ui.testId "listing-error" ] [ Html.text err ]

            Nothing ->
                Ui.empty
        , Ui.primaryButton "post-listing"
            ListingSubmitted
            (if form.submitting then
                "Posting…"

             else
                "Post listing"
            )
        ]


itemPicker : String -> String -> (String -> FrontendMsg) -> (String -> FrontendMsg) -> Html FrontendMsg
itemPicker prefix query onQuery onPick =
    let
        results =
            Item.search query |> List.take 24
    in
    Html.div [ Attr.class "flex flex-col gap-2" ]
        [ Ui.textInput [ Attr.id (prefix ++ "-search"), Attr.placeholder "Search items…" ] query onQuery
        , if String.isEmpty (String.trim query) then
            Html.p [ Attr.class "text-xs text-faint" ] [ Html.text ("Type to search " ++ String.fromInt (List.length Item.all) ++ " WalkScape items.") ]

          else if List.isEmpty results then
            Html.p [ Attr.class "text-xs text-faint" ] [ Html.text "No items match that." ]

          else
            Ui.empty
        , Html.div [ Attr.class "grid grid-cols-1 sm:grid-cols-2 gap-1.5" ]
            (List.map
                (\item ->
                    Html.button
                        [ Attr.id (prefix ++ "-pick-" ++ item.id)
                        , Events.onClick (onPick item.id)
                        , Attr.class "flex items-center gap-2.5 rounded-lg bg-card border border-edge hover:bg-raised px-2.5 py-2 text-left"
                        ]
                        [ Ui.itemIcon "w-8 h-8 rounded-md" item Item.plain
                        , Html.span [ Attr.class "text-sm font-semibold" ] [ Html.text item.name ]
                        ]
                )
                results
            )
        ]


medianCheck : FrontendModel -> ListingForm -> Html msg
medianCheck model form =
    case ( form.itemId |> Maybe.andThen Item.byId, Ui.parseAmount form.price ) of
        ( Just item, Just price ) ->
            let
                variant =
                    variantFor item form

                gradeName =
                    (variant.quality |> Maybe.map Item.qualityLabel |> Maybe.withDefault item.name)
                        ++ (if variant.fine then
                                " (fine)"

                            else
                                ""
                           )
            in
            case Derived.estimateFor model (Item.priceKey item.id variant) of
                Just est ->
                    let
                        pct =
                            Pricing.deviationPercent est.median price

                        warn =
                            Pricing.isWarning pct
                    in
                    Html.div
                        [ Attr.class
                            ("rounded-xl border p-3.5 flex flex-col gap-2.5 "
                                ++ (if warn then
                                        "border-[#7a3a34] bg-[#2a1412]"

                                    else
                                        "border-[#2c4a3a] bg-[#0f1d17]"
                                   )
                            )
                        , Ui.testId "median-check"
                        ]
                        [ Html.div [ Attr.class "flex justify-between text-[13px]" ]
                            [ Html.span
                                [ Attr.class
                                    ("font-bold "
                                        ++ (if warn then
                                                "text-warn"

                                            else
                                                "text-leaf"
                                           )
                                    )
                                ]
                                [ Html.text
                                    ((if pct >= 0 then
                                        "+"

                                      else
                                        "−"
                                     )
                                        ++ String.fromInt (abs pct)
                                        ++ "% · "
                                        ++ (if warn then
                                                "far from the estimate"

                                            else
                                                "normal for " ++ gradeName
                                           )
                                    )
                                ]
                            , Html.span [ Attr.class "text-muted" ] [ Html.text ("estimate " ++ Ui.formatInt est.median) ]
                            ]
                        , Ui.valueMeter pct
                        ]

                Nothing ->
                    Html.div [ Attr.class "rounded-xl border border-edge bg-card p-3.5 text-[13px] text-muted", Ui.testId "median-check" ]
                        [ Html.text "No estimate for this item yet. Your listing will help start one." ]

        _ ->
            Ui.empty
