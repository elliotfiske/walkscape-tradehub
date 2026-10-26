module Evergreen.V38.Types exposing (..)

import Dict
import Effect.Browser
import Effect.Browser.Navigation
import Effect.File
import Effect.Lamdera
import Evergreen.V38.Auth.Common
import Evergreen.V38.Item
import Evergreen.V38.Route
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
    | ItemsOnly
    | CoinsOrItems (Maybe Int)


type alias ItemLine =
    { itemId : String
    , variant : Evergreen.V38.Item.Variant
    , quantity : Int
    }


type alias Listing =
    { id : Int
    , trader : String
    , itemId : String
    , variant : Evergreen.V38.Item.Variant
    , side : Side
    , payment : Payment
    , wants : List ItemLine
    , quantity : Int
    , note : String
    , createdAt : Time.Posix
    , liveAt : Time.Posix
    , closed : Bool
    , excludedFromPrices : Bool
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
    , items : List ItemLine
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


type alias Giveaway =
    { id : Int
    , title : String
    , prizes : List ItemLine
    , startsAt : Time.Posix
    , endsAt : Time.Posix
    , entrants : List String
    , winner : Maybe String
    , passedOver : List String
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
    , rarities : List Evergreen.V38.Item.Rarity
    , qualities : List Evergreen.V38.Item.Quality
    , fineOnly : Bool
    , sort : MarketSort
    , hideOutliers : Bool
    , search : String
    }


type PaymentChoice
    = PayCoins
    | PayItems
    | PayEither


type alias OfferLineForm =
    { itemId : String
    , variant : Evergreen.V38.Item.Variant
    , quantity : String
    }


type alias ListingForm =
    { itemQuery : String
    , itemId : Maybe String
    , quality : Evergreen.V38.Item.Quality
    , fine : Bool
    , rare : Bool
    , side : Side
    , quantity : String
    , paymentChoice : PaymentChoice
    , price : String
    , wants : List OfferLineForm
    , wantQuery : String
    , note : String
    , error : Maybe String
    , submitting : Bool
    }


type alias OfferForm =
    { counter : Bool
    , price : String
    , items : List OfferLineForm
    , itemQuery : String
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
    | AdminGiveaways
    | AdminLog


type alias GiveawayDraft =
    { title : String
    , prizes : List ItemLine
    , hours : Int
    }


type AdminAction
    = DeleteListing Int
    | DeleteOffer Int
    | BanPlayer String String
    | UnbanPlayer String
    | ReleaseName String
    | SetReportResolved Int Bool
    | SetExcludedFromPrices Int Bool
    | StartGiveaway GiveawayDraft
    | DrawGiveaway Int
    | RedrawGiveaway Int
    | CancelGiveaway Int


type alias AdminPage =
    { tab : AdminTab
    , search : String
    , confirming : Maybe AdminAction
    , banReason : String
    }


type alias GiveawayForm =
    { title : String
    , prizes : List OfferLineForm
    , prizeQuery : String
    , days : String
    , error : Maybe String
    }


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , route : Evergreen.V38.Route.Route
    , now : Time.Posix
    , authFlow : Evergreen.V38.Auth.Common.Flow
    , authRedirectBaseUrl : Url.Url
    , me : Maybe Me
    , loaded : Bool
    , listings : Dict.Dict Int Listing
    , offers : Dict.Dict Int Offer
    , traders : Dict.Dict String Trader
    , giveaways : Dict.Dict Int Giveaway
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
    , giveawayForm : GiveawayForm
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
    , giveaways : Dict.Dict Int Giveaway
    , nextId : Int
    , pendingAuths : Dict.Dict Evergreen.V38.Auth.Common.SessionId Evergreen.V38.Auth.Common.PendingAuth
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
    | RarityToggled Evergreen.V38.Item.Rarity
    | QualityToggled Evergreen.V38.Item.Quality
    | FineOnlyToggled
    | HideOutliersToggled
    | FiltersToggled
    | NoticeDismissed
    | ListingItemQueryChanged String
    | ListingItemPicked String
    | ListingItemCleared
    | ListingQualityPicked Evergreen.V38.Item.Quality
    | ListingFineToggled Bool
    | ListingRareToggled Bool
    | ListingSidePicked Side
    | ListingQuantityChanged String
    | ListingPaymentPicked PaymentChoice
    | ListingPriceChanged String
    | ListingWantQueryChanged String
    | ListingWantPicked String
    | ListingWantQuantityChanged Int String
    | ListingWantVariantPicked Int Evergreen.V38.Item.Variant
    | ListingWantRemoved Int
    | ListingNoteChanged String
    | ListingSubmitted
    | CloseListingClicked Int
    | OfferCounterToggled Bool
    | OfferPriceChanged String
    | OfferMessageChanged String
    | OfferItemQueryChanged String
    | OfferItemPicked String
    | OfferLineQuantityChanged Int String
    | OfferLineVariantPicked Int Evergreen.V38.Item.Variant
    | OfferLineRemoved Int
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
    | GiveawayEnterClicked Int
    | GiveawayTitleChanged String
    | GiveawayDaysChanged String
    | GiveawayPrizeQueryChanged String
    | GiveawayPrizePicked String
    | GiveawayPrizeQuantityChanged Int String
    | GiveawayPrizeVariantPicked Int Evergreen.V38.Item.Variant
    | GiveawayPrizeRemoved Int
    | GiveawaySubmitted
    | NoOpFrontendMsg


type alias ListingDraft =
    { itemId : String
    , variant : Evergreen.V38.Item.Variant
    , side : Side
    , payment : Payment
    , wants : List ItemLine
    , quantity : Int
    , note : String
    }


type alias OfferDraft =
    { price : Maybe Int
    , items : List ItemLine
    , message : String
    }


type alias ReportDraft =
    { about : String
    , reasons : List String
    , details : String
    , offerId : Maybe Int
    , screenshots : List String
    }


type ToBackend
    = AuthToBackend Evergreen.V38.Auth.Common.ToBackend
    | RequestState
    | PreviewSignIn Provider
    | PreviewAdminSignIn
    | SignOut
    | ClaimName String
    | DismissTimersNotice
    | CreateListing ListingDraft
    | CloseListing Int
    | MakeOffer Int OfferDraft
    | WithdrawOffer Int
    | RespondToOffer Int Bool
    | ConfirmTrade Int
    | MarkFellThrough Int String
    | SubmitReport ReportDraft
    | EnterGiveaway Int
    | AdminLoad
    | AdminLoadScreenshots Int
    | AdminRequest AdminAction


type BackendMsg
    = ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | AuthBackendMsg Evergreen.V38.Auth.Common.BackendMsg
    | GotTime Time.Posix
    | BackendTick Time.Posix
    | FromFrontendAt Effect.Lamdera.SessionId Effect.Lamdera.ClientId ToBackend Time.Posix


type alias InitialData =
    { listings : List Listing
    , offers : List Offer
    , traders : List Trader
    , giveaways : List Giveaway
    }


type ToFrontend
    = AuthToFrontend Evergreen.V38.Auth.Common.ToFrontend
    | InitialDataSent InitialData
    | YouAre (Maybe Me)
    | ListingUpserted Listing
    | ListingRemoved Int
    | OfferUpserted Offer
    | OfferRemoved Int
    | TraderUpserted Trader
    | TraderRemoved String
    | GiveawayUpserted Giveaway
    | GiveawayRemoved Int
    | ClaimRejected String
    | ListingCreated Int
    | ReportReceived
    | ActionFailed String
    | AdminDataSent AdminData
    | AdminScreenshotsSent Int (List String)
