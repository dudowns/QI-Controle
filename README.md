# 💰 Controle Financeiro

<div align="center">
  
  ![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue?logo=flutter)
  ![Dart](https://img.shields.io/badge/Dart-3.0+-teal?logo=dart)
  ![License](https://img.shields.io/badge/license-MIT-green)
  ![Version](https://img.shields.io/badge/version-1.0.0-purple)
  
  <h3>🚀 Seu app pessoal de finanças com design moderno e performance turbinada!</h3>
  
  <img src="assets/images/splash_logo.png" width="120" height="120">
  
</div>

---

## ✨ **Preview do App**

<div align="center">
  <table>
    <tr>
      <td><img src="screenshots/dashboard.png" width="200" alt="Dashboard"></td>
      <td><img src="screenshots/contas_mes.png" width="200" alt="Contas do Mês"></td>
      <td><img src="screenshots/investimentos.png" width="200" alt="Investimentos"></td>
    </tr>
    <tr>
      <td align="center">📊 Dashboard</td>
      <td align="center">📋 Contas do Mês</td>
      <td align="center">📈 Investimentos</td>
    </tr>
    <tr>
      <td><img src="screenshots/metas.png" width="200" alt="Metas"></td>
      <td><img src="screenshots/proventos.png" width="200" alt="Proventos"></td>
      <td><img src="screenshots/grafico.png" width="200" alt="Gráficos"></td>
    </tr>
    <tr>
      <td align="center">🎯 Metas</td>
      <td align="center">💰 Proventos</td>
      <td align="center">📉 Análise</td>
    </tr>
  </table>
</div>

---

## 🎯 **Funcionalidades**

### ✅ **Já implementado**
- [x] Dashboard com gráficos interativos
- [x] Controle de gastos mensais
- [x] **Contas do Mês** com parcelamento
- [x] Carteira de investimentos (ações, FIIs, renda fixa)
- [x] Proventos e dividendos com notificações
- [x] Metas financeiras com acompanhamento
- [x] Backup e restauração de dados
- [x] Gráficos em pizza e barras
- [x] Tema claro (Windows 11 style)

### 🚧 **Em desenvolvimento**
- [ ] Tema escuro
- [ ] Sincronização com a nuvem
- [ ] Relatórios em PDF
- [ ] Meta de gastos por categoria
- [ ] Multi-moedas

---

## 🛠️ **Tecnologias Utilizadas**

| Categoria | Pacotes |
|-----------|---------|
| 🎨 **UI** | `animate_do`, `glassmorphism`, `shimmer` |
| 📊 **Gráficos** | `fl_chart`, `syncfusion_flutter_charts` |
| 💾 **Banco de Dados** | `sqflite`, `sqflite_common_ffi`, `path_provider` |
| 🔔 **Notificações** | `flutter_local_notifications`, `timezone` |
| 📤 **Exportação** | `csv`, `share_plus` |
| 🌐 **Rede** | `http` (Yahoo Finance API) |
| 🔐 **Segurança** | `crypto`, `cryptography_plus` |
| ⚡ **Performance** | `flutter_native_splash`, `flutter_launcher_icons` |

---

## 🚀 **Como executar**

### **Pré-requisitos**
- Flutter 3.0 ou superior
- Dart 3.0 ou superior
- Git

### **Passos**

```bash
# Clone o repositório
git clone https://github.com/dudowns/controle_financeiro.git

# Entre na pasta
cd controle_financeiro

# Instale as dependências
flutter pub get

# Execute o app
flutter run -d windows  # Para Windows
# ou
flutter run -d chrome   # Para Web
# ou
flutter run -d android  # Para Android