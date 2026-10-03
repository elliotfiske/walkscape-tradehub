module Evergreen.V3.Route exposing (..)

import Evergreen.V3.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V3.Item.Variant
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | NotFound
