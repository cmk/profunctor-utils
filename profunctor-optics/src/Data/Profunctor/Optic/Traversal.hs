{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE QuantifiedConstraints #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TupleSections         #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE TypeFamilies          #-}
module Data.Profunctor.Optic.Traversal (
    -- * Traversal & Ixtraversal
    Representable(..)
  , Traversal
  , Traversal'
  , Ixtraversal
  , Ixtraversal'
  , ATraversal
  , ATraversal'
  , traversing
  , ixtraversing
  , traversalVl
  , ixtraversalVl
  , noix
  , ix
    -- * Carriers
  , Star(..)
    -- * Primitive operators
  , traverseOf
    -- * Optics
  , traversed
  , both
  , duplicated
  , bitraversed
    -- * Operators
  , sequences
) where

import Data.Bifunctor (first, second)
import Data.Bitraversable
import Data.List.Index
import Data.Map as Map
import Data.Profunctor.Optic.Lens hiding (first, second, unit)
import Data.Profunctor.Optic.Import
import Data.Profunctor.Optic.Prism (prism)
import Data.Profunctor.Optic.Type
import Data.Semiring
import Control.Monad.Trans.State
import Data.Profunctor.Optic.Iso
import qualified Data.Bifunctor as B

-- $setup
-- >>> :set -XNoOverloadedStrings
-- >>> :set -XFlexibleContexts
-- >>> :set -XTypeApplications
-- >>> :set -XTupleSections
-- >>> :set -XRankNTypes
-- >>> import Data.Maybe
-- >>> import Data.List.NonEmpty (NonEmpty(..))
-- >>> import qualified Data.List.NonEmpty as NE
-- >>> import Data.Functor.Identity
-- >>> import Data.List.Index
-- >>> :load Data.Profunctor.Optic
-- >>> let catchOn :: Int -> Cxprism' Int (Maybe String) String ; catchOn n = cxjust $ \k -> if k==n then Just "caught" else Nothing
-- >>> let ixtraversed :: Ixtraversal Int [a] [b] a b ; ixtraversed = ixtraversalVl itraverse

---------------------------------------------------------------------
-- 'Traversal' & 'Ixtraversal'
---------------------------------------------------------------------

type ATraversal f s t a b = Applicative f => ARepn f s t a b

type ATraversal' f s a = ATraversal f s s a a

-- | Obtain a 'Traversal' by lifting a lens getter and setter into a 'Traversable' functor.
--
-- @
--  'withLens' o 'traversing' ≡ 'traversed' . o
-- @
--
-- Compare 'Data.Profunctor.Optic.Fold.folding'.
--
-- /Caution/: In order for the generated optic to be well-defined,
-- you must ensure that the input functions constitute a legal lens:
--
-- * @sa (sbt s a) ≡ a@
--
-- * @sbt s (sa s) ≡ s@
--
-- * @sbt (sbt s a1) a2 ≡ sbt s a2@
--
-- See 'Data.Profunctor.Optic.Property'.
--
-- The resulting optic can detect copies of the lens stucture inside
-- any 'Traversable' container. For example:
--
-- >>> lists (traversing snd $ \(s,_) b -> (s,b)) [(0,'f'),(1,'o'),(2,'o'),(3,'b'),(4,'a'),(5,'r')]
-- "foobar"
--
traversing :: Traversable f => (s -> a) -> (s -> b -> t) -> Traversal (f s) (f t) a b
traversing sa sbt = repn traverse . lens sa sbt

ixtraversed :: Monoid i => Traversable f => AIxlens i s t a b -> Ixtraversal i (f s) (f t) a b
ixtraversed = flip withIxlens ixtraversing

-- | Obtain a 'Ixtraversal' by lifting an indexed lens getter and setter into a 'Traversable' functor.
--
-- @
--  'withIxlens' o 'ixtraversing' ≡ 'ixtraversed' . o
-- @
--
-- /Caution/: In order for the generated optic to be well-defined,
-- you must ensure that the input functions constitute a legal 
-- indexed lens:
--
-- * @snd . sia (sbt s a) ≡ a@
--
-- * @sbt s (snd $ sia s) ≡ s@
--
-- * @sbt (sbt s a1) a2 ≡ sbt s a2@
--
-- See 'Data.Profunctor.Optic.Property'.
--
ixtraversing :: Monoid i => Traversable f => (s -> (i , a)) -> (s -> b -> t) -> Ixtraversal i (f s) (f t) a b
ixtraversing sia sbt = repn (\iab -> traverse (curry iab mempty) . snd) . ixlens sia sbt 

-- | Obtain a profunctor 'Traversal' from a Van Laarhoven 'Traversal'.
--
-- /Caution/: In order for the generated optic to be well-defined,
-- you must ensure that the input satisfies the following properties:
--
-- * @abst pure ≡ pure@
--
-- * @fmap (abst f) . abst g ≡ getCompose . abst (Compose . fmap f . g)@
--
-- See 'Data.Profunctor.Optic.Property'.
--
traversalVl :: (forall f. Applicative f => (a -> f b) -> s -> f t) -> Traversal s t a b
traversalVl abst = tabulate . abst . sieve

-- | Lift an indexed VL traversal into an indexed profunctor traversal.
--
-- /Caution/: In order for the generated optic to be well-defined,
-- you must ensure that the input satisfies the following properties:
--
-- * @iabst (const pure) ≡ pure@
--
-- * @fmap (iabst $ const f) . (iabst $ const g) ≡ getCompose . iabst (const $ Compose . fmap f . g)@
--
-- See 'Data.Profunctor.Optic.Property'.
--
ixtraversalVl :: (forall f. Applicative f => (i -> a -> f b) -> s -> f t) -> Ixtraversal i s t a b
ixtraversalVl f = traversalVl $ \iab -> f (curry iab) . snd

-- | Lift a VL traversal into an indexed profunctor traversal that ignores its input.
--
-- Useful as the first optic in a chain when no indexed equivalent is at hand.
--
-- >>> ixlists (noix traversed . ixtraversed) ["foo", "bar"]
-- [(0,'f'),(1,'o'),(2,'o'),(0,'b'),(1,'a'),(2,'r')]
--
-- >>> ixlists (ixtraversed . noix traversed) ["foo", "bar"]
-- [(0,'f'),(0,'o'),(0,'o'),(0,'b'),(0,'a'),(0,'r')]
--
noix :: Monoid i => Traversal s t a b -> Ixtraversal i s t a b
noix o = ixtraversalVl $ \iab s -> flip runStar s . o . Star $ iab mempty

-- | Index a traversal with a 'Data.Semiring'.
--
-- >>> ixlists (ix traversed . ix traversed) ["foo", "bar"]
-- [((),'f'),((),'o'),((),'o'),((),'b'),((),'a'),((),'r')]
--
-- >>> ixlists (ix @Int traversed . ix traversed) ["foo", "bar"]
-- [(0,'f'),(1,'o'),(2,'o'),(0,'b'),(1,'a'),(2,'r')]
--
-- >>> ixlists (ix @[()] traversed . ix traversed) ["foo", "bar"]
-- [([],'f'),([()],'o'),([(),()],'o'),([],'b'),([()],'a'),([(),()],'r')]
--
-- >>> ixlists (ix @[()] traversed % ix traversed) ["foo", "bar"]
-- [([],'f'),([()],'o'),([(),()],'o'),([()],'b'),([(),()],'a'),([(),(),()],'r')]
--
ix :: Monoid i => Semiring i => Traversal s t a b -> Ixtraversal i s t a b
ix o = ixtraversalVl $ \f s ->
  flip evalState mempty . getCompose . flip runStar s . o . Star $ \a ->
    Compose $ (f <$> get <*> pure a) <* modify (<> unit) 

---------------------------------------------------------------------
-- Primitive operators
---------------------------------------------------------------------

-- | 
--
-- The traversal laws can be stated in terms of 'traverseOf':
-- 
-- Identity:
-- 
-- @
-- traverseOf t (Identity . f) ≡  Identity (fmap f)
-- @
-- 
-- Composition:
-- 
-- @ 
-- Compose . fmap (traverseOf t f) . traverseOf t g ≡ traverseOf t (Compose . fmap f . g)
-- @
--
-- @
-- traverseOf :: Functor f => Lens s t a b -> (a -> f b) -> s -> f t
-- traverseOf :: Applicative f => Traversal s t a b -> (a -> f b) -> s -> f t
-- @
--
traverseOf :: Applicative f => ATraversal f s t a b -> (a -> f b) -> s -> f t
traverseOf o = runStar #. o .# Star

---------------------------------------------------------------------
-- Common 'Traversal0's, 'Traversal's, 'Traversal1's, & 'Cotraversal1's
---------------------------------------------------------------------

-- | TODO: Document
--
traversed :: Traversable f => Traversal (f a) (f b) a b
traversed = traversalVl traverse

-- | TODO: Document
--
-- >>> traverseOf both (pure . length) ("hello","world")
-- (5,5)
--
both :: Traversal (a , a) (b , b) a b
both p = p **** p

-- | Duplicate the results of any 'Fold'. 
--
-- >>> lists (both . duplicated) ("hello","world")
-- ["hello","hello","world","world"]
--
duplicated :: Traversal a b a b
duplicated p = pappend p p

-- | Traverse both parts of a 'Bitraversable' container with matching types.
--
-- >>> traverseOf bitraversed (pure . length) (Right "hello")
-- Right 5
--
-- >>> traverseOf bitraversed (pure . length) ("hello","world")
-- (5,5)
--
-- >>> ("hello","world") ^. bitraversed
-- "helloworld"
--
-- @
-- 'bitraversed' :: 'Traversal' (a , a) (b , b) a b
-- 'bitraversed' :: 'Traversal' (a + a) (b + b) a b
-- @
--
bitraversed :: Bitraversable f => Traversal (f a a) (f b b) a b
bitraversed = repn $ \f -> bitraverse f f
{-# INLINE bitraversed #-}

---------------------------------------------------------------------
-- Operators
---------------------------------------------------------------------

-- | TODO: Document
--
sequences :: Applicative f => ATraversal f s t (f a) a -> s -> f t
sequences o = traverseOf o id
{-# INLINE sequences #-}
