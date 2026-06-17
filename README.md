# Rastro

Consciência financeira diária — captura automática de gastos via notificações bancárias.

## Stack

| Camada | Tecnologia |
|---|---|
| UI | Flutter 3 + DM Sans (Google Fonts) |
| Estado | Provider |
| Banco de dados | SQLite via sqflite |
| Notificações do sistema | flutter_notification_listener |
| Notificações locais | flutter_local_notifications |

## Estrutura

```
lib/
├── main.dart                        # Entry point, Provider setup
├── theme/
│   └── colors.dart                  # Tokens de cor e tema
├── models/
│   └── transaction.dart             # Model + enum de categorias
├── services/
│   ├── database_service.dart        # CRUD SQLite
│   ├── notification_parser.dart     # Parser regex de notificações bancárias
│   ├── notification_service.dart    # Bridge flutter_notification_listener → DB
│   └── local_notification_service.dart # Alertas e resumo diário
├── providers/
│   └── transaction_provider.dart    # Estado reativo (ChangeNotifier)
├── screens/
│   ├── home_screen.dart             # Dashboard principal
│   └── permission_screen.dart      # Onboarding de permissão
└── widgets/
    ├── shared.dart                  # FmtValue, SectionLabel, RastroCard, CategoryChip
    ├── savings_card.dart            # Card de potencial de economia (grid 2×2 + gráfico)
    ├── transaction_item.dart        # Item da lista de gastos (toggle essencial)
    └── monthly_progress.dart       # Barras de progressão mensal por categoria
```

## Setup

### 1. Pré-requisitos

- Flutter 3.x (`flutter --version`)
- Android SDK (API 26+)

### 2. Instalar dependências

```bash
cd rastro
flutter pub get
```

### 3. Rodar

```bash
flutter run
```

### 4. Permissão de notificações (Android)

O app abre automaticamente a tela de permissão no primeiro uso.
Caminho manual: **Configurações → Notificações → Acesso a notificações → Rastro → Ativar**

Sem essa permissão o `NotificationListenerService` não funciona — é uma limitação do Android por segurança.

## Bancos suportados pelo parser

O `NotificationParser` já identifica padrões de:

- **Nubank** — "Compra aprovada de R$ X em [Loja]"
- **Inter** — "Compra de R$ X aprovada em [Loja]"
- **Bradesco** — "Débito de R$ X no cartão em [Loja]"
- **Itaú** — "Compra realizada: R$ X em [Loja]"
- **C6 Bank** — "Compra aprovada: [Loja] R$ X"
- **PicPay / PagBank** — "Pagamento de R$ X para [Nome]"
- Qualquer app que siga o padrão "R$ XX,XX" + palavra-chave de gasto

Para adicionar um banco novo, edite o mapa `_categoryMap` em `notification_parser.dart`.

## Categorização automática

| Categoria | Exemplos detectados |
|---|---|
| Alimentação | iFood, Rappi, McDonald's, padaria, restaurante |
| Mercado | Pão de Açúcar, Carrefour, Atacadão, supermercado |
| Transporte | Uber, 99, Posto Shell, combustível, metrô |
| Saúde | Farmácia, Drogaria, hospital, clínica |
| Compras | Amazon, Shopee, Mercado Livre, Renner |
| Lazer | Netflix, Spotify, cinema, bar |

## Próximos passos

- [ ] Tela de histórico por período
- [ ] Exportação CSV
- [ ] Widget de tela inicial (Android App Widget)
- [ ] Suporte a múltiplos cartões / contas
- [ ] Metas de gastos por categoria
