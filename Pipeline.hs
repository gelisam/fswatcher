-- poor man's streaming library, using threads communicating with MVars
module Pipeline where

import Prelude hiding (id, (.))

import Control.Category
import Control.Concurrent
import Control.Concurrent.MVar
import Control.Monad


newtype Pipeline a b = Pipeline {
  -- launches zero or more threads, forming a pipeline which takes from
  -- the 'MVar a' and puts to the 'MVar b'.
  runPipeline :: MVar a -> IO ([ThreadId], MVar b)
}

instance Category Pipeline where
    id = Pipeline $ \inputMVar -> return ([], inputMVar)
    s2 . s1 = Pipeline $ \inputMVar -> do
      (threads1, intermediateMVar) <- runPipeline s1 inputMVar
      (threads2, outputMVar) <- runPipeline s2 intermediateMVar
      return (threads1 ++ threads2, outputMVar)


mkPipeline :: (a -> IO b) -> Pipeline a b
mkPipeline f = Pipeline $ \inputMVar -> do
    outputMVar <- newEmptyMVar
    threadId <- forkIO $ forever $ do
      x <- takeMVar inputMVar
      y <- f x
      putMVar outputMVar y
    return ([threadId], outputMVar)
