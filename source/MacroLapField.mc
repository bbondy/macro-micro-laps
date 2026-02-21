using Toybox.Activity;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;

class MacroLapField extends WatchUi.DataField {
    const DEFAULT_TARGET_TIME_SEC = 3599;
    const DEFAULT_TARGET_DISTANCE_MI = 4.1666666667;
    const DEFAULT_DOUBLE_TAP_MS = 3000;
    const M_PER_MI = 1609.344;
    const PACE_MIN_DISTANCE_M = 10.0;
    const PROJ_MIN_DISTANCE_M = 50.0;
    const MACRO_FLASH_MS = 2000;

    var macroInitialized = false;
    var macroIndex = 0;
    var macroStartTimerMs = 0;
    var macroStartDistanceM = 0.0;
    var lastLapEventTimerMs = -1;
    var macroFlashUntilTimerMs = -1;

    var targetTimeSec = DEFAULT_TARGET_TIME_SEC;
    var targetDistanceM = DEFAULT_TARGET_DISTANCE_MI * M_PER_MI;
    var doubleTapThresholdMs = DEFAULT_DOUBLE_TAP_MS;

    function initialize() {
        DataField.initialize();
        log("initialize");
        loadSettings();
    }

    function onSettingsChanged() {
        log("onSettingsChanged");
        loadSettings();
    }

    function onTimerLap() {
        log("onTimerLap");
        handleLapEvent();
    }

    function handleLapEvent() {
        var info = Activity.getActivityInfo();
        if (info == null) {
            log("handleLapEvent: info null");
            return;
        }

        if (!macroInitialized) {
            initMacro(info);
        }

        var tMs = info.timerTime;
        if (tMs == null) {
            log("handleLapEvent: timerTime null");
            return;
        }

        if (lastLapEventTimerMs < 0) {
            lastLapEventTimerMs = tMs;
            return;
        }

        var dt = tMs - lastLapEventTimerMs;
        if (dt < doubleTapThresholdMs) {
            log("handleLapEvent: doubleTap");
            macroIndex += 1;
            macroStartTimerMs = tMs;
            macroStartDistanceM = info.elapsedDistance != null ? info.elapsedDistance : macroStartDistanceM;
            lastLapEventTimerMs = -1;
            macroFlashUntilTimerMs = tMs + MACRO_FLASH_MS;
        } else {
            lastLapEventTimerMs = tMs;
        }
    }

    function onUpdate(dc) {
        log("onUpdate");
        var info = Activity.getActivityInfo();
        if (info == null) {
            log("onUpdate: info null");
            return;
        }

        if (!macroInitialized) {
            initMacro(info);
        }

        var nowTimerMs = info.timerTime != null ? info.timerTime : 0;
        var totalDistanceM = info.elapsedDistance != null ? info.elapsedDistance : 0.0;

        var macroElapsedMs = nowTimerMs - macroStartTimerMs;
        if (macroElapsedMs < 0) {
            macroElapsedMs = 0;
        }

        var macroDistanceM = totalDistanceM - macroStartDistanceM;
        if (macroDistanceM < 0) {
            macroDistanceM = 0;
        }

        var macroElapsedSec = Math.floor(macroElapsedMs / 1000.0);
        var macroTimeLeftSec = targetTimeSec - macroElapsedSec;

        var unitInfo = getUnitInfo();
        var unitMeters = unitInfo[:meters];
        var unitLabel = unitInfo[:label];

        var elapsedStr = formatDurationSec(macroElapsedSec);
        var paceStr = formatPace(macroElapsedSec, macroDistanceM, unitMeters);
        var timeLeftLabel = macroTimeLeftSec >= 0 ? "LEFT" : "OVER";
        var timeLeftAbs = macroTimeLeftSec < 0 ? -macroTimeLeftSec : macroTimeLeftSec;
        var timeLeftStr = formatDurationSec(timeLeftAbs);
        var distStr = formatDistance(macroDistanceM, unitMeters);
        var projStr = formatProjectedTime(macroElapsedSec, macroDistanceM);

        var macroLabel = "MACROLAP";
        var macroValue = (nowTimerMs <= macroFlashUntilTimerMs) ? "START" : macroIndex.format("%d");

        drawGrid(dc, [
            { :label => macroLabel, :value => macroValue },
            { :label => "TIME", :value => elapsedStr },
            { :label => "DIST", :value => distStr },
            { :label => timeLeftLabel, :value => timeLeftStr },
            { :label => "PACE", :value => paceStr },
            { :label => "PROJ", :value => projStr }
        ]);
    }

