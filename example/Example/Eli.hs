{-# LANGUAGE ExplicitLevelImports #-}

-- | Explicit level imports (GHC 9.14 and later): the splice runs th's code,
-- which this module imports at the splice level, so the compile waits for
-- th's library and no other per-module dependency's.
module Example.Eli (hello) where

import splice Example.TH (makeGreeter)

$(makeGreeter "hello")
