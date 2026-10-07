module Page.Listing exposing (view)

import Derived
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Item exposing (Item)
import Market
import Pricing
import Route
import Types exposing (FrontendModel, FrontendMsg(..), Listing, Offer, OfferStatus(..), Side(..))
import Ui


view : FrontendModel -> Int -> Html FrontendMsg
view model listingId =
    case Dict.get listingId model.listings |> Maybe.andThen (\l -> Market.item l |> Maybe.map (Tuple.pair l)) of
        Just ( listing, item ) ->
            viewListing model listing item

        Nothing ->
            Ui.pageMessage [ Ui.testId "listing-missing" ]
                [ Html.p [ Attr.class "mb-3" ]
                    [ Html.text
                        (if model.loaded then
                            "This listing doesn't exist, or it isn't live yet."

                         else
                            "Loading…"
                        )
                    ]
                , Html.a [ Attr.href "/market" ] [ Html.text "Back to the market" ]
                ]


viewListing : FrontendModel -> Listing -> Item -> Html FrontendMsg
viewListing model listing item =
    let
        isMine =
            Derived.myName model == Just listing.trader

        verb =
            case listing.side of
                Selling ->
                    "Selling"

                Buying ->
                    "Buying"
    in
    Html.div [ Attr.class "flex-1 grid lg:grid-cols-[minmax(0,1fr)_320px]" ]
        [ Html.div [ Attr.class "flex flex-col gap-4 px-4 md:px-7 py-5 md:py-6 min-w-0" ]
            [ Html.div [ Attr.class "flex items-center gap-3 flex-wrap" ]
                [ Ui.backLink Route.Market
                , Html.h1 [ Attr.class "font-display font-extrabold text-[26px] md:text-[28px]", Ui.testId "listing-title" ]
                    [ Html.text (verb ++ " " ++ String.fromInt listing.quantity ++ "x " ++ item.name), Html.text " ", Ui.variantTag listing.variant ]
                , statusTag model listing
                ]
            , Html.div [ Attr.class "flex flex-col gap-4" ] (List.map (tradeChecklist model listing item) (myAcceptedOffers model listing))
            , Html.div [ Attr.class "grid md:grid-cols-2 gap-4" ]
                [ termsCard model listing item
                , valueCard model listing
                ]
            , offersSection model listing isMine
            ]
        , Html.aside [ Attr.class "flex flex-col gap-4 px-4 md:px-7 lg:px-5 py-5 lg:border-l border-line" ]
            [ traderCard model listing.trader
            , tricks
            , if isMine then
                if listing.closed then
                    Ui.empty

                else
                    Ui.button Ui.Secondary Ui.Block "close-listing" (CloseListingClicked listing.id) "Close this listing"

              else if Derived.isReady model then
                Html.a [ Attr.href (Route.toString (Route.Report listing.trader)), Attr.id "report-link", Attr.class "text-warn hover:text-warn text-sm font-semibold no-underline" ]
                    [ Html.text ("Report " ++ listing.trader) ]

              else
                Ui.empty
            ]
        ]


{-| Accepted offers on this listing that the signed-in trader is part of.
-}
myAcceptedOffers : FrontendModel -> Listing -> List Offer
myAcceptedOffers model listing =
    case Derived.myName model of
        Just me ->
            Derived.offersFor model listing.id
                |> List.filter (\o -> o.status == OfferAccepted && (o.from == me || listing.trader == me))

        Nothing ->
            []


