{-# LANGUAGE ApplicativeDo, RecordWildCards, OverloadedStrings #-}
module Main where

import System.Random
import Control.Concurrent
import Control.Applicative
import Data.Monoid
import Network.Wai
import Network.Wai.Handler.Warp
import Prometheus
import Prometheus.GHC
import Network.HTTP.Types

type StaticCounter = Metric Static Counter
type StaticHistogram = Metric Static Histogram

data Metrics = Metrics { counter :: StaticCounter
                       , histogram :: StaticHistogram
                       , counterTimer :: StaticHistogram
                       , histogramTimer :: StaticHistogram
                       }

main :: IO ()
main = do
  ((Metrics {..}, collectGHCStats, pusher), registry) <-
    buildRegistry $
    register
      (do counter <-
            newMetric "prom_test_counter" "Testing" mempty Counter
          histogram <-
            newMetric
              "prom_test_histo"
              ""
              mempty
              (Histogram (exponentialBuckets 1e-12 10 10))
          counterTimer <-
            newMetric
              "prom_incCounter"
              ""
              mempty
              (Histogram (exponentialBuckets 1e-12 10 10))
          histogramTimer <-
            newMetric
              "prom_observe"
              ""
              mempty
              (Histogram (exponentialBuckets 1e-12 10 10))
          collectGHCStats <- ghcStats
          pusher <- pushMetrics "localhost" 9091 "/metrics/job/j/instance/i"
          return (Metrics {..}, collectGHCStats, pusher))
  collectGHCStats
  pusher registry
  mw <- publishRegistryMiddleware ["metrics"] registry
  run 5811 $ mw $ \req respond -> do
    withMetric counter $ \c -> withMetric counterTimer $ time $ incCounter c
    withMetric histogram $ \c -> withMetric histogramTimer $ time $ observe 1 c
    respond $ responseLBS status200 [] "Hello World"
