module Types exposing
    ( AdminAction(..)
    , AdminData
    , AdminLogEntry
    , AdminPage
    , AdminTab(..)
    , AdminUser
    , BackendModel
    , BackendMsg(..)
    , Ban
    , Claim
    , ClaimStatus(..)
    , FrontendModel
    , FrontendMsg(..)
    , InitialData
    , Listing
    , ListingDraft
    , ListingForm
    , MarketFilters
    , MarketSort(..)
    , MarketTab(..)
    , Me
    , Offer
    , OfferForm
    , OfferStatus(..)
    , Payment(..)
    , Provider(..)
    , Report
    , ReportForm
    , Side(..)
    , ToBackend(..)
    , ToFrontend(..)
    , Trader
    , TradesTab(..)
    , User
    , UserId
    )

import Auth.Common
import Dict exposing (Dict)
import Effect.Browser exposing (UrlRequest)
import Effect.Browser.Navigation exposing (Key)
import Effect.Lamdera exposing (ClientId, SessionId)
import Item
import Route exposing (Route)
import Time
import Url exposing (Url)



-- SHARED DATA


type Provider
    = Discord


type ClaimStatus
    = -- Trading isn't live yet, so nobody can actually verify a name. Every
      -- claim is shown as unverified.
      PreviewUnverified


{-| A WalkScape name someone says is theirs.
-}
type alias Claim =
    { name : String
    , status : ClaimStatus
    }


{-| What the signed-in person knows about their own account.
-}
type alias Me =
    { provider : Provider
    , isPreviewLogin : Bool
    , claim : Maybe Claim
    , isAdmin : Bool
    , ban : Maybe Ban
    }


{-| Why and when an admin banned someone. `by` is the admin's name.
-}
type alias Ban =
    { reason : String
    , at : Time.Posix
    , by : String
    }


{-| The public face of a trader, keyed by WalkScape name.
-}
type alias Trader =
    { name : String
    , joinedAt : Time.Posix
    , discord : Maybe String
    , lookalikeOf : Maybe String
    , banned : Bool
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
    , variant : Item.Variant
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


{-| Interest in a listing. `price` is coins each; `Nothing` means "at your price".
-}
type alias Offer =
    { id : Int
    , listingId : Int
    , from : String
    , price : Maybe Int
    , message : String
    , at : Time.Posix
    , status : OfferStatus
    }


type alias ListingDraft =
    { itemId : String
    , variant : Item.Variant
    , side : Side
    , payment : Payment
    , quantity : Int
    , note : String
    }


type alias Report =
    { id : Int
    , reporter : String
    , about : String
    , reasons : List String
    , details : String
    , at : Time.Posix
    , resolved : Bool
    }


{-| A player as admins see them. Players are named by their claimed WalkScape
name, so ones who haven't claimed one yet only show up in `accounts`.
-}
type alias AdminUser =
    { name : String
    , ready : Bool
    , discord : Maybe String
    , isPreviewLogin : Bool
    , joinedAt : Time.Posix
    , isAdmin : Bool
    , ban : Maybe Ban
    }


type alias AdminLogEntry =
    { at : Time.Posix
    , by : String
    , text : String
    }


{-| Everything the admin screen shows, including listings that aren't live yet.
-}
type alias AdminData =
    { accounts : Int
    , users : List AdminUser
    , listings : List Listing
    , offers : List Offer
    , reports : List Report
    , log : List AdminLogEntry
    }


type AdminAction
    = DeleteListing Int
    | DeleteOffer Int
    | BanPlayer String String
    | UnbanPlayer String
    | ReleaseName String
    | SetReportResolved Int Bool


type alias InitialData =
    { listings : List Listing
    , offers : List Offer
    , traders : List Trader
    }



-- FRONTEND


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
    , rarities : List Item.Rarity
    , qualities : List Item.Quality
    , fineOnly : Bool
    , sort : MarketSort
    , hideOutliers : Bool
    , search : String
    }


type TradesTab
    = ReceivedTab
    | SentTab
    | MyListingsTab


type AdminTab
    = AdminReports
    | AdminListings
    | AdminPlayers
    | AdminLog


{-| `confirming` is a destructive action waiting for a second click. For a ban,
its reason is filled in from `banReason` when confirmed.
-}
type alias AdminPage =
    { tab : AdminTab
    , search : String
    , confirming : Maybe AdminAction
    , banReason : String
    }


type alias ListingForm =
    { itemQuery : String
    , itemId : Maybe String
    , quality : Item.Quality
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


type alias ReportForm =
    { about : String
    , reasons : List String
    , details : String
    , sent : Bool
    }


type alias FrontendModel =
    { key : Key
    , route : Route
    , now : Time.Posix
    , authFlow : Auth.Common.Flow
    , authRedirectBaseUrl : Url
    , me : Maybe Me
    , loaded : Bool
    , listings : Dict Int Listing
    , offers : Dict Int Offer
    , traders : Dict String Trader
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
    , admin : Maybe AdminData
    , adminPage : AdminPage
    }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
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
    | RarityToggled Item.Rarity
    | QualityToggled Item.Quality
    | FineOnlyToggled
    | HideOutliersToggled
    | FiltersToggled
    | NoticeDismissed
    | ListingItemQueryChanged String
    | ListingItemPicked String
    | ListingItemCleared
    | ListingQualityPicked Item.Quality
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
    | ReportReasonToggled String
    | ReportDetailsChanged String
    | ReportSubmitted
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


type ToFrontend
    = AuthToFrontend Auth.Common.ToFrontend
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



-- BACKEND


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
    }


type alias BackendModel =
    { now : Time.Posix
    , users : Dict UserId User
    , sessions : Dict String UserId
    , listings : Dict Int Listing
    , offers : Dict Int Offer
    , reports : List Report
    , adminLog : List AdminLogEntry
    , nextId : Int
    , pendingAuths : Dict Auth.Common.SessionId Auth.Common.PendingAuth
    }


type ToBackend
    = AuthToBackend Auth.Common.ToBackend
    | PreviewSignIn Provider
      -- Only works in development; see `Users.isAdmin`.
    | PreviewAdminSignIn
    | SignOut
    | ClaimName String
    | CreateListing ListingDraft
    | CloseListing Int
    | MakeOffer Int (Maybe Int) String
    | WithdrawOffer Int
    | RespondToOffer Int Bool
    | SubmitReport String (List String) String
    | AdminLoad
    | AdminRequest AdminAction


type BackendMsg
    = ClientConnected SessionId ClientId
    | ClientDisconnected SessionId ClientId
    | AuthBackendMsg Auth.Common.BackendMsg
    | GotTime Time.Posix
    | BackendTick Time.Posix
    | FromFrontendAt SessionId ClientId ToBackend Time.Posix
