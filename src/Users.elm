module Users exposing (isReady, signIn, toMe, toTrader, traders)

{-| Backend-side helpers for accounts and their public trader profiles.
-}

import Dict
import Name
import Time
import Types exposing (BackendModel, ClaimStatus(..), Me, Provider(..), Trader, User, UserId)


signIn :
    { userId : UserId, provider : Provider, isPreviewLogin : Bool, oauthUsername : Maybe String }
    -> String
    -> Time.Posix
    -> BackendModel
    -> ( BackendModel, User )
signIn info sessionId now model =
    let
        user =
            case Dict.get info.userId model.users of
                Just existing ->
                    -- Discord handles can change, so refresh it on each sign-in.
                    { existing | oauthUsername = info.oauthUsername }

                Nothing ->
                    { id = info.userId
                    , provider = info.provider
                    , isPreviewLogin = info.isPreviewLogin
                    , oauthUsername = info.oauthUsername
                    , claim = Nothing
                    , joinedAt = now
                    }
    in
    ( { model
        | users = Dict.insert user.id user model.users
        , sessions = Dict.insert sessionId user.id model.sessions
      }
    , user
    )


toMe : User -> Me
toMe user =
    { provider = user.provider
    , isPreviewLogin = user.isPreviewLogin
    , claim = user.claim
    }


{-| Signed in, named, and through the (preview) verification step.
-}
isReady : User -> Bool
isReady user =
    case user.claim of
        Just claim ->
            claim.status == PreviewUnverified

        Nothing ->
            False


{-| The public profile for a user who has finished onboarding. Look-alike
names are checked against traders who joined earlier.
-}
toTrader : BackendModel -> User -> Maybe Trader
toTrader model user =
    case user.claim of
        Just claim ->
            if claim.status == PreviewUnverified then
                let
                    earlier =
                        model.users
                            |> Dict.values
                            |> List.filter (\u -> isReady u && Time.posixToMillis u.joinedAt < Time.posixToMillis user.joinedAt)
                            |> List.filterMap (.claim >> Maybe.map .name)
                in
                Just
                    { name = claim.name
                    , joinedAt = user.joinedAt
                    , discord =
                        if user.provider == Discord then
                            user.oauthUsername

                        else
                            Nothing
                    , lookalikeOf = Name.lookalikeOf claim.name earlier
                    }

            else
                Nothing

        Nothing ->
            Nothing


traders : BackendModel -> List Trader
traders model =
    model.users |> Dict.values |> List.filterMap (toTrader model)
