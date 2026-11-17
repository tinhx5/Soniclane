package com.soniclane.app.soniclane

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.RenderMode

class MainActivity: AudioServiceActivity() {
    override fun getBackgroundMode(): BackgroundMode {
        return BackgroundMode.opaque
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }
}