{-| What each side puts in WalkScape's trade window, and what to check before
pressing Accept there.
-}
tradeChecklist : FrontendModel -> Listing -> Item -> Offer -> Html FrontendMsg
tradeChecklist model listing item offer =
    let
        terms =
            Market.tradeTerms listing offer

        me =
            Derived.myName model |> Maybe.withDefault ""

        other =
            if me == terms.seller then
                terms.buyer

            else
                terms.seller

        itemsLine =
            [ Html.b [] [ Html.text (String.fromInt listing.quantity ++ " × " ++ Item.fullName item listing.variant) ]
            , Html.text " "
            , Ui.variantTag listing.variant
            ]

        -- Written the way the trade window shows coins, with no commas.
        coinsLine =
            [ Ui.coin "w-3.5 h-3.5 inline-block align-[-2px]"
            , Html.text " "
            , Html.b [ Attr.class "text-gold tabular-nums" ] [ Html.text (String.fromInt terms.coins) ]
            , Html.text " coins"
            ]

        ( yours, theirs ) =
            if me == terms.seller then
                ( itemsLine, coinsLine )

            else
                ( coinsLine, itemsLine )

        theirsCheck =
            if me == terms.seller then
                "The trade window shows coins without commas, so count the digits: "
                    ++ String.fromInt terms.coins
                    ++ " is "
                    ++ Ui.formatInt terms.coins
                    ++ "."

            else if listing.variant.fine then
                "Fine items have teal text in the trade window. White text is the normal version."

            else if listing.variant.rare then
                "Check it's the rare egg, not a normal one."

            else
                case listing.variant.quality of
                    Just q ->
                        "Check it's " ++ Item.qualityLabel q ++ " quality, not a lower one."

                    Nothing ->
                        "Check the item and the amount."

        row title body =
            Html.div [ Attr.class "grid grid-cols-[88px_1fr] gap-3 items-baseline" ]
                [ Html.span [ Attr.class "text-muted text-[13px]" ] [ Html.text title ]
                , Html.div [] body
                ]
    in
    Ui.callout Ui.Good
        [ Attr.class "p-4 flex flex-col gap-3 text-sm", Ui.testId ("trade-checklist-" ++ String.fromInt offer.id) ]
        [ Html.div [ Attr.class "font-display font-extrabold text-lg text-leaf" ] [ Html.text ("Trade with " ++ other ++ " in WalkScape") ]
        , Html.p []
            [ Html.text "One of you invites the other: Social → Find → "
            , Html.b [] [ Html.text other ]
            , Html.text " → Invite to trade."
            ]
        , Html.div [ Attr.class "rounded-lg bg-[#0b1611] px-3.5 py-3 flex flex-col gap-2" ]
            [ row "You put in" yours
            , row "They put in" (theirs ++ [ Html.div [ Attr.class "text-xs text-muted mt-0.5" ] [ Html.text theirsCheck ] ])
            ]
        , Html.p []
            [ Html.text "Read their side before you press Accept. If either of you presses Update, Accept resets, so read it again before accepting again." ]
        , resolveTrade model listing offer other
        ]


{-| "It went through" and "It fell through", for after the trade window.
-}
resolveTrade : FrontendModel -> Listing -> Offer -> String -> Html FrontendMsg
resolveTrade model listing offer other =
    let
        idText =
            String.fromInt offer.id

        iAmLister =
            Derived.myName model == Just listing.trader

        ( iConfirmed, theyConfirmed ) =
            if iAmLister then
                ( offer.listerConfirmed, offer.offererConfirmed )

            else
                ( offer.offererConfirmed, offer.listerConfirmed )

        status text =
            Html.p [ Attr.class "font-semibold text-leaf", Ui.testId ("trade-status-" ++ idText) ] [ Html.text text ]

        buttons =
            Html.div [ Attr.class "grid grid-cols-2 gap-2" ]
                [ Ui.button Ui.Primary Ui.Block ("trade-confirm-" ++ idText) (TradeConfirmClicked offer.id) "It went through"
                , Ui.button Ui.Secondary Ui.Block ("trade-fell-through-" ++ idText) (FellThroughClicked offer.id) "It fell through"
                ]
    in
    Html.div [ Attr.class "flex flex-col gap-2 border-t border-[#2c5a2a] pt-3" ]
        (case model.fellThroughForm of
            Just form ->
                if form.offerId == offer.id then
                    [ Ui.label "What happened?"
                    , Ui.textInput [ Attr.id "fell-through-reason", Attr.placeholder "e.g. They never accepted the invite" ] form.reason FellThroughReasonChanged
                    , case form.error of
                        Just err ->
                            Html.p [ Attr.class "text-sm text-warn", Ui.testId "fell-through-error" ] [ Html.text err ]

                        Nothing ->
                            Ui.empty
                    , Html.div [ Attr.class "grid grid-cols-2 gap-2" ]
                        [ Ui.button Ui.Danger Ui.Block "fell-through-submit" FellThroughSubmitted "It fell through"
                        , Ui.button Ui.Secondary Ui.Block "fell-through-cancel" FellThroughCancelled "Cancel"
                        ]
                    , Html.p [ Attr.class "text-xs text-muted" ] [ Html.text "The listing goes back up, and you can't undo this." ]
                    ]

                else
                    resolveButtons iConfirmed theyConfirmed other status buttons

            Nothing ->
                resolveButtons iConfirmed theyConfirmed other status buttons
        )


