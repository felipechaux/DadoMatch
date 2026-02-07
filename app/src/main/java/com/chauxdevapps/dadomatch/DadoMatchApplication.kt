package com.chauxdevapps.dadomatch

import android.app.Application
import com.dadomatch.shared.initKoinAndroid

class DadoMatchApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        initKoinAndroid(this)
    }
}
