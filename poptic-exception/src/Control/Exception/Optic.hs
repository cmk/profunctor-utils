
module Control.Exception.Optic where

import Control.Exception (Exception(..), SomeException, AsyncException, ArrayException, ArithException)
import Control.Monad (liftM)
import Control.Monad.IO.Unlift
import Data.Monoid (First(..))
import Data.Profunctor.Optic

import GHC.Conc (ThreadId)
import GHC.IO.Exception
import System.IO
import Foreign.C.Types

import qualified Control.Exception as Ex 
import qualified UnliftIO.Exception as Ux

-- $setup
-- >>> :set -XNoOverloadedStrings
-- >>> :m + Control.Exception
-- >>> :m + Data.Profunctor.Optic



exception :: Exception a => Prism' SomeException a
exception = prism' toException fromException

----------------------------------------------------------------------------------------------------
-- Trying
----------------------------------------------------------------------------------------------------

{-# INLINE trying #-}

-- | A variant of 'Control.Exception.try' that takes a 'Prism' (or any 'Fold') to select which
-- exceptions are caught (c.f. 'Control.Exception.tryJust', 'Control.Exception.catchJust'). If the
-- 'Exception' does not match the predicate, it is re-thrown.
--
trying :: (MonadUnliftIO m, Exception s) => AGetter (First a) s t a b -> m r -> m (Either a r)
trying o = Ux.tryJust (preview o)


{-# INLINE trying_ #-}

-- | A version of 'trying' that discards the specific exception thrown.
--
trying_ :: (MonadUnliftIO m, Exception s) => AGetter (First a) s t a b -> m r -> m (Maybe r)
trying_ o m = preview right' `liftM` trying o m

----------------------------------------------------------------------------------------------------
-- Throwing
----------------------------------------------------------------------------------------------------

{-# INLINE throwing #-}

-- | Throw an 'Exception' described by a 'Prism'. Exceptions may be thrown from
-- purely functional code, but may only be caught within the 'IO' 'Monad'.
--
-- @
-- 'throwing' o ≡ 'throwIO' . 'review' o
-- @
--
-- @
-- 'throwing' o e \`seq\` x  ≡ 'throwing' o e
-- @
--
throwing :: (MonadIO m, Exception t) => AReview b s t a b -> b -> m r
throwing o = Ux.throwIO . review o


{-# INLINE throwing_ #-}

-- | Similar to 'throwing' but specialised for the common case of
--   error constructors with no arguments.
--
-- @
-- data MyError = Foo | Bar
-- makePrisms ''MyError
-- 'throwing_' _Foo :: 'MonadError' MyError m => m a
-- @
throwing_ :: (MonadIO m, Exception t) => AReview () s t a () -> m r
throwing_ l = throwing l ()


{-# INLINE throwingTo #-}

-- | 'throwingTo' raises an 'Exception' specified by a 'Prism' in the target thread.
--
-- @
-- 'throwingTo' thread o ≡ 'throwTo' thread . 'review' o
-- @
--
throwingTo :: (MonadIO m, Exception t) => ThreadId -> Optic (Costar (Const b)) s t a b -> b -> m ()
throwingTo tid o = Ux.throwTo tid . review o

----------------------------------------------------------------------------------------------------
-- Catching
----------------------------------------------------------------------------------------------------

{-# INLINE catching #-}

-- | Catch exceptions that match a given 'Prism' (or any 'Fold', really).
--
-- >>> catching _AssertionFailed (assert False (return "uncaught")) $ \ _ -> return "caught"
-- "caught"
--
catching :: (MonadUnliftIO m, Exception s) => AGetter (First a) s t a b -> m r -> (a -> m r) -> m r
catching l = Ux.catchJust (preview l)


{-# INLINE catching_ #-}

-- | Catch exceptions that match a given 'Prism' (or any 'Getter'), discarding
-- the information about the match. This is particuarly useful when you have
-- a @'Prism'' e ()@ where the result of the 'Prism' or 'Fold' isn't
-- particularly valuable, just the fact that it matches.
--
-- >>> catching_ _AssertionFailed (assert False (return "uncaught")) $ return "caught"
-- "caught"
--
catching_ :: (MonadUnliftIO m, Exception s) => AGetter (First a) s t a b -> m r -> m r -> m r
catching_ l a b = Ux.catchJust (preview l) a (const b)

----------------------------------------------------------------------------------------------------
-- Handling
----------------------------------------------------------------------------------------------------

{-# INLINE handling #-}

-- | A version of 'catching' with the arguments swapped around; useful in
-- situations where the code for the handler is shorter.
--
-- >>> handling _Overflow (\_ -> return "caught") $ throwIO Overflow
-- "caught"
--
handling :: (MonadUnliftIO m, Exception s) => AGetter (First a) s t a b -> (a -> m r) -> m r -> m r
handling o = flip (catching o)


{-# INLINE handling_ #-}

-- | A version of 'catching_' with the arguments swapped around; useful in
-- situations where the code for the handler is shorter.
--
-- >>> handling_ _Overflow (return "caught") $ throwIO Overflow
-- "caught"
--
handling_ :: (MonadUnliftIO m, Exception s) => AGetter (First a) s t a b -> m r -> m r -> m r
handling_ o = flip (catching_ o)

----------------------------------------------------------------------------------------------------
-- Mapping
----------------------------------------------------------------------------------------------------

{-# INLINE mappedException #-}

-- | This 'Setter' can be used to purely map over the 'Exception's an
-- arbitrary expression might throw; it is a variant of 'mapException' in
-- the same way that 'mapped' is a variant of 'fmap'.
--
-- > 'mapException' ≡ 'over' 'mappedException'
--
-- This view that every Haskell expression can be regarded as carrying a bag
-- of 'Exception's is detailed in “A Semantics for Imprecise Exceptions” by
-- Peyton Jones & al. at PLDI ’99.
--
-- The following maps failed assertions to arithmetic overflow:
--
-- >>> handling _Overflow (\_ -> return "caught") $ assert False (return "uncaught") & (mappedException %~ \ (AssertionFailed _) -> Overflow)
-- "caught"
-- 
mappedException :: (Exception e, Exception e') => Setter s s e e'
mappedException = sets Ex.mapException


{-# INLINE mappedException' #-}

-- | A type restricted version of 'mappedException'. 
--
-- This function avoids the type ambiguity in the input 'Exception' when using 'set'.
--
-- The following maps any exception to arithmetic overflow:
--
-- >>> handling _Overflow (\_ -> return "caught") $ assert False (return "uncaught") & (mappedException' .~ Overflow)
-- "caught"
mappedException' :: Exception e => Setter s s SomeException e
mappedException' = mappedException

----------------------------------------------------------------------------------------------------
-- Arithmetic exceptions
----------------------------------------------------------------------------------------------------

{-# INLINE _Overflow #-}

-- | Detect arithmetic overflow.
--
_Overflow :: Prism' ArithException ()
_Overflow = dimap seta (either id id) . right' . rmap (const Ex.Overflow)
  where seta Ex.Overflow = Right ()
        seta t = Left t


{-# INLINE _Underflow #-}

-- | Detect arithmetic underflow.
--
_Underflow :: Prism' ArithException ()
_Underflow = dimap seta (either id id) . right' . rmap (const Ex.Underflow)
  where seta Ex.Underflow = Right ()
        seta t = Left t


{-# INLINE _LossOfPrecision #-}

-- | Detect arithmetic loss of precision.
--
_LossOfPrecision :: Prism' ArithException ()
_LossOfPrecision = dimap seta (either id id) . right' . rmap (const Ex.LossOfPrecision)
  where seta Ex.LossOfPrecision = Right ()
        seta t = Left t


{-# INLINE _DivideByZero #-}

-- | Detect division by zero.
--
_DivideByZero :: Prism' ArithException ()
_DivideByZero = dimap seta (either id id) . right' . rmap (const Ex.DivideByZero)
  where seta Ex.DivideByZero = Right ()
        seta t = Left t


{-# INLINE _Denormal #-}

-- | Detect exceptional denormalized floating pure.
--
_Denormal :: Prism' ArithException ()
_Denormal = dimap seta (either id id) . right' . rmap (const Ex.Denormal)
  where seta Ex.Denormal = Right ()
        seta t = Left t


{-# INLINE _RatioZeroDenominator #-}

-- | Detect zero denominators.
--
-- Added in @base@ 4.6 in response to this libraries discussion:
--
-- <http://haskell.1045720.n5.nabble.com/Data-Ratio-and-exceptions-td5711246.html>
--
_RatioZeroDenominator :: Prism' ArithException ()
_RatioZeroDenominator = dimap seta (either id id) . right' . rmap (const Ex.RatioZeroDenominator)
  where seta Ex.RatioZeroDenominator = Right ()
        seta t = Left t

----------------------------------------------------------------------------------------------------
-- Array Exceptions
----------------------------------------------------------------------------------------------------

{-# INLINE _IndexOutOfBounds #-}

-- | Detect attempts to index an array outside its declared bounds.
--
_IndexOutOfBounds :: Prism' ArrayException String
_IndexOutOfBounds = dimap seta (either id id) . right' . rmap Ex.IndexOutOfBounds
  where seta (Ex.IndexOutOfBounds r) = Right r
        seta t = Left t


{-# INLINE _UndefinedElement #-}

-- | Detect attempts to evaluate an element of an array that has not been initialized.
--
_UndefinedElement :: Prism' ArrayException String
_UndefinedElement = dimap seta (either id id) . right' . rmap Ex.UndefinedElement
  where seta (Ex.UndefinedElement r) = Right r
        seta t = Left t

----------------------------------------------------------------------------------------------------
-- Async Exceptions
----------------------------------------------------------------------------------------------------


{-# INLINE _StackOverflow #-}

-- | The current thread's stack exceeded its limit. Since an 'Exception' has
-- been raised, the thread's stack will certainly be below its limit again,
-- but the programmer should take remedial action immediately.
--
_StackOverflow :: Prism AsyncException AsyncException () b
_StackOverflow = dimap seta (either id id) . right' . rmap (const Ex.StackOverflow)
  where seta Ex.StackOverflow = Right ()
        seta t = Left t


{-# INLINE _HeapOverflow #-}

-- | The program's heap usage has exceeded its limit.
--
_HeapOverflow :: Prism AsyncException AsyncException () b
_HeapOverflow = dimap seta (either id id) . right' . rmap (const Ex.HeapOverflow)
  where seta Ex.HeapOverflow = Right ()
        seta t = Left t


{-# INLINE _ThreadKilled #-}

-- | This 'Exception' is raised by another thread calling
-- 'Control.Concurrent.killThread', or by the system if it needs to terminate
-- the thread for some reason.
--
_ThreadKilled :: Prism AsyncException AsyncException () b
_ThreadKilled = dimap seta (either id id) . right' . rmap (const Ex.ThreadKilled)
  where seta Ex.ThreadKilled = Right ()
        seta t = Left t


{-# INLINE _UserInterrupt #-}

-- | This 'Exception' is raised by default in the main thread of the program when
-- the user requests to terminate the program via the usual mechanism(s)
-- (/e.g./ Control-C in the console).
--
_UserInterrupt :: Prism AsyncException AsyncException () b
_UserInterrupt = dimap seta (either id id) . right' . rmap (const Ex.UserInterrupt)
  where seta Ex.UserInterrupt = Right ()
        seta t = Left t

----------------------------------------------------------------------------------------------------
-- Miscellaneous Exceptions
----------------------------------------------------------------------------------------------------

{-# INLINE _AssertionFailed #-}
_AssertionFailed :: Prism' Ex.AssertionFailed String
_AssertionFailed = iso (\(Ex.AssertionFailed a) -> a) Ex.AssertionFailed


{-# INLINE _NonTermination #-}

-- | Thrown when the runtime system detects that the computation is guaranteed
-- not to terminate. Note that there is no guarantee that the runtime system
-- will notice whether any given computation is guaranteed to terminate or not.
--
_NonTermination :: Prism' Ex.NonTermination ()
_NonTermination = trivial Ex.NonTermination


{-# INLINE _NestedAtomically #-}

-- | Thrown when the program attempts to call atomically, from the
-- 'Control.Monad.STM' package, inside another call to atomically.
--
_NestedAtomically :: Prism' Ex.NestedAtomically ()
_NestedAtomically = trivial Ex.NestedAtomically


{-# INLINE _BlockedIndefinitelyOnMVar #-}

-- | The thread is blocked on an 'Control.Concurrent.MVar.MVar', but there
-- are no other references to the 'Control.Concurrent.MVar.MVar' so it can't
-- ever continue.
--
_BlockedIndefinitelyOnMVar :: Prism' Ex.BlockedIndefinitelyOnMVar ()
_BlockedIndefinitelyOnMVar = trivial Ex.BlockedIndefinitelyOnMVar


{-# INLINE _BlockedIndefinitelyOnSTM #-}

-- | The thread is waiting to retry an 'Control.Monad.STM.STM' transaction,
-- but there are no other references to any TVars involved, so it can't ever
-- continue.
--
_BlockedIndefinitelyOnSTM :: Prism' Ex.BlockedIndefinitelyOnSTM ()
_BlockedIndefinitelyOnSTM = trivial Ex.BlockedIndefinitelyOnSTM


{-# INLINE _Deadlock #-}

-- | There are no runnable threads, so the program is deadlocked. The
-- 'Deadlock' 'Exception' is raised in the main thread only.
--
_Deadlock :: Prism' Ex.Deadlock ()
_Deadlock = trivial Ex.Deadlock


{-# INLINE _NoMethodError #-}

-- | A class method without a definition (neither a default definition,
-- nor a definition in the appropriate instance) was called.
--
_NoMethodError :: Prism' Ex.NoMethodError String
_NoMethodError = iso (\(Ex.NoMethodError a) -> a) Ex.NoMethodError


{-# INLINE _PatternMatchFail #-}

-- | A pattern match failed.
--
_PatternMatchFail :: Prism' Ex.PatternMatchFail String
_PatternMatchFail = iso (\(Ex.PatternMatchFail a) -> a) Ex.PatternMatchFail


{-# INLINE _RecConError #-}

-- | An uninitialised record field was used.
--
_RecConError :: Prism' Ex.RecConError String
_RecConError = iso (\(Ex.RecConError a) -> a) Ex.RecConError


{-# INLINE _RecSelError #-}

-- | A record selector was applied to a constructor without the appropriate
-- field. This can only happen with a datatype with multiple constructors,
-- where some fields are in one constructor but not another.
--
_RecSelError :: Prism' Ex.RecSelError String
_RecSelError = iso (\(Ex.RecSelError a) -> a) Ex.RecSelError


{-# INLINE _RecUpdError #-}

-- | A record update was performed on a constructor without the
-- appropriate field. This can only happen with a datatype with multiple
-- constructors, where some fields are in one constructor but not another.
--
_RecUpdError :: Prism' Ex.RecUpdError String
_RecUpdError = iso (\(Ex.RecUpdError a) -> a) Ex.RecUpdError


{-# INLINE _ErrorCall #-}

-- | Thrown when the user calls 'Prelude.error'.
--
_ErrorCall :: Prism' Ex.ErrorCall String
_ErrorCall = iso (\(Ex.ErrorCall a) -> a) Ex.ErrorCall


{-# INLINE _AllocationLimitExceeded #-}

-- | This thread has exceeded its allocation limit.
--
_AllocationLimitExceeded :: Prism' Ex.AllocationLimitExceeded ()
_AllocationLimitExceeded = trivial AllocationLimitExceeded

trivial :: t -> Iso' t ()
trivial t = const () `iso` const t

----------------------------------------------------------------------------------------------------
-- IO Exceptions
----------------------------------------------------------------------------------------------------


{-# INLINE location #-}

-- | Where the error happened.
--
location :: Lens' IOException String
location = lens ioe_location $ \s e -> s { ioe_location = e }


{-# INLINE description #-}

-- | Error type specific information.
--
description :: Lens' IOException String
description = lens ioe_description $ \s e -> s { ioe_description = e }


{-# INLINE handle #-}

-- | The handle used by the action flagging this error.
-- 
handle :: Lens' IOException (Maybe Handle)
handle = lens ioe_handle $ \s e -> s { ioe_handle = e }


{-# INLINE fileName #-}

-- | 'fileName' the error is related to.
--
fileName :: Lens' IOException (Maybe FilePath)
fileName = lens ioe_filename $ \s e -> s { ioe_filename = e }


{-# INLINE errno #-}

-- | 'errno' leading to this error, if any.
--
errno :: Lens' IOException (Maybe CInt)
errno = lens ioe_errno $ \s e -> s { ioe_errno = e }

----------------------------------------------------------------------------------------------------
-- IO Error Types
----------------------------------------------------------------------------------------------------

{-# INLINE errorType #-}

-- | What type of error it is
--
errorType :: Lens' IOException IOErrorType
errorType = lens ioe_type $ \s e -> s { ioe_type = e }


-- * IOErrorType Prisms
--

_AlreadyExists :: Prism' IOErrorType ()
_AlreadyExists = only AlreadyExists

_NoSuchThing :: Prism' IOErrorType ()
_NoSuchThing = only NoSuchThing

_ResourceBusy :: Prism' IOErrorType ()
_ResourceBusy = only ResourceBusy

_ResourceExhausted :: Prism' IOErrorType ()
_ResourceExhausted = only ResourceExhausted

_EOF :: Prism' IOErrorType ()
_EOF = only EOF

_IllegalOperation :: Prism' IOErrorType ()
_IllegalOperation = only IllegalOperation

_PermissionDenied :: Prism' IOErrorType ()
_PermissionDenied = only PermissionDenied

_UserError :: Prism' IOErrorType ()
_UserError = only UserError

_UnsatisfiedConstraints :: Prism' IOErrorType ()
_UnsatisfiedConstraints = only UnsatisfiedConstraints

_SystemError :: Prism' IOErrorType ()
_SystemError = only SystemError

_ProtocolError :: Prism' IOErrorType ()
_ProtocolError = only ProtocolError

_OtherError :: Prism' IOErrorType ()
_OtherError = only OtherError

_InvalidArgument :: Prism' IOErrorType ()
_InvalidArgument = only InvalidArgument

_InappropriateType :: Prism' IOErrorType ()
_InappropriateType = only InappropriateType

_HardwareFault :: Prism' IOErrorType ()
_HardwareFault = only HardwareFault

_UnsupportedOperation :: Prism' IOErrorType ()
_UnsupportedOperation = only UnsupportedOperation

_TimeExpired :: Prism' IOErrorType ()
_TimeExpired = only TimeExpired

_ResourceVanished :: Prism' IOErrorType ()
_ResourceVanished = only ResourceVanished

_Interrupted :: Prism' IOErrorType ()
_Interrupted = only Interrupted