resolveButtons : Bool -> Bool -> String -> (String -> Html msg) -> Html msg -> List (Html msg)
resolveButtons iConfirmed theyConfirmed other status buttons =
    if iConfirmed then
        [ status ("Waiting for " ++ other ++ " to confirm it went through.") ]

    else if theyConfirmed then
        [ status (other ++ " says it went through. Did it?"), buttons ]

    else
        [ Html.p [] [ Html.text "Once you've traded, tell us how it went." ], buttons ]


statusTag : FrontendModel -> Listing -> Html msg
statusTag model listing =
    let
        tag cls text =
            Html.span [ Attr.class ("font-bold text-[11px] tracking-[0.1em] px-2 py-1 rounded-md border " ++ cls), Ui.testId "listing-status" ] [ Html.text text ]
    in
    if Derived.traded model listing.id then
        tag "border-[#2c5a2a] bg-[#0f1d17] text-leaf" "TRADED"

    else if Derived.tradePending model listing.id then
        tag "border-[#6b5520] bg-[#2a2210] text-gold" "TRADE PENDING"

    else if listing.closed then
        tag "border-rule text-muted" "CLOSED"

    else if not (Market.isLive model.now listing) then
        tag "border-[#6b5520] bg-[#2a2210] text-gold" "WAITING TO GO LIVE"

    else
        tag "border-[#2c5a2a] bg-[#0f1d17] text-leaf" "LIVE"


termsCard : FrontendModel -> Listing -> Item -> Html msg
termsCard model listing item =
    Ui.card [ Attr.class "p-4 flex flex-col gap-3" ]
        [ Html.div [ Attr.class "flex items-center gap-3" ]
            [ Ui.itemIcon "w-12 h-12" item listing.variant
            , Html.div [ Attr.class "flex-1" ]
                [ Html.div [ Attr.class "font-semibold text-lg text-[#9fd3e8]" ] [ Html.text item.name ]
                , Ui.gradeTag item listing.variant
                ]
            , Ui.sideBadge listing
            ]
        , Html.div [ Attr.class "rounded-lg bg-[#16232a] px-3.5 py-3 flex items-center justify-between" ]
            [ Html.span [ Attr.class "text-muted text-sm" ]
                [ Html.text
                    (case listing.side of
                        Selling ->
                            "Asking"

                        Buying ->
                            "Paying"
                    )
                ]
            , Html.span [ Attr.class "text-lg", Ui.testId "listing-price" ] [ Ui.priceText listing ]
            ]
        , Html.div [ Attr.class "flex justify-between text-sm" ]
            [ Html.span [ Attr.class "text-muted" ] [ Html.text "Quantity" ]
            , Html.span [ Attr.class "font-bold text-leaf" ] [ Html.text (String.fromInt listing.quantity ++ "x") ]
            ]
        , if String.isEmpty listing.note then
            Ui.empty

          else
            Html.p [ Attr.class "text-sm text-body border-l-2 border-rule pl-3 italic" ] [ Html.text listing.note ]
        , Html.div [ Attr.class "text-xs text-faint" ]
            [ Html.text ("Posted " ++ Ui.timeAgo model.now listing.createdAt ++ " by ")
            , Html.a [ Attr.href (Route.toString (Route.Profile listing.trader)) ] [ Html.text listing.trader ]
            ]
        , if Market.isLive model.now listing then
            Ui.empty

          else
            Ui.callout Ui.Caution
                [ Attr.class "px-3 py-2 text-[13px]", Ui.testId "pending-note" ]
                [ Html.div [ Attr.class "flex items-baseline justify-between mb-1" ]
                    [ Html.span [ Attr.class "font-semibold" ] [ Html.text "Goes live in" ]
                    , Html.span [ Attr.class "font-display font-extrabold text-xl tabular-nums", Ui.testId "go-live-countdown" ]
                        [ Html.text (Ui.countdown model.now listing.liveAt) ]
                    ]
                , Html.text "Only you can see this for now. Every listing waits 5 minutes before going live, so no deal appears and disappears in seconds."
                ]
        ]


