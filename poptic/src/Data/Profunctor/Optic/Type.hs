{-# LANGUAGE UndecidableSuperClasses, TypeOperators , GADTs, DataKinds, KindSignatures, TypeFamilies #-}

{-# LANGUAGE ExistentialQuantification #-}

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TupleSections #-}

module Data.Profunctor.Optic.Type (
    module Data.Profunctor.Optic.Type
  , module Data.Profunctor.Optic.Type.Class
  , module VL
) where

import Data.Semigroup (First, Last)
import Data.Profunctor.Optic.Type.Class 
import Data.Profunctor.Optic.Prelude
import Data.Either.Validation (Validation(..))

import qualified Data.Profunctor.Optic.Type.VL as VL
import           Control.Applicative
import           Control.Monad
import           Control.Monad.Fix
import           Data.Bifoldable
import           Data.Bifunctor
import           Data.Bitraversable
import           Data.Coerce
import           Data.Data
import           GHC.Generics

import Data.Semiring

type Optic p s t a b = p a b -> p s t

type Optic' p s a = Optic p s s a a

type LensLike f s t a b = (a -> f b) -> s -> f t

type LensLike' f s a = LensLike f s s a a

-- | A witness that @(a ~ s, b ~ t)@.
type Equality s t a b = forall p. Optic p s t a b 

type Equality' s a = Equality s s a a

type Iso s t a b = forall p. Profunctor p => Optic p s t a b

type Iso' s a = Iso s s a a

type Lens s t a b = forall p. Strong p => Optic p s t a b

type Lens' s a = Lens s s a a

type Prism s t a b = forall p. Choice p => Optic p s t a b

type Prism' s a = Prism s s a a

type Traversal s t a b = forall p. Traversing p => Optic p s t a b

type Traversal' s a = Traversal s s a a

-- A 'Traversal0' extracts at most one result, with no monoidal interactions.
type Traversal0 s t a b = forall p. (Strong p, Choice p) => Optic p s t a b

type Traversal0' s a = Traversal0 s s a a

-- A 'Traversal1' extracts at least one result.
type Traversal1 s t a b = forall p. Traversing1 p => Optic p s t a b

type Traversal1' s a = Traversal1 s s a a

-- Folds are closed, corepresentable profunctors.
type Fold s a = forall p. (OutPhantom p, Traversing p) => Optic' p s a

-- A 'Fold0' extracts at most one result.
type Fold0 s a = forall p. (OutPhantom p, Strong p, Choice p) => Optic' p s a

-- A 'Fold1' extracts at least one result.
type Fold1 s a = forall p. (OutPhantom p, Traversing1 p) => Optic' p s a 

type Grate s t a b = forall p. Closed p => Optic p s t a b

type Grate' s a = Grate s s a a

type Over s t a b = forall p. Mapping p => Optic p s t a b

type Over' s a = Over s s a a

type PrimView s t a b = forall p. OutPhantom p => Optic p s t a b

type PrimView' s a = PrimView s s a a

-- A 'View' extracts exactly one result.
type View s a = forall p. (OutPhantom p, Strong p) => Optic' p s a

type PrimReview s t a b = forall p. InPhantom p => Optic p s t a b

type PrimReview' t b = PrimReview t t b b

type Review t b = forall p. (InPhantom p, Choice p) => Optic' p t b

type ATraversal f s t a b = Optic (Star f) s t a b

type AFold r s a = Optic' (Star (Const r)) s a

type AFold0 r s a = Optic' (Star (Pre r)) s a

--type AFold r s a = Optic' (Forget r) s a

--type AFold0 r s a = Optic' (Forget (Maybe r)) s a

type ACofold r t b = Optic' (Costar (Const r)) t b

--type AView s a = forall r. AFold r s a
type AView s a = AFold a s a

--type AReview t b = forall r. ACofold r t b
type AReview t b = ACofold b t b

type Matched r = Star (Either r)

type Matching e s t a b = Optic (Matched e) s t a b

--type Validated e = Star (Validation e)

type Validating e s t a b = Optic (Validated e) s t a b

type Validating' e s a = Optic' (Validated e) s a

--type AFold0 r = Star (Pre r)
-- AFold r s a = Optic (Star (Const r)) s a
-- AFold s a = forall r. AFold r s a
--type AffineTraversed r = 

-- Retrieve either 0 or 1 subobjects, with no monoidal interactions.
--type Previewing s a = Optic' (Previewed a) s a

{-
newtype Affine f a b = Affine { runAffine :: a -> f b }

instance Alternative f => Choice (Affine f) where

  left' (Affine f) = Affine $ either (fmap Left . f) (const empty) 

foldMapOf' (traverse' . traverse1') id $ [(0 :: Int) :| [], 0 :| []]
[] :| [[] :: [Int]]


foldMapOf'' @(Valid Int) traverse1' id $ 2 :| [2,3 :: Int]

foldMapOf'' @(Valid Int) _Just Nothing

foldMapOf' (traverse1' . traverse') id $ [] :| [[] :: [Int]]
[[1,2,3 :: Int]]

foldMapOf' traverse' id [2,2,3 :: Int]
foldMapOf' traverse1' id $ 2 :| [2,3 :: Int]

λ> foldMapOf' (traverse' . _Just) Mul [Just True , Nothing]
Nothing

λ> foldMapOf' (traverse') id [Nothing :: Maybe Int]
Nothing
λ> foldMapOf' (traverse' . _Just) id [Nothing :: Maybe Int]
0
λ> foldMapOf' (traverse' . _Just) id ([] :: [Maybe Int])
1

