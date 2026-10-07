module Evergreen.V31.Route exposing (..)

import Evergreen.V31.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V31.Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Evergreen.V31.Item.Variant ))
    | MyTrades
    | Profile String
    | Report String (Maybe Int)
    | SignIn
    | Onboarding
    | Admin
    | NotFound