valueCard : FrontendModel -> Listing -> Html msg
valueCard model listing =
    Ui.card [ Attr.class "p-4 flex flex-col gap-3" ]
        (case Derived.listingEstimate model listing of
            Just ( est, pct ) ->
                [ Html.div [ Attr.class "flex justify-between items-baseline gap-2" ]
                    [ Html.span [ Attr.class "font-semibold text-sm" ] [ Html.text "Fair-value check" ]
                    , Html.span
                        [ Attr.class
                            ("text-[13px] font-bold "
                                ++ (if Pricing.isWarning pct then
                                        "text-warn"

                                    else
                                        "text-leaf"
                                   )
                            )
                        , Ui.testId "fair-value"
                        ]
                        [ Html.text (fairValueText listing pct) ]
                    ]
                , Ui.valueMeter pct
                , Html.div [ Attr.class "flex justify-between text-[11px] text-faint" ]
                    [ Html.span [] [ Html.text "−50%" ], Html.span [] [ Html.text ("estimate " ++ Ui.formatInt est.median) ], Html.span [] [ Html.text "+50%" ] ]
                , Html.p [ Attr.class "text-xs text-faint" ]
                    [ Html.text ("Estimate from " ++ String.fromInt est.counted ++ " prices by " ++ String.fromInt est.traders ++ " traders. Typical range " ++ Ui.formatInt est.low ++ "–" ++ Ui.formatInt est.high ++ ".") ]
                , Html.a [ Attr.href (Route.toString (Route.ItemPrice listing.itemId listing.variant)), Attr.class "text-sm" ]
                    [ Html.text "See price history" ]
                ]

            Nothing ->
                [ Html.span [ Attr.class "font-semibold text-sm" ] [ Html.text "Fair-value check" ]
                , Html.p [ Attr.class "text-sm text-muted" ]
                    [ Html.text
                        "Not enough prices for this item yet. Each listing and offer helps build the estimate."
                    ]
                ]
        )


fairValueText : Listing -> Int -> String
fairValueText listing pct =
    if pct == 0 then
        "Right at the estimate"

    else
        (case listing.side of
            Selling ->
                "Asks "

            Buying ->
                "Pays "
        )
            ++ Ui.percentAboveBelow pct
            ++ " the estimate"


offersSection : FrontendModel -> Listing -> Bool -> Html FrontendMsg
offersSection model listing isMine =
    let
        offers =
            Derived.offersFor model listing.id |> List.filter (\o -> o.status /= OfferWithdrawn)

        myOffer =
            Derived.myOpenOffer model listing.id
    in
    Ui.card [ Attr.class "p-4 flex flex-col gap-3" ]
        [ Html.div [ Attr.class "flex items-baseline justify-between" ]
            [ Ui.sectionLabel ("Offers · " ++ String.fromInt (List.length offers))
            , Html.span [ Attr.class "text-xs text-faint" ] [ Html.text "Offers are public and feed the price estimate" ]
            ]
        , if List.isEmpty offers then
            Html.p [ Attr.class "text-sm text-muted", Ui.testId "no-offers" ] [ Html.text "No offers yet." ]

          else
            Html.div [ Attr.class "flex flex-col gap-2", Ui.testId "offers" ] (List.map (offerRow model listing isMine) offers)
        , if not (List.isEmpty (myAcceptedOffers model listing)) then
            Ui.empty

          else if Derived.tradePending model listing.id && not listing.closed then
            Html.p [ Attr.class "text-sm text-muted border-t border-line pt-4 mt-1", Ui.testId "trade-pending" ]
                [ Html.text
                    (if isMine then
                        "A trade is pending. You can accept another offer if it falls through."

                     else
                        "A trade is pending with someone else. If it falls through, the listing takes offers again."
                    )
                ]

          else if isMine || listing.closed || not (Market.isLive model.now listing) then
            Ui.empty

          else
            offerForm model listing myOffer
        ]


