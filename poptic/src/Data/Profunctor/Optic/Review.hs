module Data.Profunctor.Optic.Review
  (
  -- * AReview
    Review
  , AReview
  , PrimReview
  , unto
  , un
  , relike
  , re
  , review, reviews
  --, reuse, reuses
  , (#)
  , retagged
  , reviewBoth
  , reviewEither
  ) where

import Control.Monad.Reader as Reader

import Data.Profunctor.Optic.View
import Data.Profunctor.Optic.Prelude
import Data.Profunctor.Optic.Type 
import Data.Profunctor.Optic.Operator

------------------------------------------------------------------------------
-- Review
------------------------------------------------------------------------------

-- | Turn a 'Prism' or 'Iso' around to build a 'View'.
--
-- If you have an 'Iso', 'from' is a more powerful version of this function
-- that will return an 'Iso' instead of a mere 'View'.
--
-- >>> 5 ^.re _Left
-- Left 5
--
-- >>> 6 ^.re (_Left.unto succ)
-- Left 7
--
-- @
-- 'review'  ≡ 'view'  '.' 're'
-- 'reviews' ≡ 'views' '.' 're'
-- 'reuse'   ≡ 'use'   '.' 're'
-- 'reuses'  ≡ 'uses'  '.' 're'
-- @
--
-- @
-- 're' :: 'Prism' s t a b -> 'View' b t
-- 're' :: 'Iso' s t a b   -> 'View' b t
-- @
--
re :: Optic (Re p a b) s t a b -> Optic p b a t s
re o = (between runRe Re) o id
{-# INLINE re #-}


-- | Convert a function into a 'Review'.
--  Analagous to 'to' for 'View'.
--
-- @
-- 'unto' :: (b -> t) -> 'PrimReview' s t a b
-- @
--
-- @
-- 'unto' = 'un' . 'to'
-- @
--
unto :: (b -> t) -> PrimReview s t a b 
unto f = icoerce . dimap id f


-- | Turn a 'View' around to get a 'Review'
--
-- @
-- 'un' = 'unto' . 'view'
-- 'unto' = 'un' . 'to'
-- @
--
-- >>> un (to length) # [1,2,3]
-- 3
un :: AView s a -> PrimReview b a t s
un = unto . (`views` id)


-- | Build a constant-valued (index-preserving) 'PrimReview' from an arbitrary value.
--
-- @
-- 'relike' a '.' 'relike' b ≡ 'relike' a
-- 'relike' a '#' b ≡ a
-- 'relike' a '#' b ≡ 'unto' ('const' a) '#' b
-- @
--
relike :: t -> PrimReview s t a b
relike t = unto (const t)


-- | TODO: Document
--
cloneReview :: AReview t b -> PrimReview' t b
cloneReview = unto . review


-- | TODO: Document
--
reviewBoth :: AReview t1 b -> AReview t2 b -> PrimReview s (t1, t2) a b
reviewBoth l r = unto (review l &&& review r)


-- | TODO: Document
--
reviewEither :: AReview t b1 -> AReview t b2 -> PrimReview s t a (Either b1 b2)
reviewEither l r = unto (review l ||| review r)

---------------------------------------------------------------------
-- Primitive Operators
---------------------------------------------------------------------

-- | This can be used to turn an 'Iso' or 'Prism' around and 'view' a value (or the current environment) through it the other way,
-- applying a function.
--
-- @
-- 'reviews' ≡ 'views' '.' 're'
-- 'reviews' ('unto' f) g ≡ g '.' f
-- @
--
-- >>> reviews _Left isRight "mustard"
-- False
--
-- >>> reviews (unto succ) (*2) 3
-- 8
--
-- Usually this function is used in the @(->)@ 'Monad' with a 'Prism' or 'Iso', in which case it may be useful to think of
-- it as having one of these more restricted type signatures:
--
-- @
-- 'reviews' :: 'Iso'' s a   -> (s -> r) -> a -> r
-- 'reviews' :: 'Prism'' s a -> (s -> r) -> a -> r
-- @
--
-- However, when working with a 'Monad' transformer stack, it is sometimes useful to be able to 'review' the current environment, in which case
-- it may be beneficial to think of it as having one of these slightly more liberal type signatures:
--
-- @
-- 'reviews' :: 'MonadReader' a m => 'Iso'' s a   -> (s -> r) -> m r
-- 'reviews' :: 'MonadReader' a m => 'Prism'' s a -> (s -> r) -> m r
-- @
-- ^ @
-- 'reviews o f ≡ unfoldMapOf o f'
-- @
--
reviews :: MonadReader r m => ACofold r t b -> (r -> b) -> m t
reviews o f = Reader.asks $ unfoldMapOf o f 
{-# INLINE reviews #-}

---------------------------------------------------------------------
-- Derived Operators
---------------------------------------------------------------------

infixr 8 #

-- | An infix alias for 'review'. Dual to '^.'.
--
-- @
-- 'unto' f # x ≡ f x
-- l # x ≡ x '^.' 're' l
-- @
--
-- This is commonly used when using a 'Prism' as a smart constructor.
--
-- >>> _Left # 4
-- Left 4
--
-- But it can be used for any 'Prism'
--
-- >>> base 16 # 123
-- "7b"
--
-- @
-- (#) :: 'Iso''      s a -> a -> s
-- (#) :: 'Prism''    s a -> a -> s
-- (#) :: 'Review'    s a -> a -> s
-- (#) :: 'Equality'' s a -> a -> s
-- @
--
(#) :: AReview t b -> b -> t
o # b = review o b
{-# INLINE ( # ) #-}


-- ^ @
-- 'review o ≡ unfoldMapOf o id'
-- @
--
review :: MonadReader b m => AReview t b -> m t
review = (`reviews` id) 
{-# INLINE review #-}
