function onCreate()
    setPropertyFromClass('flixel.FlxG', 'autoPause', false)
    setProperty('isPracticeMode', true)
    setProperty('currentChart.noteStyle', 'pixel')
    setPropertyFromGroup('unspawnNotes', 0, 'noteType', 'ItemNotePixel')
    setPropertyFromGroup('unspawnNotes', 0, 'mustPress', true)
    setPropertyFromGroup('unspawnNotes', 0, 'sustainLength', 2500)
    setPropertyFromGroup('unspawnNotes', 1, 'noteType', 'RoaringNote')
    setPropertyFromGroup('unspawnNotes', 1, 'mustPress', true)
    addLuaScript('custom_notetypes/ItemNotePixel')
    addLuaScript('custom_notetypes/RoaringNote')
    assert(getPropertyFromGroup('unspawnNotes', 0, 'texture') == 'itemnote')
    assert(getPropertyFromGroup('unspawnNotes', 0, 'ignoreNote') == true)
    assert(getPropertyFromGroup('unspawnNotes', 1, 'hitCausesMiss') == true)
    assert(getPropertyFromGroup('unspawnNotes', 1, 'missHealth') == 0)
end

function onCreatePost()
    addHaxeLibrary('NoteScriptEvent', 'funkin.modding.events')
    addHaxeLibrary('HoldNoteScriptEvent', 'funkin.modding.events')
    assert(runHaxeCode([[
        var data = game.currentChart.notes[0];
        var note = game.playerStrumline.buildNoteSprite(data);
        note.holdNoteSprite = game.playerStrumline.buildHoldNoteSprite(data);
        game.dispatchEvent(new NoteScriptEvent('NOTE_INCOMING', note, 0, 0, false));
        if (note.frameWidth != 17 || note.frameHeight != 17) throw 'Pixel note was not loaded';
        if (note.antialiasing) throw 'Pixel antialiasing was not disabled';
        if (note.holdNoteSprite.graphic.width != 56) throw 'Pixel hold was not converted';
        if (note.holdNoteSprite.graphic.height != 6) throw 'Wrong hold cap height';
        var miss = new NoteScriptEvent('NOTE_MISS', note, -0.1, 0, true);
        game.dispatchEvent(miss);
        if (!miss.eventCanceled || !note.handledMiss) throw 'Ignored note produced a miss';
        var drop = new HoldNoteScriptEvent('NOTE_HOLD_DROP', note.holdNoteSprite, -0.1, -10, true, 0, true);
        game.dispatchEvent(drop);
        if (!drop.eventCanceled) throw 'Ignored hold produced a penalty';
        if (game.psychLua.noteOptions.playSplash(note)) throw 'Missing splash should use native fallback';
        note.holdNoteSprite.kill();
        note.kill();
        var normal = game.playerStrumline.buildNoteSprite(game.currentChart.notes[2]);
        game.psychLua.noteOptions.apply(normal);
        if (normal.frameWidth == 17) throw 'Custom texture leaked into recycled note';
        if (game.psychLua.noteOptions.read(normal, 'ignoreNote')) throw 'Custom flags leaked into recycled note';
        normal.kill();
        var hurt = game.playerStrumline.buildNoteSprite(game.currentChart.notes[1]);
        game.psychLua.noteOptions.apply(hurt);
        var health = game.health;
        if (!game.psychLua.noteOptions.interceptHit(hurt)) throw 'Hurt note was treated as a normal hit';
        if (hurt.alive) throw 'Hurt note survived the hit';
        if (game.health != health) throw 'missHealth=0 changed health';
        hurt = game.playerStrumline.buildNoteSprite(game.currentChart.notes[1]);
        game.psychLua.noteOptions.write(hurt, 'missHealth', 0.2, '');
        game.isBotPlayMode = true;
        if (!game.psychLua.noteOptions.interceptHit(hurt) || !hurt.alive) throw 'Botplay hit an ignored note';
        game.isBotPlayMode = false;
        if (!game.psychLua.noteOptions.interceptHit(hurt)) throw 'Hurt note was not handled';
        if (Math.abs(game.health - health + 0.2) > 0.00001) throw 'Wrong hurt-note damage';
        return 'passed';
    ]]) == 'passed', 'Native note checks failed')
    saveFile('note-check-passed.txt', 'Texture, pixel hold, ignored misses, hold drops, hurt hit, missing splash fallback and pool reuse passed')
end
