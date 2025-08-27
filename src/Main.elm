port module Main exposing (Msg(..), main, update, viewModel)

import Browser
import Html
import Html.Attributes
import Json.Encode
import Ui
import Ui.Font as Font
import Ui.Input as Input
import Ui.Layout as Layout


init : String -> String -> Model
init gleamCode jsCode =
    Model
        { splitRatio = 50
        , theme = onedark
        , firstView = Editor
        , secondView = Output
        , viewMode = Both
        , gleamCode = gleamCode
        , jsCode = jsCode
        , browserHtml = ""
        , error = ""
        , compiledJs = ""
        , logs = ""
        }


port send :
    ( String -- The JS code
    , String -- The gleam code
    )
    -> Cmd msg


port receive :
    (( String -- The message type
     , String -- The first message parameter
     , String -- The second message parameter
     )
     -> msg
    )
    -> Sub msg


onedark : Theme
onedark =
    { bg0 = Ui.rgb 40 44 52, bg1 = Ui.rgb 44 50 60, bg2 = Ui.rgb 171 178 191, fg = Ui.rgb 255 255 255 }


main : Program () Model Msg
main =
    Browser.element
        { init =
            \_ ->
                ( init "Loading..." "Loading...", Cmd.none )
        , update = update
        , view = viewModel
        , subscriptions =
            \_ ->
                receive Receive
        }


type View
    = Editor
    | Output


renderView : Model -> View -> Ui.Element Msg
renderView (Model m) view =
    case view of
        Editor ->
            editor (Model m)

        Output ->
            output (Model m)


type ViewMode
    = FirstOnly
    | SecondOnly
    | Both


type Msg
    = SetCode String String
    | Receive ( String, String, String )


type alias Theme =
    { bg0 : Ui.Color
    , bg1 : Ui.Color
    , bg2 : Ui.Color
    , fg : Ui.Color
    }


type Model
    = Model
        { theme : Theme
        , firstView : View
        , secondView : View
        , viewMode : ViewMode
        , splitRatio : Int -- A percentage
        , gleamCode : String
        , jsCode : String
        , error : String
        , compiledJs : String
        , browserHtml : String
        , logs : String
        }


update : Msg -> Model -> ( Model, Cmd.Cmd Msg )
update msg (Model model) =
    case msg of
        SetCode gleamCode jsCode ->
            ( Model
                { model
                    | gleamCode = gleamCode
                    , jsCode = jsCode
                    , error = ""
                    , compiledJs = ""
                    , browserHtml = ""
                    , logs = ""
                }
            , send ( gleamCode, jsCode )
            )

        Receive ( "error", err, _ ) ->
            ( Model { model | error = err }, Cmd.none )

        Receive ( "js", js, _ ) ->
            ( Model { model | compiledJs = js }, Cmd.none )

        Receive ( "html", html, _ ) ->
            ( Model { model | browserHtml = html }, Cmd.none )

        Receive ( "log", log, _ ) ->
            ( Model { model | logs = model.logs ++ log }, Cmd.none )

        Receive ( "ready", gleamCode, jsCode ) ->
            ( init gleamCode jsCode
            , send ( gleamCode, jsCode )
            )

        Receive ( _, _, _ ) ->
            ( Model model, Cmd.none )


viewModel : Model -> Html.Html Msg
viewModel (Model model) =
    Ui.layout Ui.default
        [ Ui.height Ui.fill, Ui.background model.theme.bg2, Font.color model.theme.fg ]
        (case model.viewMode of
            FirstOnly ->
                renderView (Model model) model.firstView

            SecondOnly ->
                renderView (Model model) model.secondView

            Both ->
                Layout.rowWithConstraints [ Layout.portion 50, Layout.portion 50 ]
                    [ Ui.width Ui.fill, Ui.height Ui.fill, Ui.spacing 1 ]
                    [ renderView (Model model) model.firstView
                    , renderView (Model model) model.secondView
                    ]
        )


output : Model -> Ui.Element Msg
output (Model m) =
    Ui.column
        [ Font.family [ Font.monospace ]
        , Font.exactWhitespace
        , Ui.spacing 1
        , Ui.scrollable
        ]
        [ Ui.el [ Ui.padding 4, Ui.background m.theme.bg0 ]
            (Ui.text m.error)
        , Ui.html (Html.node "html-view" [ Html.Attributes.property "html" (Json.Encode.string m.browserHtml) ] [])
        , Ui.el
            [ Ui.padding 4, Ui.background m.theme.bg0 ]
            (Ui.html (Html.text m.logs))
        , Ui.el
            [ Ui.htmlAttribute (Html.Attributes.style "flex-grow" "1")
            , Ui.padding 4
            , Ui.background m.theme.bg0
            ]
            (Ui.text m.compiledJs)
        ]


editor : Model -> Ui.Element Msg
editor (Model m) =
    Ui.column [ Font.family [ Font.monospace ], Ui.spacing 1, Ui.scrollable ]
        [ Input.multiline
            [ Ui.background m.theme.bg0
            , Ui.padding 4
            , Ui.border 0
            , Ui.rounded 0
            ]
            { onChange = \c -> SetCode c m.jsCode
            , text = m.gleamCode
            , placeholder = Maybe.Nothing
            , label = Input.labelHidden "Gleam Code"
            , spellcheck = False
            }
        , Input.multiline
            [ Ui.background m.theme.bg0
            , Ui.padding 4
            , Ui.border 0
            , Ui.rounded 0
            , Ui.htmlAttribute (Html.Attributes.style "flex-grow" "1")
            ]
            { onChange = \c -> SetCode m.gleamCode c
            , text = m.jsCode
            , placeholder = Maybe.Nothing
            , label = Input.labelHidden "JS Code"
            , spellcheck = False
            }
        ]
