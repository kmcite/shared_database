package dev.loner.shared_database

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Host APK bundles plugin sources; ensure the method channels are registered.
        flutterEngine.plugins.add(SharedDatabasePlugin())
        flutterEngine.plugins.add(com.mr.flutter.plugin.filepicker.FilePickerPlugin())
    }
}
