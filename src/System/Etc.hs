{-# LANGUAGE CPP               #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

{-|

-}

module System.Etc (
  -- * Config
  -- $config
    Config
  , getConfigValue
  , getConfigValueWith
  , getSelectedConfigSource
  , getAllConfigSources

  -- * ConfigSpec
  -- $config_spec
  , ConfigSource (..)
  , ConfigValue
  , ConfigSpec
  , ConfigurationError (..)
  , parseConfigSpec
  , readConfigSpec

  -- ** Resolvers
  -- $resolvers
  , resolveDefault
  , resolveFiles
  , resolveEnvPure
  , resolveEnv

#ifdef WITH_CLI

  , resolvePlainCliPure
  , resolveCommandCliPure
  , resolvePlainCli
  , resolveCommandCli

  -- ** CLI Resolver Error type
  , getErrorMessage
  , CliConfigError(..)
#endif

#ifdef WITH_PRINTER
  -- * Printer
  -- $printer
  , renderConfig
  , printPrettyConfig
  , hPrintPrettyConfig
#endif
  ) where

import System.Etc.Internal.Resolver.Default (resolveDefault)
import System.Etc.Internal.Types
    (Config, ConfigSource (..), ConfigValue)
import System.Etc.Spec
    (ConfigSpec, ConfigurationError (..), parseConfigSpec, readConfigSpec)

#ifdef WITH_CLI
import System.Etc.Internal.Resolver.Cli.Command (resolveCommandCli, resolveCommandCliPure)
import System.Etc.Internal.Resolver.Cli.Common  (CliConfigError (..), getErrorMessage)
import System.Etc.Internal.Resolver.Cli.Plain   (resolvePlainCli, resolvePlainCliPure)
#endif

#ifdef WITH_PRINTER
import System.Etc.Internal.Printer (hPrintPrettyConfig, printPrettyConfig, renderConfig)
#endif

import System.Etc.Internal.Config
    (getAllConfigSources, getConfigValue, getConfigValueWith, getSelectedConfigSource)
import System.Etc.Internal.Resolver.Env  (resolveEnv, resolveEnvPure)
import System.Etc.Internal.Resolver.File (resolveFiles)

{- $config

   Use this functions to fetch values from the Etc.Config and cast them to types
   that make sense in your program
-}

{- $config_spec

   Use this functions to read the configuration spec. Remember you can
   use JSON or YAML(*) filepaths

   * The yaml cabal flag must be used to support yaml syntax
-}

{- $resolvers

   Use this functions to gather configuration values from different sources
   (environment variables, command lines or files). Then compose results
   together using the mappend function
-}

{- $printer

   Use these function to render the configuration map and understand how the
   resolving was performed.
-}
