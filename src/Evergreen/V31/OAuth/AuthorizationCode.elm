module Evergreen.V31.OAuth.AuthorizationCode exposing (..)

import Evergreen.V31.OAuth


type alias AuthorizationError =
    { error : Evergreen.V31.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V31.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
