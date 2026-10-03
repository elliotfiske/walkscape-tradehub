module Item exposing
    ( Item
    , Kind(..)
    , Quality(..)
    , Rarity
    , abbreviation
    , all
    , allQualities
    , allRarities
    , byId
    , gradeColor
    , gradeLabel
    , priceKey
    , qualityColor
    , qualityFromString
    , qualityLabel
    , qualityToString
    , rarityColor
    , rarityLabel
    , rarityToString
    , search
    )

{-| The WalkScape item catalog Trailpost knows about.

Loot items have a fixed rarity. Crafted items come in a quality that the
lister picks, and prices are tracked separately for each quality. Everything
else (materials, food, collectibles…) is `Plain`, labelled by its category.

The data is generated into `ItemData` by `scripts/import-items.py` from
walkscapedb.com, until there's an official WalkScape API.

-}

import Dict exposing (Dict)
import ItemData


type Rarity
    = Common
    | Uncommon
    | Rare
    | Epic
    | Legendary
    | Ethereal


type Quality
    = Normal
    | Good
    | Great
    | Excellent
    | Perfect
    | Eternal


type Kind
    = Loot Rarity
    | Crafted
    | Plain String


type alias Item =
    { id : String
    , name : String
    , kind : Kind
    , icon : Maybe String
    }


all : List Item
all =
    List.map fromRaw ItemData.raw


{-| Our own pixel-art icons. Other items show a two-letter placeholder.
-}
localIcons : Dict String String
localIcons =
    Dict.fromList
        [ ( "shovel-axe", "/assets/shovel-axe.svg" )
        , ( "iron-pickaxe", "/assets/eternal-iron-pickaxe.svg" )
        ]


fromRaw : ( String, String, ( String, String ) ) -> Item
fromRaw ( id, name, ( kind, rarity ) ) =
    { id = id
    , name = name
    , kind =
        case kind of
            "loot" ->
                Loot (rarityFromString rarity |> Maybe.withDefault Common)

            "crafted" ->
                Crafted

            "material" ->
                Plain "Material"

            "consumable" ->
                Plain "Consumable"

            "collectible" ->
                Plain "Collectible"

            "container" ->
                Plain "Container"

            "egg" ->
                Plain "Egg"

            other ->
                Plain (String.toUpper (String.left 1 other) ++ String.dropLeft 1 other)
    , icon = Dict.get id localIcons
    }


catalog : Dict String Item
catalog =
    all |> List.map (\item -> ( item.id, item )) |> Dict.fromList


byId : String -> Maybe Item
byId id =
    Dict.get id catalog


{-| Items whose name contains the query, names starting with it first.
An empty query matches nothing; there are too many items to list them all.
-}
search : String -> List Item
search query =
    let
        normalize =
            String.toLower >> String.replace "-" " "

        q =
            normalize (String.trim query)

        matches =
            List.filter (\item -> String.contains q (normalize item.name)) all

        ( starts, rest ) =
            List.partition (\item -> String.startsWith q (normalize item.name)) matches
    in
    if q == "" then
        []

    else
        starts ++ rest


{-| Two-letter placeholder shown when an item has no icon, e.g. "ST".
-}
abbreviation : Item -> String
abbreviation item =
    case String.words item.name of
        first :: second :: _ ->
            String.toUpper (String.left 1 first ++ String.left 1 second)

        [ single ] ->
            String.toUpper (String.left 2 single)

        [] ->
            "?"


{-| Identifies a price series: one per loot item, one per crafted item and quality.
-}
priceKey : String -> Maybe Quality -> String
priceKey itemId quality =
    case quality of
        Just q ->
            itemId ++ "/" ++ qualityToString q

        Nothing ->
            itemId


allRarities : List Rarity
allRarities =
    [ Common, Uncommon, Rare, Epic, Legendary, Ethereal ]


allQualities : List Quality
allQualities =
    [ Normal, Good, Great, Excellent, Perfect, Eternal ]


rarityLabel : Rarity -> String
rarityLabel rarity =
    case rarity of
        Common ->
            "Common"

        Uncommon ->
            "Uncommon"

        Rare ->
            "Rare"

        Epic ->
            "Epic"

        Legendary ->
            "Legendary"

        Ethereal ->
            "Ethereal"


qualityLabel : Quality -> String
qualityLabel quality =
    case quality of
        Normal ->
            "Normal"

        Good ->
            "Good"

        Great ->
            "Great"

        Excellent ->
            "Excellent"

        Perfect ->
            "Perfect"

        Eternal ->
            "Eternal"


rarityToString : Rarity -> String
rarityToString =
    rarityLabel >> String.toLower


qualityToString : Quality -> String
qualityToString =
    qualityLabel >> String.toLower


rarityFromString : String -> Maybe Rarity
rarityFromString s =
    allRarities |> List.filter (\r -> rarityToString r == String.toLower s) |> List.head


qualityFromString : String -> Maybe Quality
qualityFromString s =
    allQualities |> List.filter (\q -> qualityToString q == String.toLower s) |> List.head


{-| Rarity and quality share one colour ladder, from grey up to red.
-}
rarityColor : Rarity -> String
rarityColor rarity =
    case rarity of
        Common ->
            "#9aa3a7"

        Uncommon ->
            "#6fc36a"

        Rare ->
            "#5aa2e6"

        Epic ->
            "#b07ae0"

        Legendary ->
            "#e3b54c"

        Ethereal ->
            "#e8574f"


qualityColor : Quality -> String
qualityColor quality =
    case quality of
        Normal ->
            rarityColor Common

        Good ->
            rarityColor Uncommon

        Great ->
            rarityColor Rare

        Excellent ->
            rarityColor Epic

        Perfect ->
            rarityColor Legendary

        Eternal ->
            rarityColor Ethereal


{-| Colour for a listed item: its quality if crafted, otherwise its rarity.
-}
gradeColor : Item -> Maybe Quality -> String
gradeColor item quality =
    case ( item.kind, quality ) of
        ( _, Just q ) ->
            qualityColor q

        ( Loot r, Nothing ) ->
            rarityColor r

        ( Crafted, Nothing ) ->
            rarityColor Common

        ( Plain _, Nothing ) ->
            rarityColor Common


gradeLabel : Item -> Maybe Quality -> String
gradeLabel item quality =
    case ( item.kind, quality ) of
        ( _, Just q ) ->
            qualityLabel q

        ( Loot r, Nothing ) ->
            rarityLabel r

        ( Crafted, Nothing ) ->
            "Crafted item"

        ( Plain category, Nothing ) ->
            category
