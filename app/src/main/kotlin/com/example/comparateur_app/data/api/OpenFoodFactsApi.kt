package com.example.comparateur_app.data.api

import com.example.comparateur_app.data.api.model.OffProductResponse
import retrofit2.http.GET
import retrofit2.http.Path

interface OpenFoodFactsApi {
    @GET("api/v0/product/{barcode}.json")
    suspend fun getProductByBarcode(@Path("barcode") barcode: String): OffProductResponse
}