offerRow : FrontendModel -> Listing -> Bool -> Offer -> Html FrontendMsg
offerRow model listing isMine offer =
    let
        priceLabel =
            case offer.price of
                Just p ->
                    Html.span [ Attr.class "inline-flex items-center gap-1" ] [ Ui.coinAmount p, Html.span [ Attr.class "text-xs text-faint" ] [ Html.text "ea" ] ]

                Nothing ->
                    Html.span [ Attr.class "text-sm text-leaf font-semibold" ] [ Html.text "At your price" ]

        statusText =
            case offer.status of
                OfferOpen ->
                    Ui.empty

                OfferAccepted ->
                    Html.div [ Attr.class "text-xs text-leaf mt-1" ] [ Html.text "Accepted · trade pending" ]

                OfferDeclined ->
                    Html.div [ Attr.class "text-xs text-warn mt-1" ] [ Html.text "Declined" ]

                OfferWithdrawn ->
                    Ui.empty

                OfferCompleted _ ->
                    Html.div [ Attr.class "text-xs text-leaf mt-1" ] [ Html.text "Traded" ]

                OfferFellThrough fell ->
                    Html.div [ Attr.class "text-xs text-warn mt-1" ] [ Html.text ("Fell through: " ++ fell.reason) ]

        isMyOffer =
            Derived.myName model == Just offer.from
    in
    Html.div [ Attr.class "rounded-lg bg-[#16232a] px-3.5 py-2.5", Ui.testId ("offer-" ++ String.fromInt offer.id) ]
        [ Html.div [ Attr.class "flex items-center gap-3 flex-wrap" ]
            [ Html.a [ Attr.href (Route.toString (Route.Profile offer.from)), Attr.class "font-semibold text-ink hover:text-gold no-underline" ] [ Html.text offer.from ]
            , priceLabel
            , Html.span [ Attr.class "text-xs text-faint" ] [ Html.text (Ui.timeAgo model.now offer.at) ]
            , Html.div [ Attr.class "flex-1" ] []
            , if isMine && offer.status == OfferOpen && not listing.closed then
                Html.div [ Attr.class "flex gap-2" ]
                    [ if Derived.tradePending model listing.id then
                        Ui.empty

                      else
                        Ui.button Ui.Primary Ui.Compact ("accept-" ++ String.fromInt offer.id) (RespondToOfferClicked offer.id True) "Accept"
                    , Ui.button Ui.Secondary Ui.Compact ("decline-" ++ String.fromInt offer.id) (RespondToOfferClicked offer.id False) "Decline"
                    ]

              else if isMyOffer && offer.status == OfferOpen then
                Ui.button Ui.Secondary Ui.Compact ("withdraw-" ++ String.fromInt offer.id) (WithdrawOfferClicked offer.id) "Withdraw"

              else
                Ui.empty
            ]
        , if String.isEmpty offer.message then
            Ui.empty

          else
            Html.p [ Attr.class "text-sm text-body mt-1" ] [ Html.text offer.message ]
        , statusText
        ]


