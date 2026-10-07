module Page.Admin exposing (view)

{-| Moderation for the people listed in `Env.adminDiscordUsernames`: reports,
every listing and offer (including ones that aren't live yet), players, and a
log of what admins did. The backend checks every request, so this page only
decides what to show.
-}

import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Market
import Route
import Time
import Types exposing (AdminAction(..), AdminData, AdminTab(..), AdminUser, FrontendModel, FrontendMsg(..), Listing, Offer, OfferStatus(..), Report)
import Ui


view : FrontendModel -> Html FrontendMsg
view model =
    case ( Maybe.map .isAdmin model.me, model.admin ) of
        ( Just True, Just data ) ->
            viewAdmin model data

        ( Just True, Nothing ) ->
            Ui.pageMessage [] [ Html.text "Loading…" ]

        _ ->
            Ui.pageMessage [ Ui.testId "admin-only" ] [ Html.text "This page is only for admins." ]


viewAdmin : FrontendModel -> AdminData -> Html FrontendMsg
viewAdmin model data =
    let
        page =
            model.adminPage

        openReports =
            List.filter (not << .resolved) data.reports

        tab id label count tab_ =
            { id = id
            , label =
                case count of
                    Just n ->
                        label ++ " " ++ String.fromInt n

                    Nothing ->
                        label
            , active = page.tab == tab_
            , msg = AdminTabSelected tab_
            }
    in
    Html.div [ Attr.class "w-full max-w-4xl mx-auto px-4 py-5 flex flex-col gap-4" ]
        [ Html.div [ Attr.class "flex items-center gap-3" ]
            [ Html.h1 [ Attr.class "font-display font-extrabold text-[28px] text-gold flex-1" ] [ Html.text "Admin" ]
            , Ui.button Ui.Secondary Ui.Compact "admin-refresh" AdminRefreshClicked "Refresh"
            ]
        , Html.div [ Attr.class "grid grid-cols-3 md:grid-cols-6 gap-2", Ui.testId "admin-stats" ]
            [ Ui.stat "text-ink" (String.fromInt data.accounts) "accounts"
            , Ui.stat "text-ink" (String.fromInt (List.length data.users)) "named players"
            , Ui.stat "text-leaf" (String.fromInt (List.length (List.filter (\l -> not l.closed && Market.isLive model.now l) data.listings))) "live listings"
            , Ui.stat "text-ink" (String.fromInt (List.length (List.filter (\o -> o.status == OfferOpen) data.offers))) "open offers"
            , Ui.stat "text-gold" (String.fromInt (List.length openReports)) "open reports"
            , Ui.stat "text-warn" (String.fromInt (List.length (List.filter (\u -> u.ban /= Nothing) data.users))) "banned"
            ]
        , Ui.segmented
            [ tab "admin-tab-reports" "Reports" (Just (List.length openReports)) AdminReports
            , tab "admin-tab-listings" "Listings" (Just (List.length data.listings)) AdminListings
            , tab "admin-tab-players" "Players" (Just (List.length data.users)) AdminPlayers
            , tab "admin-tab-log" "Log" Nothing AdminLog
            ]
        , if page.tab == AdminListings || page.tab == AdminPlayers then
            Ui.textInput [ Attr.id "admin-search", Attr.placeholder "Search by player or item…" ] page.search AdminSearchChanged

          else
            Ui.empty
        , Html.div [ Attr.class "flex flex-col gap-2.5" ]
            (case page.tab of
                AdminReports ->
                    orEmpty "No reports yet."
                        (List.map (reportCard model data) (openReports ++ List.filter .resolved data.reports))

                AdminListings ->
                    data.listings
                        |> List.filter (matches page.search << listingSearchText)
                        |> List.sortBy (.createdAt >> Time.posixToMillis >> negate)
                        |> List.map (listingCard model data)
                        |> orEmpty "No listings."

                AdminPlayers ->
                    data.users
                        |> List.filter (matches page.search << playerSearchText)
                        |> List.sortBy (.joinedAt >> Time.posixToMillis >> negate)
                        |> List.map (playerCard model data)
                        |> orEmpty "No players."

                AdminLog ->
                    data.log
                        |> List.map
                            (\entry ->
                                Html.div [ Attr.class "flex gap-3 items-baseline text-sm border-b border-line py-2" ]
                                    [ Html.span [ Attr.class "text-faint text-xs w-20 flex-none" ] [ Html.text (Ui.timeAgo model.now entry.at) ]
                                    , Html.span [ Attr.class "text-soft font-semibold flex-none" ] [ Html.text entry.by ]
                                    , Html.span [ Attr.class "text-body" ] [ Html.text entry.text ]
                                    ]
                            )
                        |> orEmpty "Nothing yet. Every admin action is written down here."
            )
        ]


orEmpty : String -> List (Html msg) -> List (Html msg)
orEmpty text items =
    if List.isEmpty items then
        [ Html.p [ Attr.class "rounded-xl border border-dashed border-rule p-6 text-center text-muted" ] [ Html.text text ] ]

    else
        items


matches : String -> String -> Bool
matches search text =
    String.contains (String.toLower (String.trim search)) (String.toLower text)


listingSearchText : Listing -> String
listingSearchText listing =
    listing.trader ++ " " ++ Market.describe listing


playerSearchText : AdminUser -> String
playerSearchText user =
    user.name ++ " " ++ Maybe.withDefault "" user.discord


profileLink : String -> Html msg
profileLink name =
    Html.a [ Attr.href (Route.toString (Route.Profile name)), Attr.class "font-semibold" ] [ Html.text name ]


{-| The second click for a destructive action, shown under the card it belongs to.
-}
confirmBox : FrontendModel -> AdminAction -> Html FrontendMsg
confirmBox model action =
    if model.adminPage.confirming /= Just action then
        Ui.empty

    else
        let
            ( question, confirmLabel ) =
                case action of
                    DeleteListing _ ->
                        ( "Delete this listing and every offer on it? This can't be undone.", "Delete listing" )

                    DeleteOffer _ ->
                        ( "Delete this offer? This can't be undone.", "Delete offer" )

                    BanPlayer name _ ->
                        ( "Ban " ++ name ++ "? Their listings and offers are deleted, and they can't post, make offers or report anyone until they're unbanned.", "Ban " ++ name )

                    ReleaseName name ->
                        ( "Release the name " ++ name ++ "? Their listings and offers are deleted, and the account has to claim a name again. Anyone can then claim " ++ name ++ ".", "Release name" )

                    UnbanPlayer name ->
                        ( "Unban " ++ name ++ "?", "Unban" )

                    SetReportResolved _ _ ->
                        ( "", "OK" )

            needsReason =
                case action of
                    BanPlayer _ _ ->
                        True

                    _ ->
                        False

            canConfirm =
                not needsReason || String.trim model.adminPage.banReason /= ""
        in
        Ui.callout Ui.Bad
            [ Attr.class "p-3 flex flex-col gap-2.5 text-sm", Ui.testId "admin-confirm-box" ]
            [ Html.p [] [ Html.text question ]
            , if needsReason then
                Ui.textInput [ Attr.id "ban-reason", Attr.placeholder "Why? Other admins and the player see this." ] model.adminPage.banReason AdminBanReasonChanged

              else
                Ui.empty
            , Html.div [ Attr.class "flex gap-2" ]
                [ Html.button
                    [ Attr.id "admin-confirm"
                    , Attr.type_ "button"
                    , Ui.buttonStyle Ui.Danger Ui.Compact
                    , Attr.disabled (not canConfirm)
                    , Attr.class "disabled:opacity-40"
                    , Events.onClick AdminConfirmed
                    ]
                    [ Html.text confirmLabel ]
                , Ui.button Ui.Secondary Ui.Compact "admin-cancel" AdminCancelled "Cancel"
                ]
            ]


reportCard : FrontendModel -> AdminData -> Report -> Html FrontendMsg
reportCard model data report =
    let
        idText =
            String.fromInt report.id

        aboutUser =
            List.filter (\u -> u.name == report.about) data.users |> List.head

        banAction =
            BanPlayer report.about ""
    in
    Html.div [ Attr.class "flex flex-col gap-2", Ui.testId ("admin-report-" ++ idText) ]
        [ Ui.card
            [ Attr.class
                ("p-3.5 flex flex-col gap-2 "
                    ++ (if report.resolved then
                            "opacity-60"

                        else
                            ""
                       )
                )
            ]
            [ Html.div [ Attr.class "flex items-baseline gap-2 flex-wrap text-sm" ]
                [ profileLink report.reporter
                , Html.span [ Attr.class "text-muted" ] [ Html.text "reported" ]
                , profileLink report.about
                , if Maybe.andThen .ban aboutUser /= Nothing then
                    Ui.bannedTag

                  else
                    Ui.empty
                , Html.span [ Attr.class "flex-1" ] []
                , Html.span [ Attr.class "text-xs text-faint" ] [ Html.text (Ui.timeAgo model.now report.at) ]
                ]
            , Html.div [ Attr.class "flex flex-wrap gap-1.5" ]
                (report.reasons
                    |> List.map (\r -> Html.span [ Attr.class "rounded-md border border-[#7a3a34] bg-[#2a1412] text-[#f6c9c2] text-xs px-2 py-0.5" ] [ Html.text r ])
                )
            , if String.isEmpty (String.trim report.details) then
                Ui.empty

              else
                Html.p [ Attr.class "text-sm text-body whitespace-pre-wrap" ] [ Html.text report.details ]
            , case report.trade of
                Just trade ->
                    reportedTrade data report trade

                Nothing ->
                    Ui.empty
            , reportScreenshots model report
            , Html.div [ Attr.class "flex gap-2 flex-wrap" ]
                [ if report.resolved then
                    Ui.button Ui.Secondary Ui.Compact ("admin-reopen-" ++ idText) (AdminActionClicked (SetReportResolved report.id False)) "Reopen"

                  else
                    Ui.button Ui.Primary Ui.Compact ("admin-resolve-" ++ idText) (AdminActionClicked (SetReportResolved report.id True)) "Mark resolved"
                , case aboutUser of
                    Just user ->
                        if user.ban == Nothing && not user.isAdmin then
                            Ui.button Ui.Danger Ui.Compact ("admin-report-ban-" ++ idText) (AdminActionClicked banAction) ("Ban " ++ report.about)

                        else
                            Ui.empty

                    Nothing ->
                        Ui.empty
                ]
            ]
        , confirmBox model banAction
        ]


{-| The trade a report is about, as it was when it was reported, and how it
stands now if the offer still exists.
-}
reportedTrade : AdminData -> Report -> Types.ReportedTrade -> Html msg
reportedTrade data report trade =
    let
        before =
            tradeStatus trade.offer.status

        now =
            data.offers |> List.filter (\o -> o.id == trade.offer.id) |> List.head |> Maybe.map (.status >> tradeStatus)
    in
    Html.div [ Attr.class "rounded-lg bg-raised border border-edge px-3 py-2 text-sm flex flex-col gap-0.5", Ui.testId ("admin-report-trade-" ++ String.fromInt report.id) ]
        [ Html.a [ Attr.href ("/listing/" ++ String.fromInt trade.listing.id), Attr.class "text-ink font-semibold no-underline hover:text-gold" ]
            [ Html.text (Market.describeTrade trade.listing trade.offer) ]
        , Html.span [ Attr.class "text-xs text-muted" ]
            [ Html.text
                ("When reported: "
                    ++ before
                    ++ (case now of
                            Just status ->
                                if status == before then
                                    ""

                                else
                                    " · now: " ++ status

                            Nothing ->
                                " · the offer has been deleted since"
                       )
                )
            ]
        ]


tradeStatus : OfferStatus -> String
tradeStatus status =
    case status of
        OfferOpen ->
            "Open"

        OfferAccepted ->
            "Trade pending"

        OfferCompleted _ ->
            "Traded"

        OfferFellThrough fell ->
            "Fell through (" ++ fell.by ++ ": " ++ fell.reason ++ ")"

        OfferDeclined ->
            "Declined"

        OfferWithdrawn ->
            "Withdrawn"


reportScreenshots : FrontendModel -> Report -> Html FrontendMsg
reportScreenshots model report =
    let
        idText =
            String.fromInt report.id
    in
    if List.isEmpty report.screenshots then
        Ui.empty

    else
        case Dict.get report.id model.adminScreenshots of
            Just screenshots ->
                Html.div [ Attr.class "flex flex-col gap-2" ]
                    (screenshots
                        |> List.indexedMap
                            (\i src ->
                                Html.img [ Attr.src src, Attr.alt ("Screenshot " ++ String.fromInt (i + 1)), Attr.class "w-full rounded-lg border border-edge", Ui.testId ("admin-screenshot-" ++ idText ++ "-" ++ String.fromInt i) ] []
                            )
                    )

            Nothing ->
                Html.div []
                    [ Ui.button Ui.Secondary
                        Ui.Compact
                        ("admin-show-screenshots-" ++ idText)
                        (AdminShowScreenshotsClicked report.id)
                        ("Show " ++ Ui.plural (List.length report.screenshots) "screenshot" "screenshots")
                    ]


listingCard : FrontendModel -> AdminData -> Listing -> Html FrontendMsg
listingCard model data listing =
    let
        idText =
            String.fromInt listing.id

        offers =
            data.offers
                |> List.filter (\o -> o.listingId == listing.id)
                |> List.sortBy (.at >> Time.posixToMillis >> negate)

        ( statusText, statusClass ) =
            if Market.tradePending listing.id data.offers then
                ( "Trade pending", "text-gold" )

            else if listing.closed then
                ( "Closed", "text-muted" )

            else if Market.isLive model.now listing then
                ( "Live", "text-leaf" )

            else
                ( "Waiting to go live", "text-gold" )
    in
    Html.div [ Attr.class "flex flex-col gap-2", Ui.testId ("admin-listing-" ++ idText) ]
        [ Ui.card [ Attr.class "p-3.5 flex flex-col gap-2" ]
            [ Html.div [ Attr.class "flex items-center gap-3" ]
                [ case Market.item listing of
                    Just item ->
                        Ui.itemIcon "w-10 h-10" item listing.variant

                    Nothing ->
                        Ui.empty
                , Html.div [ Attr.class "flex-1 min-w-0" ]
                    [ Html.a [ Attr.href ("/listing/" ++ idText), Attr.class "font-bold text-ink block truncate" ]
                        [ Html.text ("#" ++ idText ++ " " ++ Market.describe listing) ]
                    , Html.div [ Attr.class "text-xs text-muted flex gap-1.5 flex-wrap" ]
                        [ Html.text "by"
                        , profileLink listing.trader
                        , Html.text ("· " ++ Ui.timeAgo model.now listing.createdAt ++ " ·")
                        , Html.span [ Attr.class statusClass ] [ Html.text statusText ]
                        ]
                    ]
                , Ui.priceText listing
                , Ui.button Ui.Danger Ui.Compact ("admin-delete-listing-" ++ idText) (AdminActionClicked (DeleteListing listing.id)) "Delete"
                ]
            , if String.isEmpty listing.note then
                Ui.empty

              else
                Html.p [ Attr.class "text-sm text-body" ] [ Html.text ("“" ++ listing.note ++ "”") ]
            , if List.isEmpty offers then
                Ui.empty

              else
                Html.div [ Attr.class "flex flex-col border-t border-line pt-1" ] (List.map (offerRow model) offers)
            ]
        , confirmBox model (DeleteListing listing.id)
        , Html.div [ Attr.class "flex flex-col gap-2" ] (List.map (\o -> confirmBox model (DeleteOffer o.id)) offers)
        ]


offerRow : FrontendModel -> Offer -> Html FrontendMsg
offerRow model offer =
    let
        idText =
            String.fromInt offer.id

        status =
            case offer.status of
                OfferOpen ->
                    "open"

                OfferAccepted ->
                    "accepted, trade pending"
                        ++ (case ( offer.listerConfirmed, offer.offererConfirmed ) of
                                ( True, False ) ->
                                    " (lister confirmed)"

                                ( False, True ) ->
                                    " (offerer confirmed)"

                                _ ->
                                    ""
                           )

                OfferCompleted at ->
                    "traded " ++ Ui.timeAgo model.now at

                OfferFellThrough fell ->
                    "fell through (" ++ fell.by ++ ": " ++ fell.reason ++ ")"

                OfferDeclined ->
                    "declined"

                OfferWithdrawn ->
                    "withdrawn"
    in
    Html.div [ Attr.class "flex items-center gap-2 text-sm py-1.5", Ui.testId ("admin-offer-" ++ idText) ]
        [ Html.div [ Attr.class "flex-1 min-w-0 flex flex-wrap gap-x-1.5 items-baseline" ]
            [ Html.span [ Attr.class "text-muted" ] [ Html.text "Offer from" ]
            , profileLink offer.from
            , Html.span [ Attr.class "text-soft" ]
                [ Html.text
                    (Ui.offerSummary offer)
                ]
            , Html.span [ Attr.class "text-faint text-xs" ] [ Html.text (status ++ " · " ++ Ui.timeAgo model.now offer.at) ]
            , if String.isEmpty offer.message then
                Ui.empty

              else
                Html.span [ Attr.class "text-body basis-full" ] [ Html.text ("“" ++ offer.message ++ "”") ]
            ]
        , Html.button
            [ Attr.id ("admin-delete-offer-" ++ idText)
            , Attr.type_ "button"
            , Attr.class "text-warn text-xs font-semibold px-2 py-1"
            , Events.onClick (AdminActionClicked (DeleteOffer offer.id))
            ]
            [ Html.text "Delete" ]
        ]


playerCard : FrontendModel -> AdminData -> AdminUser -> Html FrontendMsg
playerCard model data user =
    let
        count f items =
            List.length (List.filter f items)

        listings =
            count (\l -> l.trader == user.name && not l.closed) data.listings

        offers =
            count (\o -> o.from == user.name) data.offers

        reportsAgainst =
            count (\r -> r.about == user.name && not r.resolved) data.reports
    in
    Html.div [ Attr.class "flex flex-col gap-2", Ui.testId ("admin-player-" ++ user.name) ]
        [ Ui.card [ Attr.class "p-3.5 flex flex-col gap-2" ]
            [ Html.div [ Attr.class "flex items-center gap-3 flex-wrap" ]
                [ Html.div [ Attr.class "flex-1 min-w-0 flex flex-col gap-1" ]
                    [ Html.div [ Attr.class "flex items-center gap-2 flex-wrap" ]
                        [ if user.ready then
                            profileLink user.name

                          else
                            Html.span [ Attr.class "font-semibold" ] [ Html.text user.name ]
                        , if user.isAdmin then
                            Html.span [ Attr.class "font-bold text-[10px] tracking-widest text-leaf border border-leaf/50 rounded px-1.5 py-0.5" ] [ Html.text "ADMIN" ]

                          else
                            Ui.empty
                        , if user.ban /= Nothing then
                            Ui.bannedTag

                          else
                            Ui.empty
                        , if user.ready then
                            Ui.empty

                          else
                            Html.span [ Attr.class "text-xs text-faint" ] [ Html.text "hasn't finished sign-up" ]
                        ]
                    , Html.div [ Attr.class "flex items-center gap-2 text-xs text-muted flex-wrap" ]
                        [ case user.discord of
                            Just handle ->
                                Ui.discordHandle handle

                            Nothing ->
                                Html.span [] [ Html.text "preview account" ]
                        , Html.span [] [ Html.text ("joined " ++ Ui.timeAgo model.now user.joinedAt) ]
                        , Html.span [] [ Html.text (Ui.plural listings "active listing" "active listings") ]
                        , Html.span [] [ Html.text (Ui.plural offers "offer" "offers") ]
                        , if reportsAgainst > 0 then
                            Html.span [ Attr.class "text-warn" ] [ Html.text (Ui.plural reportsAgainst "open report" "open reports") ]

                          else
                            Ui.empty
                        ]
                    ]
                , if user.isAdmin then
                    Ui.empty

                  else
                    Html.div [ Attr.class "flex gap-2" ]
                        [ if user.ban == Nothing then
                            Ui.button Ui.Danger Ui.Compact ("admin-ban-" ++ user.name) (AdminActionClicked (BanPlayer user.name "")) "Ban"

                          else
                            Ui.button Ui.Secondary Ui.Compact ("admin-unban-" ++ user.name) (AdminActionClicked (UnbanPlayer user.name)) "Unban"
                        , Ui.button Ui.Secondary Ui.Compact ("admin-release-" ++ user.name) (AdminActionClicked (ReleaseName user.name)) "Release name"
                        ]
                ]
            , case user.ban of
                Just ban ->
                    Html.p [ Attr.class "text-sm text-warn" ]
                        [ Html.text ("Banned by " ++ ban.by ++ " " ++ Ui.timeAgo model.now ban.at ++ ": " ++ ban.reason) ]

                Nothing ->
                    Ui.empty
            ]
        , confirmBox model (BanPlayer user.name "")
        , confirmBox model (ReleaseName user.name)
        ]
