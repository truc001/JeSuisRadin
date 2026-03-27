package com.example.comparateur_app.ui.stores

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.comparateur_app.data.dao.StoreDao
import com.example.comparateur_app.data.entity.Store
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class StoreViewModel @Inject constructor(
    private val storeDao: StoreDao
) : ViewModel() {

    val stores: StateFlow<List<Store>> = storeDao.getAllStores()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )

    fun addStore(name: String, location: String? = null) {
        viewModelScope.launch {
            storeDao.insert(Store(name = name, location = location))
        }
    }

    fun deleteStore(store: Store) {
        viewModelScope.launch {
            storeDao.delete(store)
        }
    }
}
