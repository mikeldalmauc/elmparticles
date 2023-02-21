module Revolver exposing (Bullet, burst, view)

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
type Bullet
    = Bullet


type Color
    = Black

genBullet : Generator Bullet
genBullet =
   Random.map 
        (\_ ->
            Bullet
        )
        (normal 1 1)

view : Particle Bullet -> Svg msg
view particle =
    let
        lifetime =
            Particle.lifetimePercent particle

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
    in
        Svg.path
            [ SAttrs.width "10px"
            , SAttrs.height "30px"
            , SAttrs.x "-5px"
            , SAttrs.y "-5px"
            -- , SAttrs.rx "1px"
            -- , SAttrs.ry "1px"
            , SAttrs.fill "gray"
            , SAttrs.stroke "black"
            , SAttrs.strokeWidth "3px"
            , SAttrs.opacity <| String.fromFloat opacity
            , SAttrs.transform <|
                    "rotate("
                        ++ String.fromFloat ((Particle.directionDegrees particle) + 90)
                                ++ ") scale(0.1)"
            , SAttrs.d <|
                "M293.946,456.778c0.107-0.386,0.213-0.773,0.293-1.175l6.715-26.02c0-0.63,0-1.261-0.026-1.891"
                ++"c0.012-0.207,0.026-0.413,0.026-0.627V227.368c0.194-1.279,0.193-2.59-0.209-3.795c-0.304-1.485-0.945-2.761-1.863-3.772"
                ++"l-14.715-29.431v-48.682c0-33.574-5.036-67.987-15.108-100.721L258.987,4.875C257.308,1.518,253.951-1,250.593-1"
                ++"s-6.715,2.518-8.393,5.875l-10.072,36.092c-10.072,32.734-15.108,67.148-15.108,100.721v47.843l-15.948,31.895"
                ++"c-1.315,1.972-1.585,4.455-0.839,6.651v198.988c0,0.214,0.014,0.42,0.026,0.627c-0.026,0.63-0.026,1.261-0.026,1.891l6.715,25.18"
                ++"c0.165,0.823,0.401,1.613,0.674,2.385c-4.539,3.823-7.389,9.56-7.389,16.081v9.233c0,10.911,9.233,20.144,20.984,20.144h58.754"
                ++"c11.751,0,20.984-9.233,21.823-20.144v-9.233C301.793,466.493,298.75,460.595,293.946,456.778z M223.734,451.407l-4.197-15.948"
                ++"h62.111l-4.197,15.948c0,0-0.839,0.839-1.679,0.839h-51.2C223.734,452.246,223.734,452.246,223.734,451.407z M267.38,183.656"
                ++"h-33.574v-33.574h33.574V183.656z M230.449,200.443h40.289l8.393,16.787h-57.075L230.449,200.443z M284.167,234.016v184.656"
                ++"H217.02V234.016H284.167z M248.075,46.003l2.518-9.233l2.518,9.233c8.394,28.538,13.43,57.915,14.269,87.292h-33.574"
                ++"C234.646,103.918,239.682,74.541,248.075,46.003z M284.167,482.462c0,1.679-1.679,3.357-3.357,3.357h-59.593"
                ++"c-2.518,0-4.197-1.679-4.197-3.357v-9.233c0-2.518,1.679-4.197,4.197-4.197h3.357h52.039h3.357c2.518,0,4.197,1.679,4.197,4.197"
                ++"V482.462z"
            ]
            []


burst : ( Float, Float ) -> Generator (List (Particle Bullet))
burst (x, y) = 
        (Random.list 1 (particleAt (x + 150) (y - 44)))


{-| We're going to emit particles at the mouse location, so we pass those
parameters in here and use them without modification.
-}
particleAt : Float -> Float -> Generator (Particle Bullet)
particleAt x y =
    Particle.init genBullet
        |> Particle.withLifetime (Random.constant 3)
        |> Particle.withLocation (Random.constant { x = x, y = y })
        -- our direction is determined by the angle of the party popper cone
        -- (about 47°) as well as it's width (about 60°). We use a normal
        -- distribution here so that most of the confetti will come out in the
        -- same place, with falloff to the sides. We want most of the confetti
        -- to show up in the center 30°, so the standard deviation of the
        -- distribution should be 15°.
        |> Particle.withDirection (Random.constant (degrees 88))
        |> Particle.withSpeed (Random.constant 3000)
        |> Particle.withGravity 980
        |> Particle.withDrag
            (\_ ->  
                { density = 0.001226
                , coefficient = 0.029
                , area = 1.0
                } )
            
