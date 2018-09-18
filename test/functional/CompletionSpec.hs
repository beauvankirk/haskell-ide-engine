{-# LANGUAGE OverloadedStrings #-}
module CompletionSpec where

import Control.Applicative.Combinators
import Control.Monad.IO.Class
import Control.Lens hiding ((.=))
import Data.Aeson
import Language.Haskell.LSP.Test
-- import Language.Haskell.LSP.Test.Replay
import Language.Haskell.LSP.Types
import Language.Haskell.LSP.Types.Lens hiding (applyEdit)
import Test.Hspec
import TestUtils

spec :: Spec
spec = describe "completions" $ do
  it "works" $ runSession hieCommand fullCaps "test/testdata/completion" $ do
    doc <- openDoc "Completion.hs" "haskell"
    _ <- skipManyTill loggingNotification (count 2 noDiagnostics)

    let te = TextEdit (Range (Position 4 7) (Position 4 24)) "put"
    _ <- applyEdit doc te

    compls <- getCompletions doc (Position 4 9)
    let item = head $ filter ((== "putStrLn") . (^. label)) compls
    liftIO $ do
      item ^. label `shouldBe` "putStrLn"
      item ^. kind `shouldBe` Just CiFunction
      item ^. detail `shouldBe` Just "String -> IO ()\nPrelude"
      item ^. insertTextFormat `shouldBe` Just Snippet
      item ^. insertText `shouldBe` Just "putStrLn ${1:String}"
  --TODO: Replay session

  it "completes imports" $ runSession hieCommand fullCaps "test/testdata/completion" $ do
    doc <- openDoc "Completion.hs" "haskell"
    _ <- skipManyTill loggingNotification (count 2 noDiagnostics)

    let te = TextEdit (Range (Position 0 17) (Position 0 26)) "Data.M"
    _ <- applyEdit doc te

    compls <- getCompletions doc (Position 0 22)
    let item = head $ filter ((== "Maybe") . (^. label)) compls
    liftIO $ do
      item ^. label `shouldBe` "Maybe"
      item ^. detail `shouldBe` Just "Data.Maybe"
      item ^. kind `shouldBe` Just CiModule

  it "completes qualified imports" $ runSession hieCommand fullCaps "test/testdata/completion" $ do
    doc <- openDoc "Completion.hs" "haskell"
    _ <- skipManyTill loggingNotification (count 2 noDiagnostics)

    let te = TextEdit (Range (Position 1 17) (Position 0 25)) "Dat"
    _ <- applyEdit doc te

    compls <- getCompletions doc (Position 0 19)
    let item = head $ filter ((== "Data.List") . (^. label)) compls
    liftIO $ do
      item ^. label `shouldBe` "Data.List"
      item ^. detail `shouldBe` Just "Data.List"
      item ^. kind `shouldBe` Just CiModule
  
  it "completes with no prefix" $ runSession hieCommand fullCaps "test/testdata/completion" $ do
    doc <- openDoc "Completion.hs" "haskell"
    _ <- skipManyTill loggingNotification (count 2 noDiagnostics)
    compls <- getCompletions doc (Position 4 7)
    liftIO $ filter ((== "!!") . (^. label)) compls `shouldNotSatisfy` null

  describe "snippets" $ do
    it "work for argumentless constructors" $ runSession hieCommand fullCaps "test/testdata/completion" $ do
      doc <- openDoc "Completion.hs" "haskell"
      _ <- skipManyTill loggingNotification (count 2 noDiagnostics)

      let te = TextEdit (Range (Position 4 7) (Position 4 24)) "Nothing"
      _ <- applyEdit doc te

      compls <- getCompletions doc (Position 4 14)
      let item = head $ filter ((== "Nothing") . (^. label)) compls
      liftIO $ do
        item ^. insertTextFormat `shouldBe` Just Snippet
        item ^. insertText `shouldBe` Just "Nothing"

    it "work for polymorphic types" $ runSession hieCommand fullCaps "test/testdata/completion" $ do
      doc <- openDoc "Completion.hs" "haskell"
      _ <- skipManyTill loggingNotification (count 2 noDiagnostics)

      let te = TextEdit (Range (Position 4 7) (Position 4 24)) "fold"
      _ <- applyEdit doc te

      compls <- getCompletions doc (Position 4 11)
      let item = head $ filter ((== "foldl") . (^. label)) compls
      liftIO $ do
        item ^. label `shouldBe` "foldl"
        item ^. kind `shouldBe` Just CiFunction
        item ^. insertTextFormat `shouldBe` Just Snippet
        item ^. insertText `shouldBe` Just "foldl ${1:b -> a -> b} ${2:b} ${3:t a}"

    it "work for complex types" $ runSession hieCommand fullCaps "test/testdata/completion" $ do
      doc <- openDoc "Completion.hs" "haskell"
      _ <- skipManyTill loggingNotification (count 2 noDiagnostics)

      let te = TextEdit (Range (Position 4 7) (Position 4 24)) "mapM"
      _ <- applyEdit doc te

      compls <- getCompletions doc (Position 4 11)
      let item = head $ filter ((== "mapM") . (^. label)) compls
      liftIO $ do
        item ^. label `shouldBe` "mapM"
        item ^. kind `shouldBe` Just CiFunction
        item ^. insertTextFormat `shouldBe` Just Snippet
        item ^. insertText `shouldBe` Just "mapM ${1:a -> m b} ${2:t a}"

    it "respects lsp configuration" $ runSession hieCommand fullCaps "test/testdata/completion" $ do
      doc <- openDoc "Completion.hs" "haskell"
      _ <- skipManyTill loggingNotification (count 2 noDiagnostics)

      let config = object ["languageServerHaskell" .= (object ["completionSnippetsOn" .= False])]

      sendNotification WorkspaceDidChangeConfiguration (DidChangeConfigurationParams config)

      checkNoSnippets doc

    it "respects client capabilities" $ runSession hieCommand noSnippetsCaps "test/testdata/completion" $ do
      doc <- openDoc "Completion.hs" "haskell"
      _ <- skipManyTill loggingNotification (count 2 noDiagnostics)

      checkNoSnippets doc
  where
    checkNoSnippets doc = do
      let te = TextEdit (Range (Position 4 7) (Position 4 24)) "fold"
      _ <- applyEdit doc te

      compls <- getCompletions doc (Position 4 11)
      let item = head $ filter ((== "foldl") . (^. label)) compls
      liftIO $ do
        item ^. label `shouldBe` "foldl"
        item ^. kind `shouldBe` Just CiFunction
        item ^. insertTextFormat `shouldBe` Just PlainText
        item ^. insertText `shouldBe` Nothing
    noSnippetsCaps = (textDocument . _Just . completion . _Just . completionItem . _Just . snippetSupport ?~ False) fullCaps