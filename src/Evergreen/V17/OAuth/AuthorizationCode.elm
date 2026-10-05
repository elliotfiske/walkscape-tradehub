module Evergreen.V17.OAuth.AuthorizationCode exposing (..)

import Evergreen.V17.OAuth


type alias AuthorizationError =
    { error : Evergreen.V17.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V17.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
