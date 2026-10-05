module Evergreen.V16.OAuth.AuthorizationCode exposing (..)

import Evergreen.V16.OAuth


type alias AuthorizationError =
    { error : Evergreen.V16.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V16.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
