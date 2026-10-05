module Evergreen.V16.Route exposing (..)

import Evergreen.V16.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V16.Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Evergreen.V16.Item.Variant ))
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
