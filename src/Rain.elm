module Rain exposing (Rain, view, rainEmitter)

import Random exposing (Generator)
import Random.Extra
import Random.Float exposing (normal)
import Particle exposing (Particle)
import Svg exposing (Svg)
import Svg.Attributes as SAttrs


type Rain = Rain Color

type alias Color
    = String


droplet : Generator Rain
droplet =
    Random.map Rain
        (Random.uniform "#d8e3d7"
            [ "#9caca1"
            , "#788781"
            , "#586767"
            , "#445053"
            ]
        )
{-| Emitters take the delta (in milliseconds )since the last update. This is so
you can emit the right number of particles. This emitter emits about 60
particles per second.
-}
rainEmitter : Int -> Int -> Float -> Generator (List (Particle Rain))
rainEmitter width height delta =
    Particle.init droplet 
        |> Particle.withLifetime (normal 1 0.1)
        |> Particle.withLocation 
            (Random.map2 (\x y -> {x=x, y=y}) (Random.float (-100) (toFloat width)) (Random.constant 0))
                 
        |> Particle.withDirection (normal (degrees 170) (degrees 1))
        |> Particle.withSpeed (Random.constant 1500)
        |> Particle.withGravity 980
        |> Random.list (ceiling (delta * (400 / 1000)))
        

view : Particle Rain -> Svg msg
view particle =
   let
        (Rain color) =
            Particle.data particle

        length =
            max 1 (Particle.speed particle / 15)

    in
         Svg.ellipse
            [ SAttrs.r "1.0"
            , SAttrs.fill color
                    -- size, smeared by motion
            , SAttrs.rx (String.fromFloat length)
            , SAttrs.ry "1"
            , SAttrs.transform ("rotate(" ++ String.fromFloat (Particle.directionDegrees particle) ++ ")")

            ]
            []