module Evergreen.V18.OAuth.AuthorizationCode exposing (..)

import Evergreen.V18.OAuth


type alias AuthorizationError =
    { error : Evergreen.V18.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V18.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
