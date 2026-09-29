var sample = {counter: 0};
var tweenFinished = false;
var testTween = null;
var seconds = 0.0;

function onCreate():Void
{
    sample.counter = 7;
    if (sample.counter != 7) throw "SScript direct access failed";
    if (!configure(sample, {counter: 8}) || sample.counter != 8) throw "SScript configure failed";
    var originalX = getProperty("boyfriend.x");
    if (!setProperties(["boyfriend.x" => 700])) throw "SScript Map setter failed";
    if (getProperty("boyfriend.x") != 700) throw "SScript property mismatch";
    if (!setProperties("boyfriend", {x: originalX})) throw "SScript target setter failed";
    if (setProperties(["notARealRoot.field" => 1, "boyfriend.x" => originalX])) throw "SScript invalid path accepted";
    if (boyfriend.x != originalX) throw "SScript direct character alias failed";
    var values = getProperties(["boyfriend.x"]);
    if (values.get("boyfriend.x") != originalX) throw "SScript Map getter failed";
    testTween = tween(sample, {counter: 9}, {duration: 0.01, ease: "linear", onComplete: function() {
        if (sample.counter != 9) throw "SScript tween failed";
        tweenFinished = true;
        trace("SSCRIPT_CONVENIENCE_OK");
    }});
    if (testTween == null || testTween.duration != 0.01) throw "SScript fractional tween duration lost";
}

function onUpdate(elapsed:Float):Void
{
    seconds += elapsed;
    if (seconds > 1 && !tweenFinished) throw "SScript tween did not complete";
    if (!tweenFinished && sample.counter == 9) throw "SScript tween completion callback missing";
}
