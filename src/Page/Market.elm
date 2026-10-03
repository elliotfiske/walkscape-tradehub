module Page.Market exposing (listingRow, view)

import Derived
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Item
import Market
import Pricing
import Route
import Time
import Types exposing (FrontendModel, FrontendMsg(..), Listing, MarketSort(..), MarketTab(..))
import Ui


view : FrontendModel -> Html FrontendMsg
view model =
    let
        listings =
            Derived.marketListings model
    in
    Html.div [ Attr.class "flex-1 grid md:grid-cols-[230px_minmax(0,1fr)] lg:grid-cols-[230px_minmax(0,1fr)_270px]" ]
        [ Html.aside [ Attr.class "hidden md:flex flex-col gap-[22px] border-r border-line px-5 py-[22px] text-sm" ] (filterPanel model)
        , Html.div [ Attr.class "flex flex-col gap-3.5 px-4 md:px-[26px] py-4 md:py-[22px] min-w-0" ]
            [ Html.input
                [ Attr.id "market-search"
                , Attr.class "md:hidden w-full h-11 rounded-[10px] border border-rule bg-field px-3.5 text-[15px] text-ink placeholder:text-faint outline-none focus:border-gold"
                , Attr.placeholder "Search items or traders…"
                , Attr.value model.filters.search
                , Events.onInput SearchChanged
                ]
                []
            , Html.div [ Attr.class "flex flex-col md:flex-row md:items-center justify-between gap-3" ]
                [ Html.div [ Attr.class "md:w-[440px]" ]
                    [ Ui.segmented
                        [ { id = "tab-all", label = "All", active = model.filters.tab == AllListings, msg = TabSelected AllListings }
                        , { id = "tab-selling", label = "Selling", active = model.filters.tab == SellingTab, msg = TabSelected SellingTab }
                        , { id = "tab-buying", label = "Buying", active = model.filters.tab == BuyingTab, msg = TabSelected BuyingTab }
                        ]
                    ]
                , Html.div [ Attr.class "flex items-center gap-4 justify-between" ]
                    [ Html.span [ Attr.class "text-muted text-[13px]", Ui.testId "listing-count" ]
                        [ Html.text (Ui.plural (List.length listings) "active listing" "active listings") ]
                    , postButton model
                    ]
                ]
            , Html.div [ Attr.class "md:hidden flex flex-wrap gap-2" ]
                [ Html.button [ Attr.id "filters-toggle", Events.onClick FiltersToggled, Attr.class "rounded-full border border-rule px-3 py-1.5 text-[13px] text-soft" ]
                    [ Html.text
                        (if model.filtersOpen then
                            "Hide filters ▴"

                         else
                            "Filters ▾"
                        )
                    ]
                ]
            , if model.filtersOpen then
                Html.div [ Attr.class "md:hidden flex flex-col gap-5 rounded-xl border border-edge bg-card p-4 text-sm" ] (filterPanel model)

              else
                Ui.empty
            , notices model
            , Html.div [ Attr.class "hidden md:grid grid-cols-[minmax(0,2.2fr)_0.8fr_1.6fr_1fr_1.7fr_0.7fr] gap-3 px-3.5 font-bold text-[11px] tracking-[0.12em] text-faint" ]
                [ Html.div [] [ Html.text "ITEM" ]
                , Html.div [] [ Html.text "TYPE" ]
                , Html.div [] [ Html.text "PRICE" ]
                , Html.div [] [ Html.text "VS ESTIMATE" ]
                , Html.div [] [ Html.text "TRADER" ]
                , Html.div [ Attr.class "text-right" ] [ Html.text "LISTED" ]
                ]
            , if List.isEmpty listings then
                emptyState model

              else
                Html.div [ Attr.class "flex flex-col gap-2", Ui.testId "listings" ] (List.map (listingRow model) listings)
            ]
        , Html.aside [ Attr.class "hidden lg:flex flex-col gap-3 border-l border-line px-5 py-[22px]" ] (mostActive model)
        ]


postButton : FrontendModel -> Html msg
postButton model =
    Html.a
        [ Attr.href
            (if Derived.isReady model then
                "/new"

             else if model.me == Nothing then
                "/signin"

             else
                "/welcome"
            )
        , Attr.id "post-listing-link"
        , Attr.class "flex-none rounded-[10px] bg-go hover:bg-gohi text-white hover:text-white no-underline font-bold tracking-wider text-[13px] px-4 py-2.5 border border-white/10"
        ]
        [ Html.text "POST A LISTING" ]


