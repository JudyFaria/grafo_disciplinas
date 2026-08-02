import 'package:flutter/material.dart';
import 'screens/tela_principal.dart';

void main() {
  runApp(const MapaMateriasApp());
}

class MapaMateriasApp extends StatelessWidget {
  const MapaMateriasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapa de Materias',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TelaPrincipal(),
    );
  }
}