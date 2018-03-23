{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedLists     #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module System.Etc.Extra.EnvMisspellTest where

import RIO
import qualified RIO.Vector as Vector

import Test.Tasty       (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertEqual, testCase)

import System.Etc

tests :: TestTree
tests =
  testGroup "env misspells"
  [
    testCase "it warns when misspell is present" $ do
      let
        input =
          mconcat
            [
              "{\"etc/entries\": {"
            , " \"greeting\": { \"etc/spec\": { \"env\": \"GREETING\" }}}}"
            ]

      (spec :: ConfigSpec ()) <- parseConfigSpec input

      let
        result =
          getEnvMisspellingsPure spec ["GREEING"]

      assertBool "expecting to get a warning for typo"
                 (not $ Vector.null result)

      assertEqual "expecting to get typo for key GREETING"
                  (EnvMisspell "GREEING" "GREETING")
                  (Vector.head result)
  ]
