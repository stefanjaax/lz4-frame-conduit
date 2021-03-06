{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import           Codec.Compression.LZ4.Conduit (compress, decompress, bsChunksOf)
import           Control.Monad (when)
import           Control.Monad.Trans.Resource (ResourceT, runResourceT)
import           Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as BSL
import qualified Data.ByteString.Lazy.Char8 as BSL8
import           Data.Conduit
import qualified Data.Conduit.Binary as CB
import qualified Data.Conduit.List as CL
import           Data.List (intersperse)

main :: IO ()
main = do
  when (bsChunksOf 3 "abc123def4567" /= ["abc", "123", "def", "456", "7"]) $
    error "bsChunksOf failed"

  x <- runConduit $ yield "hellohellohello" .| compress .| CL.consume
  print x

  let compressToFile :: FilePath -> Source (ResourceT IO) ByteString -> IO ()
      compressToFile path source =
        runResourceT $ runConduit $ source .| compress .| CB.sinkFileCautious path

  compressToFile "out.lz4" $ yield "hellohellohello"

  compressToFile "outbig1.lz4" $
    CL.sourceList $ BSL.toChunks $ BSL8.pack $
      concat $ intersperse " " $ ["BEGIN"] ++ map show [1..100000 :: Int] ++ ["END"]

  compressToFile "outbig2.lz4" $
    CL.sourceList $ BSL.toChunks $ BSL8.pack $
      concat $ intersperse " " $ replicate 100000 "hello"

  d <- runConduit $ yield "hellohellohello" .| compress .| decompress .| CL.consume
  print d

  runResourceT $ runConduit $ CB.sourceFile "out.lz4" .| decompress .| CB.sinkFileCautious "out.lz4.decompressed"
  runResourceT $ runConduit $ CB.sourceFile "outbig1.lz4" .| decompress .| CB.sinkFileCautious "outbig1.lz4.decompressed"
  runResourceT $ runConduit $ CB.sourceFile "outbig2.lz4" .| decompress .| CB.sinkFileCautious "outbig2.lz4.decompressed"
