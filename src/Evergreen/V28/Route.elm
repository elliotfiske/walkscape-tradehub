module Evergreen.V28.Route exposing (..)

import Evergreen.V28.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V28.Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Evergreen.V28.Item.Variant ))
    | MyTrades
    | Profile String
    | Report String (Maybe Int)
    | SignIn
    | Onboarding
    | Admin
    | NotFound
