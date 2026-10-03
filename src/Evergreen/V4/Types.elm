module Evergreen.V4.Types exposing (..)

import Dict
import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Evergreen.V4.Auth.Common
import Evergreen.V4.Item
import Evergreen.V4.Route
import Time
import Url


type Provider
    = Discord


type ClaimStatus
    = AwaitingCoinOffer
    | PreviewUnverified


type alias Claim =
    { name : String
    , coins : Int
    , status : ClaimStatus
    }


type alias Me =
    { provider : Provider
    , isPreviewLogin : Bool
    , claim : Maybe Claim
    }


type Side
    = Selling
    | Buying


type Payment
    = Coins Int


type alias Listing =
    { id : Int
    , trader : String
    , itemId : String
    , variant : Evergreen.V4.Item.Variant
    , side : Side
    , payment : Payment
    , quantity : Int
    , note : String
    , createdAt : Time.Posix
    , liveAt : Time.Posix
    , closed : Bool
    }


type OfferStatus
    = OfferOpen
    | OfferAccepted
    | OfferDeclined
    | OfferWithdrawn


type alias Offer =
    { id : Int
    , listingId : Int
    , from : String
    , price : Maybe Int
    , message : String
    , at : Time.Posix
    , status : OfferStatus
    }


type alias Trader =
    { name : String
    , joinedAt : Time.Posix
    , discord : Maybe String
    , lookalikeOf : Maybe String
    }


type MarketTab
    = AllListings
    | SellingTab
    | BuyingTab


type MarketSort
    = Newest
    | PriceLow
    | PriceHigh


type alias MarketFilters =
    { tab : MarketTab
    , rarities : List Evergreen.V4.Item.Rarity
    , qualities : List Evergreen.V4.Item.Quality
    , fineOnly : Bool
    , sort : MarketSort
    , hideOutliers : Bool
    , search : String
    }


type alias ListingForm =
    { itemQuery : String
    , itemId : Maybe String
    , quality : Evergreen.V4.Item.Quality
    , fine : Bool
    , side : Side
    , quantity : String
    , price : String
    , note : String
    , error : Maybe String
    , submitting : Bool
    }


type alias OfferForm =
    { counter : Bool
    , price : String
    , message : String
    , error : Maybe String
    }


type alias ReportForm =
    { about : String
    , reasons : List String
    , details : String
    , sent : Bool
    }


type TradesTab
    = ReceivedTab
    | SentTab
    | MyListingsTab


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , route : Evergreen.V4.Route.Route
    , now : Time.Posix
    , authFlow : Evergreen.V4.Auth.Common.Flow
    , authRedirectBaseUrl : Url.Url
    , me : Maybe Me
    , loaded : Bool
    , listings : Dict.Dict Int Listing
    , offers : Dict.Dict Int Offer
    , traders : Dict.Dict String Trader
    , filters : MarketFilters
    , noticeDismissed : Bool
    , filtersOpen : Bool
    , claimName : String
    , claimError : Maybe String
    , listingForm : ListingForm
    , offerForm : OfferForm
    , reportForm : ReportForm
    , previewSignInFor : Maybe Provider
    , toast : Maybe String
    , tradesTab : TradesTab
    }


type alias UserId =
    String


type alias User =
    { id : UserId
    , provider : Provider
    , isPreviewLogin : Bool
    , oauthUsername : Maybe String
    , claim : Maybe Claim
    , joinedAt : Time.Posix
    }


type alias Report =
    { reporter : String
    , about : String
    , reasons : List String
    , details : String
    , at : Time.Posix
    }


type alias BackendModel =
    { now : Time.Posix
    , users : Dict.Dict UserId User
    , sessions : Dict.Dict String UserId
    , listings : Dict.Dict Int Listing
    , offers : Dict.Dict Int Offer
    , reports : List Report
    , nextId : Int
    , pendingAuths : Dict.Dict Evergreen.V4.Auth.Common.SessionId Evergreen.V4.Auth.Common.PendingAuth
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url.Url
    | Tick Time.Posix
    | ProviderClicked Provider
    | PreviewSignInConfirmed Provider
    | PreviewSignInCancelled
    | SignOutClicked
    | ClaimNameChanged String
    | ClaimNameSubmitted
    | ChangeClaimClicked
    | SkipVerificationClicked
    | SearchChanged String
    | TabSelected MarketTab
    | SortSelected MarketSort
    | RarityToggled Evergreen.V4.Item.Rarity
    | QualityToggled Evergreen.V4.Item.Quality
    | FineOnlyToggled
    | HideOutliersToggled
    | FiltersToggled
    | NoticeDismissed
    | ListingItemQueryChanged String
    | ListingItemPicked String
    | ListingItemCleared
    | ListingQualityPicked Evergreen.V4.Item.Quality
    | ListingFineToggled Bool
    | ListingSidePicked Side
    | ListingQuantityChanged String
    | ListingPriceChanged String
    | ListingNoteChanged String
    | ListingSubmitted
    | CloseListingClicked Int
    | OfferCounterToggled Bool
    | OfferPriceChanged String
    | OfferMessageChanged String
    | OfferSubmitted Int
    | WithdrawOfferClicked Int
    | RespondToOfferClicked Int Bool
    | ReportReasonToggled String
    | ReportDetailsChanged String
    | ReportSubmitted
    | ToastDismissed
    | TradesTabSelected TradesTab
    | NoOpFrontendMsg


type alias ListingDraft =
    { itemId : String
    , variant : Evergreen.V4.Item.Variant
    , side : Side
    , payment : Payment
    , quantity : Int
    , note : String
    }


type ToBackend
    = AuthToBackend Evergreen.V4.Auth.Common.ToBackend
    | PreviewSignIn Provider
    | SignOut
    | ClaimName String
    | SkipVerification
    | CreateListing ListingDraft
    | CloseListing Int
    | MakeOffer Int (Maybe Int) String
    | WithdrawOffer Int
    | RespondToOffer Int Bool
    | SubmitReport String (List String) String


type BackendMsg
    = ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | AuthBackendMsg Evergreen.V4.Auth.Common.BackendMsg
    | GotTime Time.Posix
    | BackendTick Time.Posix
    | FromFrontendAt Effect.Lamdera.SessionId Effect.Lamdera.ClientId ToBackend Time.Posix


type alias InitialData =
    { listings : List Listing
    , offers : List Offer
    , traders : List Trader
    }


type ToFrontend
    = AuthToFrontend Evergreen.V4.Auth.Common.ToFrontend
    | InitialDataSent InitialData
    | YouAre (Maybe Me)
    | ListingUpserted Listing
    | OfferUpserted Offer
    | TraderUpserted Trader
    | ClaimRejected String
    | ListingCreated Int
    | ReportReceived
    | ActionFailed String
