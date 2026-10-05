module Evergreen.V15.Route exposing (..)

import Evergreen.V15.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V15.Item.Variant
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
