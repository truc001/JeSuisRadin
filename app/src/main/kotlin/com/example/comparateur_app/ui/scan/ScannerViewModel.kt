package com.example.comparateur_app.ui.scan

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.comparateur_app.data.api.OpenFoodFactsApi
import com.example.comparateur_app.data.dao.PriceDao
import com.example.comparateur_app.data.dao.ProductDao
import com.example.comparateur_app.data.dao.StoreDao
import com.example.comparateur_app.data.entity.Price
import com.example.comparateur_app.data.entity.Product
import com.example.comparateur_app.data.entity.Store
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject

@HiltViewModel
class ScannerViewModel @Inject constructor(
    private val productDao: ProductDao,
    private val storeDao: StoreDao,
    private val priceDao: PriceDao,
    private val offApi: OpenFoodFactsApi
) : ViewModel() {

    private val _scannedProduct = MutableStateFlow<Product?>(null)
    val scannedProduct: StateFlow<Product?> = _scannedProduct.asStateFlow()

    private val _scannedBarcode = MutableStateFlow<String?>(null)
    val scannedBarcode: StateFlow<String?> = _scannedBarcode.asStateFlow()

    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching.asStateFlow()

    private val _frameCount = MutableStateFlow(0)
    val frameCount: StateFlow<Int> = _frameCount.asStateFlow()

    private val _offProductName = MutableStateFlow<String?>(null)
    val offProductName: StateFlow<String?> = _offProductName.asStateFlow()

    private val _offBrand = MutableStateFlow<String?>(null)
    val offBrand: StateFlow<String?> = _offBrand.asStateFlow()

    val allStores: StateFlow<List<Store>> = storeDao.getAllStores()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private var lastScannedBarcode: String? = null

    fun onFrameAnalyzed() {
        _frameCount.value++
    }

    fun onBarcodeDetected(barcode: String) {
        if (barcode == lastScannedBarcode || _isSearching.value || _scannedProduct.value != null || _scannedBarcode.value != null) return
        
        lastScannedBarcode = barcode
        _isSearching.value = true
        
        viewModelScope.launch {
            val product = productDao.getProductByBarcode(barcode)
            if (product != null) {
                _scannedProduct.value = product
            } else {
                _scannedBarcode.value = barcode
                fetchOffProduct(barcode)
            }
            _isSearching.value = false
        }
    }

    private suspend fun fetchOffProduct(barcode: String) {
        try {
            val response = offApi.getProductByBarcode(barcode)
            if (response.status == 1 && response.product != null) {
                _offProductName.value = response.product.productName
                _offBrand.value = response.product.brands
            }
        } catch (e: Exception) {
            // Log error or handle failure
        }
    }

    fun resetScannedProduct() {
        _scannedProduct.value = null
        _scannedBarcode.value = null
        _offProductName.value = null
        _offBrand.value = null
        lastScannedBarcode = null
    }

    fun saveNewProductWithPrice(name: String, brand: String?, storeId: Int, priceValue: Double) {
        val barcode = _scannedBarcode.value ?: return
        viewModelScope.launch {
            val id = productDao.insert(Product(name = name, brand = brand, barcode = barcode)).toInt()
            priceDao.insert(
                Price(
                    productId = id,
                    storeId = storeId,
                    price = priceValue,
                    date = Date()
                )
            )
            resetScannedProduct()
        }
    }

    fun addStore(name: String) {
        viewModelScope.launch {
            storeDao.insert(Store(name = name))
        }
    }

    fun addPrice(productId: Int, storeId: Int, priceValue: Double) {
        viewModelScope.launch {
            priceDao.insert(
                Price(
                    productId = productId,
                    storeId = storeId,
                    price = priceValue,
                    date = Date()
                )
            )
            resetScannedProduct()
        }
    }
}
