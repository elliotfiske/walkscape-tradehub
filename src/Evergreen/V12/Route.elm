module Evergreen.V12.Route exposing (..)

import Evergreen.V12.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V12.Item.Variant
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
