package com.hirumisu.carwece

import org.junit.Assert.*
import org.junit.Test
import kotlin.random.Random

class MusicDirectorTest {
    private val ids = (1..15).map { "race_%02d".format(it) }
    private val menus = (1..5).map { "menu_%02d".format(it) }
    private val battles = (1..5).map { "battle_%02d".format(it) }
    private val menu = menus.first()
    private val tracks = (ids + menus + battles).map { MusicTrack(it, it, "artist", "$it.m4a", 220000) }
    private class Fake : MusicBackend {
        data class Load(val id: String, val loop: Boolean, val seek: Int,
            val ready: () -> Unit, val complete: () -> Unit, val fail: () -> Unit)
        val loads = mutableListOf<Load>()
        var plays = 0; var pauses = 0; var releases = 0; var level = 0f
        var pos = 12345; var failLoad = false; var throwPlay = false
        var alive = 0; var peak = 0
        override fun load(track: MusicTrack, loop: Boolean, startMs: Int,
            ready: () -> Unit, completed: () -> Unit, failed: () -> Unit) {
            alive++; peak = maxOf(peak, alive)
            loads.add(Load(track.id, loop, startMs, ready, completed, failed))
            if (failLoad) failed()
        }
        override fun play() { if (throwPlay) error("codec unavailable"); plays++ }
        override fun pause() { pauses++ }
        override fun volume(value: Float) { level = value }
        override fun position() = pos
        override fun release() { if (alive > 0) releases++; alive = 0 }
    }
    private fun director(f: Fake = Fake()) = MusicDirector(tracks, menus, ids, battles, f, Random(42))
    private fun active(d: MusicDirector) { d.setActive(true); d.setFocus(true) }
    private fun racing(d: MusicDirector, f: Fake) { d.setScene("race"); active(d); f.loads.last().ready() }

