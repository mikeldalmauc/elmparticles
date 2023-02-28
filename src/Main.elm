
port module Main exposing (main)

{-| HEADS UP! You can view this example alongside the running code at


We're going to make confetti come out of the party popper emoji: 🎉
([emojipedia](https://emojipedia.org/party-popper/)) Specifically, we're going
to lift our style from [Mutant Standard][ms], a wonderful alternate emoji set,
which is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike
4.0 International License.

[ms]: https://mutant.tech/

-}

import Browser
import Browser.Events
import Html exposing (Html)
import Html.Attributes as Attrs exposing (style)
import Particle.System as System exposing (System)
import Task
import Random exposing (Generator)
import Json.Decode exposing (Decoder, map2, map4, field, int, string, float, succeed, decodeString )
import Process

import Confetti exposing (Confetti)
import Revolver exposing (Bullet)
import Puke exposing (Puke)
import Firework exposing (Firework)
import Stars exposing (Star)
import Rain exposing (Rain)
import Snow exposing (Snow)


type alias Model =
    { systemConfetti : System Confetti
    , systemBullet : System Bullet
    , systemPuke : System Puke
    , systemFirework : System Firework
    , systemStars : System Star
    , systemRain : System Rain
    , systemSnow : System Snow
    , mouse : (Float, Float)
    , cursor : Cursor
    , window : Dimension
    }

type Msg
    = TriggerBurst
    | TriggerSprouts Int
    | MouseMove Float Float
    | ParticleConfettiMsg (System.Msg Confetti)
    | ParticleBulletMsg (System.Msg Bullet)
    | ParticlePukeMsg (System.Msg Puke)
    | ParticleFireworkMsg (System.Msg Firework)
    | ParticleStarsMsg (System.Msg Star)
    | ParticleRainMsg (System.Msg Rain)
    | ParticleSnowMsg (System.Msg Snow)
    | ChangeCursor String
    | Resize String



update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TriggerBurst  ->
            ( burst model , Cmd.none )

        TriggerSprouts amount-> 
            if amount > 0 then
                update (TriggerSprouts (amount - 1)) ( sprout model)
            else
                ( model, delay 20000 (TriggerSprouts 1))

        MouseMove x y ->
            ( { model | mouse = ( x, y ) }
            , Cmd.none
            )

        ParticleConfettiMsg particleMsg ->
            ( { model | systemConfetti = System.update particleMsg model.systemConfetti }
            , Cmd.none
            )

        ParticleBulletMsg particleMsg ->
            ( { model | systemBullet = System.update particleMsg model.systemBullet }
            , Cmd.none
            )

        ParticlePukeMsg particleMsg ->
            ( { model | systemPuke = System.update particleMsg model.systemPuke }
            , Cmd.none
            )
        
        ParticleFireworkMsg particleMsg ->
            ( { model | systemFirework = System.update particleMsg model.systemFirework }
            , Cmd.none
            )

        ParticleStarsMsg particleMsg ->
            ( { model | systemStars = System.update particleMsg model.systemStars }
            , Cmd.none
            )
            
        ParticleRainMsg particleMsg ->
                ( { model | systemRain = System.update particleMsg model.systemRain }
                , Cmd.none
                )
     
        ParticleSnowMsg particleMsg ->
                ( { model | systemSnow = System.update particleMsg model.systemSnow }
                , Cmd.none
                )

        ChangeCursor cursor ->
            let
                cursorDec = (cursorDecode cursor)
            in
            case cursorDec of
                StarC _ -> 
                    update (TriggerSprouts 20) ( {model | cursor = cursorDec})
                _-> 
                    ( {model | cursor = cursorDec} , Cmd.none)
        
        Resize dimension ->
            let
                dimensionDecoded = (decodeString  dimensionDecoder dimension)   
            in
                case dimensionDecoded of
                    Ok data -> 
                        ( { model | window = data } , Cmd.none )

                    Err _ -> 
                        ( model , Cmd.none )

-- BURSTS

burst : Model -> Model
burst model = 
    let
        ( x, y ) = model.mouse
    in
        case model.cursor of
            ConfettiC _->
                { model | systemConfetti = System.burst (Confetti.burst (x, y)) model.systemConfetti }

            BulletC _->
                { model | systemBullet = System.burst (Revolver.burst (x, y)) model.systemBullet }

            Ooze _->
                { model | systemPuke = System.burst (Puke.burst (x, y)) model.systemPuke }
            
            FireworkC _->
                { model | systemFirework = System.burst (Firework.burst (x, y)) model.systemFirework }
            
            StarC _->
                { model | systemStars = System.burst (Stars.burst (x, y)) model.systemStars }

            RainC _ ->
                model

            SnowC _ ->
                model


sprout: Model -> Model
sprout model = 
    let
        { width, height } = model.window
    in
        { model | systemStars = System.burst (Stars.sprout (width, height)) model.systemStars }


delay : Float -> msg -> Cmd msg
delay time msg =
  Process.sleep time
  |> Task.perform (\_ -> msg)

-- views


view : Model -> Html msg
view model =
    let
        ( mouseX, mouseY ) =
            model.mouse

        (w, h) = cursorDimensions model.cursor

        props = [ style "width" "100%"
                , style "height" "100vh"
                -- , style "z-index" "1"
                , style "position" "absolute"
                , style "cursor" "none"
                ]

        particleView = 
            case model.cursor of
                ConfettiC _->
                    System.view Confetti.view props model.systemConfetti
                BulletC _->
                    System.view Revolver.view props model.systemBullet
                Ooze _->
                    System.view Puke.view props model.systemPuke
                FireworkC _->
                    System.view Firework.view props model.systemFirework
                StarC _->
                    System.view Stars.view props model.systemStars
                RainC _->
                    System.view Rain.view props model.systemRain
                SnowC _->
                    System.view Snow.view props model.systemSnow

    in
    Html.main_
        [Attrs.id "myapp"]
        [ particleView
        , Html.img
            [ Attrs.src <| cursorImage model.cursor
            , Attrs.width w
            , Attrs.height h
            , Attrs.alt "\"tada\" emoji from Mutant Standard"
            , style "position" "absolute"
            , style "left" (String.fromFloat (mouseX - 20) ++ "px")
            , style "top" (String.fromFloat (mouseY - 30) ++ "px")
            , style "user-select" "none"
            , style "cursor" "none"
            , style "z-index" "170"
            , style "caret-color" "transparent"
            ]
            []
        ]


-- CURSOR

type Cursor = ConfettiC  { width : Int, height : Int}
            | BulletC { width : Int, height : Int}
            | Ooze  { width : Int, height : Int}
            | FireworkC  { width : Int, height : Int}
            | StarC  { width : Int, height : Int}
            | RainC  { width : Int, height : Int}
            | SnowC  { width : Int, height : Int}
            

-- fair enough
cursorImage : Cursor -> String
cursorImage cursor =
    case cursor of
        ConfettiC _->
            "../assets/confeti/tada.png"

        BulletC _->
            "../assets/gun/gun.png"

        Ooze _->
            "../assets/puke/ooze.png"
       
        FireworkC _->
            "../assets/firework/firework.png"

        StarC _->
            "../assets/starrynight/star.png"

        RainC _->
            "../assets/rain/umbrella.png"
        
        SnowC _->
            "../assets/snow/snow.png"

-- WHY!!!
cursorDimensions : Cursor -> (Int, Int) 
cursorDimensions cursor =
    case cursor of
        BulletC dimensions ->
            (dimensions.width, dimensions.height)
            
        ConfettiC dimensions ->
            (dimensions.width, dimensions.height)

        Ooze dimensions ->
            (dimensions.width, dimensions.height)
       
        FireworkC dimensions ->
            (dimensions.width, dimensions.height)

        StarC dimensions ->
            (dimensions.width, dimensions.height)

        RainC dimensions -> 
            (dimensions.width, dimensions.height)

        SnowC dimensions -> 
            (dimensions.width, dimensions.height)

-- fishy
cursorDecode : String -> Cursor
cursorDecode cursor =
    case cursor of
        "Confetti" ->
            ConfettiC  {width = 65, height=65}

        "Bullet" ->
            BulletC {width = 150, height=85}

        "Ooze" ->
            Ooze  {width = 65, height=65}

        "Firework" ->
            FireworkC  {width = 65, height=65}
        
        "Star" ->
            StarC  {width = 65, height=65}
     
        "Rain" ->
            RainC  {width = 65, height=65}

        "Snow" ->
            SnowC  {width = 65, height=65}

        _-> 
            ConfettiC  {width = 65, height=65}


-- PORTS

port messageReceiver : (String -> msg) -> Sub msg

type alias Dimension = {
      width : Int
    , height : Int
    }   

port dimensionsReceiver : (String -> msg) -> Sub msg

dimensionDecoder : Decoder Dimension
dimensionDecoder  =
  map2 Dimension
    (field "width" int)
    (field "height" int)

-- tie it all together!

-- SUBSCRIPTIONS


-- Subscribe to the `messageReceiver` port to hear about messages coming in
-- from JS. Check out the index.html file to see how this is hooked up to a
-- WebSocket.
--
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ System.sub [] ParticleConfettiMsg model.systemConfetti
        , System.sub [] ParticleBulletMsg model.systemBullet
        , System.sub [] ParticlePukeMsg model.systemPuke
        , System.sub [] ParticleFireworkMsg model.systemFirework
        , System.sub [] ParticleStarsMsg model.systemStars
        , System.sub [ (Rain.rainEmitter model.window.width model.window.height)] ParticleRainMsg model.systemRain
        , System.sub [ (Snow.snowEmitter model.window.width model.window.height)] ParticleSnowMsg model.systemSnow
        , Browser.Events.onClick (succeed TriggerBurst)
        , Browser.Events.onMouseMove
            (map2 MouseMove
                (field "clientX" float)
                (field "clientY" float)
            )
        , dimensionsReceiver Resize
        , messageReceiver ChangeCursor
        ]


init :() -> (Model, Cmd Msg)
init =
    \_ -> (   { 
         systemConfetti = System.init (Random.initialSeed 0)
        , systemBullet = System.init (Random.initialSeed 0)
        , systemPuke = System.init (Random.initialSeed 0)
        , systemFirework = System.init (Random.initialSeed 0)
        , systemStars = System.init (Random.initialSeed 0)
        , systemRain = System.init (Random.initialSeed 0)
        , systemSnow = System.init (Random.initialSeed 0)
        , mouse = ( 0, 0 )
        , cursor = (cursorDecode "Confetti")
        , window = {width=0, height=0}
        }
    , Cmd.none
    )

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
        