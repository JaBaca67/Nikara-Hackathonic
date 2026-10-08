package com.nikara.app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 12+: por defecto el splash del sistema se desvanece al salir y, sobre el mismo
        // isotipo de Flutter, se lee como un fundido cruzado con la N a medio opacar. Quitarlo al
        // instante deja que el relevo sea un corte limpio. API < 31 no tiene este splash.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { it.remove() }
        }
        super.onCreate(savedInstanceState)
    }
}
