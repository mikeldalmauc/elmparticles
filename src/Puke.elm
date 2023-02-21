module Puke exposing (Puke, burst, view)

import Random exposing (Generator)
import Random.Extra
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
type Puke
    = Streamer
        { color : Color
        , length : Int
        }


type Color
    = Red
    | Orange
    | Yellow
    | Green
    | Blue
    | Purple


{-| Generate a streamer, again using those color ratios
-}
genStreamer : Generator Puke
genStreamer =
    Random.map2
        (\color length ->
            Streamer
                { color = color
                , length = round (abs length)
                }
        )
        (Random.uniform Red [ Orange, Yellow, Green, Blue, Purple])
        (normal 25 10 |> Random.map (max 10))


view : Particle Puke -> Svg msg
view particle =
    let
        lifetime =
            Particle.lifetimePercent particle

        (Streamer { color, length }) = Particle.data particle

        -- turns out that opacity is pretty expensive for browsers to calculate,
        -- and will slow down our framerate if we change it too much. So while
        -- we *could* do this with, like, a bezier curve or something, we
        -- actually want to just keep it as stable as possible until we actually
        -- need to fade out at the end.
        opacity =
            if lifetime < 0.1 then
                lifetime * 10
            else
                1

        -- Empezando desde la izquierda, las particulas saldrán algo desplazados hacia la derecha
        -- en función del color con un poco de distribución normal
        leftPadding =  case color of
            Red -> 
                0
            Orange ->
                2  

            Yellow ->
                4

            Green ->
                6

            Blue ->
                8

            Purple -> 
                10

        (leftPaddingRand, seed) = (Random.step (normal (leftPadding*2) 2) (Random.initialSeed 31415))
    in
        Svg.rect
            [ SAttrs.height "7px"
            , SAttrs.width <| String.fromInt length ++ "px"
            , SAttrs.y <| String.fromFloat (-leftPaddingRand) ++ "px"
            , SAttrs.rx "2px"
            , SAttrs.ry "2px"
            , SAttrs.fill (fill color)
            , SAttrs.opacity <| String.fromFloat opacity
            , SAttrs.transform <|
                "rotate("
                    ++ String.fromFloat (Particle.directionDegrees particle)
                    ++ ")"
            ]
            []



fill : Color -> String
fill color =
    case color of
        Red ->
            "#F60000"

        Orange ->
            "#FF8C00"

        Yellow ->
            "#FFEE00"

        Green ->
            "#4DE94C"

        Blue ->
            "#3783FF"

        Purple -> 
            "#4815AA"


burst : ( Float, Float ) -> Generator (List (Particle Puke))
burst (x, y) = 
        (Random.list 100 (particleAt x y))


{-| We're going to emit particles at the mouse location, so we pass those
parameters in here and use them without modification.
-}
particleAt : Float -> Float -> Generator (Particle Puke)
particleAt x y =
    Particle.init genStreamer
        |> Particle.withLifetime (normal 1.5 0.25)
        |> Particle.withDelay (normal 0 0.1)
        |> Particle.withLocation (Random.constant { x = x, y = y+15 })
        -- our direction is determined by the angle of the party popper cone
        -- (about 47°) as well as it's width (about 60°). We use a normal
        -- distribution here so that most of the confetti will come out in the
        -- same place, with falloff to the sides. We want most of the confetti
        -- to show up in the center 30°, so the standard deviation of the
        -- distribution should be 15°.
        |> Particle.withDirection (normal (degrees 180) (degrees 1))
        |> Particle.withSpeed (normal 600 100)
        |> Particle.withGravity 980
        |> Particle.withDrag
            (\confetti ->
                { density = 0.001226
                , coefficient = 1.15
                , area = 1
                }
            )
