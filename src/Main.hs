{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Data.Maybe
import           Control.Lens
import           Control.Monad
import           Control.Monad.Loops
import           Control.Monad.IO.Class
import           Control.Monad.Trans.AWS
import           Data.Text               (Text)
import qualified Data.Text               as Text
import qualified Data.Text.IO            as Text
import           Network.AWS.SQS         as SQS
import           System.IO
import           Options

main :: IO ()
main = do
  opt <- parseOptions
  log <- newLogger (logLevel opt) stdout
  env <- newEnv (region opt) Discover <&> envLogger .~ log

  let say = liftIO . Text.putStrLn

  runResourceT . runAWST env $ do
    from <- view gqursQueueURL    <$> send (getQueueURL $ deadLetterQueue opt)
    tos  <- view ldlsqrsQueueURLs <$> send (listDeadLetterSourceQueues from)

    iterateWhile (not . null) (moveMessages from tos)

    say "End."

moveMessages from tos = do
  msgs <- consume from
  deliverAndAck from tos msgs
  return msgs
  where

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
