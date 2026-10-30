package com.hirumisu.carwece

import org.junit.Assert.*
import org.junit.Test

class IntroDirectorTest {
    private data class Load(val ready:(Int,Int,Int)->Unit,val completed:()->Unit,val failed:()->Unit)
    private class Backend: IntroBackend {
        val loads=mutableListOf<Load>()
        var plays=0; var pauses=0; var releases=0; var throws=false
        override fun load(ready:(Int,Int,Int)->Unit,completed:()->Unit,failed:()->Unit) {
            if(throws)throw IllegalStateException("decoder")
            loads.add(Load(ready,completed,failed))
        }
        override fun play(){plays++}
        override fun pause(){pauses++}
        override fun release(){releases++}
    }
    private fun prepared():Pair<IntroDirector,Backend> {
        val b=Backend();val d=IntroDirector(b)
        d.setForeground(true);d.setFocus(true);d.open();b.loads.last().ready(1280,720,10027)
        return d to b
    }
    @Test fun waitsForPreparedForegroundAndFocusBeforeStarting() {
        val b=Backend();val d=IntroDirector(b);d.open()
        assertEquals("loading",d.state()["status"]);assertEquals(0,b.plays)
        b.loads.last().ready(1280,720,10027);assertEquals(0,b.plays)
        d.setForeground(true);assertEquals(0,b.plays)
        d.setFocus(true);assertEquals(1,b.plays);assertEquals("playing",d.state()["status"])
        assertEquals(1280,d.state()["width"]);assertEquals(10027,d.state()["durationMs"])
    }
    @Test fun repeatedOpenNeverRestartsAnOngoingVideo() {
        val(d,b)=prepared();repeat(8){d.open()}
        assertEquals(1,b.loads.size);assertEquals(1,b.plays);assertFalse(d.completed)
    }
    @Test fun backgroundPauseAndResumeKeepTheSameDecoderAndPosition() {
        val(d,b)=prepared();d.setForeground(false)
        assertEquals(1,b.pauses);assertEquals("paused",d.state()["status"])
        d.setForeground(true);assertEquals(2,b.plays);assertEquals(1,b.loads.size)
        assertFalse(d.completed)
    }
    @Test fun audioFocusLossPausesAndGainResumesWithoutReload() {
        val(d,b)=prepared();d.setFocus(false);assertEquals(1,b.pauses)
        d.setFocus(true);assertEquals(2,b.plays);assertEquals(1,b.loads.size)
    }
    @Test fun onlyDecoderCompletionFinishesAndForegroundChangesCannotReplay() {
        val(d,b)=prepared();assertFalse(d.completed)
        b.loads.last().completed();assertTrue(d.completed);assertEquals("completed",d.state()["status"])
        d.setForeground(false);d.setForeground(true);d.setFocus(true);d.open()
        assertEquals(1,b.plays);assertEquals(1,b.loads.size)
    }
    @Test fun decoderErrorNeverPretendsVideoFinishedAndRetryIgnoresOldCallbacks() {
        val(d,b)=prepared();val old=b.loads.last();old.failed()
        assertEquals("error",d.state()["status"]);assertFalse(d.completed)
        d.open();old.ready(1,1,1);old.completed();assertFalse(d.completed)
        b.loads.last().ready(1280,720,10027);b.loads.last().completed()
        assertTrue(d.completed);assertEquals(2,b.loads.size)
    }
    @Test fun closeRejectsLateCallbacksAndReleasesDecoder() {
        val b=Backend();val d=IntroDirector(b);d.open();val old=b.loads.last();d.close()
        val released=b.releases
        old.ready(1280,720,10027);old.completed();old.failed();d.setForeground(true);d.setFocus(true)
        assertFalse(d.completed);assertEquals(0,b.plays);assertEquals(released,b.releases)
    }
    @Test fun invalidMetadataIsAnErrorAndCannotAdvanceToMenu() {
        val b=Backend();val d=IntroDirector(b);d.open();b.loads.last().ready(0,720,10027)
        assertEquals("error",d.state()["status"]);assertFalse(d.completed)
    }
    @Test fun loadExceptionCanBeRetriedAndDoesNotSkipVideo() {
        val b=Backend();b.throws=true;val d=IntroDirector(b);d.open()
        assertEquals("error",d.state()["status"]);assertFalse(d.completed)
        b.throws=false;d.open();assertEquals(1,b.loads.size)
    }
    @Test fun prematureCompletionAndLateErrorCannotForgeOrUndoCompletion() {
        val b=Backend();val d=IntroDirector(b);d.open();val load=b.loads.last()
        load.completed();assertFalse(d.completed)
        load.ready(1280,720,10027);load.completed();load.failed()
        assertTrue(d.completed);assertEquals("completed",d.state()["status"])
    }
}
