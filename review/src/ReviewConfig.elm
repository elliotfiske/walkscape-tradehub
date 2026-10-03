module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

To add packages that contain rules, add them to this review project using

    `elm install author/packagename`

when inside the directory containing this file.

-}

import Docs.ReviewAtDocs
import NoConfusingPrefixOperator
import NoDebug.TodoOrToString
import NoExposingEverything
import NoImportingEverything
import NoMissingTypeAnnotation
import NoMissingTypeAnnotationInLetIn
import NoMissingTypeExpose
import NoPrematureLetComputation
import NoSimpleLetBody
import NoUnused.CustomTypeConstructorArgs
import NoUnused.CustomTypeConstructors
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Parameters
import NoUnused.Patterns
import NoUnused.Variables
import Review.Rule as Rule exposing (Rule)
import Simplify


{-| Lamdera's runtime (and its auto-generated `elm-stuff/lamdera/Lamdera/*`
modules, which elm-review can't see) introspects these files: `app` in
Backend/Frontend, `lamdera_handleEndpoints` in RPC, `process` in LamderaRPC.
`NoUnused.Exports` would flag those bindings as dead. We keep each module's
exposing list narrow and exempt the files from the unused-exports check.
-}
lamderaMagicModules : List String
lamderaMagicModules =
    [ "src/Backend.elm"
    , "src/Frontend.elm"
    , "src/Types.elm"
    , "src/Env.elm"
    , "src/RPC.elm"
    , "src/LamderaRPC.elm"
    ]


{-| Third-party code we copy-vendor (e.g. lamdera/auth which isn't a published
package) is exempted from all review rules — we don't own its style.
-}
vendoredDirectories : List String
vendoredDirectories =
    [ "vendor/" ]


config : List Rule
config =
    List.map (Rule.ignoreErrorsForDirectories vendoredDirectories)
        [ --Docs.ReviewAtDocs.rule
          --, NoConfusingPrefixOperator.rule
          NoDebug.TodoOrToString.rule
            |> Rule.ignoreErrorsForDirectories [ "tests/" ]
        , NoExposingEverything.rule
        , NoImportingEverything.rule []

        --, NoMissingTypeAnnotation.rule
        --, NoMissingTypeAnnotationInLetIn.rule
        --, NoMissingTypeExpose.rule
        --, NoSimpleLetBody.rule
        --, NoPrematureLetComputation.rule
        --, NoUnused.CustomTypeConstructors.rule []
        --, NoUnused.CustomTypeConstructorArgs.rule
        -- NoUnused.Dependencies disabled: Lamdera regenerates elm.json and keeps
        -- elm/browser and elm/bytes in `direct` even though no app code imports them.
        , NoUnused.Exports.rule
            |> Rule.ignoreErrorsForFiles lamderaMagicModules

        --, NoUnused.Parameters.rule
        --, NoUnused.Patterns.rule
        , NoUnused.Variables.rule

        --, Simplify.rule Simplify.defaults
        ]
