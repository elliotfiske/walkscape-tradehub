port module ScreenshotShrink exposing (request, subscription)

{-| Shrinks a picked screenshot in the browser before it's sent with a report.
`elm-pkg-js/screenshots.js` draws it on a canvas at most `Screenshot.longSide`
pixels on its long side and answers with a JPEG data URL, or an error.
-}

import Effect.Command as Command exposing (Command, FrontendOnly)
import Effect.Subscription as Subscription exposing (Subscription)
import Json.Decode as Decode
import Json.Encode as Encode
import Screenshot


port downscaleScreenshot : Encode.Value -> Cmd msg


port screenshotDownscaled : (Decode.Value -> msg) -> Sub msg


{-| `dataUrl` is the picked file, as read by `Effect.File.toUrl`.
-}
request : String -> Command FrontendOnly toBackend msg
request dataUrl =
    Command.sendToJs "downscaleScreenshot"
        downscaleScreenshot
        (Encode.object
            [ ( "dataUrl", Encode.string dataUrl )
            , ( "longSide", Encode.int Screenshot.longSide )
            , ( "maxLength", Encode.int Screenshot.maxLength )
            ]
        )


subscription : (Result String String -> msg) -> Subscription FrontendOnly msg
subscription toMsg =
    Subscription.fromJs "screenshotDownscaled"
        screenshotDownscaled
        (\value ->
            toMsg
                (case Decode.decodeValue decoder value of
                    Ok result ->
                        result

                    Err _ ->
                        Err "Something went wrong with that image."
                )
        )


decoder : Decode.Decoder (Result String String)
decoder =
    Decode.oneOf
        [ Decode.field "ok" Decode.string |> Decode.map Ok
        , Decode.field "error" Decode.string |> Decode.map Err
        ]
