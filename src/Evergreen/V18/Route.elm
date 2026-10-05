module Evergreen.V18.Route exposing (..)

import Evergreen.V18.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V18.Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Evergreen.V18.Item.Variant ))
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
