module Evergreen.V27.OAuth.AuthorizationCode exposing (..)

import Evergreen.V27.OAuth


type alias AuthorizationError =
    { error : Evergreen.V27.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V27.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
