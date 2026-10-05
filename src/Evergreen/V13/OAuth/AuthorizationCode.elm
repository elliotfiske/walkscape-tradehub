module Evergreen.V13.OAuth.AuthorizationCode exposing (..)

import Evergreen.V13.OAuth


type alias AuthorizationError =
    { error : Evergreen.V13.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V13.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
