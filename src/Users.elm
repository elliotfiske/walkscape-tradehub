module Users exposing (signIn, toMe, toTrader, traders)

{-| Backend-side helpers for accounts and their public trader profiles.
-}

import Account
import Dict
import Name
import Time
import Types exposing (BackendModel, Me, Provider(..), Trader, User, UserId)


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


{-| The public profile for a user who has finished onboarding. Look-alike
names are checked against traders who joined earlier.
-}
toTrader : BackendModel -> User -> Maybe Trader
toTrader model user =
    Account.readyName user
        |> Maybe.map
            (\name ->
                let
                    earlier =
                        model.users
                            |> Dict.values
                            |> List.filter (\u -> Time.posixToMillis u.joinedAt < Time.posixToMillis user.joinedAt)
                            |> List.filterMap Account.readyName
                in
                { name = name
                , joinedAt = user.joinedAt
                , discord =
                    if user.provider == Discord then
                        user.oauthUsername

                    else
                        Nothing
                , lookalikeOf = Name.lookalikeOf name earlier
                }
            )


traders : BackendModel -> List Trader
traders model =
    model.users |> Dict.values |> List.filterMap (toTrader model)
