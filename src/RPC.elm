module RPC exposing (lamdera_handleEndpoints)

{-| Lamdera RPC endpoints.

Lamdera's runtime looks for `lamdera_handleEndpoints` in this module and
auto-wires it as the dispatcher for `/_r/<endpoint>` HTTP requests.

See <https://dashboard.lamdera.app/docs/rpc>. Example call:

    curl -X POST -H 'Content-Type: application/json' \
         -d '{"name":"world"}' \
         http://localhost:8000/_r/ping

-}

import Http
import Json.Decode as D
import Json.Encode as E
import Lamdera exposing (SessionId)
import LamderaRPC
import Types exposing (BackendModel, BackendMsg)


lamdera_handleEndpoints :
    LamderaRPC.RPCArgs
    -> BackendModel
    -> ( LamderaRPC.RPCResult, BackendModel, Cmd BackendMsg )
lamdera_handleEndpoints args model =
    case args.endpoint of
        "ping" ->
            LamderaRPC.handleEndpointJson handlePing args model

        _ ->
            ( LamderaRPC.ResultFailure <| Http.BadBody <| "Unknown endpoint " ++ args.endpoint
            , model
            , Cmd.none
            )


handlePing :
    SessionId
    -> BackendModel
    -> E.Value
    -> ( Result Http.Error E.Value, BackendModel, Cmd BackendMsg )
handlePing _ model jsonArg =
    let
        decoder =
            D.field "name" D.string
    in
    case D.decodeValue decoder jsonArg of
        Ok name ->
            ( Ok <| E.object [ ( "pong", E.string ("Hello, " ++ name ++ "!") ) ]
            , model
            , Cmd.none
            )

        Err err ->
            ( Err <| Http.BadBody <| "Failed to decode ping request: " ++ D.errorToString err
            , model
            , Cmd.none
            )
