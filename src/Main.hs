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
   tos  <- view ldlsqrsQueueURLs <$> send (listDeadLetterSourceQueues from)

   iterateWhile (not . null) (moveMessages from tos)

   say "End."

moveMessages from tos = do
  msgs <- consume from
  deliverAndAck from tos msgs
  return msgs

payloads :: [Message] -> [(MsgBody, MsgReceipt)]
payloads msgs =
 let pair msg = (,) <$> (view mBody msg) <*> (view mReceiptHandle msg)
 in concat $ (maybeToList . pair) <$> msgs

deliverAndAck from tos msgs =
  let letters = [(to, body, rcpt) | to <- tos, (body, rcpt) <- payloads msgs]
  in forM_ letters $ \(to, body, rcpt) -> do
       void $ send (sendMessage to body)
       void $ send (deleteMessage from rcpt)

consume url = do
  batch <- send (receiveMessage url & rmWaitTimeSeconds ?~ 5)
  return $ batch ^. rmrsMessages
