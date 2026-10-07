module Evergreen.V30.Route exposing (..)

import Evergreen.V30.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V30.Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Evergreen.V30.Item.Variant ))
    | MyTrades
    | Profile String
    | Report String (Maybe Int)
    | SignIn
    | Onboarding
    | Admin
    | NotFound
