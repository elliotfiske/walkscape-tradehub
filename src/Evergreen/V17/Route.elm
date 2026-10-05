module Evergreen.V17.Route exposing (..)

import Evergreen.V17.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V17.Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Evergreen.V17.Item.Variant ))
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
