# Kode Diagram SKPL Doctor Computer (Draw.io / Mermaid)

Dokumen ini berisi **kode diagram saja** dan tidak mengubah dokumen SKPL DOCX.

- BPMN AS-IS: [proses-bisnis-as-is.bpmn](./proses-bisnis-as-is.bpmn)
- BPMN TO-BE: [proses-bisnis-to-be.bpmn](./proses-bisnis-to-be.bpmn)
- BPMN transaksi POS dan sinkronisasi offline: [proses-pos-to-be.bpmn](./proses-pos-to-be.bpmn)

## Cara memakai

- **BPMN AS-IS, TO-BE, dan POS offline:** buka masing-masing file `.bpmn` di Camunda Modeler.
- **DFD, Use Case, Activity, Sequence, Class, ERD:** di diagrams.net/draw.io pilih **Arrange → Insert → Mermaid**, tempel satu blok Mermaid, lalu pilih **Insert**.
- Mermaid tidak memiliki notasi Use Case UML native. Kode Use Case di bawah memakai aktor dan oval use case di dalam batas sistem, sehingga tetap bisa dirender oleh fitur Mermaid di draw.io.
- BPMN merinci keputusan, alur alternatif, aktivitas administrasi, dan penanganan kegagalan push. Proses POS offline dipisahkan agar alur transaksi pelanggan dan POS lebih mudah dibaca.
- Simpan setiap diagram sebagai halaman/berkas terpisah agar mudah diekspor ke PNG, SVG, atau PDF.

Catatan pemodelan: alur mengikuti fitur yang ada pada aplikasi dan skema Supabase. Checkout pelanggan membutuhkan koneksi; mode offline hanya untuk POS kasir/admin. Aplikasi mencatat metode pembayaran, bukan memproses pembayaran melalui payment gateway. Resi dapat dilacak, tetapi tidak ada pelacakan GPS kurir secara live. Notifikasi status pesanan disimpan ke `user_notifications`; webhook Supabase meneruskan event ke Edge Function/FCM untuk push ke perangkat.

---

## DFD Level 0 — Diagram Konteks

```mermaid
flowchart LR
    C[Pelanggan]
    S[Admin dan Kasir]
    AI[Layanan Gemini AI]
    MAP[Layanan Nominatim / OpenStreetMap]
    FCM[Firebase Cloud Messaging]
    SYS(("0<br/>Sistem Doctor Computer"))

    C -->|Akun, pencarian, keranjang, checkout, ulasan| SYS
    SYS -->|Katalog, hasil rakit PC, pesanan, resi, poin, notifikasi| C
    S -->|Data produk, stok, voucher, pesanan, POS, shift| SYS
    SYS -->|Data operasional, status pesanan, laporan| S
    SYS -->|Prompt pencarian dan analisis rakit PC| AI
    AI -->|Hasil rekomendasi / analisis| SYS
    SYS -->|Permintaan geocoding alamat| MAP
    MAP -->|Alamat dan koordinat| SYS
    SYS -->|Token dan payload push status pesanan| FCM
    FCM -->|Hasil pengiriman push| SYS
```

## DFD Level 1 — Proses Utama

