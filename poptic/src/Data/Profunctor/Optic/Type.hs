{-# LANGUAGE UndecidableSuperClasses, TypeOperators , GADTs, DataKinds, KindSignatures, TypeFamilies #-}

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TupleSections #-}

module Data.Profunctor.Optic.Type (
    module Data.Profunctor.Optic.Type
  , module Data.Profunctor.Optic.Type.Class
) where

import Data.Semigroup (First, Last)
import Data.Profunctor.Optic.Type.Class 
import Data.Profunctor.Optic.Prelude
import Data.Either.Validation (Validation)


import           Control.Applicative
import           Control.Monad
import           Control.Monad.Fix
import           Data.Bifoldable
import           Data.Bifunctor
import           Data.Bitraversable
import           Data.Coerce
import           Data.Data
import           GHC.Generics

type Optic p s t a b = p a b -> p s t

type Optic' p s a = Optic p s s a a

type LensLike f s t a b = (a -> f b) -> s -> f t

type LensLike' f s a = LensLike f s s a a

-- | A witness that @(a ~ s, b ~ t)@.
type Equality s t a b = forall p. Optic p s t a b 

type Equality' s a = Equality s s a a

type Iso s t a b = forall p. Profunctor p => Optic p s t a b

type Iso' s a = Iso s s a a

type VLIso s t a b = forall p f. (Profunctor p, Functor f) => p a (f b) -> p s (f t)

type Lens s t a b = forall p. Strong p => Optic p s t a b

type Lens' s a = Lens s s a a

type VLLens s t a b = forall f. Functor f => LensLike f s t a b

type Prism s t a b = forall p. Choice p => Optic p s t a b

type Prism' s a = Prism s s a a

type VLPrism s t a b = forall p f. (Choice p, Applicative f) => p a (f b) -> p s (f t)

-- An 'AffineFold' extracts at most one result, with no monoidal interactions.
type AffineTraversal s t a b = forall p. (Strong p, Choice p) => Optic p s t a b

type AffineTraversal' s a = AffineTraversal s s a a

type Traversal s t a b = forall p. Traversing p => Optic p s t a b

type Traversal' s a = Traversal s s a a

type VLTraversal s t a b = forall f. Applicative f => LensLike f s t a b

type Traversal1 s t a b = forall p. Traversing1 p => Optic p s t a b

type Traversal1' s a = Traversal1 s s a a

type VLTraversal1 s t a b = forall f. Apply f => LensLike f s t a b

-- An 'AffineFold' extracts at most one result.
type AffineFold s a = forall p. (OutPhantom p, Strong p, Choice p) => Optic' p s a

-- | A 'Fold' describes how to retrieve multiple values in a way that can be composed
-- with other optics.
--
-- A @'Fold' s a@ provides a structure with operations very similar to those of the 'Data.Foldable.Foldable'
-- typeclass, see 'foldMapOf' and the other 'Fold' combinators.
--
-- By convention, if there exists a 'foo' method that expects a @'Data.Foldable.Foldable' (f a)@, then there should be a
-- @fooOf@ method that takes a @'Fold' s a@ and a value of type @s@. See 'Data.Profunctor.Optic.Fold'.
--
-- A 'View' is a legal 'Fold' that just ignores the supplied 'Data.Monoid.Monoid'.
--
-- Unlike a 'Traversal' a 'Fold' is read-only. Since a 'Fold' cannot be used to write back there are no laws that apply.
--
type Fold s a = forall p. (OutPhantom p, Traversing p) => Optic' p s a

type VLFold s a = forall f. (Contravariant f, Applicative f) => LensLike' f s a

-- A 'Fold1' extracts at least one result.
type Fold1 s a = forall p. (OutPhantom p, Traversing1 p) => Optic' p s a 

type VLFold1 s a = forall f. (Contravariant f, Apply f) => LensLike' f s a

type Over s t a b = forall p. Mapping p => Optic p s t a b

type Over' s a = Over s s a a

type PrimView s t a b = forall p. OutPhantom p => Optic p s t a b

type PrimView' s a = PrimView s s a a

-- A 'View' extracts exactly one result.
type View s a = forall p. (OutPhantom p, Strong p) => Optic' p s a

type PrimReview s t a b = forall p. InPhantom p => Optic p s t a b

type PrimReview' t b = PrimReview t t b b

type Review t b = forall p. (InPhantom p, Choice p) => Optic' p t b

type Closure s t a b = forall p. Closed p => Optic p s t a b

type Closure' s a = Closure s s a a

type Folding r s a = Optic' (Star (Const r)) s a

type AFolding r s a = Optic' (Star (Pre r)) s a

type Unfolding r t b = Optic' (Costar (Const r)) t b

--type Viewing s a = forall r. Folding r s a
type Viewing s a = Folding a s a

--type Reviewing t b = forall r. Unfolding r t b
type Reviewing t b = Unfolding b t b

--type Matched r = Star (Either r)

type Matching e s t a b = Optic (Matched e) s t a b

type Validated r = Star (Validation r)

type Validating e s t a b = Optic (Validated e) s t a b

--type AFolding r = Star (Pre r)
-- Folding r s a = Optic (Star (Const r)) s a
-- Folding s a = forall r. Folding r s a
--type AffineTraversed r = 

-- Retrieve either 0 or 1 subobjects, with no monoidal interactions.
type Previewing s a = Optic' (Previewed a) s a



---------------------------------------------------------------------
-- 'Matched'
---------------------------------------------------------------------

newtype Matched r a b = Matched { runMatched :: a -> Either b r }

instance Profunctor (Matched r) where
    dimap f g (Matched p) = Matched (first g . p . f)

instance Choice (Matched r) where
    right' (Matched p) = Matched (unassoc . fmap p)

instance Strong (Matched r) where
    first' (Matched p) = Matched (\(a,c) -> first (,c) (p a))

{-
instance Costrong (Matched r) where
    unfirst (Matched f) =
       Matched (first fst . f . (, error "Costrong Matched"))
-}

--TODO give this a Traversing instance or else use matching'

---------------------------------------------------------------------
-- 'Previewed'
---------------------------------------------------------------------

-- This is for Affine
newtype Previewed r a b = Previewed { runPreviewed :: a -> Maybe r }

instance Profunctor (Previewed r) where
    dimap f _ (Previewed p) = Previewed (p . f)

instance OutPhantom (Previewed r) where
    ocoerce (Previewed p) = (Previewed p)

instance Choice (Previewed r) where
    right' (Previewed p) = Previewed (either (const Nothing) p)

instance Strong (Previewed r) where
    first' (Previewed p) = Previewed (p . fst)


---------------------------------------------------------------------
-- 'Pre'
---------------------------------------------------------------------

-- | 'Pre' is 'Maybe' with a phantom type variable.
--
-- 
-- Star (Pre r) a b has Strong. Also Choice & Traversing when r is a Semigroup.
newtype Pre a b = Pre { runPre :: Maybe a } deriving (Eq, Ord, Show, Data, Generic, Generic1)

instance Functor (Pre a) where fmap f (Pre p) = Pre p

instance Contravariant (Pre a) where contramap f (Pre p) = Pre p

instance Semigroup a => Applicative (Pre a) where
    pure _ = Pre $ mempty

    (Pre pbc) <*> (Pre pb) = Pre $ pbc <> pb

{-
instance Functor Pre where
  fmap f (Pre a) = Pre (fmap f a)

instance Applicative Pre where
  pure a = Pre (Just a)
  Pre a <*> Pre b = Pre (a <*> b)
  liftA2 f (Pre x) (Pre y) = Pre (liftA2 f x y)

  Pre Nothing  *>  _ = Pre Nothing
  _               *>  b = b

instance Monad Pre where
  Pre (Just a) >>= k = k a
  _               >>= _ = Pre Nothing
  (>>) = (*>)

instance Alternative Pre where
  empty = Pre Nothing
  Pre Nothing <|> b = b
  a <|> _ = a

instance MonadPlus Pre

instance MonadFix Pre where
  mfix f = Pre (mfix (runPre . f))

instance Foldable Pre where
  foldMap f (Pre (Just m)) = f m
  foldMap _ (Pre Nothing)  = mempty

instance Traversable Pre where
  traverse f (Pre (Just a)) = Pre . Just <$> f a
  traverse _ (Pre Nothing)  = pure (Pre Nothing)
-}

---------------------------------------------------------------------
-- 'Re'
---------------------------------------------------------------------


--The 'Re' type, and its instances witness the symmetry of 'Profunctor' 
-- and the relation between 'InPhantom' and 'OutPhantom'.

newtype Re p s t a b = Re { runRe :: p b a -> p t s }

instance Profunctor p => Profunctor (Re p s t) where
    dimap f g (Re p) = Re (p . dimap g f)

instance Cochoice p => Choice (Re p s t) where
    right' (Re p) = Re (p . unright)

instance Costrong p => Strong (Re p s t) where
    first' (Re p) = Re (p . unfirst)

instance Choice p => Cochoice (Re p s t) where
    unright (Re p) = Re (p . right')

instance Strong p => Costrong (Re p s t) where
    unfirst (Re p) = Re (p . first')

instance InPhantom p => OutPhantom (Re p s t) where 
    ocoerce (Re p) = Re (p . icoerce)

instance OutPhantom p => InPhantom (Re p s t) where 
    icoerce (Re p) = Re (p . ocoerce)


---------------------------------------------------------------------
-- 
---------------------------------------------------------------------

newtype Paired p c d a b = Paired { runPaired :: p (c,a) (d,b) }

fromTambara :: Profunctor p => Tambara p a b -> Paired p d d a b
fromTambara = Paired . dimap swap swap . runTambara

instance Profunctor p => Profunctor (Paired p c d) where
  dimap f g (Paired pab) = Paired $ dimap (fmap f) (fmap g) pab

instance Strong p => Strong (Paired p c d) where
  second' (Paired pab) = Paired . dimap shuffle shuffle . second' $ pab
   where
    shuffle (x,(y,z)) = (y,(x,z))

instance OutPhantom p => OutPhantom (Paired p c d) where
  ocoerce (Paired pab) = Paired $ ocoerce pab

-- ^ @
-- paired :: Iso s t a b -> Iso s' t' a' b' -> Iso (s, s') (t, t') (a, a') (b, b')
-- paired :: Lens s t a b -> Lens s' t' a' b' -> Lens (s, s') (t, t') (a, a') (b, b')
-- @
paired 
  :: Profunctor p 
  => Optic (Paired p s' t') s t a b 
  -> Optic (Paired p a b) s' t' a' b' 
  -> Optic p (s, s') (t, t') (a, a') (b, b')
paired lab lcd = 
  dimap swap swap . runPaired . lab . Paired . 
  dimap swap swap . runPaired . lcd . Paired

pairing :: Profunctor p => (s -> a) -> (b -> t) -> Optic p (c, s) (d, t) (c, a) (d, b)
pairing f g = between runPaired Paired (dimap f g)

---------------------------------------------------------------------
-- 
---------------------------------------------------------------------

newtype Split p c d a b = Split { runSplit :: p (Either c a) (Either d b) }

fromTambaraSum :: Profunctor p => TambaraSum p a b -> Split p d d a b
fromTambaraSum = Split . dimap swap swap . runTambaraSum

instance Profunctor p => Profunctor (Split p c d) where
  dimap f g (Split pab) = Split $ dimap (fmap f) (fmap g) pab

instance Choice p => Choice (Split p c d) where
  right' (Split pab) = Split . dimap shuffle shuffle . right' $ pab
   where
    shuffle = Right . Left ||| (Left ||| Right . Right)

instance InPhantom p => InPhantom (Split p c d) where
  icoerce (Split pab) = Split $ icoerce pab

-- ^ @
-- split :: Iso s t a b -> Iso s' t' a' b' -> Iso (Either s s') (Either t t') (Either a a') (Either b b')
-- split :: Prism s t a b -> Prism s' t' a' b' -> Lens (Either s s') (Either t t') (Either a a') (Either b b')
-- split :: View s t a b -> View s' t' a' b' -> Review (Either s s') (Either t t') (Either a a') (Either b b')
-- @
split 
  :: Profunctor p 
  => Optic (Split p s' t') s t a b 
  -> Optic (Split p a b) s' t' a' b' 
  -> Optic p (Either s s') (Either t t') (Either a a') (Either b b')
split lab lcd = 
  dimap swap swap . runSplit . lab . Split . 
  dimap swap swap . runSplit . lcd . Split

splitting :: Profunctor p => (s -> a) -> (b -> t) -> Optic p (Either c s) (Either d t) (Either c a) (Either d b)
splitting f g = between runSplit Split (dimap f g)



-- http://hackage.haskell.org/package/lens-4.17/docs/src/Control.Lens.Internal.Context.html#Context

-- | The indexed store can be used to characterize a 'Lens'
-- and is used by 'cloneLens'.
--
-- @'Context' a b t@ is isomorphic to
-- @newtype 'Context' a b t = 'Context' { runContext :: forall f. 'Functor' f => (a -> f b) -> f t }@,
-- and to @exists s. (s, 'Lens' s t a b)@.
--
-- A 'Context' is like a 'Lens' that has already been applied to a some structure.
--data Context a b t = Context (b -> t) a

data Context a b t = Context (b -> t) a 

instance Functor (Context a b) where
    fmap g (Context h a) = Context (g . h) a
    {-# INLINE fmap #-}

instance Profunctor (Context a) where
    dimap f g (Context h a) = Context (g . h . f) a
    {-# INLINE dimap #-}

-- The type ∀ f, g : Functor. (g a → f b) → g s → f t is isomorphic to the type (s → a)×(b → t). 
-- The Van Laarhoven representation of isomorphisms uses this representation of a pair of function to capture the notion of an isomorphism.
extractPair :: (((s -> a) -> Context (s -> a) b b) -> (s -> s) -> Context (s -> a) b t)
            -> (s -> a, b -> t)
extractPair l = (f, g) where Context g f = l (Context id) id


---------------------------------------------------------------------
-- 
---------------------------------------------------------------------


newtype Zipped a b = Zipped { runZipped :: a -> a -> b }

instance Profunctor Zipped where
    dimap f g (Zipped p) = Zipped (\x y -> g (p (f x) (f y)))

instance Closed Zipped where
    closed (Zipped p) = Zipped (\f g x -> p (f x) (g x))

instance Choice Zipped where
    right' (Zipped p) = Zipped (\x y -> p <$> x <*> y)

instance Strong Zipped where
    first' (Zipped p) = Zipped (\(x, c) (y, _) -> (p x y, c))


{-
{-# LANGUAGE CPP #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE MultiParamTypeClasses #-}

#if __GLASGOW_HASKELL__ < 708
{-# LANGUAGE Trustworthy #-}
#endif
import Control.Applicative
import Control.Arrow as Arrow
import Control.Category
import Control.Comonad
import Control.Lens.Internal.Instances ()
import Control.Monad
import Control.Monad.Fix
import Data.Distributive
import Data.Functor.Bind
import Data.Functor.Contravariant
import Data.Int
import Data.Monoid
import Data.Profunctor.Closed
import Data.Profunctor
import Data.Profunctor.Rep
import Data.Profunctor.Sieve
import qualified Data.Semigroup as Semi
import Data.Traversable
import Prelude hiding ((.),id)
#ifndef SAFE
import Data.Profunctor.Unsafe
import Control.Lens.Internal.Coerce
#endif

-- $setup
-- >>> :set -XNoOverloadedStrings
-- >>> import Control.Lens
-- >>> import Numeric.Lens
--
------------------------------------------------------------------------------
-- Conjoined
------------------------------------------------------------------------------

-- | This is a 'Profunctor' that is both 'Corepresentable' by @f@ and 'Representable' by @g@ such
-- that @f@ is left adjoint to @g@. From this you can derive a lot of structure due
-- to the preservation of limits and colimits.
class
  ( Choice p, Corepresentable p, Comonad (Corep p), Traversable (Corep p)
  , Strong p, Representable p, Monad (Rep p), MonadFix (Rep p), Distributive (Rep p)
  , Costrong p, ArrowLoop p, ArrowApply p, ArrowChoice p, Closed p
  ) => Conjoined p where

  -- | 'Conjoined' is strong enough to let us distribute every 'Conjoined'
  -- 'Profunctor' over every Haskell 'Functor'. This is effectively a
  -- generalization of 'fmap'.
  distrib :: Functor f => p a b -> p (f a) (f b)
  distrib = tabulate . collect . sieve
  {-# INLINE distrib #-}

  -- | This permits us to make a decision at an outermost point about whether or not we use an index.
  --
  -- Ideally any use of this function should be done in such a way so that you compute the same answer,
  -- but this cannot be enforced at the type level.
  conjoined :: ((p ~ (->)) => q (a -> b) r) -> q (p a b) r -> q (p a b) r
  conjoined _ r = r
  {-# INLINE conjoined #-}

instance Conjoined (->) where
  distrib = fmap
  {-# INLINE distrib #-}
  conjoined l _ = l
  {-# INLINE conjoined #-}

{-
----------------------------------------------------------------------------
-- Indexable
----------------------------------------------------------------------------

-- | This class permits overloading of function application for things that
-- also admit a notion of a key or index.
class Conjoined p => Indexable i p where
  -- | Build a function from an 'indexed' function.
  indexed :: p a b -> i -> a -> b

instance Indexable i (->) where
  indexed = const
  {-# INLINE indexed #-}
-}

-----------------------------------------------------------------------------
-- Indexed Internals
-----------------------------------------------------------------------------


---------------------------------------------------------------------
-- 
---------------------------------------------------------------------

newtype Indexed p i a b = Indexed { runIndexed :: p (i, a) b }


instance Profunctor p => Profunctor (Indexed p i) where
    dimap f g (Indexed p) = Indexed (dimap (fmap f) g p)
    --dimap f g (Indexed p) = Indexed (dimap (second' f) g p)

instance Strong p => Strong (Indexed p i) where
    first' (Indexed p) = Indexed (lmap unassoc (first' p))



instance Choice p => Choice (Indexed p i) where
    left' (Indexed p) = Indexed $
        lmap (\(i, e) -> first (i,) e) (left' p)


instance Traversing p => Traversing (Indexed p i) where
    wander f (Indexed p) = Indexed $
         wander (\g (i, s) -> f (curry g i) s) p

instance Traversing1 p => Traversing1 (Indexed p i) where
    wander1 f (Indexed p) = Indexed $
         wander1 (\g (i, s) -> f (curry g i) s) p

type IndexedOptic p i s t a b = Indexed p i a b -> p s t
type IndexedOptic' p i s a = IndexedOptic p i s s a a


itraversing 
  :: Traversing p
  => (forall f. Applicative f => (i -> a -> f b) -> s -> f t)
  -> IndexedOptic p i s t a b
itraversing itr (Indexed pab) = wander (\f s -> itr (curry f) s) pab

ifoldMapOf :: IndexedOptic' (Forget r) i s a -> (i -> a -> r) -> s -> r
ifoldMapOf o f = runForget (o (Indexed (Forget (uncurry f))))

icompose 
  :: Profunctor p
  => (i -> j -> k)
  -> (Indexed p i u v -> p s t)
  -> (Indexed (Indexed p i) j a b -> Indexed p i u v)
  -> (Indexed p k a b -> p s t)
icompose ijk stuv uvab ab = icompose' ijk
    (stuv . Indexed)
    (runIndexed . uvab . Indexed . Indexed)
    (runIndexed ab)

icompose' 
  :: Profunctor p
  => (i -> j -> k)
  -> (p (i, u) v -> p s t)
  -> (p (i, (j, a)) b -> p (i, u) v)
  -> (p (k, a) b -> p s t)
icompose' ijk stuv uvab ab = stuv (uvab (lmap f ab))
  where
    f (i, (j, a)) = (ijk i j, a)

itraverseList :: Applicative f => (Int -> a -> f b) -> [a] -> f [b]
itraverseList f = go 0
  where
    go _ []     = pure []
    go i (a:as) = (:) <$> f i a <*> go (i + 1) as

itraversedList :: Traversing p => IndexedOptic p Int [a] [b] a b
itraversedList = itraversing itraverseList

-- | A function with access to a index. This constructor may be useful when you need to store
-- an 'Indexable' in a container to avoid @ImpredicativeTypes@.
--
-- @index :: Indexed i a b -> i -> a -> b@
newtype Indexed i a b = Indexed { runIndexed :: i -> a -> b }

instance Functor (Indexed i a) where
  fmap g (Indexed f) = Indexed $ \i a -> g (f i a)
  {-# INLINE fmap #-}

instance Apply (Indexed i a) where
  Indexed f <.> Indexed g = Indexed $ \i a -> f i a (g i a)
  {-# INLINE (<.>) #-}

instance Applicative (Indexed i a) where
  pure b = Indexed $ \_ _ -> b
  {-# INLINE pure #-}
  Indexed f <*> Indexed g = Indexed $ \i a -> f i a (g i a)
  {-# INLINE (<*>) #-}

instance Bind (Indexed i a) where
  Indexed f >>- k = Indexed $ \i a -> runIndexed (k (f i a)) i a
  {-# INLINE (>>-) #-}

instance Monad (Indexed i a) where
  return = pure
  {-# INLINE return #-}
  Indexed f >>= k = Indexed $ \i a -> runIndexed (k (f i a)) i a
  {-# INLINE (>>=) #-}

instance MonadFix (Indexed i a) where
  mfix f = Indexed $ \ i a -> let o = runIndexed (f o) i a in o
  {-# INLINE mfix #-}

instance Profunctor (Indexed i) where
  dimap ab cd ibc = Indexed $ \i -> cd . runIndexed ibc i . ab
  {-# INLINE dimap #-}
  lmap ab ibc = Indexed $ \i -> runIndexed ibc i . ab
  {-# INLINE lmap #-}
  rmap bc iab = Indexed $ \i -> bc . runIndexed iab i
  {-# INLINE rmap #-}
#ifndef SAFE
  ( .# ) ibc _ = coerce ibc
  {-# INLINE ( .# ) #-}
  ( #. ) _ = coerce'
  {-# INLINE ( #. ) #-}
#endif

instance Closed (Indexed i) where
  closed (Indexed iab) = Indexed $ \i xa x -> iab i (xa x)

instance Costrong (Indexed i) where
  unfirst (Indexed iadbd) = Indexed $ \i a -> let
      (b, d) = iadbd i (a, d)
    in b

instance Sieve (Indexed i) ((->) i) where
  sieve = flip . runIndexed
  {-# INLINE sieve #-}

instance Representable (Indexed i) where
  type Rep (Indexed i) = (->) i
  tabulate = Indexed . flip
  {-# INLINE tabulate #-}

instance Cosieve (Indexed i) ((,) i) where
  cosieve = uncurry . runIndexed
  {-# INLINE cosieve #-}

instance Corepresentable (Indexed i) where
  type Corep (Indexed i) = (,) i
  cotabulate = Indexed . curry
  {-# INLINE cotabulate #-}

instance Choice (Indexed i) where
  right' = right
  {-# INLINE right' #-}

instance Strong (Indexed i) where
  second' = second
  {-# INLINE second' #-}

instance Category (Indexed i) where
  id = Indexed (const id)
  {-# INLINE id #-}
  Indexed f . Indexed g = Indexed $ \i -> f i . g i
  {-# INLINE (.) #-}

instance Arrow (Indexed i) where
  arr f = Indexed (\_ -> f)
  {-# INLINE arr #-}
  first f = Indexed (Arrow.first . runIndexed f)
  {-# INLINE first #-}
  second f = Indexed (Arrow.second . runIndexed f)
  {-# INLINE second #-}
  Indexed f *** Indexed g = Indexed $ \i -> f i *** g i
  {-# INLINE (***) #-}
  Indexed f &&& Indexed g = Indexed $ \i -> f i &&& g i
  {-# INLINE (&&&) #-}

instance ArrowChoice (Indexed i) where
  left f = Indexed (left . runIndexed f)
  {-# INLINE left #-}
  right f = Indexed (right . runIndexed f)
  {-# INLINE right #-}
  Indexed f +++ Indexed g = Indexed $ \i -> f i +++ g i
  {-# INLINE (+++)  #-}
  Indexed f ||| Indexed g = Indexed $ \i -> f i ||| g i
  {-# INLINE (|||) #-}

instance ArrowApply (Indexed i) where
  app = Indexed $ \ i (f, b) -> runIndexed f i b
  {-# INLINE app #-}

instance ArrowLoop (Indexed i) where
  loop (Indexed f) = Indexed $ \i b -> let (c,d) = f i (b, d) in c
  {-# INLINE loop #-}

instance Conjoined (Indexed i) where
  distrib (Indexed iab) = Indexed $ \i fa -> iab i <$> fa
  {-# INLINE distrib #-}

instance i ~ j => Indexable i (Indexed j) where
  indexed = runIndexed
  {-# INLINE indexed #-}

------------------------------------------------------------------------------
-- Indexing
------------------------------------------------------------------------------

-- | 'Applicative' composition of @'Control.Monad.Trans.State.Lazy.State' 'Int'@ with a 'Functor', used
-- by 'Control.Lens.Indexed.indexed'.
newtype Indexing f a = Indexing { runIndexing :: Int -> (Int, f a) }

instance Functor f => Functor (Indexing f) where
  fmap f (Indexing m) = Indexing $ \i -> case m i of
    (j, x) -> (j, fmap f x)
  {-# INLINE fmap #-}

instance Apply f => Apply (Indexing f) where
  Indexing mf <.> Indexing ma = Indexing $ \i -> case mf i of
    (j, ff) -> case ma j of
       ~(k, fa) -> (k, ff <.> fa)
  {-# INLINE (<.>) #-}

instance Applicative f => Applicative (Indexing f) where
  pure x = Indexing $ \i -> (i, pure x)
  {-# INLINE pure #-}
  Indexing mf <*> Indexing ma = Indexing $ \i -> case mf i of
    (j, ff) -> case ma j of
       ~(k, fa) -> (k, ff <*> fa)
  {-# INLINE (<*>) #-}

instance Contravariant f => Contravariant (Indexing f) where
  contramap f (Indexing m) = Indexing $ \i -> case m i of
    (j, ff) -> (j, contramap f ff)
  {-# INLINE contramap #-}

instance Semi.Semigroup (f a) => Semi.Semigroup (Indexing f a) where
    Indexing mx <> Indexing my = Indexing $ \i -> case mx i of
      (j, x) -> case my j of
         ~(k, y) -> (k, x Semi.<> y)
    {-# INLINE (<>) #-}

-- |
--
-- >>> "cat" ^@.. (folded <> folded)
-- [(0,'c'),(1,'a'),(2,'t'),(0,'c'),(1,'a'),(2,'t')]
--
-- >>> "cat" ^@.. indexing (folded <> folded)
-- [(0,'c'),(1,'a'),(2,'t'),(3,'c'),(4,'a'),(5,'t')]
instance Monoid (f a) => Monoid (Indexing f a) where
    mempty = Indexing $ \i -> (i, mempty)
    {-# INLINE mempty #-}

    mappend (Indexing mx) (Indexing my) = Indexing $ \i -> case mx i of
      (j, x) -> case my j of
         ~(k, y) -> (k, mappend x y)
    {-# INLINE mappend #-}

-- | Transform a 'Control.Lens.Traversal.Traversal' into an 'Control.Lens.Traversal.IndexedTraversal' or
-- a 'Control.Lens.Fold.Fold' into an 'Control.Lens.Fold.IndexedFold', etc.
--
-- @
-- 'indexing' :: 'Control.Lens.Type.Traversal' s t a b -> 'Control.Lens.Type.IndexedTraversal' 'Int' s t a b
-- 'indexing' :: 'Control.Lens.Type.Prism' s t a b     -> 'Control.Lens.Type.IndexedTraversal' 'Int' s t a b
-- 'indexing' :: 'Control.Lens.Type.Lens' s t a b      -> 'Control.Lens.Type.IndexedLens' 'Int'  s t a b
-- 'indexing' :: 'Control.Lens.Type.Iso' s t a b       -> 'Control.Lens.Type.IndexedLens' 'Int' s t a b
-- 'indexing' :: 'Control.Lens.Type.Fold' s a          -> 'Control.Lens.Type.IndexedFold' 'Int' s a
-- 'indexing' :: 'Control.Lens.Type.View' s a        -> 'Control.Lens.Type.IndexedView' 'Int' s a
-- @
--
-- @'indexing' :: 'Indexable' 'Int' p => 'Control.Lens.Type.LensLike' ('Indexing' f) s t a b -> 'Control.Lens.Type.Over' p f s t a b@
indexing :: Indexable Int p => ((a -> Indexing f b) -> s -> Indexing f t) -> p a (f b) -> s -> f t
indexing l iafb s = snd $ runIndexing (l (\a -> Indexing (\i -> i `seq` (i + 1, indexed iafb i a))) s) 0
{-# INLINE indexing #-}

------------------------------------------------------------------------------
-- Indexing64
------------------------------------------------------------------------------

-- | 'Applicative' composition of @'Control.Monad.Trans.State.Lazy.State' 'Int64'@ with a 'Functor', used
-- by 'Control.Lens.Indexed.indexed64'.
newtype Indexing64 f a = Indexing64 { runIndexing64 :: Int64 -> (Int64, f a) }

instance Functor f => Functor (Indexing64 f) where
  fmap f (Indexing64 m) = Indexing64 $ \i -> case m i of
    (j, x) -> (j, fmap f x)
  {-# INLINE fmap #-}

instance Apply f => Apply (Indexing64 f) where
  Indexing64 mf <.> Indexing64 ma = Indexing64 $ \i -> case mf i of
    (j, ff) -> case ma j of
       ~(k, fa) -> (k, ff <.> fa)
  {-# INLINE (<.>) #-}

instance Applicative f => Applicative (Indexing64 f) where
  pure x = Indexing64 $ \i -> (i, pure x)
  {-# INLINE pure #-}
  Indexing64 mf <*> Indexing64 ma = Indexing64 $ \i -> case mf i of
    (j, ff) -> case ma j of
       ~(k, fa) -> (k, ff <*> fa)
  {-# INLINE (<*>) #-}

instance Contravariant f => Contravariant (Indexing64 f) where
  contramap f (Indexing64 m) = Indexing64 $ \i -> case m i of
    (j, ff) -> (j, contramap f ff)
  {-# INLINE contramap #-}

-- | Transform a 'Control.Lens.Traversal.Traversal' into an 'Control.Lens.Traversal.IndexedTraversal' or
-- a 'Control.Lens.Fold.Fold' into an 'Control.Lens.Fold.IndexedFold', etc.
--
-- This combinator is like 'indexing' except that it handles large traversals and folds gracefully.
--
-- @
-- 'indexing64' :: 'Control.Lens.Type.Traversal' s t a b -> 'Control.Lens.Type.IndexedTraversal' 'Int64' s t a b
-- 'indexing64' :: 'Control.Lens.Type.Prism' s t a b     -> 'Control.Lens.Type.IndexedTraversal' 'Int64' s t a b
-- 'indexing64' :: 'Control.Lens.Type.Lens' s t a b      -> 'Control.Lens.Type.IndexedLens' 'Int64' s t a b
-- 'indexing64' :: 'Control.Lens.Type.Iso' s t a b       -> 'Control.Lens.Type.IndexedLens' 'Int64' s t a b
-- 'indexing64' :: 'Control.Lens.Type.Fold' s a          -> 'Control.Lens.Type.IndexedFold' 'Int64' s a
-- 'indexing64' :: 'Control.Lens.Type.View' s a        -> 'Control.Lens.Type.IndexedView' 'Int64' s a
-- @
--
-- @'indexing64' :: 'Indexable' 'Int64' p => 'Control.Lens.Type.LensLike' ('Indexing64' f) s t a b -> 'Control.Lens.Type.Over' p f s t a b@
indexing64 :: Indexable Int64 p => ((a -> Indexing64 f b) -> s -> Indexing64 f t) -> p a (f b) -> s -> f t
indexing64 l iafb s = snd $ runIndexing64 (l (\a -> Indexing64 (\i -> i `seq` (i + 1, indexed iafb i a))) s) 0
{-# INLINE indexing64 #-}

-}
