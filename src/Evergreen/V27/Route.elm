module Evergreen.V27.Route exposing (..)

import Evergreen.V27.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V27.Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Evergreen.V27.Item.Variant ))
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | Admin
    | NotFound
