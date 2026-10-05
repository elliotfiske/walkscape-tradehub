module Evergreen.V14.Route exposing (..)

import Evergreen.V14.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V14.Item.Variant
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
