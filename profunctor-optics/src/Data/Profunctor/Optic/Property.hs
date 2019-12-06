{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE QuantifiedConstraints #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TupleSections         #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE TypeFamilies          #-}
module Data.Profunctor.Optic.Property (
    -- * Iso
    Iso
  , fromto_iso
  , tofrom_iso
    -- * Prism
  , Prism
  , tofrom_prism
  , fromto_prism 
  , idempotent_prism 
    -- * Lens
  , Lens
  , id_lens
  , tofrom_lens
  , fromto_lens
  , idempotent_lens
    -- * Grate
  , Grate
  , id_grate
  , const_grate
  , compose_grate
    -- * Traversal0
  , Traversal0
  , tofrom_traversal0
  , fromto_traversal0
  , idempotent_traversal0
    -- * Traversal
  , Traversal
  , id_traversal
  , pure_traversal
  , compose_traversal
    -- * Traversal1
  , id_traversal1
  , compose_traversal1
    -- * Cotraversal1
  , Cotraversal1 
  , compose_cotraversal1
    -- * Setter
  , Setter
  , id_setter
  , compose_setter
  , idempotent_setter
) where 

import Control.Monad as M (join)
import Control.Applicative
import Data.Profunctor.Optic.Import
import Data.Profunctor.Optic.Type
import Data.Profunctor.Optic.Iso
--import Data.Profunctor.Optic.View
import Data.Profunctor.Optic.Setter
import Data.Profunctor.Optic.Lens
import Data.Profunctor.Optic.Prism
import Data.Profunctor.Optic.Grate
--import Data.Profunctor.Optic.Fold
import Data.Profunctor.Optic.Traversal
import Data.Profunctor.Optic.Traversal0
import Data.Profunctor.Optic.Traversal1

---------------------------------------------------------------------
-- 'Iso'
---------------------------------------------------------------------

-- | Going back and forth doesn't change anything.
--
fromto_iso :: Eq s => Iso' s a -> s -> Bool
fromto_iso o s = withIso o $ \sa as -> as (sa s) == s

-- | Going back and forth doesn't change anything.
--
tofrom_iso :: Eq a => Iso' s a -> a -> Bool
tofrom_iso o a = withIso o $ \sa as -> sa (as a) == a

---------------------------------------------------------------------
-- 'Prism'
---------------------------------------------------------------------

-- | If we are able to view an existing focus, then building it will return the original structure.
--
-- * @(id ||| bt) (sta s) ≡ s@
--
tofrom_prism :: Eq s => Prism' s a -> s -> Bool
tofrom_prism o s = withPrism o $ \sta bt -> either id bt (sta s) == s

-- | If we build a whole from a focus, that whole must contain the focus.
--
-- * @sta (bt b) ≡ Right b@
--
fromto_prism :: Eq s => Eq a => Prism' s a -> a -> Bool
fromto_prism o a = withPrism o $ \sta bt -> sta (bt a) == Right a

-- |
--
-- * @left sta (sta s) ≡ left Left (sta s)@
--
idempotent_prism :: Eq s => Eq a => Prism' s a -> s -> Bool
idempotent_prism o s = withPrism o $ \sta _ -> left' sta (sta s) == left' Left (sta s)

---------------------------------------------------------------------
-- 'Lens'
---------------------------------------------------------------------

invertible f g a = g (f a) == a

-- A 'Lens' is a valid 'Traversal' with the following additional laws:

id_lens :: Eq s => Lens' s a -> s -> Bool
id_lens o = M.join invertible $ runIdentity . withLensVl o Identity 

-- | You get back what you put in.
--
-- * @view o (set o b a) ≡ b@
--
tofrom_lens :: Eq s => Lens' s a -> s -> Bool
tofrom_lens o s = withLens o $ \sa sas -> sas s (sa s) == s

-- | Putting back what you got doesn't change anything.
--
-- * @set o (view o a) a  ≡ a@
--
fromto_lens :: Eq a => Lens' s a -> s -> a -> Bool
fromto_lens o s a = withLens o $ \sa sas -> sa (sas s a) == a

-- | Setting twice is the same as setting once.
--
-- * @set o c (set o b a) ≡ set o c a@
--
idempotent_lens :: Eq s => Lens' s a -> s -> a -> a -> Bool
idempotent_lens o s a1 a2 = withLens o $ \_ sas -> sas (sas s a1) a2 == sas s a2

---------------------------------------------------------------------
-- 'Grate'
---------------------------------------------------------------------

-- The 'Grate' laws are that of an algebra for the parameterised continuation 'Coindex'.

id_grate :: Eq s => Grate' s a -> s -> Bool
id_grate o = M.join invertible $ withGrateVl o runIdentity . Identity 

-- |
--
-- * @sabt ($ s) ≡ s@
--
const_grate :: Eq s => Grate' s a -> s -> Bool
const_grate o s = withGrate o $ \sabt -> sabt ($ s) == s

compose_grate :: Eq s => Functor f => Functor g => Grate' s a -> (f a -> a) -> (g a -> a) -> f (g s) -> Bool
compose_grate o f g = liftA2 (==) lhs rhs
  where lhs = withGrateVl o f . fmap (withGrateVl o g) 
        rhs = withGrateVl o (f . fmap g . getCompose) . Compose

---------------------------------------------------------------------
-- 'Traversal0'
---------------------------------------------------------------------

-- | You get back what you put in.
--
-- * @sta (sbt a s) ≡ either (Left . const a) Right (sta s)@
--
tofrom_traversal0 :: Eq a => Eq s => Traversal0' s a -> s -> a -> Bool
tofrom_traversal0 o s a = withTraversal0 o $ \sta sbt -> sta (sbt s a) == either (Left . flip const a) Right (sta s)

-- | Putting back what you got doesn't change anything.
--
-- * @either id (sbt s) (sta s) ≡ s@
--
fromto_traversal0 :: Eq s => Traversal0' s a -> s -> Bool
fromto_traversal0 o s = withTraversal0 o $ \sta sbt -> either id (sbt s) (sta s) == s

-- | Setting twice is the same as setting once.
--
-- * @sbt (sbt s a1) a2 ≡ sbt s a2@
--
idempotent_traversal0 :: Eq s => Traversal0' s a -> s -> a -> a -> Bool
idempotent_traversal0 o s a1 a2 = withTraversal0 o $ \_ sbt -> sbt (sbt s a1) a2 == sbt s a2

---------------------------------------------------------------------
-- 'Traversal'
---------------------------------------------------------------------

-- A 'Traversal' is a valid 'Setter' with the following additional laws:

id_traversal :: Eq s => Traversal' s a -> s -> Bool
id_traversal o = M.join invertible $ runIdentity . withTraversal o Identity 

pure_traversal :: Eq (f s) => Applicative f => ATraversal' f s a -> s -> Bool
pure_traversal o = liftA2 (==) (withTraversal o pure) pure

compose_traversal :: Eq (f (g s)) => Applicative f => Applicative g => Traversal' s a -> (a -> g a) -> (a -> f a) -> s -> Bool
compose_traversal o f g = liftA2 (==) lhs rhs
  where lhs = fmap (withTraversal o f) . withTraversal o g
        rhs = getCompose . withTraversal o (Compose . fmap f . g)

---------------------------------------------------------------------
-- 'Traversal1'
---------------------------------------------------------------------

id_traversal1 :: Eq s => Traversal1' s a -> s -> Bool
id_traversal1 o = M.join invertible $ runIdentity . withTraversal1 o Identity 

compose_traversal1 :: Eq (f (g s)) => Apply f => Apply g => Traversal1' s a -> (a -> g a) -> (a -> f a) -> s -> Bool
compose_traversal1 o f g s = lhs s == rhs s
  where lhs = fmap (withTraversal1 o f) . withTraversal1 o g
        rhs = getCompose . withTraversal1 o (Compose . fmap f . g)

---------------------------------------------------------------------
-- 'Cotraversal1'
---------------------------------------------------------------------

-- | A 'Cotraversal1' is a valid 'Resetter' with the following additional law:
--
-- * @abst f . fmap (abst g) ≡ abst (f . fmap g . getCompose) . Compose @
--
-- The cotraversal laws can be restated in terms of 'cowithTraversal1':
--
-- * @withCotraversal1 o (f . runIdentity) ≡  fmap f . runIdentity @
--
-- * @withCotraversal1 o f . fmap (withCotraversal1 o g) == withCotraversal1 o (f . fmap g . getCompose) . Compose@
--
-- See also < https://www.cs.ox.ac.uk/jeremy.gibbons/publications/iterator.pdf >
--
compose_cotraversal1 :: Eq s => Apply f => Apply g => Cotraversal1' s a -> (f a -> a) -> (g a -> a) -> f (g s) -> Bool
compose_cotraversal1 o f g = liftF2 (==) lhs rhs
  where lhs = withCotraversal1 o f . fmap (withCotraversal1 o g) 
        rhs = withCotraversal1 o (f . fmap g . getCompose) . Compose

---------------------------------------------------------------------
-- 'Setter'
---------------------------------------------------------------------

-- |
--
-- * @over o id ≡ id@
--
id_setter :: Eq s => Setter' s a -> s -> Bool
id_setter o s = over o id s == s

-- |
--
-- * @over o f . over o g ≡ over o (f . g)@
--
compose_setter :: Eq s => Setter' s a -> (a -> a) -> (a -> a) -> s -> Bool
compose_setter o f g s = (over o f . over o g) s == over o (f . g) s

-- |
--
-- * @set o y (set o x a) ≡ set o y a@
--
idempotent_setter :: Eq s => Setter' s a -> s -> a -> a -> Bool
idempotent_setter o s a b = set o b (set o a s) == set o b s
