module Page.Report exposing (view)

import Derived
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
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
            [ Html.a [ Attr.href ("/u/" ++ name), Attr.class "w-9 h-9 rounded-lg bg-raised border border-rule grid place-items-center text-gold no-underline" ] [ Html.text "‹" ]
            , Html.h1 [ Attr.class "font-display font-extrabold text-[26px] text-gold" ] [ Html.text ("Report " ++ name) ]
            ]
        , if not (Derived.isReady model) then
            Ui.previewNote [ Html.text "Sign in and link your WalkScape name to report a player." ]

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
                    , Html.textarea
                        [ Attr.id "report-details"
                        , Attr.class "w-full rounded-xl bg-field border border-rule focus:border-gold outline-none px-4 py-3 text-ink placeholder:text-faint h-28"
                        , Attr.placeholder "What did you agree on, and what happened instead?"
                        , Attr.value form.details
                        , Events.onInput ReportDetailsChanged
                        ]
                        []
                    ]
                , Html.div [ Attr.class "hatch rounded-xl border border-dashed border-rule p-6 text-center font-mono text-xs text-muted" ]
                    [ Html.text "screenshot uploads arrive with trading" ]
                , Html.div [ Attr.class "rounded-xl border border-edge bg-card p-4 flex flex-col gap-2 text-sm text-body" ]
                    [ Ui.sectionLabel "What happens next"
                    , Html.p [] [ Html.text "There's no moderation in the preview yet. Your report is saved for when there is." ]
                    ]
                , Ui.button "send-report" "w-full rounded-xl bg-[#a8403a] hover:bg-[#c0453b] text-white font-bold tracking-wider uppercase py-3.5" ReportSubmitted "Send report"
                ]
        ]
