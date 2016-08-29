module Resurrector (
   QueueName,
   runResurrector
)
where

import Data.Maybe
import Control.Lens
import Control.Monad
import Control.Monad.Loops
import Control.Monad.Trans.AWS
import Data.Text (Text)
import Network.AWS.SQS

type QueueName = Text

runResurrector :: (HasEnv e) => e -> QueueName -> IO ()
runResurrector env deadLetterQueue =
  runResourceT . runAWST env $ do
    from <- view gqursQueueURL    <$> send (getQueueURL deadLetterQueue)
    tos  <- view ldlsqrsQueueURLs <$> send (listDeadLetterSourceQueues from)

    iterateWhile (not . null) (moveMessages from tos)
    return ()

moveMessages from tos = do
  msgs <- consume from
  deliverAndAck from tos msgs
  return msgs
  where

  payloads msgs =
    let pair msg = (,) <$> view mBody msg <*> view mReceiptHandle msg
    in concat $ (maybeToList . pair) <$> msgs

  deliverAndAck from tos msgs =
    let letters = [(to, body, rcpt) | to <- tos, (body, rcpt) <- payloads msgs]
    in forM_ letters $ \(to, body, rcpt) -> do
         void $ send (sendMessage to body)
         void $ send (deleteMessage from rcpt)

  consume url = do
    batch <- send (receiveMessage url & rmWaitTimeSeconds ?~ 5 & rmMaxNumberOfMessages ?~ 10)
    return $ batch ^. rmrsMessages
