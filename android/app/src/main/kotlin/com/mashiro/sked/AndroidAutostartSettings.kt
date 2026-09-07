package com.mashiro.sked

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings

/**
 * Best-effort entry points for OEM background-start settings.
 *
 * Android exposes no public cross-vendor API for reading or changing an
 * application's autostart policy. This resolver therefore reports only
 * whether a settings activity can be opened; it never reports that the user
 * granted the policy.
 */
object AndroidAutostartSettings {
    internal data class Candidate(
        val action: String? = null,
        val packageName: String? = null,
        val componentPackage: String? = null,
        val componentClass: String? = null,
        val extras: Map<String, String> = emptyMap(),
    )

    internal data class VendorProfile(
        val id: String,
        val candidates: List<Candidate>,
    )

    private const val TARGET_VENDOR = "vendor"
    private const val TARGET_APPLICATION_DETAILS = "applicationDetails"
    private const val TARGET_UNSUPPORTED = "unsupported"

    fun support(context: Context): Map<String, Any> {
        val profile = profileForDevice(context.packageName)
        val vendorEntryAvailable = profile.candidates.any {
            isResolvable(context, buildIntent(context, it))
        }
        return mapOf(
            "vendorId" to profile.id,
            "vendorEntryAvailable" to vendorEntryAvailable,
            "fallbackAvailable" to isResolvable(context, applicationDetailsIntent(context)),
        )
    }

    fun open(context: Context): Map<String, Any> {
        val profile = profileForDevice(context.packageName)
        for (candidate in profile.candidates) {
            val intent = buildIntent(context, candidate)
            if (isResolvable(context, intent) && launch(context, intent)) {
                return mapOf(
                    "vendorId" to profile.id,
                    "opened" to true,
                    "target" to TARGET_VENDOR,
                )
            }
        }
        val fallback = applicationDetailsIntent(context)
        if (isResolvable(context, fallback) && launch(context, fallback)) {
            return mapOf(
                "vendorId" to profile.id,
                "opened" to true,
                "target" to TARGET_APPLICATION_DETAILS,
            )
        }
        return mapOf(
            "vendorId" to profile.id,
            "opened" to false,
            "target" to TARGET_UNSUPPORTED,
        )
    }

    private fun profileForDevice(packageName: String): VendorProfile = profileFor(
        android.os.Build.MANUFACTURER,
        android.os.Build.BRAND,
        packageName,
    )

    internal fun profileFor(
        rawManufacturer: String,
        rawBrand: String,
        applicationId: String,
    ): VendorProfile {
        val manufacturer = rawManufacturer.normalized()
        val brand = rawBrand.normalized()
        val device = "$manufacturer $brand"
        return when {
            device.contains("xiaomi") || device.contains("redmi") ->
                VendorProfile("xiaomi", listOf(xiaomiCandidate(applicationId)))
            device.contains("huawei") ->
                VendorProfile(
                    "huawei",
                    listOf(huaweiCandidate("com.huawei.systemmanager", applicationId)),
                )
            device.contains("honor") ->
                VendorProfile(
                    "honor",
                    listOf(
                        huaweiCandidate("com.hihonor.systemmanager", applicationId),
                        huaweiCandidate("com.huawei.systemmanager", applicationId),
                    ),
                )
            device.contains("oneplus") ->
                VendorProfile("oneplus", onePlusCandidates())
            device.contains("oppo") || device.contains("realme") ->
                VendorProfile("oppo", oppoCandidates())
            device.contains("vivo") || device.contains("iqoo") ->
                VendorProfile("vivo", vivoCandidates(applicationId))
            device.contains("samsung") -> VendorProfile("samsung", emptyList())
            else -> VendorProfile("unknown", emptyList())
        }
    }

    private fun xiaomiCandidate(applicationId: String): Candidate = Candidate(
        action = "miui.intent.action.OP_AUTO_START",
        packageName = "com.miui.securitycenter",
        extras = mapOf(
            "package_name" to applicationId,
            "packageName" to applicationId,
        ),
    )

    private fun huaweiCandidate(
        systemManagerPackage: String,
        applicationId: String,
    ): Candidate = Candidate(
        action = "huawei.intent.action.HSM_BOOTAPP_MANAGER",
        packageName = systemManagerPackage,
        extras = mapOf("packageName" to applicationId),
    )

    private fun oppoCandidates(): List<Candidate> = listOf(
        Candidate(
            componentPackage = "com.coloros.safecenter",
            componentClass = "com.coloros.safecenter.permission.startup.StartupAppListActivity",
        ),
        Candidate(
            componentPackage = "com.oppo.safe",
            componentClass = "com.oppo.safe.permission.startup.StartupAppListActivity",
        ),
    )

    private fun onePlusCandidates(): List<Candidate> = listOf(
        Candidate(
            componentPackage = "com.oneplus.security",
            componentClass =
                "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
        ),
        Candidate(
            componentPackage = "com.oneplus.security",
            componentClass = "com.oneplus.security.chainlaunch.view.ChainLaunchSettings",
        ),
    )

    private fun vivoCandidates(applicationId: String): List<Candidate> = listOf(
        Candidate(
            componentPackage = "com.iqoo.secure",
            componentClass = "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
        ),
        Candidate(
            componentPackage = "com.vivo.permissionmanager",
            componentClass = "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
        ),
        Candidate(
            componentPackage = "com.vivo.permissionmanager",
            componentClass = "com.vivo.permissionmanager.activity.SoftPermissionDetailActivity",
            extras = mapOf("packagename" to applicationId),
        ),
    )

    private fun buildIntent(context: Context, candidate: Candidate): Intent {
        val intent = when {
            candidate.componentPackage != null && candidate.componentClass != null ->
                Intent().setComponent(
                    ComponentName(candidate.componentPackage, candidate.componentClass),
                )
            candidate.action != null -> Intent(candidate.action).apply {
                candidate.packageName?.let(::setPackage)
            }
            else -> Intent()
        }
        candidate.extras.forEach { (key, value) -> intent.putExtra(key, value) }
        if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return intent
    }

    private fun applicationDetailsIntent(context: Context): Intent = Intent(
        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.parse("package:${context.packageName}"),
    ).also {
        if (context !is Activity) it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    private fun isResolvable(context: Context, intent: Intent): Boolean = try {
        context.packageManager.resolveActivity(
            intent,
            PackageManager.MATCH_DEFAULT_ONLY,
        ) != null
    } catch (_: RuntimeException) {
        false
    }

    private fun launch(context: Context, intent: Intent): Boolean = try {
        context.startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    } catch (_: RuntimeException) {
        false
    }

    private fun String.normalized(): String = trim().lowercase()
}
