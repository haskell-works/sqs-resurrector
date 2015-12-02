{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Data.List
import           Data.Maybe
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

queueName = "nkbt-batched-attacks-es-dead-letter"

main :: IO ()
main = do
  log <- newLogger Debug stdout
  env <- newEnv Oregon Discover <&> envLogger .~ log

  let say = liftIO . Text.putStrLn

  runResourceT . runAWST env $ do
    ddltrq <- view gqursQueueURL <$> send (getQueueURL queueName)
    queues <- view ldlsqrsQueueURLs <$> send (listDeadLetterSourceQueues ddltrq)
    mss <- consume ddltrq
    forM_ mss (deliver queues)

    say "End."

deliver dsts msg =
  let bs = (,) <$> (view mBody msg) <*> (view mReceiptHandle msg)
      ps = [(d, b, r) | d <- dsts, (b, r) <- maybeToList bs]
  in forM_ ps $ \(d, b, r) -> do
       --void $ send (sendMessage d b)
       (liftIO . Text.putStrLn) $ "---------------------"
       (liftIO . Text.putStrLn) $ r

consume url = do
  batch <- send (receiveMessage url & rmWaitTimeSeconds ?~ 20)
  return $ batch ^. rmrsMessages
