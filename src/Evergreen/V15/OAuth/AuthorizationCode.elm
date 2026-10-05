module Evergreen.V15.OAuth.AuthorizationCode exposing (..)

import Evergreen.V15.OAuth


type alias AuthorizationError =
    { error : Evergreen.V15.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V15.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
