module Evergreen.V13.Route exposing (..)

import Evergreen.V13.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V13.Item.Variant
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
