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
    | ItemPrice String Item.Variant
    | ListingPage Int
    | NewListing (Maybe ( String, Item.Variant ))
    | MyTrades
    | Profile String
    | Report String (Maybe Int)
    | SignIn
    | Onboarding
    | Admin
    | NotFound


parser : Parser (Route -> a) a
parser =
    oneOf
        [ Parser.map Home Parser.top
        , Parser.map Market (s "market")
        , Parser.map Prices (s "prices")
        , Parser.map (\id q fine rare -> ItemPrice id { fine = fine == Just "1", rare = rare == Just "1", quality = Maybe.andThen Item.qualityFromString q })
            (s "prices" </> Parser.string <?> Query.string "quality" <?> Query.string "fine" <?> Query.string "rare")
        , Parser.map ListingPage (s "listing" </> Parser.int)
        , Parser.map (\item q fine rare -> NewListing (item |> Maybe.map (\id -> ( id, { fine = fine == Just "1", rare = rare == Just "1", quality = Maybe.andThen Item.qualityFromString q } ))))
            (s "new" <?> Query.string "item" <?> Query.string "quality" <?> Query.string "fine" <?> Query.string "rare")
        , Parser.map MyTrades (s "trades")
        , Parser.map Profile (s "u" </> traderName)
        , Parser.map Report (s "report" </> traderName <?> Query.int "trade")
        , Parser.map SignIn (s "signin")
        , Parser.map Onboarding (s "welcome")
        , Parser.map Admin (s "admin")
        ]


{-| A trader name in the path. `Parser.string` doesn't percent-decode, and names
can have spaces ("Slyth Inaru" is `/u/Slyth%20Inaru`).
-}
traderName : Parser (String -> a) a
traderName =
    Parser.custom "NAME" Url.percentDecode


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

        ItemPrice id variant ->
            Url.Builder.absolute [ "prices", id ] (variantQuery variant)

        ListingPage id ->
            "/listing/" ++ String.fromInt id

        NewListing Nothing ->
            "/new"

        NewListing (Just ( id, variant )) ->
            Url.Builder.absolute [ "new" ] (Url.Builder.string "item" id :: variantQuery variant)

        MyTrades ->
            "/trades"

        Profile name ->
            Url.Builder.absolute [ "u", Url.percentEncode name ] []

        Report name trade ->
            Url.Builder.absolute [ "report", Url.percentEncode name ] (trade |> Maybe.map (Url.Builder.int "trade") |> Maybe.map List.singleton |> Maybe.withDefault [])

        SignIn ->
            "/signin"

        Onboarding ->
            "/welcome"

        Admin ->
            "/admin"

        NotFound ->
            "/"


variantQuery : Item.Variant -> List Url.Builder.QueryParameter
variantQuery variant =
    (if variant.fine then
        [ Url.Builder.string "fine" "1" ]

     else
        []
    )
        ++ (if variant.rare then
                [ Url.Builder.string "rare" "1" ]

            else
                []
           )
        ++ (case variant.quality of
                Just q ->
                    [ Url.Builder.string "quality" (Item.qualityToString q) ]

                Nothing ->
                    []
           )
