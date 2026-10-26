module Evergreen.V38.OAuth.AuthorizationCode exposing (..)

import Evergreen.V38.OAuth


type alias AuthorizationError =
    { error : Evergreen.V38.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V38.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
