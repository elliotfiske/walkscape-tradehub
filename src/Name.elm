module Name exposing (lookalikeOf, normalize, validate)

{-| WalkScape character names: validation and look-alike detection.

A character name is not the same as a WalkScape portal username. The portal's
leaderboard shows the character name as the main link, with the account's
username in grey parentheses after it when that account is public ("Slyth
Inaru (Slyth\_Inaru)"). Character names can contain single spaces between
words; usernames can have underscores and other punctuation.

-}


{-| Trim and check a name someone wants to claim.
-}
validate : String -> Result String String
validate raw =
    let
        name =
            String.trim raw

        len =
            String.length name
    in
    if len == 0 then
        Err "Enter your WalkScape character name."

    else if len > 30 then
        Err "WalkScape character names are at most 30 characters long."

    else if not (String.all (\c -> Char.isAlphaNum c || c == ' ') name) then
        Err "Names can only use letters, numbers and spaces."

    else if String.contains "  " name then
        Err "Use a single space between words."

    else if String.length (String.filter (\c -> c /= ' ') name) < 3 then
        Err "WalkScape character names need at least 3 letters or numbers, not counting spaces."

    else
        Ok name


{-| The form used to compare names: case-insensitive.
-}
normalize : String -> String
normalize =
    String.toLower


{-| If `name` is suspiciously close to one of `established` (but not the same
name), return the name it imitates. "Mosbeard\_" imitates "Mossbeard", and
"SlythInaru" imitates "Slyth Inaru".
-}
lookalikeOf : String -> List String -> Maybe String
lookalikeOf name established =
    let
        squash s =
            normalize s |> String.filter (\c -> c /= '_' && c /= ' ')

        target =
            squash name
    in
    established
        |> List.filter (\other -> normalize other /= normalize name)
        |> List.filter
            (\other ->
                let
                    o =
                        squash other
                in
                (o == target) || (String.length o >= 5 && distance o target <= 1)
            )
        |> List.head


{-| Levenshtein edit distance.
-}
distance : String -> String -> Int
distance a b =
    let
        bChars =
            String.toList b

        firstRow =
            List.range 0 (List.length bChars)

        step ( i, ca ) prevRow =
            let
                go prev diagAbove bs left acc =
                    case ( prev, bs ) of
                        ( above :: restPrev, cb :: restB ) ->
                            let
                                cost =
                                    if ca == cb then
                                        0

                                    else
                                        1

                                value =
                                    min (min (above + 1) (left + 1)) (diagAbove + cost)
                            in
                            go restPrev above restB value (value :: acc)

                        _ ->
                            List.reverse acc
            in
            case prevRow of
                first :: rest ->
                    go rest first bChars (i + 1) [ i + 1 ]

                [] ->
                    []
    in
    String.toList a
        |> List.indexedMap Tuple.pair
        |> List.foldl step firstRow
        |> List.reverse
        |> List.head
        |> Maybe.withDefault 0
