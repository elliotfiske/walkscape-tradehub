module Users exposing (adminName, byName, isAdmin, previewAdminPrefix, signIn, toAdminUser, toMe, toTrader, traders)

{-| Backend-side helpers for accounts and their public trader profiles.
-}

import Account
import Dict
import Env
import Name
import Time
import Types exposing (AdminUser, BackendModel, Me, Provider(..), Trader, User, UserId)


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
                    , ban = Nothing
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
    , isAdmin = isAdmin user
    , ban = user.ban
    }


{-| Preview accounts made with `PreviewAdminSignIn` get user ids starting with this.
-}
previewAdminPrefix : String
previewAdminPrefix =
    "preview-admin:"


{-| Discord accounts whose username is in `Env.adminDiscordUsernames`. In
development there are also preview admin accounts, so the admin screen can be
tried (and tested) without Discord.
-}
isAdmin : User -> Bool
isAdmin user =
    if user.isPreviewLogin then
        Env.mode == Env.Development && String.startsWith previewAdminPrefix user.id

    else
        case ( user.provider, user.oauthUsername ) of
            ( Discord, Just username ) ->
                List.member (String.toLower username) adminUsernames

            _ ->
                False


adminUsernames : List String
adminUsernames =
    Env.adminDiscordUsernames
        |> String.split ","
        |> List.map (String.trim >> String.toLower)
        |> List.filter (not << String.isEmpty)


{-| How an admin is named in the admin log.
-}
adminName : User -> String
adminName user =
    case ( user.oauthUsername, Account.claimedName user ) of
        ( Just username, _ ) ->
            "@" ++ username

        ( Nothing, Just name ) ->
            name

        ( Nothing, Nothing ) ->
            "a preview admin"


{-| The account that claimed this WalkScape name.
-}
byName : String -> BackendModel -> Maybe User
byName name model =
    model.users |> Dict.values |> List.filter (\u -> Account.claimedName u == Just name) |> List.head


toAdminUser : User -> Maybe AdminUser
toAdminUser user =
    Account.claimedName user
        |> Maybe.map
            (\name ->
                { name = name
                , ready = Account.claimedName user /= Nothing
                , discord = user.oauthUsername
                , isPreviewLogin = user.isPreviewLogin
                , joinedAt = user.joinedAt
                , isAdmin = isAdmin user
                , ban = user.ban
                }
            )


{-| The public profile for a user who has finished onboarding. Look-alike
names are checked against traders who joined earlier.
-}
toTrader : BackendModel -> User -> Maybe Trader
toTrader model user =
    Account.claimedName user
        |> Maybe.map
            (\name ->
                let
                    earlier =
                        model.users
                            |> Dict.values
                            |> List.filter (\u -> Time.posixToMillis u.joinedAt < Time.posixToMillis user.joinedAt)
                            |> List.filterMap Account.claimedName
                in
                { name = name
                , joinedAt = user.joinedAt
                , discord =
                    if user.provider == Discord then
                        user.oauthUsername

                    else
                        Nothing
                , lookalikeOf = Name.lookalikeOf name earlier
                , banned = user.ban /= Nothing
                }
            )


traders : BackendModel -> List Trader
traders model =
    model.users |> Dict.values |> List.filterMap (toTrader model)
