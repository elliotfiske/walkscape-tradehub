module Evergreen.V1.Route exposing (..)

import Evergreen.V1.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V1.Item.Variant
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | NotFound
