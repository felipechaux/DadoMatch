package com.chauxdevapps.dadomatch

import android.app.Application
import com.dadomatch.shared.initKoinAndroid
import com.google.firebase.FirebaseApp

class DadoMatchApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        FirebaseApp.initializeApp(this)
        initKoinAndroid(this)
    }
}
