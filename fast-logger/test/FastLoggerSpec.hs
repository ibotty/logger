{-# LANGUAGE OverloadedStrings, BangPatterns #-}

module FastLoggerSpec where

import Control.Applicative ((<$>))
import Control.Exception (bracket, finally)
import Control.Monad (when)
import qualified Data.ByteString.Char8 as BS
import Data.Monoid ((<>))
import System.Directory (doesFileExist, removeFile)
import System.Log.FastLogger
import Test.Hspec

spec :: Spec
spec = describe "pushLogMsg" $ do
    it "is safe for a large message" $ safeForLarge [
        100
      , 1000
      , 10000
      , 100000
      , 1000000
      ]
    it "logs all messages" logAllMsgs

nullLogger :: IO LoggerSet
nullLogger = newLoggerSet 4096 (Just "/dev/null")

safeForLarge :: [Int] -> IO ()
safeForLarge ns = mapM_ safeForLarge' ns

safeForLarge' :: Int -> IO ()
safeForLarge' n = bracket nullLogger rmLoggerSet $ \lgrset -> do
    let xs = toLogStr $ BS.pack $ replicate (abs n) 'x'
        lf = "x"
    pushLogStr lgrset $ xs <> lf
    flushLogStr lgrset

logAllMsgs :: IO ()
logAllMsgs = logAll "LICENSE" `finally` cleanup tmpfile
  where
    tmpfile = "test/temp"
    cleanup file = do
        exist <- doesFileExist file
        when exist $ removeFile file
    logAll file = do
        cleanup tmpfile
        lgrset <- newLoggerSet 512 (Just tmpfile)
        src <- BS.readFile file
        let bs = (<> "\n") . toLogStr <$> BS.lines src
        mapM_ (pushLogStr lgrset) bs
        flushLogStr lgrset
        rmLoggerSet lgrset
        dst <- BS.readFile tmpfile
        dst `shouldBe` src
