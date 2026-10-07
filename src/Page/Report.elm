module Page.Report exposing (reportedTrade, view)

import Derived
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Market
import Route
import Screenshot
import Types exposing (FrontendModel, FrontendMsg(..), Listing, Offer)
import Ui


reasons : List String
reasons =
    [ "Item or quality swapped"
    , "Didn't deliver"
    , "Fake deadline / pressure"
    , "Impersonating someone"
    , "Price manipulation"
    , "Didn't match what we agreed"
    , "Other"
    ]


{-| The trade a `/report/<name>?trade=<offerId>` link is about, if it's one
between the viewer and `name` that was accepted.
-}
reportedTrade : FrontendModel -> Maybe ( Listing, Offer )
reportedTrade model =
    model.reportForm.trade
        |> Maybe.andThen (\offerId -> Dict.get offerId model.offers)
        |> Maybe.andThen (\offer -> Dict.get offer.listingId model.listings |> Maybe.map (\listing -> ( listing, offer )))
        |> Maybe.andThen
            (\( listing, offer ) ->
                let
                    terms =
                        Market.tradeTerms listing offer

                    parties =
                        [ terms.seller, terms.buyer ]
                in
                if Market.wasAccepted offer.status && List.member model.reportForm.about parties && List.member (Derived.myName model |> Maybe.withDefault "") parties then
                    Just ( listing, offer )

                else
                    Nothing
            )


view : FrontendModel -> String -> Html FrontendMsg
view model name =
    let
        form =
            model.reportForm
    in
    Html.div [ Attr.class "w-full max-w-xl mx-auto px-4 py-5 flex flex-col gap-4" ]
        [ Html.div [ Attr.class "flex items-center gap-3" ]
            [ Ui.backLink (Route.Profile name)
            , Html.h1 [ Attr.class "font-display font-extrabold text-[26px] text-gold" ] [ Html.text ("Report " ++ name) ]
            ]
        , if not (Derived.isReady model) then
            Ui.nameGate (Derived.onboardingRoute model) "You need it to report a player."

          else if form.sent then
            Ui.card [ Attr.class "p-5 flex flex-col gap-2", Ui.testId "report-sent" ]
                [ Html.div [ Attr.class "font-display font-extrabold text-xl text-leaf" ] [ Html.text "Report sent" ]
                , Html.p [ Attr.class "text-body text-sm" ] [ Html.text "Thanks, it's saved." ]
                , Html.a [ Attr.href "/market", Attr.class "text-sm" ] [ Html.text "Back to the market" ]
                ]

          else
            Html.div [ Attr.class "flex flex-col gap-4" ]
                [ case reportedTrade model of
                    Just ( listing, offer ) ->
                        Ui.card [ Attr.class "px-3.5 py-3 flex flex-col gap-1 text-sm", Ui.testId "report-trade" ]
                            [ Ui.sectionLabel "About this trade"
                            , Html.p [ Attr.class "text-ink font-semibold" ] [ Html.text (Market.describeTrade listing offer) ]
                            ]

                    Nothing ->
                        Ui.empty
                , Html.div []
                    [ Ui.label "What happened?"
                    , Html.div [ Attr.class "flex flex-wrap gap-2" ]
                        (reasons
                            |> List.indexedMap
                                (\i reason ->
                                    let
                                        active =
                                            List.member reason form.reasons
                                    in
                                    Html.button
                                        [ Attr.id ("reason-" ++ String.fromInt i)
                                        , Events.onClick (ReportReasonToggled reason)
                                        , Attr.class
                                            ("rounded-lg px-3.5 py-2 text-[15px] border "
                                                ++ (if active then
                                                        "border-[#c0453b] bg-[#3a1a18] text-[#f6c9c2]"

                                                    else
                                                        "border-rule bg-raised text-soft"
                                                   )
                                            )
                                        ]
                                        [ Html.text reason ]
                                )
                        )
                    ]
                , Html.div []
                    [ Ui.label "Details"
                    , Ui.textArea
                        [ Attr.id "report-details", Attr.class "h-28", Attr.placeholder "What did you agree on, and what happened instead?" ]
                        form.details
                        ReportDetailsChanged
                    ]
                , screenshots form
                , Html.div [ Attr.class "rounded-xl border border-edge bg-card p-4 flex flex-col gap-2 text-sm text-body" ]
                    [ Ui.sectionLabel "What happens next"
                    , Html.p [] [ Html.text "I read every report. If someone's breaking the rules, I can take their listings down or ban them." ]
                    ]
                , Ui.button Ui.Danger Ui.Block "send-report" ReportSubmitted "Send report"
                ]
        ]


screenshots : Types.ReportForm -> Html FrontendMsg
screenshots form =
    let
        count =
            List.length form.screenshots
    in
    Html.div [ Attr.class "flex flex-col gap-2" ]
        [ Html.div [ Attr.class "flex items-baseline gap-2" ]
            [ Ui.label "Screenshots"
            , Html.span [ Attr.class "text-xs text-faint", Ui.testId "report-screenshot-count" ]
                [ Html.text (String.fromInt count ++ " of " ++ String.fromInt Screenshot.maxCount) ]
            ]
        , if count == 0 then
            Ui.empty

          else
            Html.div [ Attr.class "grid grid-cols-3 gap-2" ]
                (form.screenshots
                    |> List.indexedMap
                        (\i src ->
                            Html.div [ Attr.class "relative", Ui.testId ("report-screenshot-" ++ String.fromInt i) ]
                                [ Html.img [ Attr.src src, Attr.alt ("Screenshot " ++ String.fromInt (i + 1)), Attr.class "w-full h-24 object-cover rounded-lg border border-edge" ] []
                                , Html.button
                                    [ Attr.id ("report-remove-screenshot-" ++ String.fromInt i)
                                    , Attr.type_ "button"
                                    , Attr.attribute "aria-label" "Remove"
                                    , Events.onClick (ReportScreenshotRemoved i)
                                    , Attr.class "absolute top-1 right-1 w-6 h-6 rounded-full bg-[#0b1416cc] text-ink text-sm leading-none"
                                    ]
                                    [ Html.text "×" ]
                                ]
                        )
                )
        , if form.shrinking > 0 then
            Html.p [ Attr.class "text-[13px] text-muted" ] [ Html.text "Shrinking…" ]

          else if count + form.shrinking < Screenshot.maxCount then
            Ui.button Ui.Secondary Ui.Block "report-add-screenshots" ReportAddScreenshotsClicked "Add screenshots"

          else
            Ui.empty
        , case form.screenshotError of
            Just err ->
                Html.p [ Attr.class "text-sm text-warn", Ui.testId "report-screenshot-error" ] [ Html.text err ]

            Nothing ->
                Ui.empty
        , Html.p [ Attr.class "text-[13px] text-faint" ]
            [ Html.text "Up to 3. Only admins can see them. The trade window and Trades → Previous trades in WalkScape are the most useful." ]
        ]
