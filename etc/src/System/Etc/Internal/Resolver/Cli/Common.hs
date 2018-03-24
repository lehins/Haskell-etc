{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module System.Etc.Internal.Resolver.Cli.Common where

import qualified Prelude as P

import           RIO
import qualified RIO.ByteString.Lazy as BL (toStrict)
import qualified RIO.Set             as Set
import qualified RIO.Text            as Text
import qualified RIO.Vector          as Vector

import qualified Data.Aeson          as JSON
import qualified Data.Aeson.Internal as JSON (IResult (..), iparse)
import qualified Data.Text.IO        as Text
import qualified Options.Applicative as Opt

import System.Exit

import qualified System.Etc.Internal.Spec.Types as Spec
import           System.Etc.Internal.Types

--------------------------------------------------------------------------------

{-| A wrapper for sub-routines that return an error message; this was
    created for error report purposes.
-}
newtype GetErrorMessage
  = GetErrorMessage {
    -- | Unwrap IO action with error message
    getErrorMessage :: IO Text
  }

instance Show GetErrorMessage where
  show _ = "<<error message>>"

{-| Error when evaluating the ConfigSpec or when executing the OptParser

-}
data CliConfigError
  -- | The type of the Command Key is invalid
  = InvalidCliCommandKey Text
  -- | Trying to use command for an entry without setting commands section
  | CommandsKeyNotDefined
  -- | Trying to use a command that is not defined in commands section
  | UnknownCommandKey Text
  -- | The command setting is missing on a Command Cli
  | CommandKeyMissing
  -- | There is a command setting on a plain Cli
  | CommandKeyOnPlainCli
  -- | The internal OptParser API failed
  | CliEvalExited ExitCode GetErrorMessage
  deriving (Show)

instance Exception CliConfigError

--------------------------------------------------------------------------------

specToCliSwitchFieldMod specSettings =
  maybe Opt.idm (Opt.long . Text.unpack) (Spec.optLong specSettings)
    `mappend` maybe Opt.idm (Opt.short . Text.head) (Spec.optShort specSettings)
    `mappend` maybe Opt.idm (Opt.help . Text.unpack) (Spec.optHelp specSettings)

specToCliVarFieldMod specSettings =
  specToCliSwitchFieldMod specSettings `mappend` maybe
    Opt.idm
    (Opt.metavar . Text.unpack)
    (Spec.optMetavar specSettings)


commandToKey :: (MonadThrow m, JSON.ToJSON cmd) => cmd -> m [Text]
commandToKey cmd = case JSON.toJSON cmd of
  JSON.String commandStr -> return [commandStr]
  JSON.Array jsonList ->
    jsonList & Vector.toList & mapM commandToKey & (concat <$>)
  _ ->
    cmd
      & JSON.encode
      & BL.toStrict
      & Text.decodeUtf8'
      & either tshow id
      & InvalidCliCommandKey
      & throwM

settingsToJsonCli :: Spec.CliEntryMetadata -> Opt.Parser (Maybe JSON.Value)
settingsToJsonCli specSettings =
  let requiredCombinator =
        if Spec.optRequired specSettings then (Just <$>) else Opt.optional
  in  requiredCombinator $ case specSettings of
        Spec.Opt{} -> case Spec.optValueType specSettings of
          Spec.StringOpt -> (JSON.String . Text.pack)
            <$> Opt.strOption (specToCliVarFieldMod specSettings)

          Spec.NumberOpt -> (JSON.Number . fromInteger)
            <$> Opt.option Opt.auto (specToCliVarFieldMod specSettings)

          Spec.SwitchOpt ->
            JSON.Bool <$> Opt.switch (specToCliSwitchFieldMod specSettings)

        Spec.Arg{} -> case Spec.argValueType specSettings of
          Spec.StringArg -> (JSON.String . Text.pack) <$> Opt.strArgument
            (specSettings & Spec.argMetavar & maybe
              Opt.idm
              (Opt.metavar . Text.unpack)
            )
          Spec.NumberArg -> (JSON.Number . fromInteger) <$> Opt.argument
            Opt.auto
            (specSettings & Spec.argMetavar & maybe
              Opt.idm
              (Opt.metavar . Text.unpack)
            )

parseCommandJsonValue :: (MonadThrow m, JSON.FromJSON a) => JSON.Value -> m a
parseCommandJsonValue commandValue =
  case JSON.iparse JSON.parseJSON commandValue of
    JSON.IError _path err -> throwM (InvalidCliCommandKey $ Text.pack err)

    JSON.ISuccess result  -> return result

jsonToConfigValue :: Maybe JsonValue -> ConfigValue
jsonToConfigValue specEntryDefVal =
  ConfigValue $ Set.fromList $ maybe [] ((: []) . Cli) specEntryDefVal

handleCliResult :: Either SomeException a -> IO a
handleCliResult result = case result of
  Right config -> return config

  Left  err    -> case fromException err of
    Just (CliEvalExited ExitSuccess (GetErrorMessage getMsg)) -> do
      getMsg >>= Text.putStrLn
      exitSuccess

    Just (CliEvalExited exitCode (GetErrorMessage getMsg)) -> do
      getMsg >>= Text.hPutStrLn stderr
      exitWith exitCode

    _ -> throwIO err

programResultToResolverResult
  :: MonadThrow m => Text -> Opt.ParserResult a -> m a
programResultToResolverResult progName programResult = case programResult of
  Opt.Success result -> return result

  Opt.Failure failure ->
    let (outputMsg, exitCode) =
          Opt.renderFailure failure $ Text.unpack progName
    in  throwM $ CliEvalExited
          exitCode
          (GetErrorMessage $ return (Text.pack outputMsg))

  Opt.CompletionInvoked compl ->
    let getMsg = Text.pack <$> Opt.execCompletion compl (Text.unpack progName)
    in  throwM $ CliEvalExited ExitSuccess (GetErrorMessage getMsg)
