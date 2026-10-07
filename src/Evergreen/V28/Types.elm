module Evergreen.V28.Types exposing (..)

import Dict
import Effect.Browser
import Effect.Browser.Navigation
import Effect.File
import Effect.Lamdera
import Evergreen.V28.Auth.Common
import Evergreen.V28.Item
import Evergreen.V28.Route
import Time
import Url


type Provider
    = Discord


type ClaimStatus
    = PreviewUnverified


type alias Claim =
    { name : String
    , status : ClaimStatus
    }


type alias Ban =
    { reason : String
    , at : Time.Posix
    , by : String
    }


type alias Me =
    { provider : Provider
    , isPreviewLogin : Bool
    , claim : Maybe Claim
    , isAdmin : Bool
    , ban : Maybe Ban
    , timersNoticeDismissed : Bool
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
    , variant : Evergreen.V28.Item.Variant
    , side : Side
    , payment : Payment
    , quantity : Int
    , note : String
    , createdAt : Time.Posix
    , liveAt : Time.Posix
    , closed : Bool
    }


type alias FellThrough =
    { by : String
    , at : Time.Posix
    , reason : String
    }


type OfferStatus
    = OfferOpen
    | OfferAccepted
    | OfferDeclined
    | OfferWithdrawn
    | OfferCompleted Time.Posix
    | OfferFellThrough FellThrough


type alias Offer =
    { id : Int
    , listingId : Int
    , from : String
    , price : Maybe Int
    , message : String
    , at : Time.Posix
    , status : OfferStatus
    , listerConfirmed : Bool
    , offererConfirmed : Bool
    }


type alias Trader =
    { name : String
    , joinedAt : Time.Posix
    , discord : Maybe String
    , discordSince : Maybe Time.Posix
    , lookalikeOf : Maybe String
    , banned : Bool
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
    , rarities : List Evergreen.V28.Item.Rarity
    , qualities : List Evergreen.V28.Item.Quality
    , fineOnly : Bool
    , sort : MarketSort
    , hideOutliers : Bool
    , search : String
    }


type alias ListingForm =
    { itemQuery : String
    , itemId : Maybe String
    , quality : Evergreen.V28.Item.Quality
    , fine : Bool
    , rare : Bool
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


type alias FellThroughForm =
    { offerId : Int
    , reason : String
    , error : Maybe String
    }


type alias ReportForm =
    { about : String
    , trade : Maybe Int
    , reasons : List String
    , details : String
    , screenshots : List String
    , shrinking : Int
    , screenshotError : Maybe String
    , sent : Bool
    }


type TradesTab
    = ReceivedTab
    | SentTab
    | MyListingsTab


type alias AdminUser =
    { name : String
    , ready : Bool
    , discord : Maybe String
    , isPreviewLogin : Bool
    , joinedAt : Time.Posix
    , isAdmin : Bool
    , ban : Maybe Ban
    }


type alias ReportedTrade =
    { listing : Listing
    , offer : Offer
    }


type alias Report =
    { id : Int
    , reporter : String
    , about : String
    , reasons : List String
    , details : String
    , at : Time.Posix
    , resolved : Bool
    , trade : Maybe ReportedTrade
    , screenshots : List Int
    }


type alias AdminLogEntry =
    { at : Time.Posix
    , by : String
    , text : String
    }


type alias AdminData =
    { accounts : Int
    , users : List AdminUser
    , listings : List Listing
    , offers : List Offer
    , reports : List Report
    , log : List AdminLogEntry
    }


type AdminTab
    = AdminReports
    | AdminListings
    | AdminPlayers
    | AdminLog


type AdminAction
    = DeleteListing Int
    | DeleteOffer Int
    | BanPlayer String String
    | UnbanPlayer String
    | ReleaseName String
    | SetReportResolved Int Bool


type alias AdminPage =
    { tab : AdminTab
    , search : String
    , confirming : Maybe AdminAction
    , banReason : String
    }


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , route : Evergreen.V28.Route.Route
    , now : Time.Posix
    , authFlow : Evergreen.V28.Auth.Common.Flow
    , authRedirectBaseUrl : Url.Url
    , me : Maybe Me
    , loaded : Bool
    , listings : Dict.Dict Int Listing
    , offers : Dict.Dict Int Offer
    , traders : Dict.Dict String Trader
    , filters : MarketFilters
    , filtersOpen : Bool
    , claimName : String
    , claimError : Maybe String
    , listingForm : ListingForm
    , offerForm : OfferForm
    , fellThroughForm : Maybe FellThroughForm
    , reportForm : ReportForm
    , previewSignInFor : Maybe Provider
    , toast : Maybe String
    , tradesTab : TradesTab
    , admin : Maybe AdminData
    , adminPage : AdminPage
    , adminScreenshots : Dict.Dict Int (List String)
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
    , ban : Maybe Ban
    , timersNoticeDismissed : Bool
    }


