module Evergreen.V10.Route exposing (..)

import Evergreen.V10.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V10.Item.Variant
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
