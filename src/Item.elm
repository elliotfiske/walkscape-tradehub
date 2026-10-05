module Item exposing
    ( Item
    , Kind(..)
    , Quality(..)
    , Rarity(..)
    , Variant
    , all
    , allQualities
    , allRarities
    , byId
    , fullName
    , gradeColor
    , gradeLabel
    , normalizeVariant
    , plain
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

Materials and consumables can also be "fine", which the game treats as a better
version of the item, and pet eggs can be "rare". Fine and rare items are priced
as their own items, so a listing's `Variant` is whether it's fine or rare plus,
for crafted items, its quality.

The data is generated into `ItemData` by `scripts/import-items.py` from the
WalkScape Tools API (only items the game lets you trade), and icons by
`scripts/pull-icons.py` into `public/icons/<id>.png`. Ids are the game's own,
like "iron\_pickaxe".

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
    , canBeFine : Bool
    , canBeRare : Bool
    , icon : String
    }


type alias Variant =
    { fine : Bool
    , rare : Bool
    , quality : Maybe Quality
    }


{-| Not fine or rare, no quality: a loot or plain item as it usually comes.
-}
plain : Variant
plain =
    { fine = False, rare = False, quality = Nothing }


all : List Item
all =
    List.map fromRaw ItemData.raw


fromRaw : ( String, String, ( String, String, Bool ) ) -> Item
fromRaw ( id, name, ( kind, rarity, canBeFine ) ) =
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
    , canBeFine = canBeFine
    , canBeRare = kind == "egg"
    , icon = "/icons/" ++ id ++ ".png"
    }


catalog : Dict String Item
catalog =
    all |> List.map (\item -> ( item.id, item )) |> Dict.fromList


byId : String -> Maybe Item
byId id =
    Dict.get id catalog


{-| Items whose name contains the query, names starting with it first.
An empty query matches nothing; there are too many items to list them all.
A leading "fine" or "rare" is ignored, so "fine iron" finds the iron items.
-}
search : String -> List Item
search query =
    let
        normalize =
            String.toLower >> String.replace "-" " "

        trimmed =
            normalize (String.trim query)

        q =
            if String.startsWith "fine " trimmed || String.startsWith "rare " trimmed then
                String.trim (String.dropLeft 5 trimmed)

            else
                trimmed

        matches =
            List.filter (\item -> String.contains q (normalize item.name)) all

        ( starts, rest ) =
            List.partition (\item -> String.startsWith q (normalize item.name)) matches
    in
    if q == "" then
        []

    else
        starts ++ rest


{-| The variant this item can actually come in: fine or rare only if the item
can be, and a quality for crafted items only (`Normal` if none was picked).
-}
normalizeVariant : Item -> Variant -> Variant
normalizeVariant item variant =
    { fine = variant.fine && item.canBeFine
    , rare = variant.rare && item.canBeRare
    , quality =
        case item.kind of
            Crafted ->
                Just (Maybe.withDefault Normal variant.quality)

            _ ->
                Nothing
    }


{-| The name plus a crafted item's quality, e.g. "Iron pickaxe · Perfect".
-}
fullName : Item -> Variant -> String
fullName item variant =
    item.name ++ (variant.quality |> Maybe.map (\q -> " · " ++ qualityLabel q) |> Maybe.withDefault "")


{-| Identifies a price series: one per item, with fine and rare items and each
crafted quality tracked separately, e.g. "iron_bar", "iron_bar/fine",
"camel_egg/rare", "iron_pickaxe/perfect".
-}
priceKey : String -> Variant -> String
priceKey itemId variant =
    String.join "/"
        (itemId
            :: (if variant.fine then
                    [ "fine" ]

                else
                    []
               )
            ++ (if variant.rare then
                    [ "rare" ]

                else
                    []
               )
            ++ (variant.quality |> Maybe.map (\q -> [ qualityToString q ]) |> Maybe.withDefault [])
        )


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


{-| The red the game uses for rare pet eggs. It's not the loot Rare blue.
-}
rareEggColor : String
rareEggColor =
    "#e0524c"


{-| Colour for a listed item: its quality if crafted, red for a rare egg,
otherwise its rarity.
-}
gradeColor : Item -> Variant -> String
gradeColor item variant =
    if variant.rare then
        rareEggColor

    else
        baseGradeColor item variant


baseGradeColor : Item -> Variant -> String
baseGradeColor item variant =
    case ( item.kind, variant.quality ) of
        ( _, Just q ) ->
            qualityColor q

        ( Loot r, Nothing ) ->
            rarityColor r

        ( Crafted, Nothing ) ->
            rarityColor Common

        ( Plain _, Nothing ) ->
            rarityColor Common


{-| "Legendary", "Perfect", "Material"…, with "Fine · " or "Rare · " in front
for fine and rare items.
-}
gradeLabel : Item -> Variant -> String
gradeLabel item variant =
    (if variant.fine then
        "Fine · "

     else if variant.rare then
        "Rare · "

     else
        ""
    )
        ++ baseGradeLabel item variant.quality


baseGradeLabel : Item -> Maybe Quality -> String
baseGradeLabel item quality =
    case ( item.kind, quality ) of
        ( _, Just q ) ->
            qualityLabel q

        ( Loot r, Nothing ) ->
            rarityLabel r

        ( Crafted, Nothing ) ->
            "Crafted item"

        ( Plain category, Nothing ) ->
            category
