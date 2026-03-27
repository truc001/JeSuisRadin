package com.example.comparateur_app.util

/**
 * Normalise un prix en fonction de la quantité du produit.
 * Retourne (prixNormalisé, unitéLabel) ou null si le parsing échoue.
 * Ex: price=2.49, quantity="500g" → Pair(0.498, "100g") → afficher "0.50 €/100g"
 */
fun normalizePrice(price: Double, quantity: String?): Pair<Double, String>? {
    if (quantity.isNullOrBlank()) return null
    val q = quantity.trim().lowercase()

    // Multi-pack : "6x330ml", "4x100g", "6 x 33 cl"
    val multipackRegex = Regex("""(\d+(?:[.,]\d+)?)\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*(ml|cl|l|g|kg)""")
    multipackRegex.find(q)?.let { m ->
        val count = m.groupValues[1].replace(',', '.').toDoubleOrNull() ?: return null
        val singleQty = m.groupValues[2].replace(',', '.').toDoubleOrNull() ?: return null
        val unit = m.groupValues[3]
        return computeNormalized(price, count * singleQty, unit)
    }

    // Simple : "500g", "1.5 kg", "75 cl", "1l"
    val simpleRegex = Regex("""(\d+(?:[.,]\d+)?)\s*(ml|cl|l|g|kg)""")
    simpleRegex.find(q)?.let { m ->
        val qty = m.groupValues[1].replace(',', '.').toDoubleOrNull() ?: return null
        val unit = m.groupValues[2]
        return computeNormalized(price, qty, unit)
    }

    return null
}

private fun computeNormalized(price: Double, qty: Double, unit: String): Pair<Double, String>? {
    if (qty <= 0) return null
    return when (unit) {
        "g"  -> Pair(price / qty * 100, "100g")
        "kg" -> Pair(price / (qty * 1000) * 100, "100g")
        "ml" -> Pair(price / qty * 100, "100ml")
        "cl" -> Pair(price / (qty * 10) * 100, "100ml")
        "l"  -> Pair(price / (qty * 1000) * 100, "100ml")
        else -> null
    }
}
