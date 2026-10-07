module Page.Profile exposing (view)

import Derived
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Page.Market
import Route
import Types exposing (FrontendModel, FrontendMsg(..))
import Ui


view : FrontendModel -> String -> Html FrontendMsg
view model name =
    case Dict.get name model.traders of
        Nothing ->
            Ui.pageMessage [ Ui.testId "profile-missing" ]
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
                        [ if trader.banned then
                            Ui.bannedTag

                          else
                            Ui.unverifiedTag
                        , if model.me /= Nothing then
                            trader.discord |> Maybe.map Ui.discordHandle |> Maybe.withDefault Ui.empty

                          else
                            Ui.empty
                        ]
                    ]
                , trader.lookalikeOf |> Maybe.map Ui.lookalikeWarning |> Maybe.withDefault Ui.empty
                , Ui.sectionLabel "On Trailpost"
                , Html.div [ Attr.class "grid grid-cols-2 gap-2.5", Ui.testId "profile-stats" ]
                    [ Ui.stat "text-ink" (String.fromInt stats.activeListings) "active listings"
                    , Ui.stat "text-ink" (String.fromInt stats.partners) "unique partners"
                    , Ui.stat "text-leaf" (String.fromInt stats.offersAccepted) "offers accepted"
                    , Ui.stat "text-ink" (Ui.plural stats.days "day" "days") "on Trailpost"
                    ]
                , Ui.sectionLabel "In WalkScape"
                , Ui.card [ Attr.class "px-3.5 py-3 text-sm text-body", Ui.testId "profile-in-game" ]
                    [ Html.text "Social → Find → "
                    , Html.b [ Attr.class "text-ink" ] [ Html.text trader.name ]
                    , Html.text " shows their total level and steps walked."
                    ]
                , if List.isEmpty listings then
                    Ui.empty

                  else
                    Html.div [ Attr.class "flex flex-col gap-2" ]
                        (Ui.sectionLabel "Listings" :: List.map (Page.Market.listingRow model) listings)
                , if isMe then
                    Html.div [ Attr.class "flex flex-col gap-2 mt-4" ]
                        [ Ui.button Ui.Secondary Ui.Block "sign-out" SignOutClicked "Sign out" ]

                  else if Derived.isReady model && not trader.banned then
                    Html.a [ Attr.href (Route.toString (Route.Report name)), Attr.id "report-player", Attr.class "text-center text-warn hover:text-warn no-underline font-semibold text-sm mt-2" ]
                        [ Html.text "Report this player" ]

                  else
                    Ui.empty
                ]
