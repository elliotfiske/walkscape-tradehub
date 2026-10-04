module Evergreen.V9.Route exposing (..)

import Evergreen.V9.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V9.Item.Variant
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
