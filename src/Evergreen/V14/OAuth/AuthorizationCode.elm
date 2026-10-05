module Evergreen.V14.OAuth.AuthorizationCode exposing (..)

import Evergreen.V14.OAuth


type alias AuthorizationError =
    { error : Evergreen.V14.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationError =
    { error : Evergreen.V14.OAuth.ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
