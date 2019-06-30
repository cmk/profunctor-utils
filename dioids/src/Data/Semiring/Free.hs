{-# Language ExistentialQuantification #-}
module Data.Semiring.Free where

import Data.Semiring
--import Data.Functor.Kan.Ran
--import Data.Functor.Day
import Control.Applicative
import Control.Monad
import Data.Monoid
import GHC.Generics

--import Control.Selective.Free
--import Control.Alternative.Free.Final

import Numeric.Natural (Natural)


-- http://hackage.haskell.org/package/free-5.1/docs/Control-Applicative-Trans-Free.html#t:Alt
-- http://hackage.haskell.org/package/free-5.1/docs/Control-Alternative-Free.html
-- adding `one` gives us an affine free structure
--data Forest a = Forest [Tree a ]
--data Tree a = Leaf | Node a (Forest a)
--data Forest a = Forest [Leaf | Node a (Forest a) ]

{-

Given an object A, if the initial algebra for the endofunctor 1 + (I + A >< _) * _ exists, 
then the free semiring over A has the following carrier:

µX. 1 + (I + A >< X) * X = µX. List(I + A >< X)
-}

{-
-- Free structure for semirings.
-- | Non-empty, possibly infinite, multi-way trees; also known as /rose trees/.
data Tree a = Node {
        rootLabel :: a,         -- ^ label value
        subForest :: Forest a   -- ^ zero or more child trees
    }

type Forest a = [Tree a]
-}

-- see section 3.3 Generalised Free unital semiring
--type FreeUnital a =  FreeT (XNor a) [] a 

--newtype FreeT f m a = FreeT { runFreeT :: m (FreeF f a (FreeT f m a)) }

-- | The base functor for a free monad.
--data FreeF f a b = Pure a | Free (f b)

--data Free◦ f x = Free◦ {unFree◦ :: [FFree◦ f x ]}
--data FFree◦ f x = Pure◦ x | Con◦ (f (Free◦ f x ))

data Forest a = Forest [Tree a]
data Tree a = Leaf | Node a (Forest a)

instance Semigroup (Forest a) where

  (Forest xs) <> (Forest ys) = Forest (xs ++ ys)


instance Monoid (Forest a) where

  mempty = Forest [ ]


instance Semiring (Forest a) where

  (Forest xs) >< (Forest ys) = Forest (concatMap g xs)
    where g Leaf = ys
          g (Node a n) =[Node a (n >< (Forest ys))]

  fromBoolean = fromBooleanDef $ Forest [Leaf]

inj :: a -> Forest a
inj a = Forest [Node a one]



univ :: (Monoid r, Semiring r) => (a -> r) -> Forest a -> r
univ h (Forest xs) = foldr (<>) mempty (map univT xs)
  where univT Leaf = one
        univT (Node a ts) = h a >< univ h ts


{-
-- 2 * 0 + 1 + 2 * (1 + 2 * 0) == 3
ex0 :: Forest Int
ex0 = Forest [tree1, tree2, tree3] 
  where tree1 = Node 2 $ Forest []
        tree2 = Leaf
        tree3 = Node 2 $ Forest [Leaf, Node 2 $ Forest []]

-- 2 + 3 + 6 = 11
ex1 :: Forest Int
ex1 = Forest [Node 1 $ inj 2, Node 1 $ inj 3, Node 2 $ inj 3]
-}