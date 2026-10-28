# Notifikasi status pesanan

## Database

Jalankan `migrations/20261108_order_push_notifications.sql` di Supabase SQL
Editor setelah migration `20261029_user_notifications.sql`. Status pesanan yang
berubah akan otomatis membuat notifikasi di `user_notifications`; notifikasi
tersimpan meski perangkat pembeli sedang offline.
Jika migration draft sebelumnya sempat dijalankan, migration ini juga menghapus
tabel lokasi live dari draft tersebut.

## Push saat aplikasi tidak dibuka

Supabase menyimpan notifikasi, sedangkan Firebase Cloud Messaging (FCM)
mengirimkannya ke notifikasi sistem di HP. Push memerlukan proyek Firebase;
tanpa konfigurasi Firebase, notifikasi hanya tersimpan di Supabase dan dapat
disinkronkan ketika aplikasi dibuka.

1. Daftarkan aplikasi Android di Firebase dengan application ID
   `com.doctor.computer.app`, lalu simpan `google-services.json` di
   `android/app/`. Plugin Gradle Google Services hanya aktif jika file ini ada.
2. Daftarkan aplikasi iOS dengan bundle identifier `com.example.doctorComputer`,
   aktifkan Firebase Cloud Messaging, dan tambahkan `GoogleService-Info.plist`
   ke target Runner di Xcode.
3. Buat service account Firebase yang diizinkan mengirim pesan FCM. Simpan
   secrets berikut di Supabase; jangan commit nilai rahasia:

   ```text
   FIREBASE_PROJECT_ID
   FIREBASE_CLIENT_EMAIL
   FIREBASE_PRIVATE_KEY
   PUSH_WEBHOOK_SECRET
   ```

   `FIREBASE_PRIVATE_KEY` boleh menggunakan teks literal `\n` untuk baris baru.
   `PUSH_WEBHOOK_SECRET` harus berupa nilai acak yang panjang.

   Contoh perintah dari PowerShell (ganti placeholder dengan nilai proyek):

   ```text
   supabase secrets set FIREBASE_PROJECT_ID="..." FIREBASE_CLIENT_EMAIL="..." FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----" PUSH_WEBHOOK_SECRET="..."
   ```

4. Deploy Edge Function:

   ```text
   supabase functions deploy send-order-push
   ```

5. Di Supabase Dashboard > Database > Webhooks, buat webhook `INSERT` untuk
   `public.user_notifications` ke
   `https://<project-ref>.supabase.co/functions/v1/send-order-push`, dengan
   header `x-webhook-secret` berisi nilai `PUSH_WEBHOOK_SECRET` yang sama.

Alurnya: admin/kasir mengubah status seperti biasa di dashboard; trigger
database menyimpan notifikasi untuk pemilik pesanan; webhook meneruskannya ke
Edge Function; FCM mengirim push ke semua perangkat pembeli yang terdaftar.
Status yang dikirim mencakup diproses, diserahkan ke kurir/dikirim, selesai,
atau dibatalkan. Tidak ada pelacakan atau izin lokasi dalam alur ini.
