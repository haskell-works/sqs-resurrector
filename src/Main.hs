{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Data.List
import           Data.Maybe
import           Control.Lens
import           Control.Monad
import           Control.Monad.Loops
import           Control.Monad.IO.Class
import           Control.Monad.Trans.AWS
import           Data.Monoid
import           Data.Text               (Text)
import qualified Data.Text               as Text
import qualified Data.Text.IO            as Text
import           Network.AWS.SQS         as SQS
import           System.IO

fromQueueName = "nkbt-batched-attacks-es-dead-letter"

type MsgBody    = Text
type MsgReceipt = Text

main :: IO ()
main = do
  log <- newLogger Debug stdout
  env <- newEnv Oregon Discover <&> envLogger .~ log

  let say = liftIO . Text.putStrLn

  runResourceT . runAWST env $ do
   from <- view gqursQueueURL    <$> send (getQueueURL fromQueueName)
   to   <- view ldlsqrsQueueURLs <$> send (listDeadLetterSourceQueues from)

   iterateWhile (not . null) (copyMessages from to)

   say "End."

copyMessages from to = do
  msgs <- consume from
  deliver to msgs
  return msgs

payloads :: [Message] -> [(MsgBody, MsgReceipt)]
payloads msgs =
 let pair msg = (,) <$> (view mBody msg) <*> (view mReceiptHandle msg)
 in concat $ (maybeToList . pair) <$> msgs

deliver queues msgs =
  let letters = [(q, b, r) | q <- queues, (b, r) <- payloads msgs]
  in forM_ letters $ \(q, b, r) -> do
       --void $ send (sendMessage d b)
       (liftIO . Text.putStrLn) $ "---------------------"
       (liftIO . Text.putStrLn) $ r

consume url = do
  batch <- send (receiveMessage url & rmWaitTimeSeconds ?~ 5)
  return $ batch ^. rmrsMessages
