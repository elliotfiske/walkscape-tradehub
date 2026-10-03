module Page.Listing exposing (view)

import Derived
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
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
            Html.div [ Attr.class "p-10 text-center text-muted", Ui.testId "listing-missing" ]
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
                [ Html.a [ Attr.href "/market", Attr.class "w-9 h-9 rounded-lg bg-raised border border-rule grid place-items-center text-gold no-underline" ] [ Html.text "‹" ]
                , Html.h1 [ Attr.class "font-display font-extrabold text-[26px] md:text-[28px]", Ui.testId "listing-title" ]
                    [ Html.text (verb ++ " " ++ String.fromInt listing.quantity ++ "x " ++ item.name), Html.text " ", Ui.fineTag listing.variant ]
                , statusTag model listing
                ]
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
                    Ui.secondaryButton "close-listing" (CloseListingClicked listing.id) "Close this listing"

              else if Derived.isReady model then
                Html.a [ Attr.href ("/report/" ++ listing.trader), Attr.id "report-link", Attr.class "text-warn hover:text-warn text-sm font-semibold no-underline" ]
                    [ Html.text ("Report " ++ listing.trader) ]

              else
                Ui.empty
            ]
        ]


statusTag : FrontendModel -> Listing -> Html msg
statusTag model listing =
    let
        tag cls text =
            Html.span [ Attr.class ("font-bold text-[11px] tracking-[0.1em] px-2 py-1 rounded-md border " ++ cls), Ui.testId "listing-status" ] [ Html.text text ]
    in
    if listing.closed then
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
            , Html.a [ Attr.href ("/u/" ++ listing.trader) ] [ Html.text listing.trader ]
            ]
        , if Market.isLive model.now listing then
            Ui.empty

          else
            Html.div [ Attr.class "rounded-lg border border-[#6b5520] bg-[#1a1608] px-3 py-2 text-[13px] text-[#e9d9a6]", Ui.testId "pending-note" ]
                [ Html.text "Only you can see this for now. Every listing waits 15 minutes before going live, so no deal ever appears and disappears in seconds." ]
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
                    [ Html.text ("Preview estimate from " ++ String.fromInt est.counted ++ " prices by " ++ String.fromInt est.traders ++ " traders. Typical range " ++ Ui.formatInt est.low ++ "–" ++ Ui.formatInt est.high ++ ".") ]
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
    let
        amount =
            String.fromInt (abs pct) ++ "%"
    in
    if pct == 0 then
        "Right at the estimate"

    else
        case ( listing.side, pct > 0 ) of
            ( Selling, True ) ->
                "Asks " ++ amount ++ " above the estimate"

            ( Selling, False ) ->
                "Asks " ++ amount ++ " below the estimate"

            ( Buying, True ) ->
                "Pays " ++ amount ++ " above the estimate"

            ( Buying, False ) ->
                "Pays " ++ amount ++ " below the estimate"


offersSection : FrontendModel -> Listing -> Bool -> Html FrontendMsg
offersSection model listing isMine =
    let
        offers =
            Derived.offersFor model listing.id |> List.filter (\o -> o.status /= OfferWithdrawn)

        myOffer =
            Derived.myName model
                |> Maybe.andThen (\name -> offers |> List.filter (\o -> o.from == name && o.status == OfferOpen) |> List.head)
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
        , if isMine || listing.closed || not (Market.isLive model.now listing) then
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
                    Html.div [ Attr.class "text-xs text-leaf mt-1" ] [ Html.text "Accepted. When trading goes live, this opens a trade room with locked terms." ]

                OfferDeclined ->
                    Html.div [ Attr.class "text-xs text-warn mt-1" ] [ Html.text "Declined" ]

                OfferWithdrawn ->
                    Ui.empty

        isMyOffer =
            Derived.myName model == Just offer.from
    in
    Html.div [ Attr.class "rounded-lg bg-[#16232a] px-3.5 py-2.5", Ui.testId ("offer-" ++ String.fromInt offer.id) ]
        [ Html.div [ Attr.class "flex items-center gap-3 flex-wrap" ]
            [ Html.a [ Attr.href ("/u/" ++ offer.from), Attr.class "font-semibold text-ink hover:text-gold no-underline" ] [ Html.text offer.from ]
            , priceLabel
            , Html.span [ Attr.class "text-xs text-faint" ] [ Html.text (Ui.timeAgo model.now offer.at) ]
            , Html.div [ Attr.class "flex-1" ] []
            , if isMine && offer.status == OfferOpen && not listing.closed then
                Html.div [ Attr.class "flex gap-2" ]
                    [ Ui.button ("accept-" ++ String.fromInt offer.id) "rounded-lg bg-go hover:bg-gohi text-white text-xs font-bold tracking-wider px-3 py-1.5" (RespondToOfferClicked offer.id True) "ACCEPT"
                    , Ui.button ("decline-" ++ String.fromInt offer.id) "rounded-lg bg-raised border border-rule text-soft text-xs font-semibold px-3 py-1.5" (RespondToOfferClicked offer.id False) "Decline"
                    ]

              else if isMyOffer && offer.status == OfferOpen then
                Ui.button ("withdraw-" ++ String.fromInt offer.id) "rounded-lg bg-raised border border-rule text-soft text-xs font-semibold px-3 py-1.5" (WithdrawOfferClicked offer.id) "Withdraw"

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
        Html.a [ Attr.href "/signin", Attr.id "signin-to-offer", Attr.class "block text-center rounded-xl bg-go text-white hover:text-white no-underline font-bold tracking-wider py-3" ]
            [ Html.text "SIGN IN TO MAKE AN OFFER" ]

    else if not (Derived.isReady model) then
        Html.a [ Attr.href "/welcome", Attr.class "block text-center rounded-xl bg-raised border border-rule text-soft no-underline font-semibold py-3" ]
            [ Html.text "Link your WalkScape name to make offers" ]

    else
        let
            form =
                model.offerForm

            preview =
                case ( Derived.estimateFor model (Item.priceKey listing.itemId listing.variant), Ui.parseAmount form.price ) of
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
                                [ Html.text
                                    ((if Pricing.isWarning pct then
                                        "Heads up: "

                                      else
                                        ""
                                     )
                                        ++ String.fromInt (abs pct)
                                        ++ "% "
                                        ++ (if pct >= 0 then
                                                "above"

                                            else
                                                "below"
                                           )
                                        ++ " the preview estimate of "
                                        ++ Ui.formatInt est.median
                                        ++ "."
                                    )
                                ]

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
                , Html.textarea
                    [ Attr.id "offer-message"
                    , Attr.class "w-full rounded-xl bg-field border border-rule focus:border-gold outline-none px-4 py-3 text-ink placeholder:text-faint h-20"
                    , Attr.placeholder "When you're usually online, which mailbox you use…"
                    , Attr.value form.message
                    , Events.onInput OfferMessageChanged
                    ]
                    []
                ]
            , case form.error of
                Just err ->
                    Html.p [ Attr.class "text-sm text-warn", Ui.testId "offer-error" ] [ Html.text err ]

                Nothing ->
                    Ui.empty
            , Ui.primaryButton "send-offer"
                (OfferSubmitted listing.id)
                (if myOffer == Nothing then
                    "Send offer"

                 else
                    "Update offer"
                )
            , Html.p [ Attr.class "text-xs text-faint" ] [ Html.text "This is a preview, so nothing is traded. Offers show interest and help everyone see what items are worth." ]
            ]


