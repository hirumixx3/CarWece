package com.hirumisu.carwece

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HardwareProfileTest {
    @Test fun galaxyA05sIsLowEnd() {
        assertTrue(HardwareProfile.isLowEnd("SM-A057F", "SM6225", 4096))
        assertTrue(HardwareProfile.isLowEnd("SM-A057M", "", -1))
    }

    @Test fun snapdragon680ClassIsLowEnd() {
        assertTrue(HardwareProfile.isLowEnd("moto g42", "SM6225", 4096))
    }

    @Test fun helioEntryClassNeedsEntryRamToo() {
        assertTrue(HardwareProfile.isLowEnd("Redmi 9", "MT6769", 4096))
        assertFalse(HardwareProfile.isLowEnd("Some Phone", "MT6769", 12288))
    }

    @Test fun capableHardwareIsNotLowEnd() {
        assertFalse(HardwareProfile.isLowEnd("SM-S918B", "SM8550", 12288))
        assertFalse(HardwareProfile.isLowEnd("Pixel 8", "Tensor G3", 8192))
        assertFalse(HardwareProfile.isLowEnd("", "", -1))
    }
}
