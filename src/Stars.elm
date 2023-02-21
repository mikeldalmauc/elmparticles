module Stars exposing (Star, view, sprout, burst)

import Random exposing (Generator)
import Random.Extra
import Random.Float exposing (normal)
import Particle exposing (Particle)
import Svg exposing (Svg)
import Svg.Attributes as SAttrs
import Html.Attributes exposing (height)
-- Generators!



star : Color -> Generator (Particle Star)
star color =
    Particle.init (Random.constant (Star color))
        |> Particle.withDirection (Random.map degrees (normal 310 10))
        |> Particle.withSpeed (Random.map (clamp 0 10) (normal 3 1))
        |> Particle.withLifetime (normal 40 40)


starAt : Color -> Float -> Float -> Generator (Particle Star)
starAt color x y =
    star color
        |> Particle.withLocation (Random.constant { x = x, y = y })
        |> Particle.withGravity 0

fugazAt: Color -> Float -> Float -> Generator (Particle Star)
fugazAt color x y =
    fugaz color
        |> Particle.withLocation (Random.constant { x = x, y = y })
        |> Particle.withGravity 0

fugaz : Color -> Generator (Particle Star)
fugaz color =
    Particle.init (Random.constant (Star color))
        |> Particle.withDirection (Random.map degrees (normal 255 5))
        |> Particle.withSpeed (Random.constant 2000)
        |> Particle.withLifetime (normal 2 0.5)


type Star
    = Star Color


type Color
    = Red
    | Green
    | Blue

    
view : Particle Star -> Svg msg
view particle =
    case Particle.data particle of
        Star color ->
            let
                length =
                    max 1 (Particle.speed particle / 15)

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
                , SAttrs.ry "1"
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


burst : ( Float, Float ) -> Generator (List (Particle Star))
burst (x, y) = 
    Random.int 1 1
        |> Random.andThen (\len -> Random.list len (Random.Extra.andThen3 fugazAt
                    (Random.uniform Red [ Green, Blue ])
                    (normal (x + 500) 100)
                    (normal (y - 500) 100)))


sprout : ( Int, Int ) -> Generator (List (Particle Star))
sprout (width, height) = 
    let
        (w, h) = ((toFloat width), (toFloat height))
    in
        (Random.list 100 
            <| (Random.Extra.andThen3 starAt
                    (Random.uniform Red [ Green, Blue ])
                    (normal (w/2) (w/2))
                    (normal (h/2) (h/2))))