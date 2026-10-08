package com.nikara.app

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle

/**
 * Activity de arranque sin UI: su único trabajo es mostrar el `windowBackground` de
 * SplashTheme (degradado + isotipo) y pasar a MainActivity sin animación.
 */
class SplashActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startActivity(Intent(this, MainActivity::class.java))
        finish()
        if (Build.VERSION.SDK_INT >= 34) {
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }
}
