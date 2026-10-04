module Account exposing (claimedName, readyName)

{-| Rules about the WalkScape name on an account. They work on both the
backend's `User` and the frontend's `Me`.
-}

import Types exposing (Claim, ClaimStatus(..))


{-| The name someone has claimed, verified or not.
-}
claimedName : { a | claim : Maybe Claim } -> Maybe String
claimedName account =
    account.claim |> Maybe.map .name


{-| The claimed name once the account is through the (preview) verification
step. Only then can it post listings, make offers and report players.
-}
readyName : { a | claim : Maybe Claim } -> Maybe String
readyName account =
    case account.claim of
        Just claim ->
            if claim.status == PreviewUnverified then
                Just claim.name

            else
                Nothing

        Nothing ->
            Nothing
