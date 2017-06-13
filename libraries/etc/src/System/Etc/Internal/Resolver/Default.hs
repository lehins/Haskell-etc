{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module System.Etc.Internal.Resolver.Default (resolveDefault) where

import Protolude

import qualified Data.Aeson          as JSON
import qualified Data.HashMap.Strict as HashMap
import qualified Data.Set            as Set

import qualified System.Etc.Internal.Spec.Types as Spec
import           System.Etc.Internal.Types

toDefaultConfigValue :: JSON.Value -> ConfigValue
toDefaultConfigValue =
  ConfigValue . Set.singleton . Default

buildDefaultResolver :: Spec.ConfigSpec cmd -> Maybe ConfigValue
buildDefaultResolver spec =
  let
    resolverReducer :: Text -> Spec.ConfigValue cmd -> Maybe ConfigValue -> Maybe ConfigValue
    resolverReducer specKey specValue mConfig =
      case specValue of
        Spec.ConfigValue def _ ->
          let
            mConfigSource =
              toDefaultConfigValue <$> def

            updateConfig =
              writeInSubConfig specKey <$> mConfigSource <*> mConfig
          in
            updateConfig <|> mConfig

        Spec.SubConfig specConfigMap ->
          let
            mSubConfig =
              specConfigMap
              & HashMap.foldrWithKey
                    resolverReducer
                    (Just emptySubConfig)
              & filterMaybe isEmptySubConfig

            updateConfig =
              writeInSubConfig specKey <$> mSubConfig <*> mConfig
          in
            updateConfig <|> mConfig
  in
    Spec.specConfigValues spec
    & HashMap.foldrWithKey
          resolverReducer
          (Just emptySubConfig)
    & filterMaybe isEmptySubConfig

{-|

Gathers all default values from the @etc/spec@ entries inside a @ConfigSpec@

-}
resolveDefault
  :: Spec.ConfigSpec cmd -- ^ ConfigSpec
  -> Config              -- ^ returns Configuration Map with default values included
resolveDefault spec =
  maybe (Config emptySubConfig)
        Config
        (buildDefaultResolver spec)
