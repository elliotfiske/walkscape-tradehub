module Evergreen.V4.Item exposing (..)


type Quality
    = Normal
    | Good
    | Great
    | Excellent
    | Perfect
    | Eternal


type alias Variant =
    { fine : Bool
    , quality : Maybe Quality
    }


type Rarity
    = Common
    | Uncommon
    | Rare
    | Epic
    | Legendary
    | Ethereal
