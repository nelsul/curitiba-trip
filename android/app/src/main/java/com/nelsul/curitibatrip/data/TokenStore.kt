package com.nelsul.curitibatrip.data

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The session token (the iOS Keychain's job): encrypted with a key that never leaves the Android Keystore,
 * stored in private preferences, and cached in memory.
 */
object TokenStore {
	private const val ALIAS = "session-token"
	private const val PREF = "token"
	private lateinit var prefs: SharedPreferences
	@Volatile private var cached: String? = null

	fun init(context: Context) {
		prefs = context.getSharedPreferences("auth", Context.MODE_PRIVATE)
		cached = prefs.getString(PREF, null)?.let { runCatching { decrypt(it) }.onFailure { e -> Log.w("TokenStore", "unreadable token", e) }.getOrNull() }
	}

	val token: String? get() = cached

	fun save(token: String) {
		cached = token
		prefs.edit().putString(PREF, encrypt(token)).apply()
	}

	fun clear() {
		cached = null
		prefs.edit().remove(PREF).apply()
	}

	private fun key(): SecretKey {
		val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
		(ks.getEntry(ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
		val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
		gen.init(
			KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
				.setBlockModes(KeyProperties.BLOCK_MODE_GCM)
				.setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
				.build(),
		)
		return gen.generateKey()
	}

	private fun encrypt(plain: String): String {
		val c = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
		val out = c.iv + c.doFinal(plain.toByteArray())
		return Base64.encodeToString(out, Base64.NO_WRAP)
	}

	private fun decrypt(stored: String): String {
		val raw = Base64.decode(stored, Base64.NO_WRAP)
		val c = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, raw, 0, 12)) }
		return String(c.doFinal(raw, 12, raw.size - 12))
	}
}
