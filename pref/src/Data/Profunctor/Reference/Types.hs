{-# LANGUAGE AllowAmbiguousTypes       #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE FlexibleInstances         #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE UndecidableInstances      #-}
{-# LANGUAGE TypeOperators             #-}

module Data.Profunctor.Reference.Types (
    module Data.Profunctor.Reference.Types
  , module Export
) where

import Data.StateVar as Export
import Data.Profunctor.Optic as Export hiding (has)

debug :: Show a => SettableStateVar a
debug = SettableStateVar print

pstate 
  :: Optic (Star ((,) a)) s t a b
  -> (a -> (a, b)) -> s -> t
pstate o f = star o snd f id

pmaybe
  :: Optic (Costar Maybe) s t a b 
  -> a -> (a -> b) -> Maybe s -> t
pmaybe o a ab = costar' o ab (maybe a id)

into :: ((a -> b) -> c) -> (r -> b) -> (a -> r) -> c
into up f = up . (f .)

outof :: (c -> a -> b) -> (b -> r) -> c -> a -> r
outof down g = (g .) . down

star
  :: Optic (Star f) s t a b
  -> (f t -> r)
  -> (c -> f b)
  -> (a -> c)
  -> s
  -> r
star o down up f = outof runStar down (o . into Star up $ f)

star' :: Optic (Star f) s t a b -> (f t -> r) -> (a -> f b) -> s -> r
star' o f g = star o f g id

costar
  :: (t -> d)
  -> Optic (Costar f) s t a b
  -> (c -> b)
  -> (f a -> c)
  -> f s
  -> d
costar down o up f = outof runCostar down (o . into Costar up $ f)

costar'
  :: Optic (Costar f) s t a b
  -> (c -> b)
  -> (f a -> c)
  -> f s
  -> t
costar' = costar id