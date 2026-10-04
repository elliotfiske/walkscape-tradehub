module Page.Profile exposing (view)

import Derived
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Page.Market
import Types exposing (FrontendModel, FrontendMsg(..))
import Ui


view : FrontendModel -> String -> Html FrontendMsg
view model name =
    case Dict.get name model.traders of
        Nothing ->
            Html.div [ Attr.class "p-10 text-center text-muted", Ui.testId "profile-missing" ]
                [ Html.text
                    (if model.loaded then
                        "There's no trader called " ++ name ++ " on Trailpost."

                     else
                        "Loading…"
                    )
                ]

        Just trader ->
            let
                stats =
                    Derived.traderStats model name

                isMe =
                    Derived.myName model == Just name

                stat value label color =
                    Html.div [ Attr.class "rounded-[10px] bg-raised border border-edge px-3.5 py-3" ]
                        [ Html.div [ Attr.class ("font-bold text-xl " ++ color) ] [ Html.text value ]
                        , Html.div [ Attr.class "text-[13px] text-muted" ] [ Html.text label ]
                        ]

                apiRow label =
                    Html.div [ Attr.class "flex justify-between px-3.5 py-3 border-b border-line last:border-b-0 text-sm" ]
                        [ Html.span [ Attr.class "text-muted" ] [ Html.text label ]
                        , Html.span [ Attr.class "text-faint" ] [ Html.text "with trading" ]
                        ]

                listings =
                    model.listings
                        |> Dict.values
                        |> List.filter (\l -> l.trader == name && not l.closed)
            in
            Html.div [ Attr.class "w-full max-w-xl mx-auto px-4 py-6 flex flex-col gap-4" ]
                [ Html.div [ Attr.class "flex flex-col items-center gap-2 text-center" ]
                    [ Ui.portrait "w-24 h-24 rounded-xl"
                    , Html.h1 [ Attr.class "font-display font-extrabold text-[28px]", Ui.testId "profile-name" ] [ Html.text trader.name ]
                    , Html.div [ Attr.class "flex items-center gap-2" ]
                        [ Ui.unverifiedTag
                        , case ( model.me, trader.discord ) of
                            ( Just _, Just handle ) ->
                                Html.span [ Attr.class "flex items-center gap-1.5 text-sm text-[#b7bdf7]" ]
                                    [ Ui.discordIcon "w-4 h-4 text-discord", Html.text ("@" ++ handle) ]

                            _ ->
                                Ui.empty
                        ]
                    ]
                , case trader.lookalikeOf of
                    Just original ->
                        Html.div [ Attr.class "rounded-lg border border-[#6a3530] bg-[#2a1412] px-3 py-2 text-[13px] text-warn" ]
                            [ Html.text ("This name is very close to " ++ original ++ ", who joined earlier.") ]

                    Nothing ->
                        Ui.empty
                , Ui.sectionLabel "On Trailpost"
                , Html.div [ Attr.class "grid grid-cols-2 gap-2.5", Ui.testId "profile-stats" ]
                    [ stat (String.fromInt stats.activeListings) "active listings" "text-ink"
                    , stat (String.fromInt stats.partners) "unique partners" "text-ink"
                    , stat (String.fromInt stats.offersAccepted) "offers accepted" "text-leaf"
                    , stat
                        (if stats.days == 1 then
                            "1 day"

                         else
                            String.fromInt stats.days ++ " days"
                        )
                        "on Trailpost"
                        "text-ink"
                    ]
                , Ui.sectionLabel "From the WalkScape API"
                , Ui.card [ Attr.class "overflow-hidden" ]
                    [ apiRow "Total level", apiRow "Steps walked", apiRow "Last active" ]
                , if List.isEmpty listings then
                    Ui.empty

                  else
                    Html.div [ Attr.class "flex flex-col gap-2" ]
                        (Ui.sectionLabel "Listings" :: List.map (Page.Market.listingRow model) listings)
                , if isMe then
                    Html.div [ Attr.class "flex flex-col gap-2 mt-4" ]
                        [ Ui.secondaryButton "sign-out" SignOutClicked "Sign out" ]

                  else if Derived.isReady model then
                    Html.a [ Attr.href ("/report/" ++ name), Attr.id "report-player", Attr.class "text-center text-warn hover:text-warn no-underline font-semibold text-sm mt-2" ]
                        [ Html.text "Report this player" ]

                  else
                    Ui.empty
                ]
