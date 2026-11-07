{-# LANGUAGE ExplicitLevelImports #-}

-- | Explicit level imports (GHC 9.14 and later): the splice runs only
-- template-haskell's code, so the compile waits for no per-module
-- dependency's library.
module Example.EliNone (none) where

import splice Language.Haskell.TH (litE, stringL)

none :: String
none = $(litE (stringL "none"))
