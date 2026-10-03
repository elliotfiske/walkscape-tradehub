module LamderaRPC exposing
    ( RPCArgs
    , RPCResult(..)
    , handleEndpointJson
    , process
    )

{-| Lamdera RPC user-side plumbing.

Lamdera's auto-generated runtime calls `LamderaRPC.process` from
`elm-stuff/lamdera/Lamdera/Live.elm` (dev mode) and the equivalent
production module — so `process` must exist with this signature even
though no hand-written code calls it.

This file is a trimmed subset of the canonical LamderaRPC module from
the Lamdera community examples. The wider helper set (`asTask*` for
frontend → backend calls, `handleEndpoint` for typed Wire3 codecs, etc.)
lives in git history at `bbdb147:OLD-dashboard/src/LamderaRPC.elm` —
pull pieces back when an endpoint needs them.

-}

import Http exposing (Error(..))
import Json.Decode as D
import Lamdera.Json as Json
import Types exposing (BackendModel)


type RPCResult
    = ResultBytes (List Int)
    | ResultJson Json.Value
    | ResultString String
    | ResultFailure Http.Error


type Body
    = Bytes (List Int)
    | JSON Json.Value
    | Raw String


type alias RPCArgs =
    { sessionId : String
    , endpoint : String
    , requestId : String
    , body : Body
    }


bodyTypeToString : Body -> String
bodyTypeToString body =
    case body of
        Bytes _ ->
            "Bytes"

        JSON _ ->
            "JSON"

        Raw _ ->
            "Raw"


argsDecoder : D.Decoder RPCArgs
argsDecoder =
    D.map4 RPCArgs
        (Json.field "s" Json.decoderString)
        (Json.field "e" Json.decoderString)
        (Json.field "r" Json.decoderString)
        (D.oneOf
            [ Json.field "i" (Json.decoderList Json.decoderInt |> D.map Bytes)
            , Json.field "j" (Json.decoderValue |> D.map JSON)
            , Json.field "st" (Json.decoderString |> D.map Raw)
            ]
        )


process :
    (String -> String -> Cmd msg)
    -> (Json.Value -> Cmd msg)
    -> Json.Value
    -> (RPCArgs -> BackendModel -> ( RPCResult, BackendModel, Cmd msg ))
    -> { a | userModel : BackendModel }
    -> ( { a | userModel : BackendModel }, Cmd msg )
process log rpcOut rpcArgsJson handler model =
    case Json.decodeValue argsDecoder rpcArgsJson of
        Ok rpcArgs ->
            let
                ( result, newUserModel, newCmds ) =
                    handler rpcArgs model.userModel

                resolveRpc payload =
                    rpcOut
                        (Json.object
                            [ ( "t", Json.string "qr" )
                            , ( "r", Json.string rpcArgs.requestId )
                            , payload
                            ]
                        )
            in
            case result of
                ResultBytes intList ->
                    ( { model | userModel = newUserModel }
                    , Cmd.batch [ resolveRpc ( "i", Json.list Json.int intList ), newCmds ]
                    )

                ResultJson value ->
                    ( { model | userModel = newUserModel }
                    , Cmd.batch [ resolveRpc ( "v", value ), newCmds ]
                    )

                ResultString value ->
                    ( { model | userModel = newUserModel }
                    , Cmd.batch [ resolveRpc ( "vs", Json.string value ), newCmds ]
                    )

                ResultFailure err ->
                    ( model
                    , Cmd.batch
                        [ resolveRpc ( "v", Json.object [ ( "error", Json.string (httpErrorToString err) ) ] )
                        , newCmds
                        ]
                    )

        Err _ ->
            ( model, log "rpcIn failed to decode rpcArgsJson" "" )


handleEndpointJson :
    (String -> model -> Json.Value -> ( Result Http.Error Json.Value, model, Cmd msg ))
    -> RPCArgs
    -> model
    -> ( RPCResult, model, Cmd msg )
handleEndpointJson fn args model =
    case args.body of
        JSON json ->
            let
                ( response, newModel, newCmds ) =
                    fn args.sessionId model json
            in
            case response of
                Ok value ->
                    ( ResultJson value, newModel, newCmds )

                Err httpErr ->
                    ( ResultFailure httpErr, newModel, newCmds )

        _ ->
            ( ResultFailure <|
                BadBody <|
                    "JSON endpoint '"
                        ++ args.endpoint
                        ++ "' was given body type "
                        ++ bodyTypeToString args.body
            , model
            , Cmd.none
            )


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        BadUrl url ->
            "HTTP Malformed url: " ++ url

        Timeout ->
            "HTTP Timeout exceeded"

        NetworkError ->
            "HTTP Network error"

        BadStatus code ->
            "Unexpected HTTP response code: " ++ String.fromInt code

        BadBody text ->
            "Unexpected HTTP response: " ++ text