emptyState : FrontendModel -> Html msg
emptyState model =
    Html.div [ Attr.class "rounded-xl border border-dashed border-rule p-8 text-center text-muted", Ui.testId "empty-market" ]
        [ if Dict.isEmpty model.listings then
            Html.text "No listings yet. Post the first one and start the price history."

          else
            Html.text "No listings match these filters."
        ]


notices : FrontendModel -> Html FrontendMsg
notices model =
    if model.me == Nothing then
        Html.div [ Attr.class "flex flex-col sm:flex-row sm:items-center gap-3 rounded-xl border border-[#2e4b75] bg-gradient-to-br from-[#121b26] to-[#0f1820] px-3.5 py-3", Ui.testId "guest-notice" ]
            [ Html.div [ Attr.class "flex-1 text-sm text-[#b7cbe6]" ]
                [ Html.b [ Attr.class "text-[#d6e4f7]" ] [ Html.text "You're browsing as a guest. " ]
                , Html.text "Sign in and link your WalkScape name to post listings or make offers."
                ]
            , Html.a [ Attr.href "/signin", Attr.class "rounded-[10px] bg-go text-white hover:text-white no-underline font-bold tracking-wider text-sm px-5 py-2.5 text-center" ] [ Html.text "SIGN IN" ]
            ]

    else if model.noticeDismissed then
        Ui.empty

    else
        Html.div [ Attr.class "relative rounded-xl border border-[#2c4a3a] bg-[#0f1d17] pl-3.5 pr-11 py-3 flex flex-col gap-1", Ui.testId "timers-notice" ]
            [ Html.div [ Attr.class "font-display font-extrabold text-base text-[#9be07f]" ] [ Html.text "No timers here" ]
            , Html.div [ Attr.class "text-[13px] leading-snug text-body" ]
                [ Html.text "Listings don't expire on a countdown, and every new listing waits 15 minutes before anyone sees it. Watch out for false urgency. A trader who says a deal ends in five minutes is a common scam, meant to stop you from checking the item or the price." ]
            , Html.button [ Attr.id "dismiss-notice", Events.onClick NoticeDismissed, Attr.class "absolute top-2 right-2 w-[30px] h-[30px] rounded-md grid place-items-center text-muted hover:text-ink hover:bg-[#1a2a24] text-lg" ] [ Html.text "×" ]
            ]


filterPanel : FrontendModel -> List (Html FrontendMsg)
filterPanel model =
    let
        chip id text color active msg =
            Html.button
                [ Attr.id id
                , Events.onClick msg
                , Attr.class "px-2 py-1 rounded-md text-[12.5px]"
                , Attr.style "border" ("1px solid " ++ color)
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
                , Attr.style "font-weight"
                    (if active then
                        "700"

                     else
                        "500"
                    )
                ]
                [ Html.text text ]

        heading text =
            Html.div [ Attr.class "font-bold text-[11px] tracking-[0.14em] text-muted" ] [ Html.text text ]

        sortOption sort text =
            Html.option [ Attr.value text, Attr.selected (model.filters.sort == sort) ] [ Html.text text ]
    in
    [ Html.div [ Attr.class "flex flex-col gap-2" ]
        [ heading "SORT"
        , Html.select
            [ Attr.id "sort"
            , Attr.class "h-[38px] rounded-[9px] border border-rule bg-field px-2.5 text-soft"
            , Events.onInput
                (\v ->
                    case v of
                        "Lowest price" ->
                            SortSelected PriceLow

                        "Highest price" ->
                            SortSelected PriceHigh

                        _ ->
                            SortSelected Newest
                )
            ]
            [ sortOption Newest "Newest", sortOption PriceLow "Lowest price", sortOption PriceHigh "Highest price" ]
        ]
    , Html.div [ Attr.class "flex flex-col gap-2" ]
        [ heading "FINE ITEMS"
        , Html.div [ Attr.class "flex flex-wrap gap-1.5" ]
            [ chip "fine-only" "✦ Fine only" "#e3b54c" model.filters.fineOnly FineOnlyToggled ]
        , Html.div [ Attr.class "text-xs leading-snug text-faint" ] [ Html.text "Fine items are priced separately from regular ones." ]
        ]
    , Html.div [ Attr.class "flex flex-col gap-2" ]
        [ heading "RARITY · LOOT ITEMS"
        , Html.div [ Attr.class "flex flex-wrap gap-1.5" ]
            (Item.allRarities
                |> List.map
                    (\r ->
                        chip ("rarity-" ++ Item.rarityToString r) (Item.rarityLabel r) (Item.rarityColor r) (List.member r model.filters.rarities) (RarityToggled r)
                    )
            )
        ]
    , Html.div [ Attr.class "flex flex-col gap-2" ]
        [ heading "QUALITY · CRAFTED ITEMS"
        , Html.div [ Attr.class "flex flex-wrap gap-1.5" ]
            (Item.allQualities
                |> List.map
                    (\q ->
                        chip ("quality-" ++ Item.qualityToString q) (Item.qualityLabel q) (Item.qualityColor q) (List.member q model.filters.qualities) (QualityToggled q)
                    )
            )
        , Html.div [ Attr.class "text-xs leading-snug text-faint" ] [ Html.text "Prices for crafted items are tracked separately for each quality." ]
        ]
    , Html.button [ Attr.id "hide-outliers", Events.onClick HideOutliersToggled, Attr.class "flex justify-between items-center text-body" ]
        [ Html.text "Hide outliers"
        , Html.span
            [ Attr.class
                ("relative w-[34px] h-5 rounded-full "
                    ++ (if model.filters.hideOutliers then
                            "bg-go"

                        else
                            "bg-rule"
                       )
                )
            ]
            [ Html.span
                [ Attr.class
                    ("absolute top-0.5 w-4 h-4 rounded-full "
                        ++ (if model.filters.hideOutliers then
                                "left-4 bg-white"

                            else
                                "left-0.5 bg-muted"
                           )
                    )
                ]
                []
            ]
        ]
    ]


