{-# LANGUAGE CPP, ScopedTypeVariables, OverloadedStrings #-}
{-
Copyright (C) 2009 John MacFarlane <jgm@berkeley.edu>
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

{- Utility functions for Gitit.
-}

module Network.Gitit.Util ( readFileUTF8
                          , inDir
                          , withTempDir
                          , orIfNull
                          , splitCategories
                          , trim
                          , yesOrNo
                          , parsePageType
                          , encUrl
                          , getPageTypeDefaultExtensions
                          )
where
import System.Directory
import Control.Exception (bracket)
import System.FilePath ((</>), (<.>))
import System.IO.Error (isAlreadyExistsError)
import Control.Monad.Trans (liftIO)
import Data.Char (toLower, isAscii)
import Data.Text (Text)
import Network.Gitit.Types
import qualified Control.Exception as E
import qualified Text.Pandoc.UTF8 as UTF8
import Text.Pandoc (Extension(..), Extensions, getDefaultExtensions, enableExtension)
import Network.URL (encString)

-- | Read file as UTF-8 string.  Encode filename as UTF-8.
readFileUTF8 :: FilePath -> IO Text
#if MIN_VERSION_pandoc(2,12,0)
readFileUTF8 = UTF8.readFile
#else
readFileUTF8 = fmap T.pack . UTF8.readFile
#endif

-- | Perform a function a directory and return to working directory.
inDir :: FilePath -> IO a -> IO a
inDir d action = do
  w <- getCurrentDirectory
  setCurrentDirectory d
  result <- action
  setCurrentDirectory w
  return result

-- | Perform a function in a temporary directory and clean up.
withTempDir :: FilePath -> (FilePath -> IO a) -> IO a
withTempDir baseName f = do
  oldDir <- getCurrentDirectory
  bracket (createTempDir 0 baseName)
          (\tmp -> setCurrentDirectory oldDir >> removeDirectoryRecursive tmp)
          f

-- | Create a temporary directory with a unique name.
createTempDir :: Integer -> FilePath -> IO FilePath
createTempDir num baseName = do
  sysTempDir <- getTemporaryDirectory
  let dirName = sysTempDir </> baseName <.> show num
  liftIO $ E.catch (createDirectory dirName >> return dirName) $
      \e -> if isAlreadyExistsError e
               then createTempDir (num + 1) baseName
               else ioError e

-- | Returns a list, if it is not null, or a backup, if it is.
orIfNull :: [a] -> [a] -> [a]
orIfNull lst backup = if null lst then backup else lst

-- | Split a string containing a list of categories.
splitCategories :: String -> [String]
splitCategories = words . map puncToSpace . trim
     where puncToSpace x | x `elem` ['.',',',';',':'] = ' '
           puncToSpace x = x

-- | Trim leading and trailing spaces.
trim :: String -> String
trim = reverse . trimLeft . reverse . trimLeft
  where trimLeft = dropWhile (`elem` [' ','\t'])

-- | Show Bool as "yes" or "no".
yesOrNo :: Bool -> String
yesOrNo True  = "yes"
yesOrNo False = "no"

parsePageType :: String -> (PageType, Bool)
parsePageType s =
  case map toLower s of
       "markdown"     -> (Markdown,False)
       "markdown+lhs" -> (Markdown,True)
       "commonmark"   -> (CommonMark,False)
       "docbook"      -> (DocBook,False)
       "rst"          -> (RST,False)
       "rst+lhs"      -> (RST,True)
       "html"         -> (HTML,False)
       "textile"      -> (Textile,False)
       "latex"        -> (LaTeX,False)
       "latex+lhs"    -> (LaTeX,True)
       "org"          -> (Org,False)
       "mediawiki"    -> (MediaWiki,False)
       x              -> error $ "Unknown page type: " ++ x

getPageTypeDefaultExtensions :: PageType -> Bool -> Extensions
getPageTypeDefaultExtensions pt lhs =
  if lhs
     then enableExtension Ext_literate_haskell defaults
     else defaults
  where defaults = getDefaultExtensions $
          case pt of
            CommonMark -> "commonmark"
            DocBook    -> "docbook"
            HTML       -> "html"
            LaTeX      -> "latex"
            Markdown   -> "markdown"
            MediaWiki  -> "mediawiki"
            Org        -> "org"
            RST        -> "rst"
            Textile    -> "textile"

encUrl :: String -> String
encUrl = encString True isAscii
