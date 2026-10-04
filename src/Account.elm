module Account exposing (claimedName)

{-| Rules about the WalkScape name on an account. They work on both the
backend's `User` and the frontend's `Me`.
-}

import Types exposing (Claim)


{-| The name someone has claimed. Only an account with one can post listings,
make offers and report players.
-}
claimedName : { a | claim : Maybe Claim } -> Maybe String
claimedName account =
    account.claim |> Maybe.map .name
