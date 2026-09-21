package com.example.flutter_app

import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(
        savedInstanceState: Bundle?
    ) {
        super.onCreate(savedInstanceState)

        hideNavigationBar()
    }

    override fun onWindowFocusChanged(
        hasFocus: Boolean
    ) {
        super.onWindowFocusChanged(
            hasFocus
        )

        if (hasFocus) {
            hideNavigationBar()
        }
    }

    private fun hideNavigationBar() {
        val controller =
            WindowCompat
                .getInsetsController(
                    window,
                    window.decorView
                )

        // Hide only Android's
        // bottom navigation bar.
        controller.hide(
            WindowInsetsCompat.Type
                .navigationBars()
        )

        // Allow the user to swipe
        // up from the bottom to
        // temporarily reveal it.
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat
                .BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }
}