listingRow : FrontendModel -> Listing -> Html msg
listingRow model listing =
    case Market.item listing of
        Nothing ->
            Ui.empty

        Just item ->
            let
                trader =
                    Dict.get listing.trader model.traders

                stats =
                    Derived.traderStats model listing.trader

                estimate =
                    Derived.listingEstimate model listing

                lookalike =
                    trader |> Maybe.andThen .lookalikeOf

                flagged =
                    lookalike /= Nothing || (estimate |> Maybe.map (\( _, pct ) -> pct <= -50) |> Maybe.withDefault False)

                pending =
                    not (Market.isLive model.now listing)

                vsEstimate =
                    case estimate of
                        Just ( est, pct ) ->
                            Html.div [ Attr.class "leading-tight" ]
                                [ Html.div
                                    [ Attr.class
                                        ("font-bold text-sm "
                                            ++ (if pct <= -Pricing.warnPercent then
                                                    "text-warn"

                                                else if pct >= 5 then
                                                    "text-gold"

                                                else
                                                    "text-leaf"
                                               )
                                        )
                                    ]
                                    [ Html.text (signedPercent pct) ]
                                , Html.div [ Attr.class "text-[11px] text-faint" ] [ Html.text ("vs " ++ Ui.formatInt est.median) ]
                                ]

                        Nothing ->
                            Html.div [ Attr.class "text-xs text-faint" ] [ Html.text "—" ]

                traderLine =
                    Ui.plural stats.activeListings "listing" "listings" ++ " · " ++ Ui.plural stats.partners "partner" "partners"

                listed =
                    if pending then
                        Html.span [ Attr.class "text-gold text-xs font-semibold" ] [ Html.text ("live in " ++ minutesUntil model.now listing.liveAt) ]

                    else
                        Html.text (Ui.timeAgo model.now listing.createdAt)

                title =
                    Html.div [ Attr.class "font-semibold whitespace-nowrap overflow-hidden text-ellipsis" ]
                        [ Html.span [ Attr.class "text-leaf" ] [ Html.text (String.fromInt listing.quantity ++ "x") ]
                        , Html.text (" " ++ Item.displayName item listing.variant)
                        ]
            in
            Html.a
                [ Attr.href ("/listing/" ++ String.fromInt listing.id)
                , Attr.class
                    ("block no-underline text-ink hover:text-ink rounded-[10px] bg-card border hover:bg-raised "
                        ++ (if flagged then
                                "border-[#6a3530]"

                            else
                                "border-[#22343d]"
                           )
                    )
                , Ui.testId ("listing-" ++ String.fromInt listing.id)
                ]
                [ -- Desktop: table row
                  Html.div [ Attr.class "hidden md:grid grid-cols-[minmax(0,2.2fr)_0.8fr_1.6fr_1fr_1.7fr_0.7fr] gap-3 items-center px-3.5 py-2.5 text-sm" ]
                    [ Html.div [ Attr.class "flex items-center gap-3 min-w-0" ]
                        [ Ui.itemIcon "w-10 h-10" item listing.variant
                        , Html.div [ Attr.class "min-w-0" ] [ title, Ui.gradeTag item listing.variant ]
                        ]
                    , Html.div [] [ Ui.sideBadge listing ]
                    , Html.div [] [ Ui.priceText listing ]
                    , vsEstimate
                    , Html.div [ Attr.class "min-w-0 leading-tight" ]
                        [ Html.div [ Attr.class "font-semibold truncate" ] [ Html.text listing.trader ]
                        , Html.div [ Attr.class "text-[11px] text-faint" ] [ Html.text traderLine ]
                        ]
                    , Html.div [ Attr.class "text-right text-[13px] text-muted" ] [ listed ]
                    ]

                -- Mobile: card
                , Html.div [ Attr.class "md:hidden flex gap-3 p-3" ]
                    [ Ui.itemIcon "w-[52px] h-[52px]" item listing.variant
                    , Html.div [ Attr.class "flex-1 min-w-0 flex flex-col gap-1" ]
                        [ Html.div [ Attr.class "flex items-center gap-2" ]
                            [ Html.div [ Attr.class "flex-1 min-w-0 flex items-baseline gap-2" ] [ title, Ui.gradeTag item listing.variant ]
                            , Ui.sideBadge listing
                            ]
                        , Html.div [ Attr.class "flex items-center justify-between gap-2" ]
                            [ Ui.priceText listing
                            , case estimate of
                                Just ( est, pct ) ->
                                    Html.span [ Attr.class "text-xs text-faint" ]
                                        [ Html.span [ Attr.class "font-bold text-soft" ] [ Html.text (signedPercent pct) ], Html.text (" vs " ++ Ui.formatInt est.median) ]

                                Nothing ->
                                    Ui.empty
                            ]
                        , Html.div [ Attr.class "flex items-center justify-between text-xs text-faint" ]
                            [ Html.span [] [ Html.b [ Attr.class "text-soft" ] [ Html.text listing.trader ], Html.text (" " ++ traderLine) ]
                            , Html.span [] [ listed ]
                            ]
                        ]
                    ]
                , case lookalike of
                    Just original ->
                        Html.div [ Attr.class "px-3.5 pb-2.5 text-xs text-warn", Ui.testId "lookalike-warning" ]
                            [ Html.text ("This name is very close to " ++ original ++ ", who joined earlier. Check the spelling in-game.") ]

                    Nothing ->
                        Ui.empty
                ]


