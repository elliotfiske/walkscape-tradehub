module Page.SignIn exposing (viewOnboarding, viewSignIn)

import Auth.Common
import Auth.Flow
import AuthProviders
import Env
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Name
import Types exposing (Claim, ClaimStatus(..), FrontendModel, FrontendMsg(..), Me, Provider(..))
import Ui


type Step
    = StepSignIn
    | StepClaim
    | StepVerify
    | StepDone


stepper : Step -> Html msg
stepper current =
    let
        index s =
            case s of
                StepSignIn ->
                    0

                StepClaim ->
                    1

                StepVerify ->
                    2

                StepDone ->
                    3

        item s text =
            let
                ( mark, cls ) =
                    if index s < index current then
                        ( "✓", "text-leaf" )

                    else if s == current then
                        ( "●", "text-gold" )

                    else
                        ( "○", "text-muted" )
            in
            Html.span [ Attr.class ("flex-none font-bold text-[11px] tracking-[0.08em] " ++ cls) ] [ Html.text (mark ++ " " ++ text) ]

        bar s =
            Html.span
                [ Attr.class
                    ("flex-1 h-0.5 mx-1.5 "
                        ++ (if index s <= index current then
                                "bg-[#57b34a]"

                            else
                                "bg-rule"
                           )
                    )
                ]
                []
    in
    Html.div [ Attr.class "w-full flex items-center my-4" ]
        [ item StepSignIn "SIGN IN", bar StepClaim, item StepClaim "CLAIM NAME", bar StepVerify, item StepVerify "VERIFY" ]


providerName : Provider -> String
providerName provider =
    case provider of
        Discord ->
            "Discord"


providerLetter : Provider -> Html msg
providerLetter provider =
    Html.span
        [ Attr.class
            "inline-grid place-items-center w-5 h-5 rounded text-[11px] font-bold bg-white text-black"
        ]
        [ Html.text (String.left 1 (providerName provider)) ]


viewSignIn : FrontendModel -> Html FrontendMsg
viewSignIn model =
    let
        providerButton provider cls =
            Html.button
                [ Attr.id ("signin-" ++ String.toLower (providerName provider))
                , Events.onClick (ProviderClicked provider)
                , Attr.class ("w-full flex items-center justify-center gap-3 rounded-xl py-3.5 font-semibold text-[17px] " ++ cls)
                ]
                [ providerLetter provider, Html.text ("Continue with " ++ providerName provider) ]
    in
    Html.div [ Attr.class "flex-1 flex flex-col" ]
        [ stepper StepSignIn
        , Html.h1 [ Attr.class "font-display font-extrabold text-[26px] leading-tight mb-2" ] [ Html.text "Sign in or create an account" ]
        , Html.p [ Attr.class "text-body mb-5" ] [ Html.text "New here? Signing in creates your account." ]
        , case model.previewSignInFor of
            Just provider ->
                viewPreviewSignIn provider

            Nothing ->
                Html.div [ Attr.class "flex flex-col gap-3" ]
                    [ providerButton Discord "bg-discord text-white hover:brightness-110"
                    , if AuthProviders.isConfigured Discord && Env.mode == Env.Production then
                        Ui.empty

                      else
                        -- Lets dev and the E2E tests sign in without real Discord.
                        Html.button [ Attr.id "signin-preview", Events.onClick (PreviewSignInConfirmed Discord), Attr.class "text-soft text-sm py-1" ]
                            [ Html.text "Use a preview account instead" ]
                    ]
        , case model.authFlow of
            Auth.Common.Errored _ ->
                Html.p [ Attr.class "mt-4 text-warn text-sm", Ui.testId "auth-error" ]
                    [ Html.text "That sign-in didn't work. Please try again." ]

            Auth.Common.Requested _ ->
                Html.p [ Attr.class "mt-4 text-muted text-sm" ] [ Html.text "Redirecting…" ]

            _ ->
                Ui.empty
        , Html.div [ Attr.class "mt-6" ]
            [ Ui.previewNote
                [ Html.b [ Attr.class "text-[#d6e4f7]" ] [ Html.text "Next, you'll link your WalkScape name. " ]
                , Html.text "WalkScape doesn't have its own sign-in, so you'll claim the name you play under."
                ]
            ]
        , Html.div [ Attr.class "flex-1" ] []
        , Html.p [ Attr.class "text-center text-xs text-faint mt-10" ]
            [ Html.text "By continuing you agree to the community rules. Trailpost isn't affiliated with WalkScape." ]
        ]


