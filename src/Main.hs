{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Text.Read
import           Data.List
import           Data.Maybe
import           Data.Char (toLower)
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
import           Network.AWS.Data.Text (fromText, FromText(..))
import           System.IO
import           Options.Applicative

type MsgBody    = Text
type MsgReceipt = Text

data Options   = Options { region :: Region
                         , deadLetterQueue :: Text
                         , logLevel :: LogLevel
                         } deriving Show

fromTextOption :: (FromText a) => Mod OptionFields a -> Parser a
fromTextOption = option $ eitherReader (fromText . Text.pack)

readOrFromTextOption :: (Read a, FromText a) => Mod OptionFields a -> Parser a
readOrFromTextOption =
  let fromStr s = readEither s <|> fromText (Text.pack s)
  in option $ eitherReader fromStr

options :: Parser Options
options = Options
  <$> (readOrFromTextOption
         (  long "region"
         <> short 'r'
         <> showDefault <> value Oregon
         <> metavar "REGION"
         <> help "AWS Region Name"))

  <*> (fromTextOption
         (  long "queue"
         <> short 'q'
         <> metavar "QUEUE_NAME"
         <> help "Dead Letter Queue"))

  <*> (fromTextOption
         (  long "log"
         <> short 'l'
         <> metavar "LOG_LEVEL"
         <> showDefault <> value Error
         <> help "Log level"
         <> hidden))

optionsParser = info (helper <*> options)
  (  fullDesc
  <> progDesc "Resurrects messages from a given dead letter queue"
  <> header "SQS Deal Letter Queue messages resurrector"
  )

main :: IO ()
main = do
  opt <- execParser optionsParser
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
