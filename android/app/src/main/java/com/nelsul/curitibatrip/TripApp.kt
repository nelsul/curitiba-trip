package com.nelsul.curitibatrip

import android.app.Application
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import coil3.request.crossfade
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.TokenStore

class TripApp : Application(), SingletonImageLoader.Factory {
	lateinit var state: AppState
		private set

	override fun onCreate() {
		super.onCreate()
		TokenStore.init(this)
		state = AppState(this)
	}

	/** Photos come from presigned R2 links; Coil caches them (memory + disk) like NukeUI on iOS. */
	override fun newImageLoader(context: PlatformContext) = ImageLoader.Builder(context)
		.components { add(OkHttpNetworkFetcherFactory(callFactory = { Api.client })) }
		.crossfade(true)
		.build()
}