    function initMacro(info) {
        log("initMacro");
        macroInitialized = true;
        macroIndex = 1;
        macroStartTimerMs = info.timerTime != null ? info.timerTime : 0;
        macroStartDistanceM = info.elapsedDistance != null ? info.elapsedDistance : 0.0;
    }

    function loadSettings() {
        log("loadSettings");
        var app = Application.getApp();
        var enableCustom = toBooleanValue(app.getProperty("enable_custom_targets"), false);
        if (enableCustom == false) {
            targetTimeSec = DEFAULT_TARGET_TIME_SEC;
            targetDistanceM = DEFAULT_TARGET_DISTANCE_MI * M_PER_MI;
            doubleTapThresholdMs = DEFAULT_DOUBLE_TAP_MS;
            return;
        }

        var minutes = toNumberValue(app.getProperty("target_time_minutes"), 59);
        var seconds = toNumberValue(app.getProperty("target_time_seconds"), 45);
        targetTimeSec = (minutes * 60) + seconds;

        var distThousandths = toNumberValue(app.getProperty("target_distance_thousandths"), 4167);
        var distValue = distThousandths / 1000.0;
        var distUnit = toNumberValue(app.getProperty("target_distance_unit"), 0);
        log("loadSettings: distUnit=" + distUnit);
        if (distUnit == 1) {
            targetDistanceM = distValue * 1000.0;
        } else {
            targetDistanceM = distValue * M_PER_MI;
        }

        var tapSeconds = toNumberValue(app.getProperty("double_tap_threshold_seconds"), 3);
        doubleTapThresholdMs = tapSeconds * 1000;
    }

    function getUnitInfo() {
        log("getUnitInfo");
        var settings = System.getDeviceSettings();
        var distanceUnits = settings != null ? settings.distanceUnits : System.UNIT_STATUTE;
        if (distanceUnits == System.UNIT_METRIC) {
            return { :meters => 1000.0, :label => "km" };
        }
        return { :meters => M_PER_MI, :label => "mi" };
    }

    function formatDurationSec(totalSec) {
        log("formatDurationSec");
        totalSec = toNumberValue(totalSec, 0);
        if (totalSec < 0) {
            totalSec = 0;
        }
        var totalSecFloor = Math.floor(totalSec);
        var hours = Math.floor(totalSecFloor / 3600.0);
        var minutes = Math.floor((totalSecFloor - (hours * 3600.0)) / 60.0);
        var seconds = totalSecFloor - (hours * 3600.0) - (minutes * 60.0);

        if (hours > 0) {
            return hours.format("%0.0f") + ":" + twoDigit(minutes) + ":" + twoDigit(seconds);
        }
        return minutes.format("%0.0f") + ":" + twoDigit(seconds);
    }

    function formatTimeLeft(timeLeftSec) {
        log("formatTimeLeft");
        if (timeLeftSec >= 0) {
            return "LEFT " + formatDurationSec(timeLeftSec);
        }
        return "OVER " + formatDurationSec(-timeLeftSec);
    }

    function formatDistance(meters, unitMeters) {
        log("formatDistance");
        if (meters == null) {
            return "--";
        }
        var value = meters / unitMeters;
        return value.format("%0.2f");
    }

