
module Data.Profunctor.Optic.Environment (
    module Data.Profunctor.Optic.Environment
  , module Export
  , Costar (..)
) where

import Data.Distributive
import Data.Profunctor.Optic.Type
import Data.Profunctor.Optic.Operator
import Data.Profunctor.Optic.Operator.Task
import Data.Profunctor.Optic.Prelude

import Data.Profunctor.Closed as Export

import Control.Monad.IO.Unlift
import UnliftIO.Exception


-- | t ^ (b ^ (a ^ s)) -> Env s t a b
environment :: (((s -> a) -> b) -> t) -> Env s t a b
environment f pab = dimap (flip ($)) f (closed pab)

environment' :: (s -> a) -> (b -> t) -> Env s t a b
environment' sa bt = environment $ envMod sa bt

environment'' :: Functor f => (((s -> f a) -> f b) -> t) -> Over s t a b
environment'' f = dimap pureTaskF (f . runTask) . map'

unlifting :: MonadUnliftIO m => Env (m a) (m b) (IO a) (IO b)
unlifting = environment withRunInIO

masking :: MonadUnliftIO m => Env (m a) (m b) (m a) (m b)
masking = environment mask

unlifting' :: MonadUnliftIO m => Over (m a) (m b) a b
unlifting' = environment'' withRunInIO

masking' :: MonadUnliftIO m => Over (m a) (m b) a b
masking' = environment'' mask

---------------------------------------------------------------------
-- 
---------------------------------------------------------------------

-- | The 'EnvRep' profunctor precisely characterizes 'Env'.

newtype EnvRep a b s t = EnvRep { unEnvRep :: ((s -> a) -> b) -> t }

instance Profunctor (EnvRep a b) where
  dimap f g (EnvRep z) = EnvRep $ \d -> g (z $ \k -> d (k . f))

instance Closed (EnvRep a b) where
  -- closed :: p a b -> p (x -> a) (x -> b)
  closed (EnvRep z) = EnvRep $ \f x -> z $ \k -> f $ \g -> k (g x)

type AnEnv s t a b = Optic (EnvRep a b) s t a b

---------------------------------------------------------------------
-- Operators
---------------------------------------------------------------------

modEnv :: (((s -> a) -> b) -> t) -> (a -> b) -> s -> t
modEnv sabt ab s = sabt (\get -> ab (get s))

-- Every isomorphism is an environment.
envMod :: (s -> a) -> (b -> t) -> ((s -> a) -> b) -> t
envMod sa bt sab = bt (sab sa)

withEnv :: AnEnv s t a b -> ((s -> a) -> b) -> t
withEnv g = h where EnvRep h = (g (EnvRep $ \f -> f id))

cloneEnv :: AnEnv s t a b -> Env s t a b
cloneEnv g = environment (withEnv g)

cotraversed :: Distributive f => Env (f a) (f b) a b
cotraversed = environment $ \f -> cotraverse f id

cotraversing :: (Distributive t, Functor f) => (f a -> b) -> f (t a) -> t b
cotraversing = cotraverseOf cotraversed