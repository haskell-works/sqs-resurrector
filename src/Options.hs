module Options (
  Options(..),
  options,
  parseOptions
)
where

import           Text.Read
import           Data.Text (Text)
import qualified Data.Text as Text
import           Control.Monad.Trans.AWS
import           Network.AWS.Data.Text (fromText, FromText(..))
import           Network.AWS.Types
import           Options.Applicative

data Options = Options { region :: Region
                       , deadLetterQueue :: Text
                       , logLevel :: LogLevel
                       } deriving (Show, Eq)

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

optionsParser :: ParserInfo Options
optionsParser = info (helper <*> options)
  (  fullDesc
  <> progDesc "Resurrects messages from a given dead letter queue"
  <> header "SQS Deal Letter Queue messages resurrector"
  )

parseOptions :: IO Options
parseOptions = execParser optionsParser

--------------------------- HELPERS ------------------------------

fromTextOption :: (FromText a) => Mod OptionFields a -> Parser a
fromTextOption = option $ eitherReader (fromText . Text.pack)

readOrFromTextOption :: (Read a, FromText a) => Mod OptionFields a -> Parser a
readOrFromTextOption =
  let fromStr s = readEither s <|> fromText (Text.pack s)
  in option $ eitherReader fromStr