foldMapOf' (traverse' . _Just) id [Nothing :: Maybe Int, Just 3]




-}


newtype Forget' r a b = Forget' { runForget' :: a -> r }

instance Profunctor (Forget' r) where
  dimap f _ (Forget' k) = Forget' (k . f)
  {-# INLINE dimap #-}
  lmap f (Forget' k) = Forget' (k . f)
  {-# INLINE lmap #-}
  rmap _ (Forget' k) = Forget' k
  {-# INLINE rmap #-}

instance Functor (Forget' r a) where
  fmap _ (Forget' k) = Forget' k
  {-# INLINE fmap #-}


instance OutPhantom (Forget' f) where
  ocoerce (Forget' f) = (Forget' f)

instance Strong (Forget' r) where
  first' (Forget' k) = Forget' (k . fst)
  {-# INLINE first' #-}
  second' (Forget' k) = Forget' (k . snd)
  {-# INLINE second' #-}

instance (Monoid r, Semiring r) => Choice (Forget' r) where
  left' (Forget' k) = Forget' (either k (const one))
  {-# INLINE left' #-}
  right' (Forget' k) = Forget' (either (const one) k)
  {-# INLINE right' #-}

--instance (Semiring r) => Traversing1 (Forget' r) where
  --traverse' (Forget h) = Forget (foldMap1 $ Mul . h)
  --wander1 f (Forget h) = Forget (getConst . f (Const . h))

instance (Monoid r, Semiring r) => Traversing (Forget' r) where
  traverse' (Forget' h) = Forget' (foldMap' h)
  --wander f (Forget h) = Forget (getMul . getConst . f (Const . Mul . h))
  --wander f (Forget h) = Forget (getConst . f (Const . h))


{-
instance Foldable (Forget r a) where
  foldMap _ _ = mempty
  {-# INLINE foldMap #-}

instance Traversable (Forget r a) where
  traverse _ (Forget k) = pure (Forget k)
  {-# INLINE traverse #-}
-}

---------------------------------------------------------------------
-- 'Validated'
---------------------------------------------------------------------


--Validated r a b = Star (Validation r) a b = a -> Validation r b

--TODO would be nicer to have: Validated r a b = a -> Validation r b
newtype Validated r a b = Validated { runValidated :: a -> Validation r b }

instance Profunctor (Validated r) where
    dimap f g (Validated p) = Validated (fmap g . p . f)

instance Monoid r => Choice (Validated r) where
    --right' (Validated p) = dimap e2v v2e $ Validated (unassoc . fmap p) -- code too stable
    --left' (Validated f) = Validated $ either (fmap Left . f) (pure . Right) -- code too stable
    left' (Validated f) = Validated $ either (fmap Left . f) (const empty)

instance Strong (Validated r) where
    first' (Validated p) = Validated (\(a,c) -> fmap (,c) (p a))

instance Monoid r => Traversing (Validated r) where

    traverse' (Validated h) = Validated (traverse h)

    wander f (Validated h) = Validated (f h)

instance Semigroup r => Traversing1 (Validated r) where

    traverse1' (Validated h) = Validated (traverse1 h)

    wander1 f (Validated h) = Validated (f h)



---------------------------------------------------------------------
-- 'Alt'
---------------------------------------------------------------------


newtype Alt f a = Alt { runAlt :: f a } deriving (Eq, Ord, Show, Data, Generic, Generic1)

--instance Functor (Alt a) where fmap f (Alt p) = Alt p

instance Functor f => Functor (Alt f) where fmap f (Alt p) = Alt $ fmap f p

--instance Contravariant (Alt a) where contramap f (Alt p) = Alt p


instance Alternative f => Semigroup (Alt f a) where
  Alt a <> Alt b = Alt (a <|> b)

instance Alternative f => Monoid (Alt f a) where 
  mempty = Alt empty



---------------------------------------------------------------------
-- 'Pre'
---------------------------------------------------------------------

-- | 'Pre' is 'Maybe' with a phantom type variable.
--
-- 
-- Star (Pre r) a b has Strong. Also Choice & Traversing when r is a Semigroup.
-- idea: 

newtype Pre a b = Pre { runPre :: Maybe a } deriving (Eq, Ord, Show, Data, Generic, Generic1)

instance Functor (Pre a) where fmap f (Pre p) = Pre p

instance Contravariant (Pre a) where contramap f (Pre p) = Pre p


instance Semigroup a => Apply (Pre a) where

    (Pre pbc) <.> (Pre pb) = Pre $ pbc <> pb


instance Monoid a => Applicative (Pre a) where

    pure _ = Pre mempty

    (<*>) = (<.>)

{-

instance Semigroup (Pre a b) where

  Pre Nothing <> x = x

  Pre a <> _ = Pre a


instance Monoid (Pre a b) where

  mempty = Pre Nothing


instance Alt (Pre a) where

    (<!>) = (<>)


instance Monoid a => Alternative (Pre a) where

    empty = mempty

    (<|>) = (<>)

-}

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

{-

-- | A 'Monoid' for a 'Contravariant' 'Applicative'.
newtype AFold f a = AFold { getAFold :: f a }

instance (Contravariant f, Applicative f) => Semigroup (AFold f a) where
  AFold fr <> AFold fs = AFold (fr *> fs)
  {-# INLINE (<>) #-}

instance (Contravariant f, Applicative f) => Monoid (AFold f a) where
  mempty = AFold noEffect
  {-# INLINE mempty #-}
  AFold fr `mappend` AFold fs = AFold (fr *> fs)
  {-# INLINE mappend #-}
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

---------------------------------------------------------------------
-- 'Zipped'
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