```mermaid
flowchart LR
    C[Pelanggan]
    S[Admin dan Kasir]
    AI[Layanan Gemini AI]
    MAP[Layanan Nominatim / OpenStreetMap]
    FCM[Firebase Cloud Messaging]

    P1(("1.0<br/>Akun dan Profil"))
    P2(("2.0<br/>Katalog dan Rakit PC"))
    P3(("3.0<br/>Checkout dan Pesanan"))
    P4(("4.0<br/>POS dan Shift"))
    P5(("5.0<br/>Notifikasi dan Pelacakan"))
    P6(("6.0<br/>Administrasi dan Laporan"))
    P7(("7.0<br/>Member dan Ulasan"))

    D1[(D1 Pengguna)]
    D2[(D2 Katalog dan Komponen PC)]
    D3[(D3 Keranjang dan Wishlist)]
    D4[(D4 Pesanan dan Item Pesanan)]
    D5[(D5 Voucher dan Penukaran)]
    D6[(D6 Shift dan Pemetaan Sinkronisasi POS)]
    D7[(D7 Notifikasi dan Token Push)]
    D8[(D8 Ulasan)]

    C -->|Registrasi, login, profil| P1
    P1 -->|Sesi dan profil| C
    P1 <--> D1

    C -->|Pencarian, pilihan komponen, wishlist| P2
    P2 -->|Produk, stok, hasil kompatibilitas| C
    P2 <--> D2
    P2 <--> D3
    P2 <-->|Prompt dan hasil analisis| AI

    C -->|Alamat, keranjang, metode pembayaran, voucher| P3
    P3 -->|Konfirmasi, status dan resi| C
    P3 -->|Baca stok / harga| D2
    P3 -->|Baca keranjang / voucher| D3
    P3 <--> D5
    P3 <--> D4
    P3 -->|Permintaan geocoding alamat| MAP
    MAP -->|Alamat / koordinat| P3

    S -->|Transaksi, metode pembayaran, buka / tutup shift| P4
    P4 -->|Struk, status shift dan selisih kas| S
    P4 <--> D2
    P4 <--> D4
    P4 <--> D6

    S -->|Perubahan status dan resi| P5
    P5 -->|Status pesanan| C
    P5 <--> D4
    P5 <--> D7
    P5 -->|Permintaan push| FCM
    FCM -->|Hasil pengiriman| P5

    S -->|Perubahan produk, voucher, pengguna, konfigurasi| P6
    P6 -->|Statistik dan data operasional| S
    P6 <--> D1
    P6 <--> D2
    P6 <--> D5
    P6 -->|Baca transaksi online dan POS| D4
    P6 -->|Baca ringkasan shift| D6
    P6 -->|Baca ulasan| D8

    C -->|Ulasan, aktivitas member dan minigame| P7
    P7 -->|Poin, tier, voucher member| C
    P7 <--> D1
    P7 <--> D4
    P7 <--> D5
    P7 <--> D8
```

## DFD Level 2 — Proses 3.0 Checkout dan Pesanan

```mermaid
flowchart LR
    C[Pelanggan]
    S[Admin / Kasir]
    FCM[Firebase Cloud Messaging]

    P31(("3.1<br/>Menerima Data Checkout"))
    P32(("3.2<br/>Memvalidasi Harga, Stok,<br/>Alamat dan Voucher"))
    P33(("3.3<br/>Membuat Pesanan Online"))
    P34(("3.4<br/>Memperbarui Status / Resi"))
    P35(("3.5<br/>Mencatat Notifikasi"))
    P36(("3.6<br/>Mengirim Push"))

    D1[(D1 Pengguna)]
    D2[(D2 Produk dan Stok)]
    D3[(D3 Keranjang)]
    D4[(D4 Voucher)]
    D5[(D5 Pesanan dan Item Pesanan)]
    D6[(D6 user_notifications dan user_push_tokens)]

    C -->|Alamat, kurir, metode pembayaran, kode voucher| P31
    P31 -->|Data checkout| P32
    P32 -->|Baca identitas / alamat| D1
    P32 -->|Baca harga dan stok| D2
    P32 -->|Baca item| D3
    P32 -->|Validasi voucher| D4
    P32 -->|Ringkasan checkout valid| P33
    P32 -->|Kesalahan / item tidak valid| C
    P33 -->|Buat pesanan dan item secara atomik| D5
    P33 -->|Hapus item keranjang setelah berhasil| D3
    P33 -->|Nomor pesanan dan konfirmasi| C

    S -->|Status baru atau nomor resi| P34
    P34 -->|Perubahan status pesanan| D5
    D5 -->|Perubahan status berhasil| P35
    P35 -->|Simpan status, pesan, dan metadata| D6
    P35 -->|Event database untuk webhook| P36
    D6 -->|Token perangkat pengguna| P36
    P36 -->|Kirim push status pesanan| FCM
    FCM -->|Status pengiriman| P36
    P36 -->|Status pesanan terbaru| C
```

## DFD Level 2 — Proses 4.0 POS dan Shift

