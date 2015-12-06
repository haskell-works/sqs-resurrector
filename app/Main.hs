module Main where

import           Control.Lens
import           Control.Monad.Trans.AWS
import           System.IO
import           Options
import           Resurrector

main :: IO ()
main = do
  opt <- parseOptions
  log <- newLogger (logLevel opt) stdout
  env <- newEnv (region opt) Discover <&> envLogger .~ log

  runResurrector env (deadLetterQueue opt)
