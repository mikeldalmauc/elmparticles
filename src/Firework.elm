module Firework exposing (Firework, burst, view)

import Random exposing (Generator)
import Random.Float exposing (normal)
import Particle exposing (Particle)
import Svg exposing (Svg)
import Svg.Attributes as SAttrs
-- Generators!


{-| So, let's break down what we've got: this emoji is a cone bursting stuff
towards the upper right (you can see it at `tada.png` in the repo.) We have:

  - little brightly-colored squares. Looks like they can spin!
  - longer, wavy, brightly-colored streamers (but we'll just use rectangles here)

Let's model those as a custom type!

-}


fizzler : Color -> Generator (Particle Firework)
fizzler color =
    Particle.init (Random.constant (Fizzler color))
        |> Particle.withDirection (Random.map degrees (Random.float 0 360))
        |> Particle.withSpeed (Random.map (clamp 0 200) (normal 100 100))
        |> Particle.withLifetime (normal 1.25 0.1)


particleAt : Color -> Float -> Float -> Generator (Particle Firework)
particleAt color x y =
    fizzler color
        |> Particle.withLocation (Random.constant { x = x, y = y })
        |> Particle.withGravity 50
        |> Particle.withDrag
            (\_ ->
                { coefficient = 1
                , density = 0.015
                , area = 2
                }
            )

type Firework
    = Fizzler Color


type Color
    = Red
    | Green
    | Blue

view : Particle Firework -> Svg msg
view particle =
    case Particle.data particle of
        Fizzler color ->
            let
                length =
                    max 2 (Particle.speed particle / 15)

                ( hue, saturation, luminance ) =
                    toHsl color

                maxLuminance =
                    100

                luminanceDelta =
                    maxLuminance - luminance

                lifetime =
                    Particle.lifetimePercent particle

                opacity =
                    if lifetime < 0.1 then
                        lifetime * 10

                    else
                        1
            in
            Svg.ellipse
                [ -- location within the burst
                  SAttrs.cx (String.fromFloat (length / 2))
                , SAttrs.cy "0"

                -- size, smeared by motion
                , SAttrs.rx (String.fromFloat length)
                , SAttrs.ry "2"
                , SAttrs.transform ("rotate(" ++ String.fromFloat (Particle.directionDegrees particle) ++ ")")

                -- color!
                , SAttrs.opacity (String.fromFloat opacity)
                , SAttrs.fill
                    (hslString
                        hue
                        saturation
                        (maxLuminance - luminanceDelta * (1 - lifetime))
                    )
                ]
                []


{-| Using the tango palette, but a little lighter. Original colors at

-}
toHsl : Color -> ( Float, Float, Float )
toHsl color =
    case color of
        Red ->
            -- scarlet red
            ( 0, 86, 75 )

        Green ->
            -- chameleon
            ( 90, 75, 75 )

        Blue ->
            -- sky blue
            ( 211, 49, 83 )
        

hslString : Float -> Float -> Float -> String
hslString hue saturation luminance =
    "hsl("
        ++ String.fromFloat hue
        ++ ","
        ++ String.fromFloat saturation
        ++ "%,"
        ++ String.fromFloat luminance
        ++ "%)"


burst : ( Float, Float ) -> Generator (List (Particle Firework))
burst (x, y) = 
    let
        (color, seed) = (Random.step (Random.uniform Red [ Green, Blue ]) (Random.initialSeed 31415))
    in 
        (Random.list 100 (particleAt color x y))
