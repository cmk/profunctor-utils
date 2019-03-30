{-# LANGUAGE CPP #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}

import Control.Exception
import Control.Monad
import Control.Monad.Trans
import Data.IORef
import Data.Monoid
import System.IO.Unsafe
import System.Log.FastLogger
import qualified Data.Text as T
import qualified Data.Traversable as T
#if MIN_VERSION_base(4,9,0)
#else
import qualified GHC.SrcLoc as GHC
#endif
import qualified GHC.Stack as GHC

import Data.Void
import Data.Ref
import Data.Profunctor.PRef
import Data.Profunctor.Optic

main :: IO ()
main = print "hi"

{-


cfg = LogConfig Nothing True
msgs = ["foo", "bar", "baz", "bippy"] :: [T.Text]
withGlobalLogging cfg $ forM_ msgs (logWith LogInfo)
withGlobalLogging cfg $ forM_ msgs logInfo



putil: poptic, pref, pgen, plog, perror?

TODO logging-

use visibility trick to hide all the unsafe stuff
use traversal over list of gens of each loglevel, using filterOf

TODO random number gen-


TODO other examples-

remove ref typeclass! 

are isos cool / useful?

read only / write only / mod only  refs, mvars, etc
 - probably only want PRef' w/ MVars due to locking semantics

composition, dimap, first' / right', arrow stuff


rmap toLogStr :: ToLogStr b => PRef r c LogStr () -> PRef r c b () 
swap () w/ some const a and you have a reader pattern! show example

operate directly on PRefs w/ optics! they are profunctors after all 

can i make a profunctor w/ either s or t as well? then we could play with::  through PRef unPRef
connection w/ pipes
-}


-- | Public API

data LogConfig
    = LogConfig
    { lc_file :: !(Maybe FilePath)
    , lc_stderr :: !Bool
    }

data LogLevel
    = LogTrace
    | LogDebug
    | LogInfo
    | LogNote
    | LogWarn
    | LogError
    deriving (Eq, Show, Read, Ord)

ploggers :: PRef IORef Mapping (LogLevel, LogStr) ()
ploggers = PRef optic loggers loggers 

logWith :: (MonadIO m, Ref m IORef, ToLogStr msg) => LogLevel -> msg -> m ()
logWith ll msg = modifyPRef' (lmap (fmap toLogStr) ploggers) (const (ll,msg))

logPureWith :: (Ref IO IORef, ToLogStr msg) => LogLevel -> msg -> a -> a
logPureWith ll msg expr = unsafePerformIO (logWith ll msg) `seq` expr

-- | Set the verbosity level. Only messages at higher than this level are
-- displayed.  It defaults to 'LogDebug'.
setLogLevel :: LogLevel -> IO ()
setLogLevel = atomicWriteIORef logLevel

-- | Log with 'LogTrace' log level
logTrace :: (MonadIO m, Ref m IORef) => T.Text -> m ()
logTrace = logWith LogTrace 

-- | Log with 'LogDebug' log level
logDebug :: (MonadIO m, Ref m IORef) => T.Text -> m ()
logDebug = logWith LogDebug 

-- | Log with 'LogInfo' log level
logInfo :: (MonadIO m, Ref m IORef) => T.Text -> m ()
logInfo = logWith LogInfo 

-- | Log with 'LogNote' log level
logNote :: (MonadIO m, Ref m IORef) => T.Text -> m ()
logNote = logWith LogNote 

-- | Log with 'LogWarn' log level
logWarn :: (MonadIO m, Ref m IORef) => T.Text -> m ()
logWarn = logWith LogWarn 

-- | Log with 'LogError' log level
logError :: (MonadIO m, Ref m IORef) => T.Text -> m ()
logError = logWith LogError 

-- | Log on error level and call 'fail'
logFail :: (MonadIO m, Ref m IORef) => T.Text -> m a
logFail t = logWith LogError t >> fail (T.unpack t)

-- | Log with 'LogTrace' level when the given expression is evaluated
pureTrace :: T.Text -> a -> a
pureTrace = logPureWith LogTrace 

-- | Log with 'LogDebug' level when the given expression is evaluated
pureDebug :: T.Text -> a -> a
pureDebug = logPureWith LogDebug 

-- | Log with 'LogInfo' level when the given expression is evaluated
pureInfo :: T.Text -> a -> a
pureInfo = logPureWith LogInfo 

-- | Log with 'LogNote' level when the given expression is evaluated
pureNote :: T.Text -> a -> a
pureNote = logPureWith LogNote 

-- | Log with 'LogWarn' level when the given expression is evaluated
pureWarn :: T.Text -> a -> a
pureWarn = logPureWith LogWarn 

-- | Log with 'LogError' level when the given expression is evaluated
pureError :: T.Text -> a -> a
pureError = logPureWith LogError 

-- | Setup global logging. Wrap your 'main' function with this.
withGlobalLogging :: LogConfig -> IO a -> IO a
withGlobalLogging lc f =
    bracket initLogger flushLogger (const f)
    where
      flushLogger (Loggers a b _) =
          do forM_ a $ \(_, flush) -> flush
             forM_ b $ \(_, flush) -> flush
      initLogger =
          do fileLogger <-
                 flip T.mapM (lc_file lc) $ \fp ->
                 do let spec =
                            FileLogSpec
                            { log_file = fp
                            , log_file_size = 1024 * 1024 * 50
                            , log_backup_number = 5
                            }
                    newFastLogger (LogFile spec defaultBufSize)
             stderrLogger <-
                 if lc_stderr lc
                 then Just <$> newFastLogger (LogStderr defaultBufSize)
                 else pure Nothing
             tc <- newTimeCache timeFormat
             let lgrs = Loggers fileLogger stderrLogger tc
             writeIORef loggers lgrs
             pure lgrs

-- | Internal
--

data Loggers
    = Loggers
    { l_file :: !(Maybe (FastLogger, IO ()))
    , l_stderr :: !(Maybe (FastLogger, IO ()))
    , l_timeCache :: !(IO FormattedTime)
    }

loggers :: IORef Loggers
loggers =
    unsafePerformIO $
    do tc <- newTimeCache timeFormat
       newIORef (Loggers Nothing Nothing tc)
{-# NOINLINE loggers #-}

logLevel :: IORef LogLevel
logLevel = unsafePerformIO $ newIORef LogDebug
{-# NOINLINE logLevel #-}

--baz :: ToLogStr b => Loggers -> (LogLevel, b) -> LogLevel
--baz lgr (ll, b) = unsafePerformIO (logmsg lgr ll (toLogStr b)) `seq` ll

--x :: (ToLogStr b, Strong p) => Optic p Loggers LogLevel Config (LogLevel, b)
--x = lens (const config) baz
--
--config :: Config --some config

unsafeLogIO :: (?callStack :: GHC.CallStack) => Loggers -> (LogLevel, LogStr) -> Loggers
unsafeLogIO lgr (ll, b) = unsafePerformIO (logmsg ?callStack lgr LogInfo b) `seq` lgr

optic :: Mapping p => Optic p Loggers Loggers () (LogLevel, LogStr)
optic = setting $ \ub lgr -> unsafeLogIO lgr (ub ())

logmsg :: MonadIO m => GHC.CallStack -> Loggers -> LogLevel -> LogStr -> m ()
logmsg cs lgrs ll msg = liftIO $ readIORef logLevel >>= \logLim ->
    when (ll >= logLim) $
      do time <- l_timeCache lgrs
         let loc =
                 case GHC.getCallStack cs of
                     ((_, l):_) ->
                         GHC.srcLocFile l <> ":" <> show (GHC.srcLocStartLine l)
                     _ -> "unknown"
             out =
                 "[" <> renderLevel ll <> " "
                 <> toLogStr time
                 <> " "
                 <> toLogStr loc
                 <> "] "
                 <> msg
                 <> "\n"
         forM_ (l_stderr lgrs) $ \(writeLog, _) -> writeLog (renderColor ll <> out <> resetColor) 
         forM_ (l_file lgrs) $ \(writeLog, _) -> writeLog out

timeFormat :: TimeFormat
timeFormat = "%Y-%m-%d %T %z"

renderLevel ll =
    case ll of
      LogTrace -> "TRACE"
      LogDebug -> "DEBUG"
      LogInfo -> "INFO"
      LogNote -> "NOTE"
      LogWarn -> "WARN"
      LogError -> "ERROR"

resetColor = "\o33[0;0m"

renderColor ll =
    case ll of
      LogTrace -> "\o33[0;30m"
      LogDebug -> "\o33[0;34m"
      LogInfo -> "\o33[0;34m"
      LogNote -> "\o33[1;32m"
      LogWarn -> "\o33[0;33m"
      LogError -> "\o33[1;31m"

