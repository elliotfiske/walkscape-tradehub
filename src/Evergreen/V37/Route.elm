module Evergreen.V37.Route exposing (..)

import Evergreen.V37.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V37.Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Evergreen.V37.Item.Variant ))
    | MyTrades
    | Profile String
    | Report String (Maybe Int)
    | SignIn
    | Onboarding
    | Admin
    | GiveawayPage
    | NotFound
