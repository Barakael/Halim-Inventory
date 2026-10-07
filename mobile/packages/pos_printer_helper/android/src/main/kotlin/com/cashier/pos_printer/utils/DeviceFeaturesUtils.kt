package com.cashier.pos_printer.utils

import android.os.Build


object DeviceFeaturesUtils {

    fun isSunmi() = Build.BRAND.equals("SUNMI", ignoreCase = true)

    fun isSenraise(): Boolean {
        val brand = Build.BRAND.lowercase()
        val model = Build.MODEL.uppercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        val device = Build.DEVICE.lowercase()
        val product = Build.PRODUCT.lowercase()

        return brand.contains("posh5") ||
            manufacturer.contains("senraise") ||
            brand.contains("senraise") ||
            model.contains("H10") ||
            model in listOf("POS-OS01", "POSP-OS01", "H10", "H10S") ||
            device.contains("h10") ||
            product.contains("h10")
    }

    fun isTelpo() = Build.BRAND.equals("qti", ignoreCase = true) ||
        Build.MODEL in listOf("M8")

}