viewPreviewSignIn : Provider -> Html FrontendMsg
viewPreviewSignIn provider =
    Ui.card [ Attr.class "p-4 flex flex-col gap-3", Ui.testId "preview-signin" ]
        [ Html.div [ Attr.class "font-display font-extrabold text-lg text-gold" ]
            [ Html.text (providerName provider ++ " sign-in isn't connected yet") ]
        , Html.p [ Attr.class "text-sm text-body leading-relaxed" ]
            [ Html.text "While Trailpost is in preview, you can use a preview account instead. It's tied to this browser, so you'll lose it if you clear your cookies." ]
        , Ui.primaryButton "preview-signin-continue" (PreviewSignInConfirmed provider) "Continue with a preview account"
        , Html.button [ Attr.id "preview-signin-cancel", Events.onClick PreviewSignInCancelled, Attr.class "text-soft text-sm py-1" ] [ Html.text "Pick another option" ]
        ]


viewOnboarding : FrontendModel -> Html FrontendMsg
viewOnboarding model =
    case model.me of
        Nothing ->
            case model.authFlow of
                Auth.Common.Idle ->
                    Html.div [ Attr.class "mt-10 flex flex-col gap-4" ]
                        [ Html.p [ Attr.class "text-body" ] [ Html.text "You're signed out." ]
                        , Html.a [ Attr.href "/signin", Attr.id "goto-signin" ] [ Html.text "Sign in to continue" ]
                        ]

                Auth.Common.Errored err ->
                    Html.div [ Attr.class "mt-10 flex flex-col gap-4", Ui.testId "auth-error" ]
                        [ Html.p [ Attr.class "text-warn" ] [ Html.text "That sign-in didn't work. Please try again." ]
                        , Html.p [ Attr.class "text-faint text-sm" ] [ Html.text (Auth.Flow.errorToString err) ]
                        , Html.a [ Attr.href "/signin", Attr.id "goto-signin" ] [ Html.text "Back to sign-in" ]
                        ]

                _ ->
                    Html.p [ Attr.class "mt-10 text-muted" ] [ Html.text "Signing you in…" ]

        Just me ->
            case me.claim of
                Nothing ->
                    viewClaim model me

                Just claim ->
                    case claim.status of
                        AwaitingCoinOffer ->
                            viewVerify claim

                        PreviewUnverified ->
                            viewDone me claim


viewClaim : FrontendModel -> Me -> Html FrontendMsg
viewClaim model me =
    let
        validName =
            Name.validate model.claimName |> Result.toMaybe
    in
    Html.div [ Attr.class "flex-1 flex flex-col" ]
        [ stepper StepClaim
        , Html.div [ Attr.class "flex items-center gap-2.5 rounded-xl bg-card border border-edge px-3.5 py-2.5 mb-4 text-soft text-sm", Ui.testId "signed-in-with" ]
            [ providerLetter me.provider
            , Html.text
                (if me.isPreviewLogin then
                    "Signed in with a preview account"

                 else
                    "Signed in with " ++ providerName me.provider
                )
            ]
        , Html.h1 [ Attr.class "font-display font-extrabold text-[26px] leading-tight mb-4" ] [ Html.text "Which WalkScape account is yours?" ]
        , Html.form [ Events.onSubmit ClaimNameSubmitted, Attr.class "flex flex-col flex-1" ]
            [ Html.label [ Attr.for "claim-name" ] [ Ui.label "WalkScape username" ]
            , Ui.textInput [ Attr.id "claim-name", Attr.placeholder "Wanderling", Attr.autocomplete False ] model.claimName ClaimNameChanged
            , Html.p [ Attr.class "text-xs text-faint mt-1.5" ] [ Html.text "Must match exactly, including capitals." ]
            , case model.claimError of
                Just err ->
                    Html.p [ Attr.class "text-sm text-warn mt-3", Ui.testId "claim-error" ] [ Html.text err ]

                Nothing ->
                    Ui.empty
            , case validName of
                Just name ->
                    Html.div [ Attr.class "mt-4 flex items-center gap-3.5 rounded-xl border border-[#2c5a2a] bg-card p-3.5" ]
                        [ Ui.portrait "w-[60px] h-[60px]"
                        , Html.div []
                            [ Html.div [ Attr.class "font-display font-extrabold text-xl" ] [ Html.text name ]
                            , Html.div [ Attr.class "text-xs text-faint mt-1" ]
                                [ Html.text "Preview: we'll look this name up in the WalkScape API (level, steps) once trading launches." ]
                            ]
                        ]

                Nothing ->
                    Ui.empty
            , Html.p [ Attr.class "text-sm text-muted mt-4" ]
                [ Html.text "If someone else has claimed this name, verifying it (once that's live) moves the name to you." ]
            , Html.div [ Attr.class "flex-1 min-h-8" ] []
            , Html.button
                [ Attr.id "claim-submit"
                , Attr.type_ "button"
                , Events.onClick ClaimNameSubmitted
                , Attr.class "w-full rounded-xl bg-go hover:bg-gohi text-white font-bold tracking-wider uppercase py-3.5 border border-white/10"
                ]
                [ Html.text "That's me · Continue" ]
            ]
        ]


