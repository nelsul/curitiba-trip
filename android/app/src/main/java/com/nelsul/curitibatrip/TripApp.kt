package com.nelsul.curitibatrip

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import coil3.video.VideoFrameDecoder
import com.nelsul.curitibatrip.upload.Uploads
import com.nelsul.curitibatrip.data.LocationSharing
import org.maplibre.android.MapLibre
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
		Uploads.init(this)
		LocationSharing.init(this)
		MapLibre.getInstance(this)
		val nm = getSystemService(NotificationManager::class.java)
		nm.createNotificationChannel(NotificationChannel(CHANNEL_UPLOADS, "Envios", NotificationManager.IMPORTANCE_LOW).apply { description = "Progresso dos envios de fotos e vídeos" })
	}

	companion object {
		const val CHANNEL_UPLOADS = "envios"
	}

	/** Photos come from presigned R2 links; Coil caches them (memory + disk) like NukeUI on iOS. */
	override fun newImageLoader(context: PlatformContext) = ImageLoader.Builder(context)
		.components {
			add(OkHttpNetworkFetcherFactory(callFactory = { Api.client }))
			add(VideoFrameDecoder.Factory()) // thumbnails of picked videos
		}
		.crossfade(true)
		.build()
}
