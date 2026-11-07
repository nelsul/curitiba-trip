package com.nelsul.curitibatrip.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.nelsul.curitibatrip.R

/** Fredoka for titles and buttons, Nunito for text, the same as the web and iOS apps. */
val Fredoka = FontFamily(
	Font(R.font.fredoka_medium, FontWeight.Medium),
	Font(R.font.fredoka_semibold, FontWeight.SemiBold),
)
val Nunito = FontFamily(
	Font(R.font.nunito_regular, FontWeight.Normal),
	Font(R.font.nunito_bold, FontWeight.Bold),
	Font(R.font.nunito_extrabold, FontWeight.ExtraBold),
)

/** Display text (Fredoka). Sizes follow the phone's font-size setting (sp). */
fun display(size: Int, weight: FontWeight = FontWeight.SemiBold) =
	TextStyle(fontFamily = Fredoka, fontWeight = weight, fontSize = size.sp, lineHeight = (size * 1.2).sp)

/** Body text (Nunito). */
fun body(size: Int = 16, weight: FontWeight = FontWeight.Normal) =
	TextStyle(fontFamily = Nunito, fontWeight = weight, fontSize = size.sp, lineHeight = (size * 1.35).sp)