viewVerify : Claim -> Html FrontendMsg
viewVerify claim =
    let
        stepRow n content =
            Html.div [ Attr.class "flex gap-3 items-start" ]
                [ Html.span [ Attr.class "flex-none w-6 h-6 rounded-full bg-raised border border-rule grid place-items-center text-xs font-bold text-gold" ] [ Html.text (String.fromInt n) ]
                , Html.div [ Attr.class "text-soft leading-snug" ] content
                ]
    in
    Html.div [ Attr.class "flex-1 flex flex-col gap-4" ]
        [ stepper StepVerify
        , Html.div [ Attr.class "flex items-center justify-between rounded-xl bg-card border border-edge px-3.5 py-2.5 text-sm" ]
            [ Html.span [ Attr.class "text-muted" ]
                [ Html.text "Claimed "
                , Html.b [ Attr.class "text-ink ml-1", Ui.testId "claimed-name" ] [ Html.text claim.name ]
                ]
            , Html.button [ Attr.id "change-name", Events.onClick ChangeClaimClicked, Attr.class "text-xs text-gold font-semibold" ] [ Html.text "Change" ]
            ]
        , Html.h1 [ Attr.class "font-display font-extrabold text-[22px]" ] [ Html.text ("Prove you own " ++ claim.name) ]
        , Ui.previewNote
            [ Html.b [ Attr.class "text-[#d6e4f7]" ] [ Html.text "This is where you'd verify your account. " ]
            , Html.text "Trading isn't live yet, so TrailpostBot isn't running. Here's how it will work. For now you can carry on unverified, and your name will show as unverified."
            ]
        , Html.div [ Attr.class "flex flex-col gap-3 opacity-80" ]
            [ stepRow 1 [ Html.text "In WalkScape, start a trade with ", Html.b [ Attr.class "text-[#9fd3e8]" ] [ Html.text "TrailpostBot" ], Html.text "." ]
            , stepRow 2 [ Html.text "Put exactly this many coins in your offer, with no items:" ]
            , Html.div [ Attr.class "self-center flex items-center gap-3 rounded-2xl border border-[#6b5520] bg-card px-7 py-4 shadow-[0_0_30px_rgba(227,181,76,0.12)]" ]
                [ Ui.coin "w-10 h-10"
                , Html.span [ Attr.class "font-display font-extrabold text-[40px] text-gold leading-none", Ui.testId "coin-amount" ] [ Html.text (String.fromInt claim.coins) ]
                , Html.span [ Attr.class "text-muted" ] [ Html.text "coins" ]
                ]
            , stepRow 3 [ Html.text "Send the offer. The bot checks the amount and rejects it, so your coins never leave." ]
            ]
        , Html.div [ Attr.class "flex-1" ] []
        , Ui.primaryButton "skip-verify" SkipVerificationClicked "Continue unverified"
        ]


viewDone : Me -> Claim -> Html FrontendMsg
viewDone me claim =
    Html.div [ Attr.class "flex-1 flex flex-col items-center text-center gap-3" ]
        [ stepper StepDone
        , Html.div [ Attr.class "relative mt-2" ]
            [ Ui.portrait "w-24 h-24 rounded-xl"
            , Html.span [ Attr.class "absolute -right-2 -bottom-2 w-8 h-8 rounded-full bg-[#6b5520] border-2 border-shell grid place-items-center text-gold font-bold" ] [ Html.text "?" ]
            ]
        , Html.h1 [ Attr.class "font-display font-extrabold text-[28px]", Ui.testId "done-heading" ] [ Html.text (claim.name ++ " is linked") ]
        , Html.p [ Attr.class "text-body" ] [ Html.text "You can now post listings and make offers. Until verification is live, your name shows as unverified." ]
        , Ui.card [ Attr.class "w-full text-left p-4 mt-3 flex flex-col gap-3" ]
            [ Html.div [ Attr.class "flex items-center justify-between" ]
                [ Html.span [ Attr.class "flex items-center gap-2.5 font-semibold" ]
                    [ Html.span [ Attr.class "w-6 h-6 rounded bg-discord" ] [], Html.text "Discord" ]
                , Html.span [ Attr.class "text-xs text-faint" ] [ Html.text "optional" ]
                ]
            , Html.p [ Attr.class "text-sm text-body" ]
                [ Html.text
                    (if not me.isPreviewLogin then
                        "You signed in with Discord, so your handle shows on your profile and traders can message you there."

                     else
                        "Linking Discord, so traders can message you there, arrives with trading. Signing in with Discord shows your handle on your profile."
                    )
                ]
            ]
        , Html.div [ Attr.class "flex-1" ] []
        , Html.a
            [ Attr.href "/market"
            , Attr.id "goto-market"
            , Attr.class "w-full block rounded-xl bg-go hover:bg-gohi text-white hover:text-white no-underline font-bold tracking-wider uppercase py-3.5 border border-white/10"
            ]
            [ Html.text "Go to the market" ]
        ]
