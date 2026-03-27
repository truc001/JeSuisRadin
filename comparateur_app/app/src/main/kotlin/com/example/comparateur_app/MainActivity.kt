package com.example.comparateur_app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.example.comparateur_app.ui.navigation.MainScreen
import com.example.comparateur_app.ui.theme.ComparateurTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            ComparateurTheme {
                MainScreen()
            }
        }
    }
}
