module Main where

import Level
import Params

import System.Random (getStdGen, RandomGen)
import Linear

import qualified Control.Monad as CM
import qualified Graphics.UI.SDL as SDL
import Data.Set (Set)
import qualified Data.Set as Set
import Control.Monad.State (State)
import qualified Control.Monad.State as CMS
import Control.Monad.Reader (Reader, ReaderT)
import qualified Control.Monad.Reader as CMR
import Control.Wire
import Prelude hiding (id, (.))
import Data.Maybe (isJust)
import FRP.Netwire
import Debug.Trace
import Control.Monad.Fix

data UserCommand = Accelerate | QuitGame | NoCmd
  deriving (Show, Eq)

parseEvent :: IO UserCommand
parseEvent = do
  event <- SDL.pollEvent
  case event of
    SDL.KeyDown (SDL.Keysym key mods unic)  ->
      case key of
        SDL.SDLK_SPACE -> return Accelerate
        SDL.SDLK_ESCAPE -> return QuitGame
        _              -> return NoCmd
    SDL.Quit -> return QuitGame
    _        -> return NoCmd
      

main' :: IO ()
main' = do
  SDL.init [SDL.InitEverything]
  screen <- SDL.setVideoMode screenW screenH 32 [SDL.SWSurface]
  go screen clockSession_ helicopter
  where
  go screen s w = do
      cmd <- parseEvent
      (ds, s') <- stepSession s
      let (continue, w') = flip CMR.runReader 10.0 $ do
          (eab, w') <- stepWire w ds (Right cmd)
          case eab of
            Left _ -> return (Nothing, w') -- (True, w')
            Right e -> return (Just e, w')
      CM.when (isJust continue) $ print continue
      go screen s' w' 



game :: (HasTime t s) => Wire s () (Reader Double) UserCommand Bool
game = pure False . onUserCommand QuitGame

data Helicopter = Helicopter (V2 Double) deriving (Show)


position :: (HasTime t s) => Wire s () m Double Double
position = mkPureN $ const (Right 0.0, integral 0.0)
  where
    go x =
      mkPure $ \ds vel ->
                let t = realToFrac . dtime $ ds
                    pos = x+vel*t
                    col = pos < 0 || 150 < pos
                    bounded = if col then max 1 (min 149 pos) else pos
                in (Right bounded, go bounded)
                   
main :: IO ()
main = do
       g <- getStdGen
       testWire clockSession_ (l g)


 where l :: (Monad m, HasTime t s, RandomGen g) => g -> Wire s () m a (Ceiling, Floor)
       l = level

                       

           


helicopter :: (HasTime t s) => Wire s () (Reader Double) UserCommand Helicopter
helicopter = undefined
{-  
  where
  fly = proc cmd -> do
    thrust <- thrust -< cmd

    pos <- integral (V2 (fromIntegral screenW / 2) (fromIntegral screenH / 2)) -< thrust

    returnA -< Helicopter pos

  thrust = (pure (V2 (-10) 0) . when ((==) Accelerate)) <|> pure 0
-}
-- create a position by using your initial position as
-- the base for integration, and then itegrat the velocity.


onUserCommand :: (Monoid e, Monad m) => UserCommand -> Wire s e m UserCommand a
onUserCommand command =
  mkPure_ $ \cmd -> if cmd == command then Right undefined else Left mempty