offerForm : FrontendModel -> Listing -> Maybe Offer -> Html FrontendMsg
offerForm model listing myOffer =
    if model.me == Nothing then
        Html.a [ Attr.href (Route.toString Route.SignIn), Attr.id "signin-to-offer", Ui.buttonStyle Ui.Primary Ui.Block ]
            [ Html.text "Sign in to make an offer" ]

    else if not (Derived.isReady model) then
        Html.a [ Attr.href (Route.toString Route.Onboarding), Ui.buttonStyle Ui.Secondary Ui.Block ]
            [ Html.text "Link your WalkScape name to make offers" ]

    else
        let
            form =
                model.offerForm

            preview =
                case ( Derived.estimateFor model (Item.priceKey listing.itemId listing.variant), Market.parseCoins form.price ) of
                    ( Just est, Just p ) ->
                        if form.counter then
                            let
                                pct =
                                    Pricing.deviationPercent est.median p
                            in
                            Html.div
                                [ Attr.class
                                    ("text-xs "
                                        ++ (if Pricing.isWarning pct then
                                                "text-warn"

                                            else
                                                "text-faint"
                                           )
                                    )
                                , Ui.testId "offer-check"
                                ]
                                [ Html.text (Ui.percentAboveBelow pct ++ " the estimate of " ++ Ui.formatInt est.median ++ ".") ]

                        else
                            Ui.empty

                    _ ->
                        Ui.empty
        in
        Html.div [ Attr.class "flex flex-col gap-3 border-t border-line pt-4 mt-1" ]
            [ Html.div [ Attr.class "font-semibold" ]
                [ Html.text
                    (if myOffer == Nothing then
                        "Interested?"

                     else
                        "Update your offer"
                    )
                ]
            , Ui.segmented
                [ { id = "offer-at-price", label = "At their price", active = not form.counter, msg = OfferCounterToggled False }
                , { id = "offer-counter", label = "Counter-offer", active = form.counter, msg = OfferCounterToggled True }
                ]
            , if form.counter then
                Html.div []
                    [ Ui.label "Your price each (coins)"
                    , Ui.textInput [ Attr.id "offer-price", Attr.attribute "inputmode" "numeric", Attr.placeholder "e.g. 9400" ] form.price OfferPriceChanged
                    ]

              else
                Ui.empty
            , preview
            , Html.div []
                [ Ui.label "Message (optional)"
                , Ui.textArea
                    [ Attr.id "offer-message", Attr.class "h-20", Attr.placeholder "When you're usually online, or anything else they should know" ]
                    form.message
                    OfferMessageChanged
                ]
            , case form.error of
                Just err ->
                    Html.p [ Attr.class "text-sm text-warn", Ui.testId "offer-error" ] [ Html.text err ]

                Nothing ->
                    Ui.empty
            , Ui.button Ui.Primary
                Ui.Block
                "send-offer"
                (OfferSubmitted listing.id)
                (if myOffer == Nothing then
                    "Send offer"

                 else
                    "Update offer"
                )
            , Html.p [ Attr.class "text-xs text-faint" ] [ Html.text "If they accept, you trade in WalkScape. Your offer also goes into the price estimate." ]
            ]


traderCard : FrontendModel -> String -> Html msg
traderCard model name =
    let
        stats =
            Derived.traderStats model name

        trader =
            Dict.get name model.traders
    in
    Html.div [ Attr.class "flex flex-col gap-3", Ui.testId "trader-card" ]
        [ Html.a [ Attr.href (Route.toString (Route.Profile name)), Attr.class "flex items-center gap-3.5 no-underline text-ink hover:text-ink" ]
            [ Html.div [ Attr.class "flex flex-col gap-1" ]
                [ Html.div [ Attr.class "font-display font-extrabold text-xl" ] [ Html.text name ]
                , Html.div [ Attr.class "flex items-center gap-2" ]
                    [ Ui.unverifiedTag
                    , if model.me /= Nothing then
                        trader |> Maybe.andThen .discord |> Maybe.map Ui.discordHandle |> Maybe.withDefault Ui.empty

                      else
                        Ui.empty
                    ]
                ]
            ]
        , Html.div [ Attr.class "grid grid-cols-2 gap-2" ]
            [ Ui.stat "text-ink" (String.fromInt stats.activeListings) "active listings"
            , Ui.stat "text-ink" (String.fromInt stats.partners) "unique partners"
            , Ui.stat "text-ink" (String.fromInt stats.offersMade) "offers made"
            , Ui.stat "text-ink" (Ui.plural stats.days "day" "days") "on Trailpost"
            ]
        , trader |> Maybe.andThen .lookalikeOf |> Maybe.map Ui.lookalikeWarning |> Maybe.withDefault Ui.empty
        ]


tricks : Html msg
tricks =
    Ui.callout Ui.Caution
        [ Attr.class "p-4 flex flex-col gap-2.5 text-[13px]" ]
        [ Html.div [ Attr.class "font-display font-extrabold text-lg text-gold" ] [ Html.text "Common tricks" ]
        , Html.p [] [ Html.text "Changing their side just before you accept. Update resets Accept, so read it again every time." ]
        , Html.p [] [ Html.text "The normal version instead of fine. Fine items have teal text in the trade window." ]
        , Html.p [] [ Html.text "Same item at a lower quality: an Eternal pickaxe turns into a Normal one. Check the outline colour." ]
        , Html.p [] [ Html.text "A zero missing from the coins. The trade window has no commas, so count the digits." ]
        , Html.p [] [ Html.text "A name that's one letter off (Mosbeard, Mossbeard_)." ]
        , Html.p [] [ Html.text "\"Someone else is buying in 2 minutes.\" Real buyers wait." ]
        , Html.p [] [ Html.text "Splitting it into two trades so you go first. Do it in one." ]
        ]
