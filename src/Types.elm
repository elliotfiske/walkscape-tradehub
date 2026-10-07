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
    , FellThrough
    , FellThroughForm
    , FrontendModel
    , FrontendMsg(..)
    , InitialData
    , ItemLine
    , Listing
    , ListingDraft
    , ListingForm
    , MarketFilters
    , MarketSort(..)
    , MarketTab(..)
    , Me
    , Offer
    , OfferDraft
    , OfferForm
    , OfferLineForm
    , OfferStatus(..)
    , Payment(..)
    , PaymentChoice(..)
    , Provider(..)
    , Report
    , ReportDraft
    , ReportForm
    , ReportedTrade
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
import Effect.File
import Effect.Lamdera exposing (ClientId, SessionId)
import Item
import Route exposing (Route)
import Time
import Url exposing (Url)



-- SHARED DATA


type Provider
    = Discord


type ClaimStatus
    = -- There's no way to verify a name yet, so every claim is shown as
      -- unverified.
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
    , timersNoticeDismissed : Bool
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
    , discordSince : Maybe Time.Posix
    , lookalikeOf : Maybe String
    , banned : Bool
    }


type Side
    = Selling
    | Buying


{-| What the side paying for the items will take: coins each, items only (the
offers say which), or either, with an optional coin price each.
-}
type Payment
    = Coins Int
    | ItemsOnly
    | CoinsOrItems (Maybe Int)


{-| One item in an item-for-item offer. `quantity` is the total for the whole
trade, not per unit of the listing.
-}
type alias ItemLine =
    { itemId : String
    , variant : Item.Variant
    , quantity : Int
    }


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


{-| An accepted offer is a pending trade until both traders confirm it went
through (`OfferCompleted`, when the second one confirmed) or either one says it
fell through.
-}
type OfferStatus
    = OfferOpen
    | OfferAccepted
    | OfferDeclined
    | OfferWithdrawn
    | OfferCompleted Time.Posix
    | OfferFellThrough FellThrough


{-| Who said a trade fell through, when, and why.
-}
type alias FellThrough =
    { by : String
    , at : Time.Posix
    , reason : String
    }


{-| Interest in a listing. `price` is coins each, and `items` are paid on top
(see `Market.offerCoinsEach`): with no items, a `Nothing` price means "at your
price"; with items, it means no coins. `listerConfirmed` and `offererConfirmed` say which side has confirmed an
accepted offer's trade went through.
-}
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


{-| An offer as the frontend sends it (see `Market.validateOffer`).
-}
type alias OfferDraft =
    { price : Maybe Int
    , items : List ItemLine
    , message : String
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
    , trade : Maybe ReportedTrade
    , screenshots : List Int
    }


{-| The trade a report is about, as it was when the report was sent. Banning a
player deletes their listings and offers, so the report keeps its own copy.
-}
type alias ReportedTrade =
    { listing : Listing
    , offer : Offer
    }


{-| What the report form sends. Screenshots are JPEG data URLs (see `Screenshot`).
-}
type alias ReportDraft =
    { about : String
    , reasons : List String
    , details : String
    , offerId : Maybe Int
    , screenshots : List String
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
    , paymentChoice : PaymentChoice
    , price : String
    , note : String
    , error : Maybe String
    , submitting : Bool
    }


type PaymentChoice
    = PayCoins
    | PayItems
    | PayEither


{-| `counter` is off for "at their price". `itemQuery` is the search for
adding another item line.
-}
type alias OfferForm =
    { counter : Bool
    , price : String
    , items : List OfferLineForm
    , itemQuery : String
    , message : String
    , error : Maybe String
    }


type alias OfferLineForm =
    { itemId : String
    , variant : Item.Variant
    , quantity : String
    }


{-| The "It fell through" form, open for one offer at a time.
-}
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
    , adminScreenshots : Dict Int (List String)
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
    | ListingPaymentPicked PaymentChoice
    | ListingPriceChanged String
    | ListingNoteChanged String
    | ListingSubmitted
    | CloseListingClicked Int
    | OfferCounterToggled Bool
    | OfferPriceChanged String
    | OfferMessageChanged String
    | OfferItemQueryChanged String
    | OfferItemPicked String
    | OfferLineQuantityChanged Int String
    | OfferLineVariantPicked Int Item.Variant
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
    | AdminScreenshotsSent Int (List String)



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
    , timersNoticeDismissed : Bool
    }


type alias BackendModel =
    { now : Time.Posix
    , users : Dict UserId User
    , sessions : Dict String UserId
    , listings : Dict Int Listing
    , offers : Dict Int Offer
    , reports : List Report
    , screenshots : Dict Int String
    , adminLog : List AdminLogEntry
    , nextId : Int
    , pendingAuths : Dict Auth.Common.SessionId Auth.Common.PendingAuth
    }


type ToBackend
    = AuthToBackend Auth.Common.ToBackend
      -- Asks for what a connecting client is pushed (`InitialDataSent` and
      -- `YouAre`), for a tab that never got it. See `Frontend.update`'s `Tick`.
    | RequestState
    | PreviewSignIn Provider
      -- Only works in development; see `Users.isAdmin`.
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
    | AdminLoad
    | AdminLoadScreenshots Int
    | AdminRequest AdminAction


type BackendMsg
    = ClientConnected SessionId ClientId
    | ClientDisconnected SessionId ClientId
    | AuthBackendMsg Auth.Common.BackendMsg
    | GotTime Time.Posix
    | BackendTick Time.Posix
    | FromFrontendAt SessionId ClientId ToBackend Time.Posix
