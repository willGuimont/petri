module Draw (draw) where

import AppTypes
import Constants
import Control.Lens
import qualified Data.Map as M
import Data.Maybe
import Data.Tuple
import qualified DefaultMap as DM
import Graphics.Gloss
import MathUtils
import Petri

draw :: World -> IO Picture
draw w =
  pure . pictures $
    drawPlaces pp n
      ++ drawTransitions tp
      ++ drawInstructions
      ++ drawArcsForTransitions tp pp tdm n
      ++ drawPlacementMode pm
  where
    pp = w ^. worldPlacePositions
    n = w ^. worldNet
    tp = w ^. worldTransitionPositions
    tdm = w ^. worldTransitionDirectionMap
    pm = w ^. worldPlacementMode

drawPlaces :: PlacePositions -> Net -> [Picture]
drawPlaces pp n = concat [drawPlace pp n i | i <- placeIndices]
  where
    placeIndices = M.keys pp

drawPlace :: PlacePositions -> Net -> Id Place -> [Picture]
drawPlace pp n i = [placePicture, numTokenText]
  where
    Just (x, y) = M.lookup i pp
    numToken = numTokenAtPlace i n
    translated = translate x y
    placePicture = translated $ color black $ circle placeRadius
    -- TODO draw dots instead?
    numTokenText =
      translated $
        translate numTokenOffset numTokenOffset $
          scale numTokenScale numTokenScale $
            text $
              show numToken

drawTransitions :: TransitionPositions -> [Picture]
drawTransitions tp = concat [drawTransition tp i | i <- transitionIndices]
  where
    transitionIndices = M.keys tp

drawTransition :: TransitionPositions -> Id Transition -> [Picture]
drawTransition tp i = [trans]
  where
    Just (x, y) = M.lookup i tp
    trans = translate x y $ rectangleSolid transitionWidth transitionHeight

drawInstructions :: [Picture]
drawInstructions = [instruction]
  where
    translated = uncurry translate instructionPosition
    instruction =
      translated $
        scale instructionTextScale instructionTextScale $
          text instructionText

drawArcsForTransitions ::
  TransitionPositions ->
  PlacePositions ->
  TransitionDirectionMap ->
  Net ->
  [Picture]
drawArcsForTransitions tp pp tdm n =
  concat [drawArcForTransition tp pp tdm i n | i <- transitionIndices]
  where
    transitionIndices = M.keys tp

drawArcForTransition ::
  TransitionPositions ->
  PlacePositions ->
  TransitionDirectionMap ->
  Id Transition ->
  Net ->
  [Picture]
drawArcForTransition tp pp tdm i n = fromMaybe [] $ M.lookup i tdm >>= (\td -> Just $ concat [drawArc tp pp td i ip n | ip <- placeIndices])
  where
    placeIndices = maybe [] DM.keys (transitionAsDefaultMap n i)

drawArc ::
  TransitionPositions ->
  PlacePositions ->
  TransitionDirections ->
  Id Transition ->
  Id Place ->
  Net ->
  [Picture]
drawArc tp pp td it ip n = if numToken == placeDeltaOf 0 then [blank] else numTokenText : arrow : [line [lineStart, transPos]]
  where
    Just transPos = M.lookup it tp
    Just placePos = M.lookup ip pp
    dp = normalizePoint $ subPoints transPos placePos
    startOffset = placeRadius
    lineStart = addPoints placePos $ scalePoint startOffset dp
    center = scalePoint 0.5 $ addPoints lineStart transPos
    translated = uncurry translate center
    angle = (* (-180 / pi)) $ uncurry atan2 $ swap dp
    Just arrowDirection = M.lookup ip td

    dir :: Picture -> Picture
    trans :: Picture -> Picture
    (dir, trans) = case arrowDirection of
      ToPlace -> (scale (-1) (-1), translate (- arrowSize) 0)
      FromPlace -> (scale 1 1, id)

    rotated = rotate angle
    arrowLegs = line [(-1, -1), (0, 0), (-1, 1)]
    arrow =
      translated $ rotated $ trans $ dir $ scale arrowSize arrowSize arrowLegs

    Just numToken = deltaOfTransition it ip n
    numTokenText =
      translated $
        translate 0 arrowSize $
          scale numDeltaTokenScale numDeltaTokenScale $
            text $
              show numToken

drawPlacementMode :: PlacementMode -> [Picture]
drawPlacementMode PlaceMode = pure $ placementModeTransform $ text "Place"
drawPlacementMode TransitionMode = pure $ placementModeTransform $text "Transition"
drawPlacementMode ArcMode = pure $ placementModeTransform $text "Arc"

placementModeTransform :: Picture -> Picture
placementModeTransform = uncurry translate placementModePosition . scale placementModeScale placementModeScale
