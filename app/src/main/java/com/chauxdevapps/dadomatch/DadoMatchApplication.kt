package com.chauxdevapps.dadomatch

import android.app.Application
import com.dadomatch.shared.initKoin
import org.koin.android.ext.koin.androidContext
import org.koin.android.ext.koin.androidLogger

class DadoMatchApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        initKoin {
            androidContext(this@DadoMatchApplication)
            androidLogger()
        }
    }
}