    @Test fun menuUsesOnlyMenuTracksAndRepeatedUpdatesDoNotRestartIt() {
        val f=Fake();val d=director(f);active(d);f.loads.last().ready()
        assertTrue(d.currentId in menus);assertFalse(f.loads.single().loop);assertEquals(1,f.plays)
        repeat(100){d.setScene("menu");d.setVolume(.35f);d.setShuffle(true)}
        assertEquals(1,f.loads.size);assertEquals(1,f.plays)
    }
    @Test fun raceUsesOnlyRaceTracksAndMenuChangesOnlyOnReturn() {
        val f=Fake();val d=director(f);active(d);val old=f.loads.last();d.setScene("race");f.loads.last().ready()
        assertTrue(d.currentId in ids);assertFalse(f.loads.last().loop)
        old.ready();assertEquals(1,f.plays)
        d.setScene("menu");f.loads.last().ready();assertTrue(d.currentId in menus);assertFalse(f.loads.last().loop)
        repeat(20){d.setScene("menu")};assertEquals(3,f.loads.size)
    }
    @Test fun randomDeckCoversAllRaceTracksBeforeRepeatingAndDoesNotRepeatAtTheBoundary() {
        val f=Fake();val d=director(f);racing(d,f);val played=mutableListOf<String>()
        repeat(ids.size * 3){played.add(d.currentId!!);val c=f.loads.last();c.complete();f.loads.last().ready()}
        for(i in 0 until ids.size * 3 step ids.size)assertEquals(ids.toSet(),played.subList(i,i+ids.size).toSet())
        for(i in 1 until played.size)assertNotEquals(played[i-1],played[i])
        assertEquals(1,f.peak)
    }
    @Test fun explicitSelectionStartsThatTrackAndFollowingCompletionContinuesThePlaylist() {
        val f=Fake();val d=director(f);racing(d,f);d.select("race_09");f.loads.last().ready()
        assertEquals("race_09",d.currentId);assertEquals("playing",d.state()["status"])
        f.loads.last().complete();assertTrue(d.currentId in ids);assertNotEquals("race_09",d.currentId)
    }
    @Test fun invalidOrMenuSelectionsCannotEnterTheRacePlaylist() {
        val f=Fake();val d=director(f);racing(d,f);val n=f.loads.size;val id=d.currentId
        d.select("unknown");d.select(menu);assertEquals(id,d.currentId);assertEquals(n,f.loads.size)
    }
    @Test fun sequentialModePreservesTheCurrentTrackThenAdvancesInOrder() {
        val f=Fake();val d=director(f);racing(d,f);d.select("race_02");f.loads.last().ready();val n=f.loads.size
        d.setShuffle(false);assertEquals(n,f.loads.size);assertEquals("race_02",d.currentId)
        d.next();assertEquals("race_03",d.currentId);assertFalse(d.shuffle)
    }
    @Test fun manualPauseSurvivesSceneAndVolumeUpdatesUntilTheUserPlaysAgain() {
        val f=Fake();val d=director(f);racing(d,f);d.setUserPaused(true);assertEquals("paused",d.state()["status"])
        repeat(50){d.setScene("race");d.setVolume(.4f)}
        assertEquals(1,f.plays);assertEquals(1,f.pauses);d.setUserPaused(false);assertEquals(2,f.plays)
    }
    @Test fun changingTracksWhilePausedByTheUserExplicitlyPlaysTheChosenTrack() {
        val f=Fake();val d=director(f);racing(d,f);d.setUserPaused(true);d.select("race_04");f.loads.last().ready()
        assertFalse(d.userPaused);assertEquals("playing",d.state()["status"])
    }
    @Test fun gameplayPauseDoesNotSwitchToMenuOrReloadTheSong() {
        val f=Fake();val d=director(f);racing(d,f);val id=d.currentId;val loads=f.loads.size
        repeat(100){d.setScene("race");d.setVolume(.35f)}
        assertEquals(id,d.currentId);assertEquals(loads,f.loads.size);assertEquals("playing",d.state()["status"])
    }
    @Test fun zeroVolumePausesWithoutChangingTrackAndRestoringVolumeResumesIt() {
        val f=Fake();val d=director(f);racing(d,f);val id=d.currentId
        d.setVolume(0f);assertEquals("paused",d.state()["status"]);assertEquals(0f,f.level,0f)
        d.setVolume(.8f);assertEquals(id,d.currentId);assertEquals("playing",d.state()["status"]);assertEquals(.8f,f.level,.001f)
    }
    @Test fun focusLossPausesAndGainResumesWithoutReloadOrShuffle() {
        val f=Fake();val d=director(f);racing(d,f);val n=f.loads.size;val id=d.currentId
        d.setFocus(false);assertEquals("waiting",d.state()["status"]);assertEquals(1,f.pauses)
        d.setFocus(true);assertEquals("playing",d.state()["status"]);assertEquals(n,f.loads.size);assertEquals(id,d.currentId)
        d.setDuck(.2f);assertEquals(.07f,f.level,.001f)
    }
    @Test fun noPlaybackOccursWithoutFocusOrInTheBackgroundEvenIfPreparationFinishes() {
        val f=Fake();val d=director(f);d.setActive(true);f.loads.last().ready();assertEquals(0,f.plays)
        d.setActive(false);d.setFocus(true);assertEquals(0,f.plays)
        d.setActive(true);assertEquals(0,f.plays) // The new menu song must prepare first.
        f.loads.last().ready();assertEquals(1,f.plays)
    }
    @Test fun onStopReleasesTheDecoderAndResumeSeeksToTheSavedPosition() {
        val f=Fake();val d=director(f);racing(d,f);val old=f.loads.last();val id=d.currentId
        d.setActive(false);d.suspend();assertEquals(0,f.alive);d.setActive(true)
        assertEquals(id,d.currentId);assertEquals(12345,f.loads.last().seek)
        val before=f.plays;old.ready();old.complete();old.fail();assertEquals(before,f.plays)
        f.loads.last().ready();assertEquals(before+1,f.plays)
    }
    @Test fun obsoleteCallbacksAfterTrackChangesAndCloseNeverRestartAReleasedDecoder() {
        val f=Fake();val d=director(f);racing(d,f);val old=f.loads.last();d.select("race_02");val current=f.loads.last()
        old.ready();old.complete();old.fail();assertEquals("race_02",d.currentId)
        d.close();val n=f.loads.size;current.ready();current.complete();current.fail();d.next();d.setActive(true)
        assertEquals(n,f.loads.size);assertEquals(0,f.alive)
    }
    @Test fun failedSongsAreSkippedAndAnEntirelyFailedLibraryStopsAfterAllRaceAttempts() {
        val f=Fake();f.failLoad=true;val d=director(f);d.setScene("race");active(d)
        assertEquals(ids.size,f.loads.size);assertEquals("error",d.state()["status"]);assertEquals(0,f.alive)
        repeat(100){d.setScene("race")};assertEquals(ids.size,f.loads.size)
        f.failLoad=false;d.next();f.loads.last().ready();assertEquals("playing",d.state()["status"])
    }
    @Test fun aFailedMenuSongNeverSubstitutesARaceSong() {
        val f=Fake();f.failLoad=true;val d=director(f);active(d)
        assertTrue(d.currentId in menus);assertEquals(menus.size,f.loads.size);assertEquals("error",d.state()["status"])
    }
    @Test fun aPreparingSongCanBeSuspendedAndTheObsoleteReadyIsIgnored() {
        val f=Fake();val d=director(f);d.setScene("race");d.setActive(true);d.setFocus(true)
        val old=f.loads.last();d.suspend();old.ready();assertEquals(0,f.plays)
        d.setActive(true);assertEquals(0,f.loads.last().seek);f.loads.last().ready();assertEquals(1,f.plays)
    }
    @Test fun playbackExceptionsSkipAProblematicSongWithoutCrashingTheGame() {
        val f=Fake();val d=director(f);d.setScene("race");active(d);val id=d.currentId
        f.throwPlay=true;f.loads.last().ready();assertNotEquals(id,d.currentId);assertEquals(1,f.peak)
        f.throwPlay=false;f.loads.last().ready();assertEquals("playing",d.state()["status"])
    }
    @Test fun visitingMenusBetweenRacesPreservesTheDeckAndSequentialPosition() {
        val f=Fake();val d=director(f);val played=mutableListOf<String>()
        active(d)
        repeat(ids.size * 3) {
            d.setScene("race");f.loads.last().ready();played.add(d.currentId!!)
            d.setScene("menu");f.loads.last().ready()
        }
        for(i in 0 until ids.size * 3 step ids.size)assertEquals(ids.toSet(),played.subList(i,i+ids.size).toSet())
        for(i in 1 until played.size)assertNotEquals(played[i-1],played[i])
        d.setScene("race");d.select("race_02");f.loads.last().ready();d.setShuffle(false)
        d.setScene("menu");f.loads.last().ready();d.setScene("race")
        assertEquals("race_03",d.currentId)
    }