```mermaid
flowchart LR
    S[Kasir]
    P41(("4.1<br/>Membuka Shift"))
    P42(("4.2<br/>Mencatat Transaksi POS"))
    P43(("4.3<br/>Menyimpan Transaksi Lokal<br/>saat Offline"))
    P44(("4.4<br/>Menyinkronkan Data"))
    P45(("4.5<br/>Menutup Shift"))
    P46(("4.6<br/>Menghitung Selisih Kas"))

    D1[(D1 Produk dan Stok Supabase)]
    D2[(D2 Orders channel POS)]
    D3[(D3 cashier_shifts)]
    D4[(D4 pos_sync_shifts dan pos_sync_orders)]
    L1[(L1 SQLite lokal pada perangkat kasir)]

    S -->|Kas awal dan catatan| P41
    P41 -->|Data shift terbuka| D3
    P41 -->|Shift siap| S

    S -->|Item, jumlah, metode pembayaran| P42
    P42 -->|Permintaan cek stok| D1
    D1 -->|Jumlah stok tersedia| P42
    P42 -->|Jika online: transaksi POS| D2
    P42 -->|Jika offline: transaksi lokal| P43
    P43 -->|Simpan antrean lokal| L1
    L1 -->|Transaksi tertunda saat koneksi pulih| P44
    P44 -->|Sinkronisasi idempoten| D2
    P44 -->|Pemetaan ID lokal ke ID server| D4
    P42 -->|Pembaruan total transaksi| D3
    P42 -->|Struk digital| S

    S -->|Kas akhir dan catatan| P45
    P45 -->|Data shift dan total penjualan| D3
    D3 -->|Kas awal, kas akhir, penjualan| P46
    P46 -->|Selisih kas| D3
    P46 -->|Ringkasan penutupan shift| S
```

## Use Case Diagram

```mermaid
flowchart LR
    Customer[/"Aktor<br/>Pelanggan"/]
    Cashier[/"Aktor<br/>Kasir"/]
    Admin[/"Aktor<br/>Admin"/]

    subgraph DC["Batas Sistem: Doctor Computer"]
        UC01(["UC-01 Registrasi"])
        UC02(["UC-02 Login dan Keamanan Akun"])
        UC03(["UC-03 Kelola Profil"])
        UC04(["UC-04 Telusuri dan Cari Produk"])
        UC05(["UC-05 Rakit PC"])
        UC06(["UC-06 Checkout Pesanan Online"])
        UC07(["UC-07 Lihat Status dan Resi Pesanan"])
        UC08(["UC-08 Beri Ulasan Produk"])
        UC09(["UC-09 Kelola Member dan Minigame"])
        UC10(["UC-10 Gunakan Doctor AI"])
        UC11(["UC-11 Lihat Notifikasi"])
        UC12(["UC-12 Jalankan Transaksi POS"])
        UC13(["UC-13 Kelola Shift Kasir"])
        UC14(["UC-14 Sinkronkan POS Offline"])
        UC15(["UC-15 Kelola Pesanan dan Status"])
        UC16(["UC-16 Kelola Produk dan Flash Sale"])
        UC17(["UC-17 Kelola Voucher, Pengguna, dan Staf"])
        UC18(["UC-18 Lihat Statistik dan Konfigurasi"])
        UC19(["UC-19 Kelola Ulasan"])
    end

    Customer --- UC01
    Customer --- UC02
    Customer --- UC03
    Customer --- UC04
    Customer --- UC05
    Customer --- UC06
    Customer --- UC07
    Customer --- UC08
    Customer --- UC09
    Customer --- UC10
    Customer --- UC11

    Cashier --- UC02
    Cashier --- UC12
    Cashier --- UC13
    Cashier --- UC14
    Cashier --- UC15
    Cashier --- UC19

    Admin --- UC02
    Admin --- UC15
    Admin --- UC16
    Admin --- UC17
    Admin --- UC18
    Admin --- UC19
```

## Activity Diagram UC-02 — Login

```mermaid
flowchart TD
    Start((Mulai))
    Open[Buka aplikasi dan pilih Login]
    Input[Masukkan email dan kata sandi]
    Submit[Kirim kredensial]
    Auth[Supabase Auth memverifikasi kredensial]
    Valid{Kredensial valid?}
    Profile[Ambil profil dan peran pengguna]
    Role{Peran akun?}
    Client[Masuk ke beranda pelanggan]
    Staff[Masuk ke dashboard kasir / admin]
    Error[Tampilkan pesan login gagal]
    Retry{Coba lagi?}
    End((Selesai))

    Start --> Open --> Input --> Submit --> Auth --> Valid
    Valid -- Tidak --> Error --> Retry
    Retry -- Ya --> Input
    Retry -- Tidak --> End
    Valid -- Ya --> Profile --> Role
    Role -- client --> Client --> End
    Role -- cashier / admin --> Staff --> End
```

## Activity Diagram UC-05 — Rakit PC

