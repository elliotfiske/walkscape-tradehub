module Evergreen.V4.Route exposing (..)

import Evergreen.V4.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V4.Item.Variant
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | NotFound
