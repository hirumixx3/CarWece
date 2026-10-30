#!/usr/bin/env python3
"""Run the real MusicDirector unit-test methods using Kotlin/JVM without Android.

Requires Java and kotlinc on PATH (or KOTLINC). A small assertion adapter replaces
only the JUnit dependency in a temporary copy of the tests. Production source is
compiled unchanged. This is not Flutter testing, an Android build or device QA.
The normal JUnit tests remain intact for Gradle/GitHub Actions.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'android/app/src/main/kotlin/com/hirumisu/carwece/MusicDirector.kt'
TEST = ROOT / 'android/app/src/test/kotlin/com/hirumisu/carwece/MusicDirectorTest.kt'


def main():
    compiler = os.environ.get('KOTLINC') or shutil.which('kotlinc')
    java = shutil.which('java')
    if not compiler or not java:
        raise SystemExit('Instale Java e Kotlin (kotlinc), ou configure KOTLINC.')
    original = TEST.read_text(encoding='utf-8')
    names = re.findall(r'@Test\s+fun\s+(\w+)\s*\(\s*\)', original)
    if not names or original.count('@Test') != len(names):
        raise SystemExit('Formato de testes não suportado; use JUnit/Gradle.')
    adapted = original.replace('import org.junit.Assert.*\n', '').replace('import org.junit.Test\n', '')
    adapted = re.sub(r'@Test\s+', '', adapted)
    adapter = '''package com.hirumisu.carwece
import kotlin.math.abs
fun assertTrue(value: Boolean) { check(value) { "Expected true" } }
fun assertFalse(value: Boolean) { check(!value) { "Expected false" } }
fun assertEquals(expected: Any?, actual: Any?) {
    check(expected == actual) { "Expected <$expected>, got <$actual>" }
}
fun assertNotEquals(expected: Any?, actual: Any?) {
    check(expected != actual) { "Expected values to differ, both were <$actual>" }
}
fun assertEquals(expected: Float, actual: Float, delta: Float) {
    check(abs(expected - actual) <= delta) { "Expected <$expected>, got <$actual> (delta $delta)" }
}
fun main() {
    var failures = 0
    var passed = 0
'''
    for name in names:
        adapter += f'''    try {{
        MusicDirectorTest().{name}()
        println("PASS {name}"); passed++
    }} catch (error: Throwable) {{
        println("FAIL {name}: ${{error.message}}")
        error.printStackTrace(); failures++
    }}
'''
    adapter += '''    println("Kotlin/JVM standalone: $passed passed; $failures failed.")
    check(failures == 0) { "Music regression failures" }
}
'''
    with tempfile.TemporaryDirectory(prefix='carwece-music-') as tmp:
        out = Path(tmp)
        (out / 'MusicDirectorTest.kt').write_text(adapted, encoding='utf-8')
        (out / 'OfflineMusicTests.kt').write_text(adapter, encoding='utf-8')
        jar = out / 'music-tests.jar'
        subprocess.run([compiler, str(SRC), str(out / 'MusicDirectorTest.kt'),
                        str(out / 'OfflineMusicTests.kt'), '-jvm-target', '17',
                        '-include-runtime', '-d', str(jar)], check=True)
        subprocess.run([java, '-jar', str(jar)], check=True)


if __name__ == '__main__':
    main()