type alias BackendModel =
    { now : Time.Posix
    , users : Dict.Dict UserId User
    , sessions : Dict.Dict String UserId
    , listings : Dict.Dict Int Listing
    , offers : Dict.Dict Int Offer
    , reports : List Report
    , screenshots : Dict.Dict Int String
    , adminLog : List AdminLogEntry
    , nextId : Int
    , pendingAuths : Dict.Dict Evergreen.V28.Auth.Common.SessionId Evergreen.V28.Auth.Common.PendingAuth
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url.Url
    | Tick Time.Posix
    | ProviderClicked Provider
    | PreviewSignInConfirmed Provider
    | PreviewAdminSignInClicked
    | PreviewSignInCancelled
    | SignOutClicked
    | ClaimNameChanged String
    | ClaimNameSubmitted
    | SearchChanged String
    | TabSelected MarketTab
    | SortSelected MarketSort
    | RarityToggled Evergreen.V28.Item.Rarity
    | QualityToggled Evergreen.V28.Item.Quality
    | FineOnlyToggled
    | HideOutliersToggled
    | FiltersToggled
    | NoticeDismissed
    | ListingItemQueryChanged String
    | ListingItemPicked String
    | ListingItemCleared
    | ListingQualityPicked Evergreen.V28.Item.Quality
    | ListingFineToggled Bool
    | ListingRareToggled Bool
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
    | TradeConfirmClicked Int
    | FellThroughClicked Int
    | FellThroughReasonChanged String
    | FellThroughSubmitted
    | FellThroughCancelled
    | ReportReasonToggled String
    | ReportDetailsChanged String
    | ReportSubmitted
    | ReportAddScreenshotsClicked
    | ReportScreenshotsPicked Effect.File.File (List Effect.File.File)
    | ReportScreenshotRead String
    | ReportScreenshotShrunk (Result String String)
    | ReportScreenshotRemoved Int
    | AdminShowScreenshotsClicked Int
    | ToastDismissed
    | TradesTabSelected TradesTab
    | AdminTabSelected AdminTab
    | AdminSearchChanged String
    | AdminActionClicked AdminAction
    | AdminBanReasonChanged String
    | AdminConfirmed
    | AdminCancelled
    | AdminRefreshClicked
    | NoOpFrontendMsg


type alias ListingDraft =
    { itemId : String
    , variant : Evergreen.V28.Item.Variant
    , side : Side
    , payment : Payment
    , quantity : Int
    , note : String
    }


type alias ReportDraft =
    { about : String
    , reasons : List String
    , details : String
    , offerId : Maybe Int
    , screenshots : List String
    }


type ToBackend
    = AuthToBackend Evergreen.V28.Auth.Common.ToBackend
    | RequestState
    | PreviewSignIn Provider
    | PreviewAdminSignIn
    | SignOut
    | ClaimName String
    | DismissTimersNotice
    | CreateListing ListingDraft
    | CloseListing Int
    | MakeOffer Int (Maybe Int) String
    | WithdrawOffer Int
    | RespondToOffer Int Bool
    | ConfirmTrade Int
    | MarkFellThrough Int String
    | SubmitReport ReportDraft
    | AdminLoad
    | AdminLoadScreenshots Int
    | AdminRequest AdminAction


type BackendMsg
    = ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | AuthBackendMsg Evergreen.V28.Auth.Common.BackendMsg
    | GotTime Time.Posix
    | BackendTick Time.Posix
    | FromFrontendAt Effect.Lamdera.SessionId Effect.Lamdera.ClientId ToBackend Time.Posix


type alias InitialData =
    { listings : List Listing
    , offers : List Offer
    , traders : List Trader
    }


type ToFrontend
    = AuthToFrontend Evergreen.V28.Auth.Common.ToFrontend
    | InitialDataSent InitialData
    | YouAre (Maybe Me)
    | ListingUpserted Listing
    | ListingRemoved Int
    | OfferUpserted Offer
    | OfferRemoved Int
    | TraderUpserted Trader
    | TraderRemoved String
    | ClaimRejected String
    | ListingCreated Int
    | ReportReceived
    | ActionFailed String
    | AdminDataSent AdminData
    | AdminScreenshotsSent Int (List String)
