module Evergreen.V38.Route exposing (..)

import Evergreen.V38.Item


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String Evergreen.V38.Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Evergreen.V38.Item.Variant ))
    | MyTrades
    | Profile String
    | Report String (Maybe Int)
    | SignIn
    | Onboarding
    | Admin
    | GiveawayPage
    | NotFound
