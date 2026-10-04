module Evergreen.V10.OAuth.AuthorizationCode exposing (..)

import Evergreen.V10.OAuth


type alias AuthorizationError =
    { error : Evergreen.V10.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V10.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