traderCard : FrontendModel -> String -> Html msg
traderCard model name =
    let
        stats =
            Derived.traderStats model name

        trader =
            Dict.get name model.traders

        stat value text =
            Html.div [ Attr.class "rounded-[10px] bg-raised border border-edge px-3 py-2.5" ]
                [ Html.div [ Attr.class "font-bold text-lg" ] [ Html.text value ]
                , Html.div [ Attr.class "text-xs text-muted" ] [ Html.text text ]
                ]
    in
    Html.div [ Attr.class "flex flex-col gap-3", Ui.testId "trader-card" ]
        [ Html.a [ Attr.href ("/u/" ++ name), Attr.class "flex items-center gap-3.5 no-underline text-ink hover:text-ink" ]
            [ Ui.portrait "w-16 h-16 rounded-xl"
            , Html.div [ Attr.class "flex flex-col gap-1" ]
                [ Html.div [ Attr.class "font-display font-extrabold text-xl" ] [ Html.text name ]
                , Html.div [ Attr.class "flex items-center gap-2" ]
                    [ Ui.unverifiedTag
                    , case trader |> Maybe.andThen .discord of
                        Just handle ->
                            Html.span [ Attr.class "flex items-center gap-1 text-[13px] text-muted" ]
                                [ Ui.discordIcon "w-3.5 h-3.5", Html.text ("@" ++ handle) ]

                        Nothing ->
                            Ui.empty
                    ]
                ]
            ]
        , Html.div [ Attr.class "grid grid-cols-2 gap-2" ]
            [ stat (String.fromInt stats.activeListings) "active listings"
            , stat (String.fromInt stats.partners) "unique partners"
            , stat (String.fromInt stats.offersMade) "offers made"
            , stat (pluralDays stats.days) "on Trailpost"
            ]
        , case trader |> Maybe.andThen .lookalikeOf of
            Just original ->
                Html.div [ Attr.class "rounded-lg border border-[#6a3530] bg-[#2a1412] px-3 py-2 text-[13px] text-warn" ]
                    [ Html.text ("This name is one letter away from " ++ original ++ ", who joined earlier. Make sure you're trading with who you think.") ]

            Nothing ->
                Ui.empty
        ]


pluralDays : Int -> String
pluralDays days =
    if days == 1 then
        "1 day"

    else
        String.fromInt days ++ " days"


tricks : Html msg
tricks =
    Html.div [ Attr.class "rounded-xl border border-[#6b5520] bg-[#1d1708] p-4 flex flex-col gap-2.5 text-[13px] text-[#e9d9a6]" ]
        [ Html.div [ Attr.class "font-display font-extrabold text-lg text-gold" ] [ Html.text "Common tricks" ]
        , Html.p [] [ Html.text "Same item at a lower quality: an Eternal pickaxe turns into a Normal one. Check the outline colour." ]
        , Html.p [] [ Html.text "\"Someone else is buying in 2 minutes.\" Real buyers wait." ]
        , Html.p [] [ Html.text "A name that's one letter off (Mosbeard, Mossbeard_)." ]
        , Html.p [] [ Html.text "Asking you to \"go first\" with part of the payment." ]
        ]
