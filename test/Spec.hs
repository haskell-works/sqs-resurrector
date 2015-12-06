{-# LANGUAGE OverloadedStrings #-}

module Main where

import Options
import Options.Applicative
import Network.AWS.Types
import Test.Hspec

expected = Options Sydney "test-queue" Info

main :: IO ()
main = hspec $ do
  describe "Verify that Region can be parsed" $ do

    it "from region name" $ do
      let res = parseArgs ["-r", "Sydney", "-q", "test-queue", "-l", "info"]
      res `shouldParse` expected

    it "from region code" $ do
      let res = parseArgs ["-r", "ap-southeast-2", "-q", "test-queue", "-l", "info"]
      res `shouldParse` expected

parseArgs = execParserPure (prefs mempty) (info (helper <*> options) mempty)

shouldParse :: (Eq a, Show a) => ParserResult a -> a -> Expectation
shouldParse (Success a) b = a `shouldBe` b
shouldParse res a = expectationFailure $ "Expected: " ++ (show a) ++ "\nFound: " ++ (show res)
