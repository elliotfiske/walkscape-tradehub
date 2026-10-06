port module Analytics exposing (Event(..), track)

{-| Custom events for Simple Analytics.

`track` hands an event to `elm-pkg-js/analytics.js`, which calls `sa_event`.
Event names are lowercase letters, digits and underscores (Simple Analytics
rewrites anything else). Metadata never carries a trader name or any other
identifier.

-}

import Effect.Command as Command exposing (Command, FrontendOnly)
import Json.Encode as Encode
import Types exposing (Side(..))


port analyticsEvent : Encode.Value -> Cmd msg


type Event
    = SigninDiscordClicked
    | SigninPreviewConfirmed
    | SignedIn
    | SignedOut
    | ClaimNameSubmitted
    | ClaimNameRejected
    | OnboardingCompleted
    | ListingSubmitRejected
    | ListingSubmitted { side : Side, itemId : String }
    | ListingCreated
    | ListingCreateFailed
    | ListingClosed
    | OfferSubmitted
    | ReportSubmitted


track : Event -> Command FrontendOnly toBackend msg
track event =
    Command.sendToJs "analyticsEvent" analyticsEvent (encode event)


name : Event -> String
name event =
    case event of
        SigninDiscordClicked ->
            "signin_discord_clicked"

        SigninPreviewConfirmed ->
            "signin_preview_confirmed"

        SignedIn ->
            "signed_in"

        SignedOut ->
            "signed_out"

        ClaimNameSubmitted ->
            "claim_name_submitted"

        ClaimNameRejected ->
            "claim_name_rejected"

        OnboardingCompleted ->
            "onboarding_completed"

        ListingSubmitRejected ->
            "listing_submit_rejected"

        ListingSubmitted _ ->
            "listing_submitted"

        ListingCreated ->
            "listing_created"

        ListingCreateFailed ->
            "listing_create_failed"

        ListingClosed ->
            "listing_closed"

        OfferSubmitted ->
            "offer_submitted"

        ReportSubmitted ->
            "report_submitted"


metadata : Event -> List ( String, Encode.Value )
metadata event =
    case event of
        ListingSubmitted { side, itemId } ->
            [ ( "side"
              , Encode.string
                    (case side of
                        Selling ->
                            "sell"

                        Buying ->
                            "buy"
                    )
              )
            , ( "itemId", Encode.string itemId )
            ]

        _ ->
            []


{-| `{ name, metadata }`, the shape `elm-pkg-js/analytics.js` expects.
-}
encode : Event -> Encode.Value
encode event =
    Encode.object
        [ ( "name", Encode.string (name event) )
        , ( "metadata", Encode.object (metadata event) )
        ]