```mermaid
flowchart TD
    Start((Mulai))
    Open[Buka fitur Rakit PC]
    Load[Muat komponen dan harga]
    Select[Pilih komponen pada 8 slot]
    Check{Slot wajib lengkap?}
    Compat[Validasi kompatibilitas komponen]
    Compatible{Kompatibel?}
    Fix[Pilih ulang komponen yang tidak sesuai]
    Estimate[Hitung total komponen dan biaya rakit]
    Analyze[Analisis bottleneck dengan AI]
    Fallback{Layanan AI tersedia?}
    Local[Gunakan estimasi offline dan beri label]
    Show[Tampilkan build, harga dan analisis]
    Save[Simpan build atau lanjutkan ke checkout]
    End((Selesai))

    Start --> Open --> Load --> Select --> Check
    Check -- Belum --> Select
    Check -- Ya --> Compat --> Compatible
    Compatible -- Tidak --> Fix --> Select
    Compatible -- Ya --> Estimate --> Analyze --> Fallback
    Fallback -- Ya --> Show
    Fallback -- Tidak --> Local --> Show
    Show --> Save --> End
```

## Activity Diagram UC-06 — Checkout Pesanan Online

```mermaid
flowchart TD
    Start((Mulai))
    Cart[Buka keranjang]
    Address[Pilih alamat dan kurir]
    Payment[Pilih metode pembayaran dan voucher]
    Validate[Server validasi harga, stok dan voucher]
    Valid{Valid?}
    Error[Tampilkan alasan checkout gagal]
    Fix[Perbarui keranjang atau data checkout]
    Create[Buat pesanan dan item secara atomik]
    Confirm[Tampilkan nomor dan ringkasan pesanan]
    External[Verifikasi pembayaran dilakukan di luar aplikasi]
    Track[Pantau status dan nomor resi]
    End((Selesai))

    Start --> Cart --> Address --> Payment --> Validate --> Valid
    Valid -- Tidak --> Error --> Fix --> Cart
    Valid -- Ya --> Create --> Confirm --> External --> Track --> End
```

## Activity Diagram UC-12 — Transaksi POS

```mermaid
flowchart TD
    Start((Mulai))
    OpenShift[Kasir membuka shift dan memasukkan kas awal]
    Items[Masukkan item dan jumlah]
    Stock{Stok mencukupi?}
    Error[Tampilkan stok tidak mencukupi]
    Payment[Pilih tunai, QRIS atau debit BCA]
    Online{Perangkat online?}
    Remote[Simpan transaksi POS ke server]
    Local[Simpan transaksi pada SQLite lokal]
    Sync{Koneksi tersedia kembali?}
    Wait[Tandai transaksi menunggu sinkronisasi]
    SyncRemote[Sinkronkan transaksi secara idempoten]
    Receipt[Terbitkan struk digital]
    Close[Kasir memasukkan kas akhir dan menutup shift]
    Reconcile[Hitung selisih kas]
    End((Selesai))

    Start --> OpenShift --> Items --> Stock
    Stock -- Tidak --> Error --> Items
    Stock -- Ya --> Payment --> Online
    Online -- Ya --> Remote --> Receipt
    Online -- Tidak --> Local --> Sync
    Sync -- Belum --> Wait --> Sync
    Sync -- Ya --> SyncRemote --> Receipt
    Receipt --> Close --> Reconcile --> End
```

## Sequence Diagram UC-02 — Login

```mermaid
sequenceDiagram
    actor U as Pengguna
    participant App as Aplikasi Flutter
    participant Auth as Supabase Auth
    participant DB as Supabase Database

    U->>App: Masukkan email dan kata sandi
    App->>Auth: signInWithPassword()
    Auth-->>App: Sesi autentikasi
    App->>DB: Ambil profil users berdasarkan auth.uid()
    DB-->>App: Profil dan role
    alt Kredensial atau profil tidak valid
        App-->>U: Tampilkan pesan gagal
    else Login berhasil
        App-->>U: Buka halaman sesuai role
    end
```

## Sequence Diagram UC-05 — Rakit PC

```mermaid
sequenceDiagram
    actor U as Pelanggan
    participant App as Aplikasi Flutter
    participant Builder as PcBuilderProvider
    participant DB as Supabase Database
    participant AI as GeminiService

    U->>App: Buka Rakit PC
    App->>Builder: Muat komponen
    Builder->>DB: Ambil pc_parts
    DB-->>Builder: Komponen, harga, spesifikasi
    Builder-->>App: Tampilkan daftar komponen
    U->>App: Pilih komponen pada slot
    App->>Builder: Validasi build
    Builder-->>App: Status kompatibilitas dan total biaya
    App->>AI: Minta analisis bottleneck
    alt Gemini tersedia
        AI-->>App: Analisis bottleneck
    else Gemini tidak tersedia
        App->>App: Gunakan estimasi offline berlabel
    end
    App-->>U: Tampilkan hasil build
```

