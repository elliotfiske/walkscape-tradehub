module Screenshot exposing (check, jpegPrefix, longSide, maxCount, maxLength)

{-| Screenshots on reports. The browser shrinks each picked image in a canvas
(`elm-pkg-js/screenshots.js`) and sends it as a JPEG data URL, and the backend
keeps them in `BackendModel.screenshots`, where only admins can load them.
-}


maxCount : Int
maxCount =
    3


{-| The longest side, in pixels, after shrinking.
-}
longSide : Int
longSide =
    1280


{-| The most characters a screenshot's data URL can have: about 300KB of JPEG,
base64-encoded.
-}
maxLength : Int
maxLength =
    410000


jpegPrefix : String
jpegPrefix =
    "data:image/jpeg;base64,"


check : List String -> Result String ()
check screenshots =
    if List.length screenshots > maxCount then
        Err ("You can add up to " ++ String.fromInt maxCount ++ " screenshots.")

    else if List.any (not << String.startsWith jpegPrefix) screenshots then
        Err "Screenshots have to be JPEG images."

    else if List.any (\s -> String.length s > maxLength) screenshots then
        Err "One of the screenshots is too big. Try a smaller one."

    else
        Ok ()
