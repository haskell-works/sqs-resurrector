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
import           Resurrector

main :: IO ()
main = do
  opt <- parseOptions
  log <- newLogger (logLevel opt) stdout
  env <- newEnv (region opt) Discover <&> envLogger .~ log

  runResurrector env (deadLetterQueue opt)
