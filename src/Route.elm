module Route exposing (Route(..), fromUrl, toString)

import Item
import Url exposing (Url)
import Url.Builder
import Url.Parser as Parser exposing ((</>), (<?>), Parser, oneOf, s)
import Url.Parser.Query as Query


type Route
    = Home
    | Market
    | Prices
    | ItemPrice String (Maybe Item.Quality)
    | ListingPage Int
    | NewListing
    | MyTrades
    | Profile String
    | Report String
    | SignIn
    | Onboarding
    | NotFound


parser : Parser (Route -> a) a
parser =
    oneOf
        [ Parser.map Home Parser.top
        , Parser.map Market (s "market")
        , Parser.map Prices (s "prices")
        , Parser.map (\id q -> ItemPrice id (Maybe.andThen Item.qualityFromString q))
            (s "prices" </> Parser.string <?> Query.string "quality")
        , Parser.map ListingPage (s "listing" </> Parser.int)
        , Parser.map NewListing (s "new")
        , Parser.map MyTrades (s "trades")
        , Parser.map Profile (s "u" </> Parser.string)
        , Parser.map Report (s "report" </> Parser.string)
        , Parser.map SignIn (s "signin")
        , Parser.map Onboarding (s "welcome")
        ]


fromUrl : Url -> Route
fromUrl url =
    Parser.parse parser url |> Maybe.withDefault NotFound


toString : Route -> String
toString route =
    case route of
        Home ->
            "/"

        Market ->
            "/market"

        Prices ->
            "/prices"

        ItemPrice id quality ->
            Url.Builder.absolute [ "prices", id ]
                (case quality of
                    Just q ->
                        [ Url.Builder.string "quality" (Item.qualityToString q) ]

                    Nothing ->
                        []
                )

        ListingPage id ->
            "/listing/" ++ String.fromInt id

        NewListing ->
            "/new"

        MyTrades ->
            "/trades"

        Profile name ->
            Url.Builder.absolute [ "u", name ] []

        Report name ->
            Url.Builder.absolute [ "report", name ] []

        SignIn ->
            "/signin"

        Onboarding ->
            "/welcome"

        NotFound ->
            "/"
