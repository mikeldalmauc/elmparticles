module Snow exposing (Snow, view, snowEmitter)

import Random exposing (Generator)
import Random.Extra
import Random.Float exposing (normal)
import Particle exposing (Particle)
import Svg exposing (Svg)
import Svg.Attributes as SAttrs
import String exposing (length)


type Snow = Snow  { 
          color : Color
        , radius : Int
        , rotations : Float

        -- we add a rotation offset to our rotations when rendering. It looks
        -- pretty odd if all the particles start or end in the same place, so
        -- this is part of our random generation.
        , rotationOffset : Float
        }

type alias Color
    = String


flake : Generator Snow
flake =
    Random.map4
        (\color radius rotations rotationOffset->
            Snow
                { color = color
                , radius = round (abs radius)
                , rotations = rotations
                , rotationOffset = rotationOffset
                }
        )
        (Random.uniform "#ffffff"
            [ "#dae2e2"
            , "#d6e6e6"
            , "#becdce"
            , "#bfc9c9"
            ]
        )
        ((normal 7 4 |> Random.map (max 10)))
        (normal 1 1)
        (Random.float 0 1)

{-| Emitters take the delta (in milliseconds )since the last update. This is so
you can emit the right number of particles. This emitter emits about 60
particles per second.
-}
snowEmitter : Int -> Int -> Float -> Generator (List (Particle Snow))
snowEmitter width height delta =
    Particle.init flake 
        |> Particle.withLifetime (normal 5 1)
        |> Particle.withLocation 
            (Random.map2 (\x y -> {x=x, y=y}) (Random.float (-100) (toFloat width)) (Random.constant 0))
                 
        |> Particle.withDirection (normal (degrees 180) (degrees 5))
        |> Particle.withSpeed  (normal 170 20)
        |> Particle.withGravity 0
        |> Particle.withDrag 
            ( \_ -> {
                  density = 0.001226
                , coefficient = 0.029
                , area = 5 
            })
        |> Random.list (ceiling (delta * (400 / 1000)))
        
        
createHexPoint : Int -> Int -> String
createHexPoint deltaX deltaY = 
        String.join
        ","
        [ (String.fromInt deltaX) ++ " 0"
        , (String.fromInt (deltaX*2)) ++ " " ++ (String.fromInt deltaY)
        , (String.fromInt (deltaX*2)) ++ " " ++ (String.fromInt (deltaY*3))
        , (String.fromInt deltaX) ++ " " ++ (String.fromInt (deltaY*4))
        , "0 " ++ (String.fromInt (deltaY*3))
        , "0 " ++ (String.fromInt (deltaY))
        ]

        
view : Particle Snow -> Svg msg
view particle =
   let
        (Snow {color, radius, rotations, rotationOffset}) =
            Particle.data particle
        deltaX = radius // 2
        deltaY = radius // 4

        lifetime =
            Particle.lifetimePercent particle
    in
         Svg.polygon 
            [ 
              SAttrs.points <| createHexPoint deltaX deltaY
            -- , SAttrs.r (String.fromInt radius)
            , SAttrs.fill color
            , SAttrs.transform <|
                "rotate("
                    ++ String.fromFloat ((rotations * lifetime + rotationOffset) * 360)
                    ++ ")"
            ]
            []

            