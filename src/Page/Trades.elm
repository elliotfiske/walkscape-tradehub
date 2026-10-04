module Page.Trades exposing (view)

import Derived
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Item
import Market
import Time
import Types exposing (FrontendModel, FrontendMsg(..), Listing, Offer, OfferStatus(..), TradesTab(..))
import Ui


view : FrontendModel -> Html FrontendMsg
view model =
    case ( Derived.isReady model, Derived.myName model ) of
        ( True, Just name ) ->
            let
                myListings =
                    model.listings
                        |> Dict.values
                        |> List.filter (\l -> l.trader == name)
                        |> List.sortBy (.createdAt >> Time.posixToMillis >> negate)

                received =
                    Derived.offersReceived model name

                sent =
                    Derived.offersSent model name

                tabLabel text n =
                    text ++ " " ++ String.fromInt n
            in
            Html.div [ Attr.class "w-full max-w-2xl mx-auto px-4 py-5 flex flex-col gap-4" ]
                [ Html.h1 [ Attr.class "font-display font-extrabold text-[28px] text-gold" ] [ Html.text "My trades" ]
                , Ui.segmented
                    [ { id = "trades-received", label = tabLabel "Received" (List.length received), active = model.tradesTab == ReceivedTab, msg = TradesTabSelected ReceivedTab }
                    , { id = "trades-sent", label = tabLabel "Sent" (List.length sent), active = model.tradesTab == SentTab, msg = TradesTabSelected SentTab }
                    , { id = "trades-listings", label = tabLabel "Listings" (List.length myListings), active = model.tradesTab == MyListingsTab, msg = TradesTabSelected MyListingsTab }
                    ]
                , Html.div [ Attr.class "flex flex-col gap-2.5", Ui.testId "trades-list" ]
                    (case model.tradesTab of
                        ReceivedTab ->
                            orEmpty "No offers on your listings yet." (List.filterMap (offerCard model True) received)

                        SentTab ->
                            orEmpty "You haven't made any offers yet." (List.filterMap (offerCard model False) sent)

                        MyListingsTab ->
                            orEmpty "You haven't posted anything yet." (List.filterMap (listingCard model) myListings)
                    )
                , Html.p [ Attr.class "text-[13px] text-faint" ]
                    [ Html.text "In the preview, accepting an offer just records that you'd trade. Once trading is live, it opens a trade room with locked terms and an in-game checklist." ]
                ]

        _ ->
            Html.div [ Attr.class "w-full max-w-xl mx-auto px-4 py-6" ]
                [ Ui.nameGate (Derived.onboardingRoute model) "Your offers and listings show up here." ]


orEmpty : String -> List (Html msg) -> List (Html msg)
orEmpty text items =
    if List.isEmpty items then
        [ Html.p [ Attr.class "rounded-xl border border-dashed border-rule p-6 text-center text-muted" ] [ Html.text text ] ]

    else
        items


progress : Int -> String -> Html msg
progress filled color =
    Html.div [ Attr.class "grid grid-cols-3 gap-1.5 my-2.5" ]
        (List.range 1 3
            |> List.map
                (\i ->
                    Html.div
                        [ Attr.class "h-1 rounded-full"
                        , Attr.style "background"
                            (if i <= filled then
                                color

                             else
                                "#1e2c33"
                            )
                        ]
                        []
                )
        )


offerCard : FrontendModel -> Bool -> Offer -> Maybe (Html msg)
offerCard model received offer =
    Dict.get offer.listingId model.listings
        |> Maybe.andThen (\l -> Market.item l |> Maybe.map (Tuple.pair l))
        |> Maybe.map
            (\( listing, item ) ->
                let
                    other =
                        if received then
                            offer.from

                        else
                            listing.trader

                    ( filled, color, status ) =
                        case offer.status of
                            OfferOpen ->
                                if listing.closed then
                                    ( 0, "#6d7d85", "Listing closed" )

                                else if received then
                                    ( 1, "#e3b54c", "Your turn: accept or decline this offer" )

                                else
                                    ( 1, "#5aa2e6", "Offer sent · waiting for " ++ other )

                            OfferAccepted ->
                                ( 2, "#57b34a", "Accepted · trade room opens when trading is live" )

                            OfferDeclined ->
                                ( 3, "#c0453b", "Declined" )

                            OfferWithdrawn ->
                                ( 0, "#6d7d85", "Withdrawn" )

                    priceText =
                        case offer.price of
                            Just p ->
                                " · " ++ Ui.formatInt p ++ " ea"

                            Nothing ->
                                " · at listed price"

                    highlight =
                        received && Derived.awaitsResponse model offer
                in
                Html.a
                    [ Attr.href ("/listing/" ++ String.fromInt listing.id)
                    , Attr.class
                        ("block no-underline text-ink hover:text-ink rounded-xl bg-card border px-3.5 py-3 hover:bg-raised "
                            ++ (if highlight then
                                    "border-[#6b5520]"

                                else
                                    "border-edge"
                               )
                        )
                    , Ui.testId ("trade-offer-" ++ String.fromInt offer.id)
                    ]
                    [ Html.div [ Attr.class "flex items-center gap-3" ]
                        [ Ui.itemIcon "w-10 h-10" item listing.variant
                        , Html.div [ Attr.class "flex-1 min-w-0" ]
                            [ Html.div [ Attr.class "font-bold truncate" ] [ Html.text (String.fromInt listing.quantity ++ "x " ++ item.name), Html.text " ", Ui.fineTag listing.variant ]
                            , Html.div [ Attr.class "text-xs text-muted" ] [ Html.text ("with " ++ other ++ priceText) ]
                            ]
                        , Html.span [ Attr.class "text-xs text-faint" ] [ Html.text (Ui.timeAgo model.now offer.at) ]
                        ]
                    , progress filled color
                    , Html.div [ Attr.class "text-[13px] font-semibold", Attr.style "color" color ] [ Html.text status ]
                    ]
            )


listingCard : FrontendModel -> Listing -> Maybe (Html msg)
listingCard model listing =
    Market.item listing
        |> Maybe.map
            (\item ->
                let
                    openOffers =
                        Derived.offersFor model listing.id |> List.filter (\o -> o.status == OfferOpen) |> List.length

                    status =
                        if listing.closed then
                            Html.span [ Attr.class "text-muted" ] [ Html.text "Closed" ]

                        else if not (Market.isLive model.now listing) then
                            Html.span [ Attr.class "text-gold" ] [ Html.text "Waiting to go live" ]

                        else
                            Html.span [ Attr.class "text-leaf" ] [ Html.text ("Live · " ++ String.fromInt openOffers ++ " open offers") ]
                in
                Html.a
                    [ Attr.href ("/listing/" ++ String.fromInt listing.id)
                    , Attr.class "flex items-center gap-3 no-underline text-ink hover:text-ink rounded-xl bg-card border border-edge px-3.5 py-3 hover:bg-raised"
                    , Ui.testId ("my-listing-" ++ String.fromInt listing.id)
                    ]
                    [ Ui.itemIcon "w-10 h-10" item listing.variant
                    , Html.div [ Attr.class "flex-1 min-w-0" ]
                        [ Html.div [ Attr.class "font-bold truncate" ] [ Html.text (String.fromInt listing.quantity ++ "x " ++ Item.fullName item listing.variant), Html.text " ", Ui.fineTag listing.variant ]
                        , Html.div [ Attr.class "text-[13px] font-semibold" ] [ status ]
                        ]
                    , Ui.priceText listing
                    ]
            )