## Sequence Diagram UC-06 — Checkout dan Notifikasi Status

```mermaid
sequenceDiagram
    actor C as Pelanggan
    actor S as Admin / Kasir
    participant App as Aplikasi Flutter
    participant DB as Supabase Database
    participant Hook as Database Trigger / Webhook
    participant Edge as Supabase Edge Function
    participant FCM as Firebase Cloud Messaging

    C->>App: Konfirmasi checkout
    App->>DB: RPC membuat pesanan online
    DB->>DB: Validasi stok, harga, dan voucher lalu simpan order beserta items secara atomik
    alt Checkout ditolak
        DB-->>App: Error validasi
        App-->>C: Tampilkan alasan dan minta koreksi
    else Pesanan dibuat
        DB-->>App: Nomor pesanan dan ringkasan
        App-->>C: Tampilkan konfirmasi
        S->>DB: RPC update_order_status(order_id, status)
        DB->>DB: Update orders.status
        DB->>Hook: Trigger menyimpan user_notifications
        Hook->>Edge: Webhook event notifikasi
        Edge->>DB: Ambil token dari user_push_tokens
        Edge->>FCM: Kirim push ke perangkat pengguna
        FCM-->>Edge: Hasil pengiriman
        App-->>C: Tampilkan status / push notification
    end
```

## Sequence Diagram UC-12 — POS dan Sinkronisasi Offline

```mermaid
sequenceDiagram
    actor K as Kasir
    participant App as Aplikasi Flutter
    participant POS as PosSyncService
    participant SQLite as SQLite lokal
    participant DB as Supabase RPC / Database

    K->>App: Buka shift dan masukkan kas awal
    App->>DB: open_cashier_shift()
    DB-->>App: Data shift aktif
    K->>App: Masukkan item dan metode pembayaran
    App->>POS: Simpan transaksi POS
    alt Perangkat online
        POS->>DB: create_pos_order()
        DB-->>POS: Order POS server
        POS-->>App: Transaksi berhasil
    else Perangkat offline
        POS->>SQLite: Simpan shift / transaksi lokal
        SQLite-->>POS: Data lokal tersimpan
        POS-->>App: Transaksi menunggu sinkronisasi
        Note over POS,DB: Saat koneksi kembali
        POS->>DB: sync_pos_order() dengan ID lokal idempoten
        DB-->>POS: Pemetaan ID lokal dan order server
        POS->>SQLite: Tandai transaksi tersinkron
    end
    K->>App: Tutup shift dan masukkan kas akhir
    App->>DB: close_cashier_shift()
    DB-->>App: Selisih dan ringkasan shift
```

## Class Diagram — Ringkasan Arsitektur Aplikasi

```mermaid
classDiagram
    class AuthProvider
    class ProductProvider
    class OrderProvider
    class PcBuilderProvider
    class NotificationProvider
    class ProductModel
    class UserModel
    class OrderModel
    class CartItemModel
    class PcBuildModel
    class PcPartModel
    class AppNotificationModel
    class PushNotificationService
    class PosSyncService
    class PosLocalDatabaseHelper

    AuthProvider ..> UserModel : memuat profil
    ProductProvider ..> ProductModel : mengelola katalog
    OrderProvider ..> OrderModel : memuat dan membuat order
    OrderProvider ..> CartItemModel : checkout
    PcBuilderProvider ..> PcBuildModel : menyusun build
    PcBuilderProvider ..> PcPartModel : memilih komponen
    NotificationProvider ..> AppNotificationModel : memuat notifikasi
    NotificationProvider ..> PushNotificationService : token dan push
    PosSyncService ..> PosLocalDatabaseHelper : simpan / sinkron lokal
    PosSyncService ..> OrderModel : transaksi POS
```

## ERD — Tabel Utama Supabase dan POS Offline

