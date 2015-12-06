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
import           Options.Applicative

type MsgBody    = Text
type MsgReceipt = Text

data Options   = Options { region :: Region, deadLetterQueue :: Text } deriving Show
defaultOptions = Options { region = Oregon,  deadLetterQueue = "" }

textOption = option $ Text.pack <$> str

options :: Parser Options
options = Options
  <$> (option auto (  long "region"
                   <> short 'r'
                   <> metavar "REGION"
                   <> showDefault
                   <> value Oregon
                   <> help "AWS Region Name"))
  <*> (textOption (  long "queue"
                  <> short 'q'
                  <> metavar "QUEUE_NAME"
                  <> help "Dead Letter Queue"))

parseOptions =
  info (helper <*> options)
    (  fullDesc
    <> progDesc "Resurrects messages from a given dead letter queue"
    <> header "SQS Deal Letter Queue messages resurrector"
    )

main :: IO ()
main = do
  opt <- execParser parseOptions
  log <- newLogger Debug stdout
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
