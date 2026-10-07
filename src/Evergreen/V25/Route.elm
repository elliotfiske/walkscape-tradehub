module Evergreen.V25.Route exposing (..)

import Evergreen.V25.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V25.Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Evergreen.V25.Item.Variant ))
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
