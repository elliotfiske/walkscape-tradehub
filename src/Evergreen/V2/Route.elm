module Evergreen.V2.Route exposing (..)

import Evergreen.V2.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V2.Item.Variant
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | NotFound
