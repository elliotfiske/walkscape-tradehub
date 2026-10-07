module Page.Report exposing (view)

import Derived
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Route
import Types exposing (FrontendModel, FrontendMsg(..))
import Ui


reasons : List String
reasons =
    [ "Item or quality swapped"
    , "Didn't deliver"
    , "Fake deadline / pressure"
    , "Impersonating someone"
    , "Price manipulation"
    , "Other"
    ]


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
                [ Html.div []
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
                , Html.p [ Attr.class "text-[13px] text-faint" ]
                    [ Html.text "You can't upload screenshots yet. If it was a trade, keep a screenshot of it from Trades → Previous trades in WalkScape in case I ask." ]
                , Html.div [ Attr.class "rounded-xl border border-edge bg-card p-4 flex flex-col gap-2 text-sm text-body" ]
                    [ Ui.sectionLabel "What happens next"
                    , Html.p [] [ Html.text "I read every report. If someone's breaking the rules, I can take their listings down or ban them." ]
                    ]
                , Ui.button Ui.Danger Ui.Block "send-report" ReportSubmitted "Send report"
                ]
        ]