```mermaid
erDiagram
    USERS {
        varchar id PK
        varchar email
        varchar role
        varchar membership_tier
        integer points
    }
    MEMBERSHIP_TIERS {
        varchar tier PK
        varchar name
        integer required_points
    }
    CATEGORIES {
        varchar id PK
        varchar name
    }
    PRODUCTS {
        varchar id PK
        varchar category_id FK
        varchar name
        numeric price
        integer stock
    }
    CART_ITEMS {
        uuid id PK
        varchar user_id FK
        varchar product_id FK
        integer quantity
    }
    WISHLIST {
        varchar user_id PK
        varchar product_id PK
    }
    PC_PARTS {
        varchar id PK
        varchar category
        varchar name
        numeric price
    }
    PC_BUILDS {
        uuid id PK
        varchar user_id FK
        varchar cpu_id FK
        varchar gpu_id FK
        varchar motherboard_id FK
        varchar ram_id FK
        varchar storage_id FK
        varchar psu_id FK
        varchar case_id FK
        varchar cooler_id FK
        numeric grand_total
    }
    ORDERS {
        varchar id PK
        varchar user_id FK
        varchar cashier_id
        varchar channel
        varchar status
        numeric total_price
        varchar voucher_code
    }
    ORDER_ITEMS {
        uuid id PK
        varchar order_id FK
        varchar product_id FK
        integer quantity
        numeric unit_price
    }
    REVIEWS {
        varchar id PK
        varchar user_id FK
        varchar product_id FK
        varchar order_id FK
        numeric rating
    }
    VOUCHERS {
        uuid id PK
        varchar code
        varchar discount_type
        numeric discount_value
        varchar reward_type
    }
    VOUCHER_REDEMPTIONS {
        uuid id PK
        uuid voucher_id FK
        varchar user_id
        varchar order_id FK
        numeric discount_amount
    }
    CASHIER_SHIFTS {
        uuid id PK
        varchar cashier_id FK
        numeric opening_cash
        numeric closing_cash
        varchar status
    }
    POS_SYNC_SHIFTS {
        varchar cashier_id PK
        uuid local_shift_id PK
        uuid remote_shift_id FK
    }
    POS_SYNC_ORDERS {
        varchar cashier_id PK
        uuid local_order_id PK
        varchar remote_order_id FK
    }
    USER_NOTIFICATIONS {
        text id PK
        varchar user_id FK
        text order_id
        text type
        boolean is_read
    }
    USER_PUSH_TOKENS {
        text token PK
        varchar user_id FK
        text platform
    }

    CATEGORIES ||--o{ PRODUCTS : mengelompokkan
    USERS ||--o{ CART_ITEMS : memiliki
    PRODUCTS ||--o{ CART_ITEMS : dimasukkan
    USERS ||--o{ WISHLIST : memiliki
    PRODUCTS ||--o{ WISHLIST : disukai
    USERS o|--o{ PC_BUILDS : menyimpan
    PC_PARTS o|--o{ PC_BUILDS : mengisi_slot_komponen
    USERS ||--o{ ORDERS : membuat
    ORDERS ||--|{ ORDER_ITEMS : berisi
    PRODUCTS o|--o{ ORDER_ITEMS : dijual
    USERS o|--o{ REVIEWS : menulis
    PRODUCTS ||--o{ REVIEWS : menerima
    ORDERS o|--o{ REVIEWS : menjadi_dasar
    VOUCHERS ||--o{ VOUCHER_REDEMPTIONS : ditukarkan
    ORDERS ||--o| VOUCHER_REDEMPTIONS : menggunakan
    USERS ||--o{ CASHIER_SHIFTS : membuka
    CASHIER_SHIFTS ||--o{ POS_SYNC_SHIFTS : dipetakan_dari_lokal
    USERS ||--o{ POS_SYNC_SHIFTS : disinkronkan_oleh
    ORDERS ||--o| POS_SYNC_ORDERS : dipetakan_dari_lokal
    USERS ||--o{ POS_SYNC_ORDERS : disinkronkan_oleh
    USERS ||--o{ USER_NOTIFICATIONS : menerima
    USERS ||--o{ USER_PUSH_TOKENS : mendaftarkan
```

Catatan ERD:
- Kolom `membership_tier` pada `users` menyimpan tier membership; skema dasar tidak mendeklarasikan foreign key ke `membership_tiers`.
- `user_notifications.order_id` dan `voucher_redemptions.user_id` tidak dideklarasikan sebagai foreign key pada migrasi; hubungan tersebut tidak digambar sebagai relasi fisik.
- `wishlist.user_id` dan `wishlist.product_id`, serta `cashier_id` pada tabel pemetaan POS adalah bagian dari primary key komposit sekaligus foreign key; Mermaid hanya menampilkan satu penanda key per atribut.
- `PC_BUILDS` mempunyai delapan foreign key opsional ke `PC_PARTS`, masing-masing untuk satu slot. Relasi ringkas di diagram mewakili semua slot tersebut.
- `POS_SYNC_*` adalah pemetaan idempotensi antara UUID transaksi SQLite lokal dan baris transaksi/shift server.
