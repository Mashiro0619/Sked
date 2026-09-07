package com.mashiro.sked

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidAutostartSettingsTest {
    @Test
    fun normalizesManufacturerAndBrandForSupportedVendors() {
        assertEquals(
            "xiaomi",
            AndroidAutostartSettings.profileFor("  Xiaomi ", "Redmi", "com.mashiro.sked").id,
        )
        assertEquals(
            "honor",
            AndroidAutostartSettings.profileFor("HONOR", "", "com.mashiro.sked").id,
        )
        assertEquals(
            "oneplus",
            AndroidAutostartSettings.profileFor("OnePlus", "", "com.mashiro.sked").id,
        )
        assertEquals(
            "oppo",
            AndroidAutostartSettings.profileFor("OPPO", "", "com.mashiro.sked").id,
        )
        assertEquals(
            "oppo",
            AndroidAutostartSettings.profileFor("realme", "", "com.mashiro.sked").id,
        )
        assertEquals(
            "vivo",
            AndroidAutostartSettings.profileFor("vivo", "iQOO", "com.mashiro.sked").id,
        )
    }

    @Test
    fun keepsVendorCandidateOrderForFallbackResolution() {
        val honor = AndroidAutostartSettings.profileFor(
            "Honor",
            "",
            "com.mashiro.sked",
        )
        assertEquals(2, honor.candidates.size)
        assertEquals("com.hihonor.systemmanager", honor.candidates[0].packageName)
        assertEquals("com.huawei.systemmanager", honor.candidates[1].packageName)

        val onePlus = AndroidAutostartSettings.profileFor(
            "OnePlus",
            "",
            "com.mashiro.sked",
        )
        assertEquals(2, onePlus.candidates.size)
        assertEquals("oneplus", onePlus.id)
        assertEquals("com.oneplus.security", onePlus.candidates[0].componentPackage)
        assertEquals(
            "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            onePlus.candidates[0].componentClass,
        )
        assertEquals("com.oneplus.security", onePlus.candidates[1].componentPackage)
        assertEquals(
            "com.oneplus.security.chainlaunch.view.ChainLaunchSettings",
            onePlus.candidates[1].componentClass,
        )

        val oppo = AndroidAutostartSettings.profileFor(
            "OPPO",
            "",
            "com.mashiro.sked",
        )
        assertEquals(2, oppo.candidates.size)
        assertEquals("oppo", oppo.id)
        assertEquals("com.coloros.safecenter", oppo.candidates[0].componentPackage)
        assertEquals("com.oppo.safe", oppo.candidates[1].componentPackage)
    }

    @Test
    fun unsupportedAndSamsungProfilesHaveNoClaimedVendorEntry() {
        val samsung = AndroidAutostartSettings.profileFor(
            "Samsung",
            "Galaxy",
            "com.mashiro.sked",
        )
        assertEquals("samsung", samsung.id)
        assertTrue(samsung.candidates.isEmpty())

        val unknown = AndroidAutostartSettings.profileFor(
            "Generic",
            "AOSP",
            "com.mashiro.sked",
        )
        assertEquals("unknown", unknown.id)
        assertTrue(unknown.candidates.isEmpty())
    }
}
