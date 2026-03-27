package com.example.comparateur_app.data.api.model

import com.google.gson.annotations.SerializedName

data class OffProductResponse(
    @SerializedName("status") val status: Int,
    @SerializedName("product") val product: OffProduct?
)

data class OffProduct(
    @SerializedName("product_name") val productName: String?,
    @SerializedName("brands") val brands: String?,
    @SerializedName("image_url") val imageUrl: String?
)
