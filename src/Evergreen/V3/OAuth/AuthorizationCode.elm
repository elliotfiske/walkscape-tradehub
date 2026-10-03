module Evergreen.V3.OAuth.AuthorizationCode exposing (..)

import Evergreen.V3.OAuth


type alias AuthorizationError =
    { error : Evergreen.V3.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V3.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
