using Toybox.Application;
using Toybox.WatchUi;

class MacroLapApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        return [new MacroLapField()];
    }
}

function getApp() {
    return Application.getApp() as MacroLapApp;
}
