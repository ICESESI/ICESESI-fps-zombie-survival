# FPS Zombie Survival (Android)

Projek permulaan game FPS 3D zombie offline menggunakan Godot 4.4 dan GDScript.

## Kandungan
- Pergerakan FPS menggunakan WASD pada PC atau joystick sentuh di Android.
- Serangan zombie secara asas.
- Tembak menggunakan raycast, magazin 12 peluru, reload, HP, skor, wave dan restart.
- Dunia 3D ringkas yang dibina melalui kod.
- GitHub Actions untuk export APK Android ARM64.

## Cara buka dan uji
1. Pasang Godot 4.4.x pada komputer (jika ada) dan Android export templates.
2. Buka folder ini dalam Godot.
3. Tekan F6/F5 untuk menjalankan scene utama.
4. Uji sentuhan pada peranti sebenar selepas export APK.

## Build APK melalui GitHub Actions
1. Buat repository GitHub baharu.
2. Muat naik semua fail dalam ZIP ini ke root repository (termasuk folder `.github`).
3. Pergi ke tab **Actions**.
4. Pilih **Build FPS Zombie APK** dan tekan **Run workflow**; atau push commit ke `main`.
5. Buka run yang selesai dan muat turun artifact **FPS-Zombie-Survival-APK**.
6. Extract artifact dan pasang APK pada Android. Benarkan pemasangan daripada sumber itu jika Android meminta.

## Nota penting
- Ini ialah prototaip playable asas, bukan game siap taraf Free Fire.
- Pastikan GitHub Actions runner/container mempunyai Godot 4.4.1, export templates dan Android SDK/JDK yang serasi. Jika container berubah atau export Android gagal, semak log job.
- `export_presets.cfg` mengandungi preset Android. Untuk penerbitan Play Store, gunakan signing key milik sendiri dan jangan simpan kata laluan signing dalam repository.
- APK tidak memerlukan internet untuk bermain. Workflow GitHub memerlukan internet untuk membina dan memuat turun artifact.