    function formatPace(elapsedSec, distanceM, unitMeters) {
        log("formatPace");
        if (distanceM < PACE_MIN_DISTANCE_M) {
            return "--:--";
        }
        var secondsPerUnit = (elapsedSec / 1.0) / (distanceM / unitMeters);
        var paceMinutes = Math.floor(secondsPerUnit / 60.0);
        var paceSeconds = Math.floor(secondsPerUnit - (paceMinutes * 60.0));
        return paceMinutes.format("%0.0f") + ":" + twoDigit(paceSeconds);
    }

    function formatProjectedTime(elapsedSec, distanceM) {
        log("formatProjectedTime");
        if (distanceM < PROJ_MIN_DISTANCE_M) {
            return "--:--";
        }
        var paceSecPerM = (elapsedSec / 1.0) / distanceM;
        var projectedTotalSec = paceSecPerM * targetDistanceM;
        return formatDurationSec(Math.floor(projectedTotalSec + 0.5));
    }

    function twoDigit(value) {
        if (value == null) {
            return "00";
        }
        return value.format("%02.0f");
    }

    function drawGrid(dc, items) {
        log("drawGrid");
        var width = dc.getWidth();
        var height = dc.getHeight();
        var compact = (height < 220 || width < 220);
        var labelFont = Graphics.FONT_XTINY;
        var valueFont = compact ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
        var rows = 3;
        var cols = 2;
        var pad = compact ? 6 : 8;
        var inset = Math.floor(width * 0.10);
        var usableWidth = width - (inset * 2);
        var usableHeight = height - (inset * 2);
        var rowHeight = usableHeight / rows;
        var colWidth = usableWidth / cols;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawLine(inset + colWidth, inset + (pad * 2), inset + colWidth, inset + usableHeight - (pad * 2));
        dc.drawLine(inset + (pad * 2), inset + rowHeight, inset + usableWidth - (pad * 2), inset + rowHeight);
        dc.drawLine(inset + (pad * 2), inset + rowHeight * 2, inset + usableWidth - (pad * 2), inset + rowHeight * 2);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        for (var i = 0; i < items.size(); i += 1) {
            var row = Math.floor(i / cols);
            var col = i % cols;
            var x0 = inset + (col * colWidth);
            var y0 = inset + (row * rowHeight);
            var label = items[i][:label];
            var value = items[i][:value];

            var labelX = x0 + (colWidth / 2);
            var labelHeight = dc.getFontHeight(labelFont);
            var valueHeight = dc.getFontHeight(valueFont);
            var available = rowHeight - (pad * 2) - labelHeight - valueHeight;
            if (available < 0) {
                available = 0;
            }
            var labelY = y0 + pad;
            var valueY = labelY + labelHeight + (available * 0.6);

            var labelText = fitLine(dc, labelFont, label, colWidth - (pad * 2));
            var valueText = fitLine(dc, valueFont, value, colWidth - (pad * 2));

            dc.drawText(labelX, labelY, labelFont, labelText, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(labelX, valueY, valueFont, valueText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function toNumberValue(value, fallback) {
        log("toNumberValue");
        if (value == null) {
            return fallback;
        }
        if (value has :toNumber) {
            var num = value.toNumber();
            if (num != null) {
                return num;
            }
        }
        return fallback;
    }

    function toBooleanValue(value, fallback) {
        log("toBooleanValue");
        if (value == null) {
            return fallback;
        }
        if (value == true || value == false) {
            return value;
        }
        if (value has :toString) {
            var text = value.toString();
            if (text == "true") {
                return true;
            }
            if (text == "false") {
                return false;
            }
        }
        return fallback;
    }

    function fitLine(dc, font, line, maxWidth) {
        if (!(dc has :getTextWidth)) {
            return line;
        }
        var width = dc.getTextWidth(font, line);
        if (width <= maxWidth) {
            return line;
        }
        var trimmed = line;
        while (trimmed.length() > 3) {
            trimmed = trimmed.substring(0, trimmed.length() - 1);
            if (dc.getTextWidth(font, trimmed + "...") <= maxWidth) {
                return trimmed + "...";
            }
        }
        return "...";
    }

    function log(message) {
        System.println("MacroLap: " + message);
    }
}