    @Test fun battleMusicUsesOnlyBattleTracksAndNeverLeaksIntoRaceOrMenu() {
        val f = Fake(); val d = director(f); active(d)
        d.setScene("battle"); f.loads.last().ready()
        repeat(battles.size * 2) {
            assertTrue(d.currentId in battles)
            f.loads.last().complete(); f.loads.last().ready()
        }
        d.setScene("race"); f.loads.last().ready(); assertTrue(d.currentId in ids)
        d.setScene("menu"); f.loads.last().ready(); assertTrue(d.currentId in menus)
    }


    @Test fun coldStartDrawsFromAllFiveMenuSongsEvenWhenRaceShuffleIsOff() {
        val firstSongs = mutableSetOf<String>()
        repeat(100) { seed ->
            val f = Fake()
            val d = MusicDirector(tracks, menus, ids, battles, f, Random(seed))
            d.setShuffle(false); active(d)
            assertTrue(d.currentId in menus)
            firstSongs.add(d.currentId!!)
            d.close()
        }
        assertEquals(menus.toSet(), firstSongs)
    }

    @Test fun eachExplicitMenuEntryUsesTheIndependentShuffleBagWithoutImmediateRepeats() {
        val f = Fake(); val d = director(f)
        d.setShuffle(false); active(d); f.loads.last().ready()
        val played = mutableListOf<String>()
        repeat(menus.size * 4) {
            played.add(d.currentId!!)
            val before = f.loads.size
            d.enterMenu(); f.loads.last().ready()
            assertEquals(before + 1, f.loads.size)
        }
        for (i in played.indices step menus.size)
            assertEquals(menus.toSet(), played.subList(i, i + menus.size).toSet())
        for (i in 1 until played.size) assertNotEquals(played[i - 1], played[i])
        assertFalse(d.shuffle) // Race/battle preference was not overwritten.
        assertEquals(1, f.peak)
    }

    @Test fun returningToTheAppInMenuDrawsANewSongAtTheBeginning() {
        val f = Fake(); val d = director(f); active(d); f.loads.last().ready()
        val old = f.loads.last(); val id = d.currentId
        d.setActive(false); d.suspend(); d.setActive(true)
        assertTrue(d.currentId in menus); assertNotEquals(id, d.currentId)
        assertEquals(0, f.loads.last().seek)
        val n = f.loads.size
        old.ready(); old.complete(); old.fail()
        assertEquals(n, f.loads.size)
        f.loads.last().ready(); assertEquals("playing", d.state()["status"])
        assertEquals(1, f.peak)
    }

