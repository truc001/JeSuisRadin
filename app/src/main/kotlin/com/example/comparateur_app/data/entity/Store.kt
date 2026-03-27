package com.example.comparateur_app.data.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "stores")
data class Store(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val name: String,
    val location: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null
)