signedPercent : Int -> String
signedPercent pct =
    if pct > 0 then
        "+" ++ String.fromInt pct ++ "%"

    else if pct < 0 then
        "−" ++ String.fromInt (abs pct) ++ "%"

    else
        "0%"


minutesUntil : Time.Posix -> Time.Posix -> String
minutesUntil now t =
    String.fromInt (max 1 ((Time.posixToMillis t - Time.posixToMillis now + 59999) // 60000)) ++ "m"


mostActive : FrontendModel -> List (Html msg)
mostActive model =
    let
        series =
            model.listings
                |> Dict.values
                |> List.filter (Market.isLive model.now)
                |> List.map (\l -> ( Item.priceKey l.itemId l.variant, ( l.itemId, l.variant ) ))
                |> Dict.fromList
                |> Dict.toList
                |> List.filterMap
                    (\( key, ( itemId, quality ) ) ->
                        Maybe.map2 (\item est -> ( item, quality, est ))
                            (Item.byId itemId)
                            (Derived.estimateFor model key)
                    )
                |> List.sortBy (\( _, _, est ) -> negate (est.counted + est.excluded))
                |> List.take 6
    in
    Html.div [ Attr.class "font-bold text-[11px] tracking-[0.14em] text-muted mb-1" ] [ Html.text "MOST ACTIVE · PREVIEW" ]
        :: (if List.isEmpty series then
                [ Html.p [ Attr.class "text-[13px] text-faint" ] [ Html.text "Items with the most listings and offers will show here." ] ]

            else
                List.map
                    (\( item, quality, est ) ->
                        Html.a
                            [ Attr.href (Route.toString (Route.ItemPrice item.id quality))
                            , Attr.class "flex items-center gap-2.5 no-underline text-ink hover:text-ink"
                            ]
                            [ Ui.itemIcon "w-[30px] h-[30px] rounded-md" item quality
                            , Html.div [ Attr.class "flex-1 min-w-0 leading-tight" ]
                                [ Html.div [ Attr.class "font-semibold text-sm truncate" ] [ Html.text (Item.fullName item quality) ]
                                , Html.div [ Attr.class "text-[11px] text-faint" ] [ Html.text (Ui.plural est.counted "price" "prices" ++ " · " ++ Ui.plural est.traders "trader" "traders") ]
                                ]
                            , Html.div [ Attr.class "font-bold text-sm text-gold" ] [ Html.text (Ui.formatInt est.median) ]
                            ]
                    )
                    series
           )