    @Test fun repeatedResumeOrMenuUpdatesNeverRestartTheCurrentMenuSong() {
        val f = Fake(); val d = director(f); active(d); f.loads.last().ready()
        val id = d.currentId
        repeat(100) { d.setActive(true); d.setScene("menu"); d.setVolume(.35f) }
        assertEquals(1, f.loads.size); assertEquals(id, d.currentId)
        d.enterMenu(); f.loads.last().ready()
        val nextId = d.currentId
        repeat(100) { d.setScene("menu"); d.setActive(true) }
        assertEquals(2, f.loads.size); assertEquals(nextId, d.currentId)
    }

    @Test fun transientAudioFocusLossDoesNotCountAsANewMenuVisit() {
        val f = Fake(); val d = director(f); active(d); f.loads.last().ready()
        val id = d.currentId
        d.setFocus(false); d.setFocus(true)
        assertEquals(1, f.loads.size); assertEquals(id, d.currentId)
        assertEquals("playing", d.state()["status"])
    }

    @Test fun anExplicitUserPauseIsStillRespectedAfterReopeningTheMenu() {
        val f = Fake(); val d = director(f); active(d); f.loads.last().ready()
        d.setUserPaused(true)
        val plays = f.plays
        d.setActive(false); d.suspend(); d.setActive(true); f.loads.last().ready()
        assertTrue(d.userPaused); assertEquals(plays, f.plays)
        assertEquals("paused", d.state()["status"])
    }

    @Test fun raceShuffleChangesDoNotResetTheMenuBag() {
        val f = Fake(); val d = director(f); active(d); f.loads.last().ready()
        val played = mutableListOf<String>()
        repeat(menus.size * 3) { i ->
            played.add(d.currentId!!)
            d.setShuffle(i % 2 == 0)
            d.enterMenu(); f.loads.last().ready()
        }
        for (i in played.indices step menus.size)
            assertEquals(menus.toSet(), played.subList(i, i + menus.size).toSet())
    }

    @Test fun battleResumeRetainsTheTrackAndSavedPositionInsteadOfDrawingMenuMusic() {
        val f = Fake(); val d = director(f)
        d.setScene("battle"); active(d); f.loads.last().ready()
        val id = d.currentId
        d.setActive(false); d.suspend(); d.setActive(true)
        assertEquals(id, d.currentId); assertEquals(12345, f.loads.last().seek)
        assertTrue(d.currentId in battles)
    }

    @Test fun explicitMenuEntryFromEitherGameplaySceneLoadsExactlyOnce() {
        for (scene in listOf("race", "battle")) {
            val f = Fake(); val d = director(f)
            d.setScene(scene); active(d); f.loads.last().ready()
            val before = f.loads.size
            d.enterMenu(); f.loads.last().ready()
            assertEquals(before + 1, f.loads.size)
            assertTrue(d.currentId in menus); assertEquals("menu", d.scene)
            repeat(20) { d.setScene("menu") }
            assertEquals(before + 1, f.loads.size)
        }
    }

    @Test fun closingTheDirectorAlsoDisablesExplicitMenuEntries() {
        val f = Fake(); val d = director(f); active(d)
        d.close(); val n = f.loads.size
        d.enterMenu(); d.setActive(true)
        assertEquals(n, f.loads.size); assertEquals(0, f.alive)
    }

    @Test fun aNewMenuVisitRetriesFailedMenuMusicWithoutLeakingOtherCategories() {
        val f = Fake(); val d = director(f)
        f.failLoad = true; active(d)
        assertEquals("error", d.state()["status"])
        assertTrue(f.loads.all { it.id in menus })
        f.failLoad = false; d.enterMenu(); f.loads.last().ready()
        assertEquals("playing", d.state()["status"])
        assertTrue(d.currentId in menus)
    }

    @Test fun menuCompletionShufflesEvenWhenRacePlaybackIsSequential() {
        val firstSongs = mutableSetOf<String>()
        repeat(30) { seed ->
            val f = Fake()
            val d = MusicDirector(tracks, menus, ids, battles, f, Random(seed))
            d.setShuffle(false); active(d); f.loads.last().ready()
            d.select(menus.first()); f.loads.last().ready()
            f.loads.last().complete()
            assertTrue(d.currentId in menus); assertNotEquals(menus.first(), d.currentId)
            firstSongs.add(d.currentId!!)
            d.close()
        }
        assertTrue(firstSongs.size > 1)
    }

}
