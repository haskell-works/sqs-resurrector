{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Control.Lens
import           Control.Monad
import           Control.Monad.IO.Class
import           Control.Monad.Trans.AWS
import           Data.Monoid
import           Data.Text               (Text)
import qualified Data.Text               as Text
import qualified Data.Text.IO            as Text
import           Network.AWS.SQS         as SQS
import           System.IO

queueName = "allen-batched-attacks-dead-letter"

main :: IO ()
main = do
  log <- newLogger Debug stdout
  env <- newEnv Oregon Discover <&> envLogger .~ log

  let say = liftIO . Text.putStrLn

  runResourceT . runAWST env $ do
    url <- view gqursQueueURL <$> send (getQueueURL queueName)
    src <- view ldlsqrsQueueURLs <$>  send (listDeadLetterSourceQueues $ url)
    mss <- send (receiveMessage url & rmWaitTimeSeconds ?~ 20)

    -- this consumes ones into `m [Message]`
    -- how to produce a stream of messages within that `m`?
    forM_ (mss ^. rmrsMessages) $ \m -> do
            say "---------------------------------------------"
            say $ "Received Message: " <> Text.pack (show m)


    say "End."


